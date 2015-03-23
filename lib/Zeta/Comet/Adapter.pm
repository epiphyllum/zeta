package Zeta::Comet::Adapter;

use strict;
use warnings;
use Carp qw/cluck/;
use IO::Handle;
use POE::Session;
use POE::Wheel::ReadWrite;
use POE::Filter::Stream;
use POE::Filter::Block;
use Zeta::Codec::Frame qw/ascii_n/;

###################################################
# must args:
#   reader     => $reader_file
#   writer     => $writer_file || $writer_qid
#   serializer => $serializer,
#   logger     => $logger,
# -------------------------------------------------
# optional:
###################################################
sub spawn {

    my $class = shift;
    my $args  = {@_};

    unless ( $args->{logger} ) {
        cluck "logger => \$logger needed";
        return;
    }

    $args->{logger}->debug( "$class spawn with:\n" . Data::Dump->dump($args) );
    $args->{class} = $class;

    my $session;
    unless ( $session = POE::Session->create(
        'package_states' => [
            $class => {
                _start           => 'on_start',
                on_remote_data   => 'on_remote_data',      # got remote data
                on_adapter_data  => 'on_adapter_data',     # got pack data
                on_session_join  => 'on_session_join',     # session join
                on_session_leave => 'on_session_leave',    # session leave
            },
        ],
        args => [$args],
    ))
    {
        cluck "can not POE::Session->create";
        return;
    }
    return $session;
}

sub on_start {

    my $args = $_[ARG0];

    # 设置session alias
    $_[KERNEL]->alias_set('adapter');
    $_[HEAP]{class}      = delete $args->{class};       # must
    $_[HEAP]{logger}     = delete $args->{logger};      # must
    $_[HEAP]{serializer} = delete $args->{serializer};  # 没有serializer, 只能单进程内使用， on_remote_data需要重写

    # 读wheel，只能是File
    my $w = POE::Wheel::ReadWrite->new(
        Handle     => $args->{reader} || \*STDIN,
        InputEvent => 'on_adapter_data',
        Filter     => POE::Filter::Block->new(LengthCodec => ascii_n(4)),
    );
    unless ($w) {
        $_[HEAP]{logger}->error("can not POE::Wheel::ReadWrite->new(STDIN)");
        exit 0;
    }
    $_[HEAP]{recv} = $w;

    # 写wheel, 需要子类化
    $_[HEAP]{send} = $_[HEAP]{class}->_send_wheel($_[HEAP], $args->{writer});

    # 更多的子类化定制， 用_on_start
    return _on_start( $_[HEAP]{class}, $_[HEAP], $_[KERNEL], $args );
}

##############################################################################################################
#  机构线路session.on_remote_data收到数据, post到adapter.on_remote_data
#  $_[ARG0]:
#  {
#    src    => 'pos',
#    packet => 'tran_code:purchase|pos_serial:5|term_id:00000001|pan:6226090217048509|mcht_id:309120|amt:9999'
#  }
#  定制化可: 重写_remote_filter
#  更多定制: 可子类化on_remote_data
#
##############################################################################################################
sub on_remote_data {

    my $logger = $_[HEAP]{logger};
    # $logger->info("on_remote_data got:\n" . Data::Dump->dump($_[ARG0])) ;

    # 子类处理: 收到远端数据后, _remote_filter默认不作任何处理
    my $data = $_[HEAP]{class}->_remote_filter( $_[HEAP], $_[ARG0] );
    unless ($data) {
        $logger->error("_remote_filter error");
        return;
    }

    # 序列化远端数据
    my $ser   = $_[HEAP]{serializer};
    my $fdata = $ser->serialize($data);
    unless ($fdata) {
        $logger->error( "can not serialize:\n" . Data::Dump->dump($data) );
        return 1;
    }

    # 通过send wheel 发送给后端处理模块
    # $logger->debug("on_remote_data snd:\n[$fdata]");
    $_[HEAP]{send}->put($fdata);

    return 1;
}

