package Zeta::Upgrade::Client;
use strict;
use warnings;
use IO::Socket::INET;
use IO::File;
use Zeta::Run;
use POE;

#######################################################################
# args:
#   chk_interval   => $chk_interval  # 检查更新周期
#   maxfail        => $maxfail       # 最大连续失败次数
#   fail_interval  => $fail_interval # 失败重试间隔
#   app_home       => $app_home      # 应用的主目录
#
#######################################################################
sub new {

    my $class = shift;
    my $args  = {@_};

    my $self = bless $args, $class;

    # 版本文件检查
    my $vfile = "$self->{app_home}/.version";
    unless ( -f $vfile ) {
        $run_kernel->{logger}->error("$vfile does not exists");
        return undef;
    }

    # 读取当前版本信息
    my $vfh = IO::File->new("< $self->{app_home}/.version");
    unless ($vfh) {
        $run_kernel->{logger}->error("can not read version file[$vfile");
        return undef;
    }
    $self->{version} = <$vfh>;
    chomp $self->{version};

    return $self;

}

###########################################
#
###########################################
sub run {

    my $self = shift;
    my $args = shift;

    # 日志
    my $logger = $run_kernel->{logger}->clone("upgrade.log");
    $self->{logger} = $logger;

    # POE session
    POE::Session->create(
        object_states => [
            $self => {
                'on_start'             => 'on_start',             #
                'on_socket_error'      => 'on_socket_error',      # socket错误
                'on_response'          => 'on_response',          # 响应
                'on_upgrade_list'      => 'on_upgrade_list',      # 请求更新列表
                'on_upgrade_list_res'  => 'on_upgrade_list_res',  # 请求更新列表响应
                'on_request_file'      => 'on_request_file',      # 请求文件
                'on_request_file_res'  => 'on_request_file_res',  # 请求文件响应
                'on_upgrade_check'     => 'on_upgrade_check',     # 升级检查
                'on_upgrade_check_res' => 'on_upgrade_check_res', # 升级检查响应
                'on_restart'           => 'on_restart',           # 重启
            },
        ],
        args => [],
    );

    $poe_kernel->run();

}

sub spawn {
}

###########################################
# 重启系统
###########################################
sub restart {

    my $self   = shift;
    my $logger = $self->{logger};

    local $SIG{HUP} = 'IGNORE';

    $logger->warn("Restarting...");

    my $leader = getppid;
    kill -1, $leader;    # send hup to process group execept myself
    unless ( POSIX::setsid() ) {
        $logger->error("Couldn't start a new session: $!");
        exit 0;
    }

    my $cmdline = $run_kernel->{cmdline};
    unless ( exec $run_kernel->{cmdline} ) {
        $logger->error("can not restart with[$cmdline]");
    }

    exit 0;
}

###########################################
#
###########################################
sub on_start {

    my $self   = $_[OBJECT];
    my $logger = $self->{logger};

    # 开始定时检查更新
    $_[KERNEL]->yield('on_upgrade_check');

    return 1;
}

###########################################
# 通讯错误
###########################################
sub on_socket_error {
    my $self   = $_[OBJECT];
    my $logger = $self->{logger};

    delete $self->{server};
    $logger->error("on_socket_error");

    $_[KERNEL]->yield('on_start');

}

###########################################
# 升级检查
# req:
#   {
#      action   => 'upgrade_check',
#      version  => 0.1,
#   }
###########################################
sub on_upgrade_check {

    my $self   = $_[OBJECT];
    my $logger = $self->{logger};

    # 连接服务器
    my $svr = IO::Socket::INET->new("$self->{remoteaddr}:$self->{remoteport}");
    unless ($svr) {
        $logger->error( "can not connect to $self->{remoteaddr}:$self->{remoteport}");
        $_[HEAP]{fail}++;
        if ( $_[HEAP]{fail} > $self->{maxfail} ) {
            $_[KERNEL]->delay( 'on_upgrade_check' => $self->{chk_interval} );
            return 1;
        }
        $_[KERNEL]->delay( 'on_upgrade_check' => $self->{fail_interval} );
        return 1;
    }

    my $wheel = POE::Wheel::ReadWrite->new(
        Handle     => $svr,
        Filter     => POE::Filter::CCC->new(),
        InputEvent => 'on_data',
        ErrorEvent => 'on_socket_error',
    );
    unless ($wheel) {
        $logger->error("can not create wheel");
        return 1;
    }
    $self->{server} = $wheel;

    # 发送升级申请
    $wheel->put(
        {
            action  => 'upgrade_check',
            version => $self->{version},
        }
    );

    return 1;
}

