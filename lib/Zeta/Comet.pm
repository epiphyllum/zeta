package Zeta::Comet;
use strict;
use warnings;
use Carp qw/cluck croak/;
use POE::Session;
use Zeta::IniParse qw/ini_parse/;

#####################################################
# 机构通讯服务器
#----------------------------------------------------
#  session A       <==>  机构A
#  session B       <==>  机构B
#  session C       <==>  机构C
#  session D       <==>  机构D
#  session E       <==>  机构E
#  session Adapter <==>  pack/unpack
#----------------------------------------------------
# 1> session A 从机构A收到机构数据$packet发送给unpack
#----------------------------------------------------
#    1) 一般机构:
#      $data = {
#        src    => 机构A
#        packet => $packet,
#      }
#      post('adapter', 'on_remote_data', $data);
#    2) 对于HS/TS,
#      $data = {
#        src    => 机构A
#        packet => $packet,
#        sid    => 'HS/TS wheel ID',
#      }
#      post('adapter', 'on_remote_data', $data);
#----------------------------------------------------
# 2> adapter 从pack收到数据
#----------------------------------------------------
#    {
#      packet  => $packet,
#      dst     => 机构xxx,
#      skey    => 'TC/HC 同步session key' 可选
#    }
#    1) post('机构xxx', 'on_adapter_data', $packet);
#    2) 机构xxx将$packet发送给机构
#    3) 对于TC/HC, 机构响应时候要将skey带回给adapter
######################################################

###############################################################
# logger     => $logger,                  # 日志对象
# ins|conf   => \%ins,
# adapter    => 'My::Adapter'  #
# ad_args    => {    # Zeta::Comet::Adapter::Pipe
#               reader     => $fh_r  || SDIN(default)
#               writer     => $fh_w  || STDOUT(default)
#               serializer => $ser,
#               #---------------------
#               optionN    => optionValue
#            }
# 或者
# ad_args    => {   # Zeta::Comet::Adapter::Queue
#               ipc        => 'queue',
#               reader     => $fh_r  || STDIN(default)
#               writer     => $wqid,
#               serializer => $ser,
#               #---------------------
#               optionN    => optionValue    # for extension usage
#            }
#
###############################################################
#
###############################################################
#   \%ins的结构
###############################################################
# {
#     icbc => {
#         codec     => 'nac 2|ins 4|http',
#         mode      => 'tc',
#         module    => 'Zeta::Comet::TC',
#         lines     => [
#             {
#                 remoteaddr => '127.0.0.1',
#                 remoteport => '7772',
#                 timeout    => 40,
#             },
#         ],
#     },
#
#     nac => {
#         codec     => 'nac 2',
#         mode      => 'dr',
#         module    => 'Zeta::Comet::DR',
#         lines     => [
#             {
#                 localaddr => '127.0.0.1',
#                 localport => '7771',
#                 timeout   => 40,
#             },
#         ],
#     },
# }
#
###############################################################
sub spawn {

    my $class = shift;
    my $args  = {@_};

    # 日志
    my $logger = $args->{logger};
    unless ($logger) {
        cluck "logger must be provided";
    }

    # 机构配置
    my $ic = $args->{ins};

    # 检查机构线路参数
    for my $iname ( keys %{$ic} ) {
        unless ( &ins_check( $iname, $ic->{$iname} ) ) {
            $logger->error("check config for $iname failed");
            return;
        }
    }

    # 启动所有机构session
    for my $ins ( keys %{$ic} ) {
        my $icfg = delete $ic->{$ins};
        $icfg->{name} = $ins;
        if ( $icfg->{mode} =~ /^(si|da|dr|tc|ts)$/) {
            &_spawn_common($icfg, $logger, $icfg->{mode});
        }
        else {
            &_spawn_ext($icfg, $logger);
        }
    }

    # 启动适配器
    &_spawn_ad($args, $logger);

    return 1;
}

#
# 常见通讯方式
#
sub _spawn_common {
    my ($icfg, $logger, $mode) = @_;
    my $func = \&{'_spawn_' . $mode};
    return $func->($icfg, $logger);
}