#############################################
# 反序列化前
# {
#   dst     => '目的机构',
#   packet  => '发送给机构的的数据',
# }
# _adapter_filter
# on_adapter_data也可子类重写
#############################################
sub on_adapter_data {

    my $logger = $_[HEAP]{logger};
    # $logger->info("on_adapter_data got:\n" .  Data::Dump->dump($_[ARG0])) ;

    # 收到后端业务处理模块返回的数据，反序列化
    my $tdata = $_[HEAP]{serializer}->deserialize( $_[ARG0] );
    unless ($tdata) {
        $logger->error( "can not deserialize data:\n" . "[$_[ARG0]]" . "\n" );
        return 1;
    }
    # $logger->debug("after deserialize:\n" .  Data::Dump->dump($tdata)) ;

    # 子模块过滤过滤处理，_adapter_filter默认不作任何处理
    my $data = $_[HEAP]{class}->_adapter_filter( $_[HEAP], $tdata );
    unless ($data) {
        $logger->error( "_adapter_filter error with:\n" . Data::Dump->dump($tdata) );
        return 1;
    }

    # 选择目标线路session
    unless($data->{dst}) {
        $logger->error("no dst field, can not route");
        return 1;
    }
    my $alias = $_[HEAP]{class}->get_line_session( $_[HEAP], $data->{dst} );
    unless ($alias) {
        $logger->error("no lines availabe for destination[$data->{dst}]");
        return 1;
    }

    # 发送给目标线路session
    $logger->debug("post to [$alias, on_adapter_data]");
    $_[KERNEL]->post( $alias, 'on_adapter_data', $data );

    return 1;
}

##############################################################
# $_[HEAP]{sessions}->{'目的机构'}: [alias1, alias2];
# 随机选择一个alias, 将$data发送给它
##############################################################
sub get_line_session {

    my $class = shift;
    my $heap  = shift;
    my $dst   = shift;

    my @lines = grep { $_ } @{ $heap->{sessions}->{$dst} };
    my $alias;
    my $cnt = @lines;

    if ( $cnt == 0 ) {
        return;
    }

    $heap->{logger}->debug("there are line sessions[@lines]for $dst");

    if ( $cnt == 1 ) {
        $alias = $lines[0];
    }
    else {
        $alias = $lines[ int( rand($cnt) ) ];
    }

    return $alias;
}

#########################################################################
# 通讯line session在线路建立好后， 会发送session alias给adapter,
# 以告知adapter, 哪些机构的哪些线路准备好了。
# $_[ARG0]:
#   [ $iname,  $idx, $cookie ];
#########################################################################
sub on_session_join {

    my $iname = $_[ARG0][0];  # 哪个机构
    my $idx   = $_[ARG0][1];  # 第几条线路
    my $args  = $_[ARG0][2];  # cookie

    my $logger = $_[HEAP]{logger};
    $logger->info("$iname line[$idx] join");
    $_[HEAP]{sessions}{$iname}[$idx] = $iname . "." . $idx;
    $logger->info( "now sessions:\n" . Data::Dump->dump( $_[HEAP]{sessions} ) );

    # 客户子类化: 当有线路加入后如何处理, 默认_on_session_join不作任何处理
    unless ( $_[HEAP]{class}->_on_session_join( $_[HEAP], $_[KERNEL], $args ) ) {
        $logger->error("_on_session_join error");
        return 1;
    }

    return 1;
}

#
# 通讯session在线路没连上或是线路断开后， 告知adapter
# $_[ARG0]:
#   [ $iname,  $idx, $cookie ];
#
sub on_session_leave {

    my $iname = $_[ARG0]->[0]; # 哪个机构
    my $idx   = $_[ARG0]->[1]; # 那条线路
    my $args  = $_[ARG0]->[2]; # cookie

    my $logger = $_[HEAP]{logger};
    $logger->info("$iname line[$idx] leave");
    $_[HEAP]{sessions}{$iname}[$idx] = undef;
    $logger->debug( "sessions:\n" . Data::Dump->dump( $_[HEAP]{sessions} ) );

    # 客户子类化:
    unless ($_[HEAP]{class}->_on_session_leave( $_[HEAP], $_[KERNEL], $args )) {
        $logger->error("_on_session_leave error");
        return 1;
    }

    return 1;
}

############################################
# hooks && filters
############################################
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
# 发送设施准备
#
sub _send_wheel {
}

#
# remote data:
# {
#    src    => $src,
#    packet => $packet,
# },
# 将remote_data作过滤
#
sub _remote_filter {
    my $class = shift;
    my $heap  = shift;
    my $rd    = shift;
    return $rd;
}

#
# adapter_data:
# {
#   dst    => $dst,
#   packet => $packet,
#   sid    => 'NNN'
# }
# 将adapter_data作过滤处理
#
#
sub _adapter_filter {
    my $class = shift;
    my $heap  = shift;
    my $ad    = shift;
    return $ad;
}

#
# on_session_join的后处理
#
sub _on_session_join {
    return 1;
}

#
# on_session_leave的后处理
#
sub _on_session_leave {
    return 1;
}

1;

