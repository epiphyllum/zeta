package Zeta::Comet::TS;

#############################
# TCP短连接服务器端
# 同步转异步
#
#  定制接口回调:
#  1>  _on_start  :
#  2>  _packet    : 从remote  data 取出业务报文
#  3>  _adapter  : 从adapter data 构造response
#############################

use strict;
use warnings;

use Time::HiRes qw/tv_interval gettimeofday/;
use POE;
use IO::Socket::INET;
use POE::Wheel::ReadWrite;
use POE::Wheel::ListenAccept;
use POE::Filter::Block;
use POE::Filter::Stream;
use Zeta::Codec::Frame;

use constant {
    DEBUG => $ENV{COMET_DEBUG} || 0,
};

############################################
# args:
#   logger
#   config => {
#     name        => 机构名称
#     localaddr   => 本机IP
#     localport   => 本机端口
#     codec       => ins  4 | nac 2
#     timeout     => 超时时间
#   }
#
#   localaddr|
#       +    |---->  lfd
#   localport|
#
############################################
sub spawn {

    my $class = shift;

    my $logger = shift;
    my $config = shift;
    $config->{class} = $class;

    POE::Session->create(
        'package_states' => [
            $class => {
                _start          => 'on_start',           # alias set
                on_setup        => 'on_setup',           # 初始化
                on_accept       => 'on_accept',          # accept
                on_la_error     => 'on_la_error',        # listen-accept error
                on_remote_data  => 'on_remote_data',     # 收到客户端数据
                on_adapter_data => 'on_adapter_data',    # adapter post数据到机构
                on_socket_error => 'on_socket_error',    # socket错误
                on_timeout      => 'on_timeout',         # 扫描超时请求
                on_flush        => 'on_flush',           #
            },
        ],
        args => [ $logger, $config ],
    );
    return $config->{name} . "." . $config->{idx};
}

#############################################
# 1> 设置好alias
# 2> yield to on_setup
#############################################
sub on_start {

    $_[HEAP]{logger} = $_[ARG0];
    $_[HEAP]{config} = $_[ARG1];
    $_[HEAP]{class}  = delete $_[HEAP]{config}->{class};
    $_[KERNEL]->alias_set( $_[HEAP]{config}->{name} . "." . $_[HEAP]{config}->{idx} );

    ####################
    # 过滤器codec
    ####################
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
        $_[KERNEL]->delay( '_start', 2 );
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

}