#
# 启动单工双链
#
sub _spawn_si {

    my ($icfg, $logger)  = @_;
    my $mode = $icfg->{mode};

    my $idx = 0;
    $logger->debug("beg create session[SI] for $icfg->{name}.$idx");
    for my $line ( @{ $icfg->{lines} } ) {
        my $lscfg = {%$icfg};
        delete $lscfg->{lines};

        $lscfg->{idx}        = $idx;
        $lscfg->{localaddr}  = $line->{localaddr};
        $lscfg->{localport}  = $line->{localport};
        $lscfg->{remoteaddr} = $line->{remoteaddr};
        $lscfg->{remoteport} = $line->{remoteport};
        $lscfg->{timeout}    = $line->{timeout} if $line->{timeout};
        $lscfg->{interval}   = $line->{interval} if $line->{interval};

        # 每条线路都用自己的日志
        my $logname =
            $lscfg->{name} . "."
          . $lscfg->{idx} . "."
          . $lscfg->{remoteaddr} . "-"
          . $lscfg->{remoteport} . "."
          . "$mode.log";
        my $newlog = $logger->clone($logname);

        # 启动
        my $ls = $icfg->{module}->spawn( $newlog, $lscfg );
        $idx++;
    }
}

#
# 启动双工主动
#
sub _spawn_da {

    my ($icfg, $logger)  = @_;
    my $mode = $icfg->{mode};

    my $idx = 0;
    for my $line ( @{ $icfg->{lines} } ) {
        my $lscfg = {%$icfg};
        delete $lscfg->{lines};

        $logger->debug("beg create session[$mode] for $icfg->{name}.$idx");

        $lscfg->{idx}        = $idx;
        $lscfg->{remoteaddr} = $line->{remoteaddr};
        $lscfg->{remoteport} = $line->{remoteport};
        $lscfg->{timeout}    = $line->{timeout} if $line->{timeout};
        $lscfg->{interval}   = $line->{interval} if $line->{interval};

        # $logger->debug("lscfg:\n" . Data::Dump->dump($lscfg));

        # 每条线路都用自己的日志
        my $logname =
            $lscfg->{name} . "."
          . $lscfg->{idx} . "."
          . $lscfg->{remoteaddr} . "-"
          . $lscfg->{remoteport} . "."
          . "$mode.log";
        my $newlog = $logger->clone($logname);

        # 启动线路session
        $logger->debug(
            "spawn $icfg->{module} with:\n" . Data::Dump->dump($lscfg) );
        my $ls = $icfg->{module}->spawn( $newlog, $lscfg );
        $idx++;
    }
}

#
# 启动双工被动
#
sub _spawn_dr {

    my ($icfg, $logger)  = @_;
    my $mode = $icfg->{mode};

    my $idx = 0;
    for my $line ( @{ $icfg->{lines} } ) {
        my $lscfg = {%$icfg};
        delete $lscfg->{lines};

        $logger->debug("beg create session[$mode] for $icfg->{name}.$idx");

        $lscfg->{idx}       = $idx;
        $lscfg->{localaddr} = $line->{localaddr};
        $lscfg->{localport} = $line->{localport};
        $lscfg->{timeout}   = $line->{timeout}  if $line->{timeout};
        $lscfg->{interval}  = $line->{interval} if $line->{interval};
        $lscfg->{lfd}       = $line->{lfd} if $line->{lfd} and $mode =~ /ts/;

        # $logger->debug("lscfg:\n" . Data::Dump->dump($lscfg));

        # 每条线路都用自己的日志
        my $logname =
            $lscfg->{name} . "."
          . $lscfg->{idx} . "."
          . $lscfg->{localaddr} . "-"
          . $lscfg->{localport} . "."
          . "$mode.log";
        my $newlog = $logger->clone($logname);

        # 启动线路session
        $logger->debug( "spawn $icfg->{module} with:\n" . Data::Dump->dump($lscfg) );
        my $ls = $icfg->{module}->spawn( $newlog, $lscfg );
        $idx++;
    }
    return 1;
}

#
# 启动TCP client
#
sub _spawn_tc {
    return &_spawn_da(@_);
}

#
# 启动TCP server
#
sub _spawn_ts {
    return &_spawn_dr(@_);
}

#
# 启动特别服务
#
sub _spawn_ext {

    my ($icfg, $logger) = @_;
    my $mode = $icfg->{mode};

    #############################
    # 定制化配置, 启动方式:
    # {
    #     mode   => 'xx',
    #     module => 'Zeta::Comet::XX',
    # }
    #############################
    my $idx = 0;
    for my $line ( @{ $icfg->{lines} } ) {

        my $lscfg = {%$icfg};
        delete $lscfg->{lines};
        $lscfg->{line} = $line;
        $lscfg->{line}->{idx} = $idx;

        $logger->debug("begin spawn new session for $lscfg->{name}");
        my $logname = $lscfg->{name} . "." . $lscfg->{idx} . "." . "cust.log";
        my $newlog = $logger->clone( $lscfg->{name} . "." . $lscfg->{idx} . "cust.log" );

        # 准备日志启动
        my $ls = $icfg->{module}->spawn( $newlog, $icfg );
        $idx++;
    }

    return 1;
}

