package Zeta::Comet::FH;
use strict;
use warnings;

#############################
# 双工长连接  主动
#############################
use POE;
use POE::Wheel::ReadWrite;
use POE::Filter::Block;
use Zeta::Codec::Frame qw/ascii_n binary_n/;

############################################
# args:
#-------------------------------------------
# name         => 机构名称
# idx          => $index
# fh           => $socket|$pipe_rw
# codec        => ins 4 | nac 2
#                 (设置默认的$_[HEAP]{filter} $_[HEAP]{fargs})
#                 _on_start hook中主要就是提供filter与fargs
# interval     => 检测周期
# check        => 检测报文
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
                on_destroy      => 'on_destroy',
                on_negotiation  => 'on_negotiation',
                on_remote_data  => 'on_remote_data',     # 收到客户端数据
                on_adapter_data => 'on_adapter_data',    # switch中心post数据到机构
                on_fh_error     => 'on_fh_error',
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
    $_[HEAP]{class}  = delete $_[HEAP]{config}->{class};
    $_[KERNEL]
      ->alias_set( $_[HEAP]{config}->{name} . "." . $_[HEAP]{config}->{idx} );

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

    # setup
    $_[KERNEL]->yield('on_setup');
}

#
#
#
sub on_setup {

    #
    # 定制初始化
    #
    unless ( $_[HEAP]{class}->_on_start( $_[HEAP], $_[KERNEL] ) ) {
        $_[HEAP]{logger}->error("can not _on_start");
        $_[KERNEL]->delay( 'on_setup', 4 );
        return 1;
    }

    #
    # 定制初始化后， filter, fargs仍然没有设置好。
    #
    unless ( $_[HEAP]{filter} && $_[HEAP]{fargs} ) {
        $_[HEAP]{logger}->error("filter and fargs still not setup");
        exit 0;
    }

    #
    # connected
    #
    $_[KERNEL]->yield( 'on_negotiation' => $_[HEAP]{config}->{fh} );
}

#
#
#
sub on_negotiation {

    my $logger = $_[HEAP]{logger};
    my $config = $_[HEAP]{config};

    $logger->debug("on_negotiation called");

    #
    # 通知session line leave
    #
    if (   $_[CALLER_STATE] ne 'on_setup' && $_[CALLER_STATE] ne 'on_negotiation' ) {
        $logger->warn( "line[$config->{idx}] leaved last state[$_[CALLER_STATE]]");
        $_[KERNEL]->post( 'adapter', 'on_session_leave', [ $config->{name}, $config->{idx} ] );
    }

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
    my $fh = POE::Wheel::ReadWrite->new(
        Handle     => $_[ARG0],
        ErrorEvent => 'on_fh_error',
        InputEvent => 'on_remote_data',
        Filter     => $filter,
    );
    unless ($fh) {
        $logger->error("can not create rw wheel");
        $_[KERNEL]->delay( 'on_negotiation' => 2 );
        return;
    }
    $_[HEAP]{fh} = $fh;

    # $logger->debug(">>>>>>>>>>>>>>>begin service now...");

    # 报文检测
    #
    if ( $_[HEAP]{config}->{interval} ) {
        $_[HEAP]{check_id} = $_[KERNEL]->alarm_set( 'on_check' => $_[HEAP]{config}->{interval} + time() );
    }

    #
    # 超时检测
    #
    if ( $_[HEAP]{config}->{timeout} ) {
        $_[HEAP]{timeout_id} = $_[KERNEL]->alarm_set( 'on_timeout' => $_[HEAP]{config}->{timeout} + time() );
    }

    #
    # _on_negotiation hook: 连接协商
    # undef:   _on_negotiation失败
    # 1    :   子类管理session join/leave
    # 0    :   父类管理session join/leave
    #
    my $rtn = $_[HEAP]{class}->_on_negotiation( $_[HEAP], $_[KERNEL] );
    unless ( defined $rtn ) {
        $_[KERNEL]->yield('on_destroy');
        return 1;
    }
    else {
        unless ($rtn) {
            $_[KERNEL]->post( 'adapter', 'on_session_join', [ $_[HEAP]{config}->{name}, $_[HEAP]{config}->{idx} ] );
        }
    }

    return 1;
}

######################################
# 发送检测报文
######################################
sub on_check {

    if ( $_[HEAP]{check_id} ) {
        $_[KERNEL]->alarm_remove( $_[HEAP]{check_id} );
        $_[HEAP]{check_id} = $_[KERNEL]->alarm_set( 'on_check' => $_[HEAP]{config}->{interval} + time() );
    }
    $_[HEAP]{fh}->put("") if $_[HEAP]{fh};
    return 1;
}

