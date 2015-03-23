package Zeta::Comet::SI;

##############################
# 单工双链 长连接
##############################

use strict;
use warnings;

use POE;
use POE::Wheel::ReadWrite;
use POE::Wheel::ListenAccept;
use POE::Filter::Block;
use IO::Socket::INET;
use Zeta::Codec::Frame;

############################################
# args:
#----------------------------
# name        => 机构名称
# idx         =>
# localaddr   => 远端ip
# localport   => 远端端口
# remoteaddr  => 远端ip
# remoteport  => 远端端口

# codec       => ins 4 | nac 2
# interval    => 检测周期
# timeout     => 超时时间
# check       => 检测报文
############################################
sub spawn {

    my $class = shift;

    my $logger = shift;
    my $config = shift;
    $config->{class} = $class;

    POE::Session->create(
        'package_states' => [
            $class => {
                _start            => 'on_start',
                on_setup          => 'on_setup',
                on_accept         => 'on_accept',
                on_la_error       => 'on_la_error',
                on_connect        => 'on_connect',
                on_remote_data    => 'on_remote_data',     # 收到客户端数据
                on_adapter_data   => 'on_adapter_data',    # switch中心post数据到机构
                on_socket_error   => 'on_socket_error',
                on_check          => 'on_check',
                on_timeout        => 'on_timeout',
                on_notify_adapter => 'on_notify_adapter',
            }
        ],
        args => [ $logger, $config ],
    );
    return $config->{name} . "." . $config->{idx};
}

#############################################
# 1> set alias
# 2> yield to on_setup
#############################################
sub on_start {

    $_[HEAP]{logger} = $_[ARG0];
    $_[HEAP]{config} = $_[ARG1];
    $_[HEAP]{class}  = delete $_[HEAP]{config}{class};
    $_[KERNEL]
      ->alias_set( $_[HEAP]{config}{name} . "." . $_[HEAP]{config}{idx} );

    #
    # 过滤器codec
    #
    if ( $_[HEAP]{config}{codec} ) {
        if ( $_[HEAP]{config}{codec} =~ /ins\s+(\d+)/ ) {
            $_[HEAP]{filter} = "POE::Filter::Block";
            $_[HEAP]{fargs} = [ LengthCodec => &ascii_n($1) ],;
        }
        elsif ( $_[HEAP]{config}{codec} =~ /nac\s+(\d+)/ ) {
            $_[HEAP]{filter} = "POE::Filter::Block";
            $_[HEAP]{fargs} = [ LengthCodec => &binary_n($1) ],;
        }
        else {
        }
    }

    #
    # 子类定制初始化
    #
    unless ( $_[HEAP]{class}->_on_start( $_[HEAP], $_[KERNEL] ) ) {
        $_[HEAP]{logger}->error("can not _on_start");
        $_[KERNEL]->delay( '_start' => 4 );
        return 1;
    }

    #
    # 子类定制初始化后， 仍然没有设置好filter fargs
    #
    unless ( $_[HEAP]{filter} && $_[HEAP]{fargs} ) {
        $_[HEAP]{logger}->error("filter and fargs still not setup");
        die "filter and fargs still not setup"; 
    }

    $_[KERNEL]->yield('on_setup');
}

#############################################
# 1> setup LA-wheel
# 2> yield to on_connect
#############################################
sub on_setup {

    my $logger = $_[HEAP]{logger};
    my $config = $_[HEAP]{config};

    #
    # 通知session leave, 这里的if条件表明不是从_start过来， 也不是从on_setup过来
    #
    if ( $_[CALLER_STATE] ne '_start' && $_[CALLER_STATE] ne 'on_setup' ) {
        $logger->warn("line[$_[HEAP]{config}->{idx}] leaved");
        $_[KERNEL]->post( 'adapter', 'on_session_leave', [ $config->{name}, $config->{idx} ] );
    }

    #
    # 清理wheel, 定时器
    #
    delete $_[HEAP]{in};
    delete $_[HEAP]{out};
    $_[KERNEL]->alarm_remove( $_[HEAP]{timeout_id} ) if $_[HEAP]{timeout_id};      # 超时ID
    $_[KERNEL]->alarm_remove( $_[HEAP]{check_id} )   if $_[HEAP]{check_id};        # 定期检查ID

    #
    # listen accept
    #
    my $la_socket = IO::Socket::INET->new(
        LocalAddr => $config->{localaddr},
        LocalPort => $config->{localport},
        Listen    => 5,
        ReuseAddr => 1,
    );
    unless ($la_socket) {
        $logger->error( "can not create LA socket[$config->{localaddr}:$config->{localport}]");
        $_[KERNEL]->delay( 'on_setup' => 2 );
    }
    my $la = POE::Wheel::ListenAccept->new(
        Handle      => $la_socket,
        AcceptEvent => 'on_accept',
        ErrorEvent  => 'on_la_error',
    );
    unless ($la) {
        $logger->error("can not create la wheel");
        $_[KERNEL]->delay( 'on_setup' => 2 );
        return;
    }
    $_[HEAP]{la} = $la;

    $_[KERNEL]->yield('on_connect');

}

