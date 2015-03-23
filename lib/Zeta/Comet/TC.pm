package Zeta::Comet::TC;

use strict;
use warnings;

################################
# TCP短连接客户端
# 异步转同步
#
#  定制接口:
#  1>  _on_start  :
#  2>  _packet    : 从remote  data 取出业务数据
#  3>  _adpater   : 从adapter data 构造请求
################################

use Time::HiRes qw/gettimeofday tv_interval/;
use POE;
use IO::Socket::INET;
use POE::Wheel::ReadWrite;
use POE::Filter::Block;
use POE::Filter::Stream;
use Zeta::Codec::Frame;
use constant {
    DEBUG => $ENV{COMET_DEBUG} || 0,
};

############################################
# args:
#    logger
#    config => {
#      name        => 机构名称
#      remoteaddr  => 远端ip
#      remoteport  => 远端端口
#      timeout     => 超时时间
#      codec       => ins N | nac N
#    }
############################################
sub spawn {

    my $class = shift;

    my $logger = shift;
    my $config = shift;
    $config->{class} = $class;

    POE::Session->create(
        'package_states' => [
            $class => {
                _start          => 'on_start',           # 启动
                on_socket_error => 'on_socket_error',    # socket错误
                on_timeout      => 'on_timeout',         # 扫描超时请求
                on_setup        => 'on_setup',           # setup
                on_remote_data  => 'on_remote_data',     # 收到客户端数据
                on_adapter_data => 'on_adapter_data',    # adapter post数据到机构
            },
        ],
        args => [ $logger, $config ],
    );
    return $config->{name} . "." . $config->{idx};
}

#############################################
# 1> 设置alias
# 2> codec准备
#############################################
sub on_start {

    delete $_[HEAP]{tc};

    $_[HEAP]{logger} = $_[ARG0];
    $_[HEAP]{config} = $_[ARG1];
    $_[HEAP]{class}  = delete $_[HEAP]{config}->{class};
    $_[KERNEL]->alias_set( $_[HEAP]{config}->{name} . "." . $_[HEAP]{config}->{idx} );

    #
    # 过滤器codec
    #
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

    #
    # 定制初始化
    #
    unless ( $_[HEAP]{class}->_on_start( $_[HEAP], $_[KERNEL] ) ) {
        $_[HEAP]{logger}->error("can not _on_start");
        $_[KERNEL]->delay( '_start' => 4 );
        return 1;
    }

    #
    # 定制初始化后， 仍然没有设置好filter fargs
    #
    unless ( $_[HEAP]{filter} && $_[HEAP]{fargs} ) {
        $_[HEAP]{logger}->error("filter and fargs still not setup");
        exit 0;
    }

    $_[KERNEL]->yield('on_setup');

    return 1;
}

#############################################
#
#############################################
sub on_setup {

    if ( $_[CALLER_STATE] ne '_start' && $_[CALLER_STATE] ne 'on_setup' ) {
        $_[HEAP]{logger}->warn("line[$_[HEAP]{config}->{idx}] leaved");
        $_[KERNEL]->post('adapter', 'on_session_leave', [$_[HEAP]{config}{name}, $_[HEAP]{config}{idx}, ] );
    }

    #
    # 告知adapter session line joined
    #
    $_[KERNEL]->post('adapter', 'on_session_join', [$_[HEAP]{config}{name}, $_[HEAP]{config}{idx}]);
    return 1;
}

#############################################
# 超时处理
#############################################
sub on_timeout {
    my $id = $_[ARG0];
    my $interval = tv_interval( $_[HEAP]{tc}{$id}->{beg}, [gettimeofday] );
    $_[HEAP]{logger}->warn("REQ[$id] last for[$interval], timeout");
    $_[KERNEL]->alarm_remove( delete $_[HEAP]{tc}{$id}->{to} );
    delete $_[HEAP]{tc}{$id};
}