#
# 启动adapter
#
sub _spawn_ad {

    my ($args, $logger) = @_;

    #################################
    # adapter配置参数经检查
    #################################
    my $ad_name = $args->{adapter};

    eval "use $ad_name;";
    if ($@) {
        $logger->error("can not load $ad_name\[$@]");
        return undef;
    }

    # $logger->debug("begin spawn adapter[$ad_name] with args:\n" . Data::Dump->dump($args->{ad_args}));
    my $ad = $ad_name->spawn(
        logger => $logger,
        %{ $args->{ad_args} },
    );
    unless ($ad) {
        $logger->error("can not create Adapter::Pipe");
        return undef;
    }

}


#
# 机构配置检查
#
sub ins_check {

    my $iname = shift;
    my $ins   = shift;

    # mode
    unless ( $ins->{mode} ) {
        cluck "$iname mode does not configured:\n" . Data::Dump->dump($ins);
        return;
    }

    # 加载模块
    eval "use $ins->{module};";
    if ($@) {
        cluck "can not load $ins->{module}\[$@]";
        return;
    }

    #
    # default modules
    # codec must be provided
    #
    if (   $ins->{module} =~ /^(Zeta::Comet::SI)$/
        || $ins->{module} =~ /^(Zeta::Comet::DA)$/
        || $ins->{module} =~ /^(Zeta::Comet::DR)$/
        || $ins->{module} =~ /^(Zeta::Comet::TC)$/
        || $ins->{module} =~ /^(Zeta::Comet::TS)$/ )
    {
        unless ( $ins->{codec} && $ins->{codec} =~ /(nac|ins)\s+(\d+)/ ) {
            cluck "$iname mode[$ins->{mode}] module[$ins->{module}] codec must be [nac N|ins N]";
            return;
        }
    }

    return 1;
}

#################################################################################
# 启动机构的指线路
# $icfg = {
#     mode   => 'tc',
#     module => 'Zeta::Comet::TC',
#     codec  => 'ins 4',
#     lines  => [
#        localaddr => '127.0.0.1'
#        localport => '9191'
#        timeout   => 10,
#        interval  => 5,
#     ],
# }
# Zeta::Comet->spawn_line($icfg,  name => $name, idx => 0, logger => $logger );
#################################################################################
sub spawn_line {

    my $class = shift;
    my $icfg  = shift;
    my $args  = {@_};

    my $line = { %{ $icfg->{lines}->[ $args->{idx} ] }, @_ };    # slice all

    my ( $addr_name, $addr_value );
    my ( $port_name, $port_value );

    #
    # da tc 为客户端， 需要remote
    #
    if ( $icfg->{mode} =~ /^(da|tc|si)/ ) {
        $addr_name  = "remoteaddr";
        $port_name  = "remoteport";
        $addr_value = $line->{remoteaddr};
        $port_value = $line->{remoteport};
    }

    #
    # dr ts 为服务端， 需要local
    #
    elsif ( $icfg->{mode} =~ /^(ts|dr)/ ) {
        $addr_name  = "localaddr";
        $port_name  = "localport";
        $addr_value = $line->{localaddr};
        $port_value = $line->{localport};
    }
    else {
        return;
    }

    my $logname =
        $line->{name} . "."
      . $line->{idx} . "."
      . $line->{$addr_name} . "-"
      . $line->{$port_name} . "."
      . "$icfg->{mode}.log";

    my $old_log = delete $line->{logger};
    $line->{logger} = $old_log->clone($logname);
    $line->{idx}    = $args->{idx};
    $line->{codec}  = $icfg->{codec};

    eval "use $icfg->{module};";
    if ($@) {
        croak "can not load module[$icfg->{module}]";
    }

    $old_log->debug( "begin spawn line:\n" . Data::Dump->dump($line) );
    $icfg->{module}->spawn($line);
}

1;

__END__


=head1 NAME

