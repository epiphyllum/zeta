package Zeta::POE::Client;
use strict;
use warnings;

use Zeta::Run;
use POE;
use Carp;
use HTTP::Request;
use HTTP::Response;
use POE::Wheel::ListenAccept;
use POE::Filter::Block;
use POE::Wheel::ReadWrite;
use JSON::XS;
use Zeta::Codec::Frame qw/ascii_n binary_n/;
use Data::Dumper;

sub spawn {
    return shift->_spawn(@_);
}

#
#  host => '127.0.0.1',
#  port => 8888,
#  ocb  => \&ocb,   # 发送数据处理
#  icb  => \&icb,   # 接受数据处理
#  codec => 'ascii n, binary n, http, [\&encode, \&decode]',
#  single => 1,
#  debug  => 1,
#
sub _spawn {
    my $class = shift;
    my $args = { @_ };
    
    # 过滤器准备
    my $filter;
    my $fargs;
    my $codec = delete $args->{codec};
    unless($codec) {
        confess "codec is needed";
    }
    if ('ARRAY' eq ref $codec) {
        $filter = 'POE::Filter::Block';
        $fargs  = [ LengthCodec => $codec ];
    }
    else {
        if ($codec =~ /ascii (\d+)/) {
            $filter = 'POE::Filter::Block';
            $fargs  = [ LengthCodec => ascii_n($1) ];
        }
        elsif($codec =~ /binary (\d+)/) {
            $filter = 'POE::Filter::Block';
            $fargs  = [ LengthCodec => binary_n($1) ];
        }
        elsif($codec =~ /http/) {
            $filter = 'POE::Filter::HTTP::Parser';
            $fargs = [];
            require POE::Filter::HTTP::Parser;
        }
        else {
            confess "codec must be either of [ascii N, binary n, http]";
        }
    }
    
    my $ocb    = delete $args->{ocb};
    my $icb    = delete $args->{icb};
    my $single = delete $args->{single};
    my $debug  = delete $args->{debug};
    
    POE::Session->create(
        inline_states => {
            _start => sub {
                
                # 连接服务器
                my $svr = IO::Socket::INET->new("$args->{host}:$args->{port}");
                unless($svr) {
                    die "can not connect to $args->{host}:$args->{port}";
                }
                # binmode $svr, ':encoding(utf8)';                
                my $swheel = POE::Wheel::ReadWrite->new(
                    Handle       => $svr,
                    InputEvent   => 'on_resp',
                    FlushedEvent => 'on_flush',
                    ErrorEvent   => 'on_error',
                    Filter       => $filter->new(@$fargs),
                );
                $_[HEAP]{server} = $swheel;
                $_[KERNEL]->yield('on_loop');
            },
            
            
            # 发送数据
            on_loop => sub {
                my $req = &$ocb();
                $req = $class->_out($args, $req);
                warn "------------------\nsend req: \n------------------\n" . Dumper($req) if $debug;
                $_[HEAP]{server}->put($req);
            },

            on_resp => sub {
                my ( $res, $wid ) = @_[ ARG0, ARG1 ];
                warn "------------------\nrecv res: \n------------------\n" . Dumper($res) if $debug;
                my $resp = $class->_in($args,$res);
                &$icb($resp);
                
                # 只作一次
                if ($single) {
                    exit 0;
                }
                else {
                    warn "begin next loop..." if $debug;
                    $_[KERNEL]->yield('on_loop');
                }
            },
            
            on_error => sub {
                delete $_[HEAP]{server};
            },

            on_flush => sub {
                # warn "request is sent";
            },
        },
    );
}

sub _in {
    my ($class, $args, $in) = @_;
    return $in;
}

sub _out {
    my ($class, $args, $out) = @_;
    return $out;
}

1;

__END__