#############################################
# socket错误
#############################################
sub on_socket_error {
    my ( $operation, $errnum, $errstr, $id ) = @_[ ARG0 .. ARG3 ];
    $_[KERNEL]->alarm_remove( $_[HEAP]{tc}{$id}->{to} );
    $_[HEAP]{logger}->warn( "on_socket_error op[$operation] errnum[$errnum] errstr[$errstr] id[$id]");
    delete $_[HEAP]{tc}{$id};
}

#############################################
# 收到远端数据, 发送给switch
#############################################
sub on_remote_data {

    my ( $res, $id ) = @_[ ARG0, ARG1 ];

    if ( exists $_[HEAP]{tc}{$id} ) {
        $_[KERNEL]->post(
            'adapter',
            'on_remote_data',
            {
                src    => $_[HEAP]{config}->{name},
                packet => $_[HEAP]{class}->_packet( $_[HEAP], $res ),
                skey   => $_[HEAP]{tc}{$id}->{skey},    # 取出保存的skey
            }
        );
        $_[KERNEL]->alarm_remove( $_[HEAP]{tc}{$id}->{to} );
        delete $_[HEAP]{tc}{$id};
    }

    return 1;
}

#############################################
# 从adapter得到数据,
# {
#   src    => src机构,   # maybe not
#   dst    => dst机构,
#   packet => 数据,
#   skey   => 'session key',
# }
# 1> 建立到机构连接
# 2> 发送给机构
# 3> 等待机构应答
# 4> 断开连接
#############################################
sub on_adapter_data {

    my $config = $_[HEAP]{config};
    my $logger = $_[HEAP]{logger};

    # $logger->debug( "got adapter data:\n" . Data::Dump->dump( $_[ARG0] ) ) ;

    ######################
    # 连接客户端
    ######################
    # $logger->debug( "begin connect to [$config->{remoteaddr}:$config->{remoteport}]");
    my $tc_sock = IO::Socket::INET->new(
        PeerHost => $config->{remoteaddr},
        PeerPort => $config->{remoteport},
        Blocking => 0,
    );
    unless ($tc_sock) {
        $logger->error( "can not connect to [$config->{remoteaddr}:$config->{remoteport}]");
        return;
    }
    # $logger->debug( "connected to server [$config->{remoteaddr}:$config->{remoteport}]");

    ######################
    # Filter
    ######################
    my $filter;
    if ( $_[HEAP]{filter} ) {
        $filter = $_[HEAP]{filter}->new( @{ $_[HEAP]{fargs} } );
    }
    else {
        $filter = POE::Filter::Stream->new();
    }

    ######################
    # Wheel
    ######################
    my $tc = POE::Wheel::ReadWrite->new(
        Handle     => $tc_sock,
        ErrorEvent => 'on_socket_error',
        InputEvent => 'on_remote_data',
        Filter     => $filter,
    );
    unless ($tc) {
        $logger->error("can not create rw wheel");
        return;
    }

    # 子类化处理
    my $req = $_[HEAP]{class}->_adpater( $_[HEAP], $_[ARG0] );

    # 发送请求到机构
    $tc->put($req) if $req;
     
    # 保存tc, 设置超时
    $_[HEAP]{tc}{ $tc->ID } = {
        tc   => $tc,
        skey => $_[ARG0]->{skey},        # 保存好session key
        beg  => [gettimeofday],
        to   => $_[KERNEL]->alarm_set( 'on_timeout', time() + $_[HEAP]{config}->{timeout}, $tc->ID),   # 超时设置
    };

}

######################################################################################
#  hook && filters
######################################################################################

#
# 定制初始化
#
sub _on_start {
    my $class  = shift;
    my $heap   = shift;
    my $kernel = shift;
    my $args   = shift;
    return 1;
}

#
# 从adapter data 构造一个request
#
sub _adpater {
    my $class = shift;
    my $heap  = shift;
    my $ad    = shift;
    $heap->{logger}->debug_hex("send data>>>>>>>>:", $ad->{packet});
    return $ad->{packet};
}

#
# 从remote data 取出业务数据
#
sub _packet {

    my $class = shift;
    my $heap  = shift;
    my $rd    = shift;

    $heap->{logger}->debug_hex("recv data<<<<<<<<:", $rd);
    return $rd;
}

1;