Zeta::Comet  - a communication framework for multi-institute switch

  Common Switch Senario:

  unpack :  module used for transforming incoming packet to inner swith data 
  pack   :  module used for transforming inner swith data to out-going packet
  switch :  module used for loggging txn, routing etc...

              ---------
  ------     \|       |                               |------|
  | DA |------|       |                               |      |
  ------     /|       |             ------------      |      |
              |       |             |  unpack  |------|      |
              |       |             ------------      |      |
  ------/     |       |             /                 |      |
  | DR |------|       |            /                  |      |
  ------\     |       |________   /                   |      |
              |       |        | /                    |      |
              |       |        |/                     |      |
  ------/    \| Comet | Adapter|                      |Switch|
  | SI |------|       |        |\                     |      |
  ------\    /|       |        | \                    |      |
              |       |________|  \                   |      |
              |       |            \                  |      |
  ------     \|       |             \                 |      |
  | TC |------|       |             ------------      |      |
  ------     /|       |             |  pack    |------|      |
              |       |             ------------      |      |
              |       |                               |      | 
  ------/     |       |                               |------|
  | TS |------|       |
  ------\     |       |
              ---------

=head1 SYNOPSIS

  #!/usr/bin/perl -w
  use strict;
  
  my $comet = Zeta::Comet->spawn(
    logger  => $logger,
    ins     => \%ins,
    adapter => 'Tino::Comet::Adapter::Container',
    ad_args => \%ad_args,
  ); 


  $comet->run();


=head1 Component

  Zeta::Comet::DA         : Duplex Active Long Connection
  Zeta::Comet::DR         : Duplex Reactive Long Connection 
  Zeta::Comet::SI         : Simplex
  Zeta::Comet::TC         : TCP  Client
  Zeta::Comet::TC::HTTP   : HTTP Client
  Zeta::Comet::TS         : TCP  Server
  Zeta::Comet::TS::HTTP   : HTTP Server
  Zeta::Comet::Adapter    : Adapter between institute and inner modules


=head2 Zeta::Comet::DA

  Duplex Active

=head3 Subclass API

  _on_start    : customizable configuration
  _on_connect  : after connected to remote, you can do some negotiation in it
  _packet      : recieved packet from remote, change it
  _adapter     : recieved data from adapter, change it

=head3 _on_start($class, $heap, $kernel, $args)

=head3 _on_connect($class, $heap, $kernel)

=head3 _packet($class, $heap, $remote_data)

=head3 _adapter($class, $heap, $adapter_data)


=head2 Zeta::Comet::DR

  Duplex Reactive

=head3 Subclass API

  _on_start    : customizable configuration
  _on_accept   : after got a client, you can do some negotiation with the client
  _packet      : recieved packet from remote, change it
  _adapter     : recieved data from adapter, change it

=head3 _on_start($class, $heap, $kernel, $args)

=head3 _on_accept($class, $heap, $kernel)

=head3 _packet($class, $heap, $remote_data)

=head3 _adapter($class, $heap, $adapter_data)


=head2 Zeta::Comet::SI

  Simplex  

=head3 Subclass API

  _on_start    : customizable configuration
  _on_connect  : after connected to remote, you can do some negotiation in it
  _on_accept   : after got a client, you can do some negotiation with the client
  _packet      : recieved packet from remote, change it
  _adapter     : recieved data from adapter, change it

=head3 _on_start($class, $heap, $kernel, $args)

=head3 _on_connect($class, $heap, $kernel)

=head3 _on_accept($class, $heap, $kernel)

=head3 _packet($class, $heap, $remote_data)

=head3 _adapter($class, $heap, $adapter_data)


=head2 Zeta::Comet::TC

  TCP Client

=head3 Subclass API

  _on_start
  _request
  _packet 

=head3 _on_start

=head3 _request

=head3 _adapter


=head2 Zeta::Comet::TS

  TCP Server

=head3 Subclass API

  _on_start
  _request
  _packet 

=head3 _on_start

=head3 _response

=head3 _packet


=head2 Zeta::Comet::Adapter

  Adatper

=head3 Subclass API

  _on_start          : customizable configuration
  _recv_wheel        : how to recieve data from other module
  _send_wheel        : hot to send data to other module
  _remote_filter     : after recieve data from institute, change it
  _adapter_filter    : after recieve data from inner module, change it
  _on_session_join   : institute line negotiated, the line session will notify adapter
  _on_session_leave  : institute line lost, the line session will notify adapter

=head3 _on_start($class,$heap,$kernel,$args)

=head3 _recv_wheel($class,$heap,$recv_arg)

=head3 _send_wheel($class,$heap,$send_arg)

=head3 _remote_filter($class,$heap,$remote_data)

=head3 _adapter_filter($class,$heap,$adapter_data)

=head3 _on_session_join($heap,$kernel,$cookie)

=head3 _on_session_leave($heap,$kernek,$cookie)


=head1 Author

  zcman2005@gmail.com

=cut