#############################################
# 等待机构连接
#############################################
sub on_accept {

    my $config = $_[HEAP]{config};
    my $logger = $_[HEAP]{logger};

    $logger->debug("on_accept is called");

    delete $_[HEAP]{la};

    #
    # 过滤器
    #
    my $filter;
    if ( $_[HEAP]{filter} ) {
        $filter = $_[HEAP]{filter}->new( @{ $_[HEAP]{fargs} } );
    }
    else {
        $filter = POE::Filter::Stream->new();
    }

    # wheel
    my $in = POE::Wheel::ReadWrite->new(
        Handle     => $_[ARG0],
        ErrorEvent => 'on_socket_error',
        InputEvent => 'on_remote_data',
        Filter     => $filter,
    );
    unless ($in) {
        $logger->error("can not create rw wheel");
        $_[KERNEL]->delay( 'on_setup' => 2 );
        return;
    }
    $_[HEAP]{in} = $in;

    # 超时检测
    if ( $_[HEAP]{config}{timeout} ) {
        $_[HEAP]{timeout_id} =
          $_[KERNEL]
          ->alarm_set( 'on_timeout' => $_[HEAP]{config}{timeout} + time() );
    }
    $logger->debug(">>>>>>>>>>>>>>>begin service now...");

    return 1;
}

#############################################
# 连接到机构
##############################################
sub on_connect {

    my $config = $_[HEAP]{config};
    my $logger = $_[HEAP]{logger};

    #
    # 连接到远端
    #
    $logger->info("begin connect to [$config->{remoteaddr}:$config->{remoteport}]");
    my $out_sock = IO::Socket::INET->new(
        PeerHost => $config->{remoteaddr},
        PeerPort => $config->{remoteport},
    );
    unless ($out_sock) {
        $logger->error( "can not connect to [$config->{remoteaddr}:$config->{remoteport}]"); $_[KERNEL]->delay( 'on_connect' => 2 );
        return 1;
    }
    $logger->debug("connected to client[$config->{remoteaddr}:$config->{remoteport}]");

    #
    # 过滤器
    #
    my $filter;
    if ( $_[HEAP]{filter} ) {
        $filter = $_[HEAP]{filter}->new( @{ $_[HEAP]{fargs} } );
    }
    else {
        $filter = POE::Filter::Stream->new();
    }

    #
    # wheel
    #
    my $out = POE::Wheel::ReadWrite->new(
        Handle     => $out_sock,
        ErrorEvent => 'on_socket_error',
        Filter     => $filter,
    );
    unless ($out) {
        $logger->error("can not create rw wheel");
        $_[KERNEL]->delay( 'on_connect' => 2 );
        return 1;
    }
    $_[HEAP]{out} = $out;

    # 报文检测
    if ( $_[HEAP]{config}{interval} ) {
        $_[HEAP]{check_id} = $_[KERNEL]->alarm_set('on_check' => $_[HEAP]{config}{interval}+time());
    }

    $logger->debug(">>>>>>>>>>>>>>>begin service now...");

    # 连上对端后， loop检查是否都协商好，
    $_[KERNEL]->yield('on_notify_adapter');

    return 1;
}

#############################################
# on_connect后， 定期检查是否双向连接好
# 通知adapter session line join
#############################################
sub on_notify_adapter {

    if ( $_[HEAP]{out} && $_[HEAP]{in} ) {
        my $config = $_[HEAP]{config};
        $_[KERNEL]->post( 'adapter', 'on_session_join', [ $config->{name}, $config->{idx} ] );
    }
    else {
        $_[KERNEL]->delay( 'on_notify_adapter' => 1 );
    }

    return 1;
}

