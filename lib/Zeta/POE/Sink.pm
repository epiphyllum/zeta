package Zeta::POE::Sink;
use strict;
use warnings;
use POE;
use Carp;
use POE::Wheel::ListenAccept;
use POE::Filter::Block;
use POE::Wheel::ReadWrite;
use JSON::XS;
use Zeta::Codec::Frame qw/ascii_n binary_n/;
use constant {
    DEBUG => $ENV{ZETA_POE_TCP_DEBUG} || 0,
};

#
# Sink: 
#     1> 只接受客户端消息, 交由callback处理, 
#     2> 然后就不管了, 不应答客户端, 
#
# 应用场景:
#      监控服务器
#

BEGIN {
    require Data::Dump if DEBUG;
}

sub spawn {
    my $class = shift;
    $class->_spawn(@_);
}

#
# 参数方式1:
# (
#    ip      => '192.168.1.10',
#    port    => '9999',
#    module  => 'XXX::Admin',
#    para    => 'xxx.cfg',
#    codec   => ''
# )
# -----------------------------------
# 参数方式2:
# (
#    lfd     => $lfd,
#    module  => 'XXX::Admin',
#    para    => 'xxx.cfg',
#    codec   => '',
# )
# -----------------------------------
# 参数方式3:
# (
#    lfd      => $lfd,
#    callback => \&func,
#    codec    => 'ascii n, binary n, http'
# )
#
sub _spawn {

    my $class = shift;
    my $args  = {@_};
    Data::Dump->dump($args) if DEBUG;

    # 直接提供了lfd
    unless($args->{lfd}) {
        confess "port needed" unless $args->{port};
    }

    my $callback;
    if ($args->{callback}) {
        $callback = $args->{callback};
    }
    else {
        confess "module needed" unless $args->{module};

        # 加载管理模块
        eval "use $args->{module};";
        confess "can not load module[$args->{module}] error[$@]" if $@;

        # 构造管理对象
        my $admin = $args->{module}->new( @{$args->{para}} ) 
          or confess "can not new $args->{module} with " . Data::Dump->dump( $args->{para} );

        $callback = sub {
            $admin->handle(+shift);
        };
    }

    # 过滤器
    my $filter;
    my $fargs;
    unless($args->{codec}) {
        confess "codec is needed";
    }
    if ($args->{codec} =~ /ascii (\d+)/) {
        $filter = 'POE::Filter::Block'; 
        $fargs  = [ LengthCodec => ascii_n($1) ];
        require POE::Filter::HTTPD;
    }
    elsif($args->{codec} =~ /binary (\d+)/) {
        $filter = 'POE::Filter::Block'; 
        $fargs  = [ LengthCodec => binary_n($1) ];
        require POE::Filter::HTTPD;
    }  
    elsif($args->{codec} =~ /http/) {
        $filter = 'POE::Filter::HTTPD';
        $fargs = [];
        require POE::Filter::HTTPD;
    }
    else {
        confess "codec must be either of [ascii N, binary n, http]";
    }

    # 创建POE
    POE::Session->create(
        inline_states => {
            _start => sub {
                $_[HEAP]{la} = POE::Wheel::ListenAccept->new(
                    Handle => $args->{lfd} || IO::Socket::INET->new(
                        LocalPort => $args->{port},
                        Listen    => 5,
                        Proto     => 'tcp',
                        ReuseAddr => 1,
                    ),
                    AcceptEvent => "on_client_accept",
                    ErrorEvent  => "on_server_error",
                );
            },

            # 收到连接请求
            on_client_accept => sub {
                my $cli = $_[ARG0];
                my $w   = POE::Wheel::ReadWrite->new(
                    Handle       => $cli,
                    InputEvent   => 'on_client_input',
                    ErrorEvent   => 'on_client_error',
                    FlushedEvent => 'on_flush',
                    Filter       => $filter->new(@$fargs),
                );
                $_[HEAP]{client} = $w;
            },

            # 收到客户请求
            on_client_input => sub {

                # 接收请求
                eval {
                    my $req = $class->_in($_[ARG0]);
                    warn "recv request: \n" . Data::Dump->dump($req) if DEBUG;
                    my $res = $callback->($req);
                };
                if ($@) {
                   warn "can not process request, error[$@]";
                   delete $_[HEAP]{client}{$_[ARG1]};
                };

            },

            # 客户端错误
            on_client_error => sub {
                delete $_[HEAP]{client};
            },

            # 服务端错误
            on_server_error => sub {
                my ( $op, $errno, $errstr ) = @_[ ARG0, ARG1, ARG2 ];
                warn "Server $op error $errno: $errstr";
                delete $_[HEAP]{server};
            },
        },
    );
}

sub _in {
    my ($class, $in) = @_;
    return $in;
}

sub _out {
    my ($class, $out) = @_;
    return $out;
}


1;

__END__
=head1 NAME


=head1 SYNOPSIS


=head1 API


=head1 Author & Copyright


=cut



