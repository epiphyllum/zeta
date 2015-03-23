package Zeta::POE::TCPD;
use strict;
use warnings;

use POE;
use Carp;

use POE::Wheel::ListenAccept;
use POE::Filter::Block;
use POE::Wheel::ReadWrite;
use JSON::XS;
use Zeta::Codec::Frame qw/ascii_n binary_n/;
use Data::Dumper;

sub spawn {
    my $class = shift;
    return $class->_spawn(@_);
}

#
# 参数方式1:
# (
#    ip      => '192.168.1.10',
#    port    => '9999',
#
#    module  => 'XXX::Admin',
#    para    => 'xxx.cfg',
#    codec   => 'ascii 4, binary 2, http, [\&encode, \&decode]'
#    alias   => 'tcpd'
#    events  => {
#        event => sub {},
#    },
#    permanent => 1,       # 长连接
#    debug   => 1, 
# )
# -----------------------------------
# 参数方式2:
# (
#    lfd     => $lfd,
#
#    module  => 'XXX::Admin',
#    para    => 'xxx.cfg',
#
#    codec   => '',
#    alias   => 'tcpd'
#    events  => {
#        event => sub {},
#    },
#    permanent => 1,       # 长连接
#    debug   => 1, 
# )
# -----------------------------------
# 参数方式3:
# (
#    lfd      => $lfd,
#
#    callback => \&func,
#    context  => $context,
#
#    codec    => 'ascii n, binary n, http',
#    alias   => 'tcpd',
#
#    events  => {
#        event => sub {},
#    },
#    permanent => 1,       # 长连接
#    debug   => 1, 
# )
#
sub _spawn {

    my $class = shift;
    my $args  = {@_};
    # warn Dumper($args);

    # 其他事件处理注册
    my $events = delete $args->{events};

    my $debug     = delete $args->{debug};
    my $permanent = delete $args->{permanent} || 0;

    # 直接提供了lfd
    unless($args->{lfd}) {
        confess "port needed" unless $args->{port};
    }

    # 回调函数准备
    my $callback;
    my $ctx;
    if ($args->{callback}) {
        $callback = $args->{callback};
        $ctx      = $args->{context};
    }
    else {
        confess "module needed" unless $args->{module};

        # 加载管理模块
        eval "use $args->{module};";
        confess "can not load module[$args->{module}] error[$@]" if $@;

        # 构造管理对象
        my $para = delete $args->{para};
        $ctx = $args->{module}->new( @{$para} ) 
          or confess "can not new $args->{module} with " . Dumper( $para );

        $callback = \&{"$args->{module}::handle"};
    }

    # 过滤器准备
    my $filter;
    my $fargs;
    my $codec = delete $args->{codec};
    unless($codec) {
        confess "codec is needed";
    }

    if ('ARRAY' eq  ref $codec) {
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
            $filter = 'POE::Filter::HTTPD';
            $fargs = [];
            require POE::Filter::HTTPD;
        }
        else {
            confess "codec must be either of [ascii N, binary n, http]";
        }
    }
    

    # 创建POE
    my @events = () || %$events if $events;
    my $lfd = delete $args->{lfd};
    my $port = delete $args->{port};
    
    return POE::Session->create(
        inline_states => {
            _start => sub {
                $_[KERNEL]->alias_set(delete $args->{alias} || 'tcpd');
                $lfd ||= IO::Socket::INET->new(
                    LocalPort => $port,
                    Listen    => 5,
                    Proto     => 'tcp',
                    ReuseAddr => 1,
                );
                            
                $_[HEAP]{la} = POE::Wheel::ListenAccept->new(
                    Handle      => $lfd,
                    AcceptEvent => "on_client_accept",
                    ErrorEvent  => "on_server_error",
                );
            },

            # 用户提供事件处理
            @events,

            # 收到连接请求
            on_client_accept => sub {
                my $cli = $_[ARG0];
                # binmode $cli, ':encoding(utf8)';
                my $w   = POE::Wheel::ReadWrite->new(
                    Handle       => $cli,
                    InputEvent   => 'on_client_input',
                    ErrorEvent   => 'on_client_error',
                    FlushedEvent => 'on_flush',
                    Filter       => $filter->new(@$fargs),
                );
                $_[HEAP]{client}{$w->ID()} = $w;
            },

            # 收到客户请求
            on_client_input => sub {

                # 接收请求
                eval {
                    warn "recv request: \n" . Dumper($_[ARG0])  if $debug;
                    my $req = $class->_in($args, $_[ARG0]);
                    # warn "recv request: \n" . Dumper($req)  if $debug;
                    
                    # 回调处理
                    my $res = $callback->($ctx, $req); 
                    # warn "result: " . Dumper($res) if $debug;
                                       
                    $res = $class->_out($args, $res);
                    warn "send response: \n"  . Dumper($res) if $debug;
                
                    $_[HEAP]{client}{$_[ARG1]}->put($res);
                };
                if ($@) {
                   warn "can not process request, error[$@]";
                   delete $_[HEAP]{client}{$_[ARG1]};
                };

            },

            # 客户端错误
            on_client_error => sub {
                my $id = $_[ARG3];
                delete $_[HEAP]{client}{$id};
            },

            # 服务端错误
            on_server_error => sub {
                my ( $op, $errno, $errstr ) = @_[ ARG0, ARG1, ARG2 ];
                warn "Server $op error $errno: $errstr";
                delete $_[HEAP]{server};
            },

            # 发送完毕
            on_flush => sub {
                warn "on_flush permanent[$permanent]" if $debug;
                unless($permanent) {
                    delete $_[HEAP]{client}{$_[ARG0]};
                }
            }
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

=head1 NAME


=head1 SYNOPSIS


=head1 API


=head1 Author & Copyright


=cut