######################################
#
######################################
sub on_timeout {
    $_[HEAP]{logger}->debug("on_timeout called");
    $_[KERNEL]->yield('on_destroy');
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
        $_[HEAP]{timeout_id} = $_[KERNEL]->alarm_set( 'on_timeout' => $_[HEAP]{config}{timeout}+time());
    }

    unless ( $_[ARG0] ) {
        $_[HEAP]{logger}->debug("got checkdata");
        return 1;
    }

    $_[HEAP]{logger}->debug("got remote_data[$_[ARG0]]");
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

######################################
# 从adapter得到数据, 发送给机构
######################################
sub on_adapter_data {

    my $logger = $_[HEAP]{logger};
    $logger->debug( "got adapter data:\n" . Data::Dump->dump( $_[ARG0] ) );

    #
    # 重置check
    #
    if ( $_[HEAP]{check_id} ) {
        $_[KERNEL]->alarm_remove( $_[HEAP]{check_id} );
        $_[HEAP]{check_id} = $_[KERNEL]->alarm_set( 'on_check' => $_[HEAP]{config}{interval}+time() );
    }

    # 子类处理
    my $packet = $_[HEAP]{class}->_adapter($_[HEAP], $_[ARG0]);

    # 发送
    $_[HEAP]{fh}->put( $packet ) if $_[HEAP]{fh} && defined $packet;
}

######################################
# fh读写错误
######################################
sub on_fh_error {
    $_[KERNEL]->alarm_remove( $_[HEAP]{check_id} ) if $_[HEAP]{check_id};
    my ( $operation, $errnum, $errstr, $id ) = @_[ ARG0 .. ARG3 ];
    $_[HEAP]{logger}->warn( "on_socket_error op[$operation] errnum[$errnum] errstr[$errstr] id[$id]");
    $_[KERNEL]->yield('on_destroy');
}

######################################
#
######################################
sub on_destroy {

    my $sid = $_[SESSION]->ID();
    $_[HEAP]{logger}->error("session[$sid] on_destroy is called");

    #
    # remove wheel
    delete $_[HEAP]{fh};
    $_[HEAP]{logger}->error("session[$sid] wheel[fh] is removed");

    #
    # remove alarm
    my @removed_alarms = $_[KERNEL]->alarm_remove_all();
    for (@removed_alarms) {
        $_[HEAP]{logger}->error("session[$sid] alarm[@$_] removed");
    }

    # remove alias
    my $alias = $_[HEAP]{config}->{name} . "." . $_[HEAP]{config}->{idx};
    $_[KERNEL]->alias_remove($alias);
    $_[HEAP]{logger}->error("session[$sid] alias[$alias] removed");

    # 子类 自己通知adapter on_session_leave or something
    if ( $_[HEAP]{class}->_on_destroy( $_[HEAP], $_[KERNEL] ) ) {
        return 1;
    }
    else {
        $_[HEAP]{logger}->debug("session line[$_[HEAP]{config}->{idx}] leave now...");
        $_[KERNEL]->post( 'adapter', 'on_session_leave', [ $_[HEAP]{config}->{name}, $_[HEAP]{config}->{idx} ] );
    }

    return;
}

######################################################################################
#  hook && filters
######################################################################################

#
# 默认, 有codec作 [len header] + [ data ]的协议支持
# 当你需要自定义通信协议(如HTTP)时, 子类可重写_on_start
# 产生 $_[HEAP]{filter}, $_[HEAP]{fargs}
#
sub _on_start {
    my $class  = shift;
    my $heap   = shift;
    my $kernel = shift;
    return 1;
}

#
# _on_negotiation 返回值含义:
# undef : _on_negotiation 调用error
# 1     : 子类负责管理session join/leave
# 0     : 父类管理session join/leave
#
sub _on_negotiation {
    my $class  = shift;
    my $heap   = shift;
    my $kernel = shift;
    return 0;
}

#
# 从对方发送数据中取出所需数据
#
sub _packet {
    my $class  = shift;
    my $heap   = shift;
    my $rd     = shift;
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

#
# undef : _on_negotiation 调用error
# 1     : 子类负责管理session leave
# 0     : 父类管理session leave
#
sub _on_destroy {
    my $class  = shift;
    my $heap   = shift;
    my $kernel = shift;
    return 0;
}

1;

