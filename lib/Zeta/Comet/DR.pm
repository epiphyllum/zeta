package Zeta::Comet::DR;

use strict;
use warnings;

###########################
# 双工长连接 被动
###########################

use POE;
use IO::Socket::INET;
use POE::Wheel::ReadWrite;
use POE::Wheel::ListenAccept;
use POE::Filter::Block;
use Zeta::Codec::Frame;

############################################
# args:
#----------------------------
# name        => 机构名称
# localaddr   => 远端ip
# localport   => 远端端口
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
                _start          => 'on_start',
                on_setup        => 'on_setup',
                on_accept       => 'on_accept',
                on_la_error     => 'on_la_error',
                on_remote_data  => 'on_remote_data',     # 收到客户端数据
                on_adapter_data => 'on_adapter_data',    # switch中心post数据到机构
                on_socket_error => 'on_socket_error',
                on_check        => 'on_check',
                on_timeout      => 'on_timeout',
            }
        ],
        args => [ $logger, $config ],
    );
    return $config->{name} . "." . $config->{idx};
}

#
#
#
sub on_start {

    delete $_[HEAP]{da};

    $_[HEAP]{logger} = $_[ARG0];
    $_[HEAP]{config} = $_[ARG1];
    $_[HEAP]{class}  = delete $_[HEAP]{config}->{class};
    $_[KERNEL]->alias_set( $_[HEAP]{config}->{name} . "." . $_[HEAP]{config}->{idx} );

    if ( $_[HEAP]{config}->{codec} ) {
        if ( $_[HEAP]{config}->{codec} =~ /ins\s+(\d+)/ ) {
            $_[HEAP]{filter} = "POE::Filter::Block";
            $_[HEAP]{fargs} = [ LengthCodec => &ascii_n($1) ],;
        }
        elsif ( $_[HEAP]{config}->{codec} =~ /nac\s+(\d+)/ ) {
            $_[HEAP]{filter} = "POE::Filter::Block";
            $_[HEAP]{fargs} = [ LengthCodec => &binary_n($1) ],;
        }
        else {
        }
    }

    $_[KERNEL]->yield('on_setup');

}

#############################################
# 1> LA-wheel creation
# 2>
#############################################
sub on_setup {

    my $logger = $_[HEAP]{logger};
    my $config = $_[HEAP]{config};

    #
    # 定制初始化
    #
    unless ( $_[HEAP]{class}->_on_start( $_[HEAP], $_[KERNEL] ) ) {
        $_[HEAP]{logger}->error("can not _on_start");
        $_[KERNEL]->delay( 'on_setup', 4 );
        return 1;
    }

    #
    # 过滤器检查
    #
    unless ( $_[HEAP]{filter} && $_[HEAP]{fargs} ) {
        $_[HEAP]{logger}->error("filter and fargs still not setup");
        exit 0;
    }

    #
    # 通知session line leave
    #
    if ( $_[CALLER_STATE] ne '_start' && $_[CALLER_STATE] ne 'on_setup' ) {
        $logger->warn("line[$config->{idx}] leaved state[$_[CALLER_STATE]]");
        $_[KERNEL]->post( 'adapter', 'on_session_leave', [ $config->{name}, $config->{idx} ] );
    }

    delete $_[HEAP]{dr};
    $_[KERNEL]->alarm_remove_all();

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
        $_[KERNEL]->delay( 'on_setup' => 2 );  # 2秒后再试
        return;
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

    return 1;

}