#############################################
# 发送检测报文
#############################################
sub on_check {

    if ( $_[HEAP]{check_id} ) {
        $_[KERNEL]->alarm_remove( $_[HEAP]{check_id} );
        $_[HEAP]{check_id} = $_[KERNEL]->alarm_set( 'on_check' => $_[HEAP]{config}{interval} + time() );
    }

    $_[HEAP]{logger}->debug("snd checkdata");
    $_[HEAP]{out}->put("");
    return 1;
}

#############################################
#
#############################################
sub on_timeout {
    $_[HEAP]{logger}->warn("on_timeout called");
    $_[KERNEL]->yield('on_setup');
}

#############################################
# 从客户端得到数据, 发送给switch
#############################################
sub on_remote_data {

    #
    # 重置超时时间
    #
    if ( $_[HEAP]{timeout_id} ) {
        $_[KERNEL]->alarm_remove( $_[HEAP]{timeout_id} );
        $_[HEAP]{timeout_id} = $_[KERNEL]->alarm_set('on_timeout' => $_[HEAP]{config}{timeout}+time());
    }

    # $_[HEAP]{logger}->debug("on_remoete data got[$_[ARG0]]");

    unless ( $_[ARG0] ) {
        $_[HEAP]{logger}->debug("got checkdata");
        return 1;
    }

    # socket 日志
    # my $len = length $_[ARG0];
    # $_[HEAP]{logger}->debug("recv data\n  length : [$len]");
    # $_[HEAP]{logger}->debug_hex($_[ARG0]);

    # 发送给adapter session
    $_[KERNEL]->post(
        'adapter',
        'on_remote_data',
        {
            src    => $_[HEAP]{config}->{name},
            packet => $_[HEAP]{class}->_packet($_[HEAP], $_[ARG0]),
        }
    );

    return 1;
}

#############################################
# 从adapter得到数据, 发送给机构
#############################################
sub on_adapter_data {

    my $logger = $_[HEAP]{logger};
    # $logger->debug( "got adapter data:\n" . Data::Dump->dump( $_[ARG0] ) );

    # socket 日志
    # my $len = length $_[ARG0]->{packet};;
    # $_[HEAP]{logger}->debug("send data\n  length : [$len]");
    # $_[HEAP]{logger}->debug_hex($_[ARG0]->{packet});

    # 发送数据到机构
    my $packet = $_[HEAP]{class}->_adapter($_[HEAP], $_[ARG0]);
    $_[HEAP]{out}->put( $packet ) if $_[HEAP]{out} && $packet;

    # 重置check
    if ( $_[HEAP]{check_id} ) {
        $_[KERNEL]->alarm_remove( $_[HEAP]{check_id} );
        $_[HEAP]{check_id} = $_[KERNEL]->alarm_set( 'on_check' => $_[HEAP]{config}{interval} + time() );
    }

}

#############################################
# socket读写发生错误
#############################################
sub on_socket_error {
    my ( $operation, $errnum, $errstr, $id ) = @_[ ARG0 .. ARG3 ];
    $_[HEAP]{logger}->warn(
        "on_socket_error op[$operation] errnum[$errnum] errstr[$errstr] id[$id]"
    );
    $_[KERNEL]->yield('on_setup');
}

#############################################
# listen accept error
#############################################
sub on_la_error {

    my ( $operation, $errnum, $errstr ) = @_[ ARG0, ARG1, ARG2 ];
    $_[HEAP]{logger}->error("listen-accept error: operation[$operation] error[$errnum: $errstr]");
    delete $_[HEAP]{la};
    delete $_[HEAP]{in};
    $_[KERNEL]->yield('on_setup');

}

################################################################
# hook && filter
################################################################
#
#
#
sub _on_start {
    my ( $class, $heap, $kernel, $args ) = @_;
    return 1;
}

#
#
#
sub _on_connect {
    my ( $class, $heap, $kernel ) = @_;
    return 1;
}

#
#
#
sub _on_accept {
    my ( $class, $heap, $kernel ) = @_;
    return 1;
}

#
#
#
sub _packet {
    my $class = shift;
    my $heap  = shift;
    my $rd    = shift;
    $heap->{logger}->debug_hex("recv data<<<<<<<<:", $rd);
    return $rd;
}

#
#
#
sub _adapter {
    my $class = shift;
    my $heap  = shift;
    my $ad    = shift;
    $heap->{logger}->debug_hex("send data>>>>>>>>:", $ad->{packet});
    return $ad->{packet};
}

1;

