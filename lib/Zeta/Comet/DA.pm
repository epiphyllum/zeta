package Zeta::Comet::DA;
use strict;
use warnings;

#############################
# 双工长连接  主动
#############################
use POE;
use IO::Socket::INET;
use POE::Wheel::ReadWrite;
use POE::Filter::Block;
use Zeta::Codec::Frame;

############################################
# args:
#-------------------------------------------
# $logger,
# {
#   name         => 机构名称
#   remoteaddr   => 远端ip
#   remoteport   => 远端端口
#   codec        => ins 4 | nac 2 | etc
#                 (设置默认的$_[HEAP]{filter} $_[HEAP]{fargs})
#                 _on_start hook中主要就是提供filter与fargs
#   interval     => 检测周期
#   check        => 检测报文
# }
############################################
sub spawn {

    my $class  = shift;
    my $logger = shift;
    my $config = shift;

    $config->{class} = $class;
    POE::Session->create(
        'package_states' => [
            $class => {
                _start          => 'on_start',
                on_setup        => 'on_setup',
                on_connect      => 'on_connect',
                on_remote_data  => 'on_remote_data',    # 收到客户端数据
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

    $_[HEAP]{logger} = $_[ARG0];
    $_[HEAP]{config} = $_[ARG1];
    $_[HEAP]{class}  = delete $_[HEAP]{config}{class};
    $_[KERNEL]->alias_set($_[HEAP]{config}{name} . "." . $_[HEAP]{config}{idx} );

    ######################################
    # 过滤器codec
    ######################################
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

    $_[KERNEL]->yield('on_setup');

}

#
#
#
sub on_setup {

    unless ( $_[HEAP]{class}->_on_start( $_[HEAP], $_[KERNEL] ) ) {
        $_[HEAP]{logger}->error("can not _on_start");
        $_[KERNEL]->delay( 'on_setup', 4 );
        return 1;
    }

    # 
    # 过滤器
    #
    unless ( $_[HEAP]{filter} && $_[HEAP]{fargs} ) {
        $_[HEAP]{logger}->error("filter and fargs still not setup");
        exit 0;
    }

    $_[KERNEL]->yield('on_connect');
    return 1;
}

######################################
# 连接到机构
######################################
sub on_connect {

    my $config = $_[HEAP]{config};
    my $logger = $_[HEAP]{logger};

    $_[KERNEL]->alarm_remove_all();

    #  通知session line leave. if是判断上一状态不是(on_setup, on_connect)
    if ( $_[CALLER_STATE] ne 'on_setup' && $_[CALLER_STATE] ne 'on_connect' ) {
        $logger->warn( "line[$_[HEAP]{config}{idx}] leaved, state[$_[CALLER_STATE]]");
        $_[KERNEL]->post( 'adapter', 'on_session_leave', [ $config->{name}, $config->{idx} ] );
    }

    ######################################
    # 连接客户端
    ######################################
    $logger->info( "begin connect to [$config->{remoteaddr}:$config->{remoteport}]");
    my $da_sock = IO::Socket::INET->new(
        PeerHost => $config->{remoteaddr},
        PeerPort => $config->{remoteport},
    );
    unless ($da_sock) {
        $logger->error( "can not connect to [$config->{remoteaddr}:$config->{remoteport}]");
        $_[KERNEL]->delay( 'on_connect' => 2 );  # 2秒后重试
        return;
    }
    $logger->debug( "connected to client[$config->{remoteaddr}:$config->{remoteport}]");

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
    my $da = POE::Wheel::ReadWrite->new(
        Handle     => $da_sock,
        ErrorEvent => 'on_socket_error',
        InputEvent => 'on_remote_data',
        Filter     => $filter,
    );
    unless ($da) {
        $logger->error("can not create rw wheel");
        $_[KERNEL]->delay( 'on_connect' => 2 );
        return;
    }
    $_[HEAP]{da} = $da;

    # $logger->debug(">>>>>>>>>>>>>>>begin service now...");

    #
    # 报文检测
    #
    if ( $_[HEAP]{config}{interval} ) {
        $logger->debug("begin set check alarm...");
        $_[HEAP]{check_id} = $_[KERNEL]->alarm_set('on_check' => $_[HEAP]{config}{interval}+time());
    }

    #
    # 超时检测
    #
    if ( $_[HEAP]{config}{timeout} ) {
        $logger->debug("begin set timeout alarm...");
        $_[HEAP]{timeout_id} = $_[KERNEL]->alarm_set('on_timeout' => $_[HEAP]{config}{timeout}+time());
    }

    ######################################
    # _on_connect 返回值含义:
    # undef : _on_connect 调用error
    # 1     : 子类负责管理session join
    # 0     : 父类管理session join
    ######################################
    my $rtn = $_[HEAP]{class}->_on_connect( $_[HEAP], $_[KERNEL] );
    unless ( defined $rtn ) {
        $logger->error("_on_connect failed");
        $_[KERNEL]->delay( 'on_connect' => 4 );
        return 1;
    }
    else {
        unless ($rtn) {
            $_[KERNEL]->post( 'adapter', 'on_session_join', [ $_[HEAP]{config}{name}, $_[HEAP]{config}->{idx} ] );
        }
    }
    return 1;

}

######################################
# 测试用状态
######################################
sub on_tick {
    $_[HEAP]{logger}->debug("on_tick is called");
    $_[HEAP]{da}->put('');

    if ( $_[HEAP]{config}{interval} ) {
        $_[KERNEL]->alarm_remove( $_[HEAP]{check_id} );
        $_[HEAP]{check_id} = $_[KERNEL]->alarm_set('on_check' => $_[HEAP]{config}{interval}+time());
    }

    $_[KERNEL]->delay('on_tick' => 4);
}

######################################
# 发送检测报文
######################################
sub on_check {

    if ( $_[HEAP]{check_id} ) {
        $_[KERNEL]->alarm_remove( $_[HEAP]{check_id} );
        $_[HEAP]{check_id} = $_[KERNEL]->alarm_set( 'on_check' => $_[HEAP]{config}{interval}+time());
    }

    $_[HEAP]{logger}->debug("snd checkdata");
    $_[HEAP]{da}->put("") if $_[HEAP]{da};
    return 1;
}

######################################
#
######################################
sub on_timeout {
    $_[HEAP]{logger}->debug("on_timeout called");
    $_[KERNEL]->yield('on_connect');
}

######################################
# 从客户端得到数据, 发送给switch
######################################
sub on_remote_data {

    #
    # 重置超时时间
    #
    if ( $_[HEAP]{timeout_id} ) {
        $_[KERNEL]->alarm_remove( $_[HEAP]{timeout_id} );
        $_[HEAP]{timeout_id} = $_[KERNEL] ->alarm_set('on_timeout' => $_[HEAP]{config}{timeout}+time());
    }

    unless ( $_[ARG0] ) {
        $_[HEAP]{logger}->debug("got checkdata");
        return 1;
    }

    # 从机构数 ---> 处理   
    my $packet = $_[HEAP]{class}->_packet($_[HEAP], $_[ARG0]);

    $_[KERNEL]->post(
        'adapter',
        'on_remote_data',
        {
            src    => $_[HEAP]{config}{name},
            packet => $packet,
        }
    );

    return 1;
}

######################################
# 从adapter得到数据, 发送给机构
######################################
sub on_adapter_data {

    my $logger = $_[HEAP]{logger};
    # $logger->debug( "got adapter data:\n" . Data::Dump->dump( $_[ARG0] ) );

    #
    # 重置check
    #
    if ( $_[HEAP]{check_id} ) {
        $_[KERNEL]->alarm_remove( $_[HEAP]{check_id} );
        $_[HEAP]{check_id} = $_[KERNEL]->alarm_set('on_check' => $_[HEAP]{config}{interval} + time() );
    }

    # 子类处理: 从adapter  -----> 机构数据
    my $packet = $_[HEAP]{class}->_adapter($_[HEAP], $_[ARG0]);

    $_[HEAP]{da}->put($packet) if $_[HEAP]{da} && $packet;
 
}

######################################
# socket读写错误
######################################
sub on_socket_error {

    $_[KERNEL]->alarm_remove( $_[HEAP]{check_id} );
    my ( $operation, $errnum, $errstr, $id ) = @_[ ARG0 .. ARG3 ];
    $_[HEAP]{logger}->warn( "on_socket_error op[$operation] errnum[$errnum] errstr[$errstr] id[$id]");
    $_[KERNEL]->yield('on_connect');

}

######################################################################################
#  hook && filters
######################################################################################

#
# 默认, 有codec作[len header] + [ data ]的协议支持
# 当你需要自定义通信协议(如HTTP)时, 子类可重写_on_start
# 产生 $_[HEAP]{filter}, $_[HEAP]{fargs}
#
sub _on_start {
    my $class  = shift;
    my $heap   = shift;
    my $kernel = shift;
    my $args   = shift;
    return 1;
}

#
# 连接上以后的初始化, 如果双方的协商
# 默认返回1;
#
sub _on_connect {
    my $class  = shift;
    my $heap   = shift;
    my $kernel = shift;
    return 0;
}

#
# 从remote数据取出业务数据
#
sub _packet {
    my $class = shift;
    my $heap  = shift;
    my $rd    = shift;
    $heap->{logger}->debug_hex("recv data<<<<<<<<:", $rd);
    return $rd;
}

#
# 从adapter数据构造一个机构数据
#
sub _adapter {
    my $class = shift;
    my $heap  = shift;
    my $ad    = shift;
    $heap->{logger}->debug_hex("send data>>>>>>>>:", $ad->{packet});
    return $ad->{packet};
}

1;