#############################################
# 等待机构连接
#############################################
sub on_accept {

    my $config = $_[HEAP]{config};
    my $logger = $_[HEAP]{logger};

    $logger->debug("on_accept is called");

    #
    # 机构连接上以后， LA就不需要了
    #
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
    my $dr = POE::Wheel::ReadWrite->new(
        Handle     => $_[ARG0],
        ErrorEvent => 'on_socket_error',
        InputEvent => 'on_remote_data',
        Filter     => $filter,
    );
    unless ($dr) {
        $logger->error("can not create rw wheel");
        $_[KERNEL]->delay( 'on_setup' => 2 );
        return 1;
    }
    $_[HEAP]{dr} = $dr;
    $logger->debug(">>>>>>>>>>>>>>>begin service now...");

    #
    # 报文检测
    #
    if ( $_[HEAP]{config}{interval} ) {
        $_[HEAP]{check_id} = $_[KERNEL]->alarm_set( 'on_check' => $_[HEAP]{config}{interval}+time() );
    }

    #
    # 超时检测
    #
    if ( $_[HEAP]{config}{timeout} ) {
        $_[HEAP]{timeout_id} = $_[KERNEL]->alarm_set('on_timeout' => $_[HEAP]{config}{timeout}+time());
    }

    #
    # _on_accept 返回值含义:
    # undef : _on_accept 调用error
    # 1     : 子类负责管理session join/leave
    # 0     : 父类管理session join/leave
    #
    my $rtn = $_[HEAP]{class}->_on_accept( $_[HEAP], $_[KERNEL] );
    unless ( defined $rtn ) {
        $_[KERNEL]->yield('on_destroy');
        return 1;
    }
    else {
        unless ($rtn) {
            $_[KERNEL]->post( 'adapter', 'on_session_join', [ $_[HEAP]{config}{name}, $_[HEAP]{config}{idx} ] );
        }
    }
    return 1;
}

#############################################
# 测试定时发送
#############################################
sub on_tick {

    $_[HEAP]{logger}->debug("on_tick is called");
    $_[HEAP]{dr}->put('');

    #
    if ( $_[HEAP]{check_id} ) {
        $_[KERNEL]->alarm_remove( $_[HEAP]{check_id} );
        $_[HEAP]{check_id} = $_[KERNEL]->alarm_set( 'on_check' => $_[HEAP]{config}{interval} + time() );
    }

    $_[KERNEL]->delay( 'on_tick' => 4 );
}

#############################################
# 发送检测报文
#############################################
sub on_check {

    if ( $_[HEAP]{check_id} ) {
        $_[KERNEL]->alarm_remove( $_[HEAP]{check_id} );
        $_[HEAP]{check_id} = $_[KERNEL]->alarm_set( 'on_check' => $_[HEAP]{config}{interval}+time() );
    }

    $_[HEAP]{dr}->put('');  # attention
    $_[HEAP]{logger}->debug("snd checkdata");

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

    unless ( $_[ARG0] ) {
        $_[HEAP]{logger}->debug("got checkdata");
        return 1;
    }

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

    # 发送数据到机构
    my $packet = $_[HEAP]{class}->_adapter($_[HEAP], $_[ARG0]);
    $_[HEAP]{dr}->put( $packet ) if $_[HEAP]{dr} && $packet;

    # 重置check
    if ( $_[HEAP]{check_id} ) {
        $_[KERNEL]->alarm_remove( $_[HEAP]{check_id} );
        $_[HEAP]{check_id} = $_[KERNEL]->alarm_set('on_check' => $_[HEAP]{config}{interval}+time());
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
    $_[HEAP]{logger}->error( "listen-accept error: operation[$operation] error[$errnum: $errstr]");
    delete $_[HEAP]{la};
    delete $_[HEAP]{dr};
    $_[KERNEL]->yield('on_setup');

}

######################################################################################
#  hook && filters
######################################################################################

#
# filter fargs 设定, 以支持其他通讯协议, 如HTTP
#
sub _on_start {
    my $class  = shift;
    my $heap   = shift;
    my $kernel = shift;
    my $args   = shift;
    return 1;
}

#
# _on_accept 返回值含义:
# undef : _on_accept 调用error
# 1     : 子类负责管理session join/leave
# 0     : 父类管理session join/leave
#
sub _on_accept {
    my $class  = shift;
    my $heap   = shift;
    my $kernel = shift;
    return 0;
}

#
# 从远端数据取出业务数据
#
sub _packet {
    my $class = shift;
    my $heap  = shift;
    my $rd    = shift;
    $heap->{logger}->debug_hex("recv data<<<<<<<<:", $rd);
    return $rd;
}

#
# 从adapter数据构造packet
#
sub _adapter {
    my $class = shift;
    my $heap  = shift;
    my $ad    = shift;

    $heap->{logger}->debug_hex("send data>>>>>>>>:", $ad->{packet});
    return $ad->{packet};
}

1;