#############################################
# 建立listen-accept wheel, 设置定时扫描
#############################################
sub on_setup {

    my $logger = $_[HEAP]{logger};
    my $config = $_[HEAP]{config};

    #
    # 通知adapter, session line leave
    #
    if ( $_[CALLER_STATE] ne '_start' && $_[CALLER_STATE] ne 'on_setup' ) {
        $logger->warn("line[$_[HEAP]{config}->{idx}] leaved");
        $_[KERNEL]->post( 'adapter', 'on_session_leave',[ $config->{name}, $config->{idx} ] );
    }

    ###########################################################
    # listen accept:  要么直接是lfd, 要么是localaddr:localport
    ###########################################################
    my $la_socket;
    if ( $config->{lfd} ) {
        $la_socket = $config->{lfd};
    }
    else {
        $la_socket = IO::Socket::INET->new(
            LocalAddr => $config->{localaddr},
            LocalPort => $config->{localport},
            Listen    => 5,
            ReuseAddr => 1,
        );
        unless ($la_socket) {
            $logger->warn( "can not create LA socket[$config->{localaddr}:$config->{localport}]");
            $_[KERNEL]->delay( 'on_setup' => 2 );
            return;
        }
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

    #
    # 告知session line joined
    #
    $_[KERNEL]->post( 'adapter', 'on_session_join', [ $_[HEAP]{config}->{name}, $_[HEAP]{config}->{idx}, ] );

    return 1;
}

#############################################
# 等待机构连接, 将连接wheel保存
#############################################
sub on_accept {

    my $config = $_[HEAP]{config};
    my $logger = $_[HEAP]{logger};

    my $filter;
    if ( $_[HEAP]{filter} ) {
        $filter = $_[HEAP]{filter}->new( @{ $_[HEAP]{fargs} } );
    }
    else {
        $filter = POE::Filter::Stream->new();
    }

    my $ts = POE::Wheel::ReadWrite->new(
        Handle       => $_[ARG0],
        ErrorEvent   => 'on_socket_error',
        InputEvent   => 'on_remote_data',
        FlushedEvent => 'on_flush',
        Filter       => $filter,
    );
    unless ($ts) {
        $logger->error("can not create rw wheel");
        $_[KERNEL]->delay( 'on_setup' => 2 );
        return;
    }

    #
    # 记录请求wheel
    #
    my $id = $ts->ID();
    $_[HEAP]{ts}{$id} = {
        ts  => $ts,
        beg => [gettimeofday],
        to  => $_[KERNEL]->alarm_set('on_timeout' => time() + $_[HEAP]{config}->{timeout}, $id),  # 超时设置
    };

    return 1;

}

#############################################
#
#############################################
sub on_timeout {
    my $id = $_[ARG0];
    my $interval = tv_interval($_[HEAP]{ts}{$id}->{beg}, [gettimeofday]);
    $_[HEAP]{logger}->warn("REQ wheel_id[$id] last for[$interval], timeout");
    $_[KERNEL]->alarm_remove($_[HEAP]{ts}{$id}->{to});   # to, timeout对象
    delete $_[HEAP]{ts}{$id};
}

#############################################
# 从机构得到数据,
# 1> 发送给adapter => on_remote_data, $data
#############################################
sub on_remote_data {

    my ( $req, $id ) = @_[ ARG0, ARG1 ];
    unless($req) {
        $_[HEAP]{logger}->debug("recv invalid data");
        return 1;
    } 

    # 收到数据开始， 重新设置超时回调
    $_[KERNEL]->alarm_remove($_[HEAP]{ts}{$id}->{to});
    $_[HEAP]{ts}{$id}->{to} = $_[KERNEL]->alarm_set('on_timeout' => time() + $_[HEAP]{config}->{timeout}, $id);

    # 发送给adapter
    $_[KERNEL]->post(
        'adapter',
        'on_remote_data',
        {
            src    => $_[HEAP]{config}->{name},
            packet => $_[HEAP]{class}->_packet( $_[HEAP], $req ),
            sid => $id,    # 将sid发送给业务模块
        },
    );

    return 1;
}

#############################################
# 从adapter得到数据, 发送给机构
# {
#    packet  =>  $packet,
#    sid     =>  $sid,       # 业务模块带回的sid
#    src     =>  '机构名称'
#    dst     =>  '机构名称'
# }
#############################################
sub on_adapter_data {

    my $data = $_[ARG0];

    my $logger= $_[HEAP]{logger};

    $logger->debug( "got adapter data:\n" . Data::Dump->dump($data) ) if DEBUG;

    my $sid = $data->{sid};
    unless ($sid) {
        $logger->warn("undefined sid from adapter_data");
        return 1;
    }

    unless ( exists $_[HEAP]{ts}{$sid} ) {
        $logger->warn("ts wheel[$sid] does not exists");
        return 1;
    }

    # 删除超时
    $_[KERNEL]->alarm_remove( delete $_[HEAP]{ts}{$sid}->{to} );

    # 子类处理
    my $res = $_[HEAP]{class}->_adapter( $_[HEAP], $data );

    # 发送数据到机构
    $_[HEAP]{ts}{$sid}->{ts}->put($res) if $res;

}

#############################################
# socket读写发生错误
#############################################
sub on_socket_error {
    my ( $operation, $errnum, $errstr, $id ) = @_[ ARG0 .. ARG3 ];
    $_[KERNEL]->alarm_remove( $_[HEAP]{ts}{$id}->{to} );
    if ($errstr) {
        $_[HEAP]{logger}->warn("on_socket_error op[$operation] errnum[$errnum] errstr[$errstr] id[$id]");
    }

    # $_[HEAP]{logger}->warn("wheel_id[$id] deleted");
    delete $_[HEAP]{ts}{$id};
}

#############################################
# listen accept error
#############################################
sub on_la_error {

    my ( $operation, $errnum, $errstr ) = @_[ ARG0, ARG1, ARG2 ];
    $_[HEAP]{logger}->error("listen-accept error: operation[$operation] error[$errnum: $errstr]");
    delete $_[HEAP]{la};
    delete $_[HEAP]{ts};
    $_[KERNEL]->yield('on_setup');
}

sub on_flush {
    delete $_[HEAP]{ts}{ $_[ARG0] };

    # $_[HEAP]{logger}->warn("wheel_id[$_[ARG0]]deleted");
}

######################################################################################
#  hook && filters
######################################################################################
#
#
#
sub _on_start {
    my $class  = shift;
    my $heap   = shift;
    my $kernel = shift;
    my $args   = shift;
    return 1;
}

#
# 从adapter data构造response
#
sub _adapter {
    my $class = shift;
    my $heap  = shift;
    my $ad    = shift;

    $heap->{logger}->debug_hex("send data>>>>>>>>:",  $ad->{packet});
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