###########################################
# 升级检查响应
###########################################
sub on_upgrade_check_response {

    my $self   = $_[OBJECT];
    my $logger = $self->{logger};

    my $args = $_[ARG0];

    # 需要更新
    if ( $args->{version} > $self->{version} ) {
        $logger->info( "begin upgrade from version[$self->{version}] to version[$args->{version}]");
        $self->{new_version} = $args->{version};
        $_[KERNEL]->yield('on_upgrade_list');
        return 1;
    }

    # 本次检查不需要更新, 则定期再发送更新申请...
    $_[KERNEL]->delay( 'on_upgrade_check' => $self->{chk_interval} );

    return 1;
}

###########################################
# 获取更新列表
# req:
#   {
#     action  => 'upgrade_list',
#     version => 0.4,
#   }
###########################################
sub on_upgrade_list {

    my $self   = $_[OBJECT];
    my $logger = $self->{logger};

    $self->{server}->put( { action => 'upgrade_list', } );

    return 1;
}

sub on_upgrade_list_response {
    my $self   = $_[OBJECT];
    my $logger = $self->{logger};
    my $args   = $_[ARG0];
    my $list   = $_[ARG0]->{list};

    my %progress;
    for (@$list) {
        $progress{$_} = 1;
    }
    $self->{progress} = \%progress;

    for (@$list) {
        $_[KERNEL]->yield( 'on_request_file' => $_ );
    }
}

###########################################
# 请求文件
# req:
#   {
#     version  => 0.4,
#     filename => "libexec/monitor.pl",
#   }
###########################################
sub on_request_file {

    my $self   = $_[OBJECT];
    my $logger = $self->{logger};
    my $args   = $_[ARG0];

    $self->{server}->put(
        {
            action   => 'request_file',
            filename => $_[ARG0],
        }
    );

    return 1;
}

sub on_request_file_response {

    my $self   = $_[OBJECT];
    my $logger = $self->{logger};
    my $args   = $_[ARG0];

    unless ( $args->{status} == 0 ) {
        $logger->error("request_file failed");
    }

    # save file;
    my $file = IO::File->new();

    $file->print( $args->{content} );

    $self->{download} = delete $self->{progress}->{ $args->{filename} };

    # 所有文件都下载成功, 开始重启
    unless ( @{ $self->{progress} } ) {
        $_[KERNEL]->yield('on_restart');
    }

    return 1;
}

###########################################
# 重启
###########################################
sub on_restart {

    my $self     = $_[OBJECT];
    my $logger   = $self->{logger};
    my $download = delete $self->{download};

    # 重命名所有下载的文件
    for (@$download) {
    }

    # 写入版本号到版本文件
    my $vfh = IO::File->new("> $self->{app_home}/.version");
    unless ($vfh) {
        $logger->error("can not open(> $self->{app_home}/.version)");
        return 1;
    }
    $vfh->print( $self->{new_version} );

    # 重启系统
    $self->restart();

}

###########################################
# 得到服务器响应
###########################################
sub on_response {
    my $self   = $_[OBJECT];
    my $logger = $self->{logger};

    my $action = $_[ARG0]->{action};
    my $status = $_[ARG0]->{status};

    unless ( $status == 0 ) {
        $logger->error( "on_response got failed response:\n"
              . Data::Dump->dump( $_[ARG0] ) );
        $_[KERNEL]->yield('on_start');
        return 1;
    }

    $_[KERNEL]->yield( "on_${action}_response" => $_[ARG0] );

    return 1;
}

1;
