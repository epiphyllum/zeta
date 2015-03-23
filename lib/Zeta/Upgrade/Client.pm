package Zeta::Upgrade::Client;
use strict;
use warnings;
use IO::Socket::INET;
use IO::File;
use Zeta::Run;
use POE;

#######################################################################
# args:
#   chk_interval   => $chk_interval  # ����������
#   maxfail        => $maxfail       # �������ʧ�ܴ���
#   fail_interval  => $fail_interval # ʧ�����Լ��
#   app_home       => $app_home      # Ӧ�õ���Ŀ¼
#
#######################################################################
sub new {

    my $class = shift;
    my $args  = {@_};

    my $self = bless $args, $class;

    # �汾�ļ����
    my $vfile = "$self->{app_home}/.version";
    unless ( -f $vfile ) {
        $run_kernel->{logger}->error("$vfile does not exists");
        return undef;
    }

    # ��ȡ��ǰ�汾��Ϣ
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

    # ��־
    my $logger = $run_kernel->{logger}->clone("upgrade.log");
    $self->{logger} = $logger;

    # POE session
    POE::Session->create(
        object_states => [
            $self => {
                'on_start'             => 'on_start',             #
                'on_socket_error'      => 'on_socket_error',      # socket����
                'on_response'          => 'on_response',          # ��Ӧ
                'on_upgrade_list'      => 'on_upgrade_list',      # ��������б�
                'on_upgrade_list_res'  => 'on_upgrade_list_res',  # ��������б���Ӧ
                'on_request_file'      => 'on_request_file',      # �����ļ�
                'on_request_file_res'  => 'on_request_file_res',  # �����ļ���Ӧ
                'on_upgrade_check'     => 'on_upgrade_check',     # �������
                'on_upgrade_check_res' => 'on_upgrade_check_res', # ���������Ӧ
                'on_restart'           => 'on_restart',           # ����
            },
        ],
        args => [],
    );

    $poe_kernel->run();

}

sub spawn {
}

###########################################
# ����ϵͳ
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

    # ��ʼ��ʱ������
    $_[KERNEL]->yield('on_upgrade_check');

    return 1;
}

###########################################
# ͨѶ����
###########################################
sub on_socket_error {
    my $self   = $_[OBJECT];
    my $logger = $self->{logger};

    delete $self->{server};
    $logger->error("on_socket_error");

    $_[KERNEL]->yield('on_start');

}

###########################################
# �������
# req:
#   {
#      action   => 'upgrade_check',
#      version  => 0.1,
#   }
###########################################
sub on_upgrade_check {

    my $self   = $_[OBJECT];
    my $logger = $self->{logger};

    # ���ӷ�����
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

    # ������������
    $wheel->put(
        {
            action  => 'upgrade_check',
            version => $self->{version},
        }
    );

    return 1;
}

###########################################
# ���������Ӧ
###########################################
sub on_upgrade_check_response {

    my $self   = $_[OBJECT];
    my $logger = $self->{logger};

    my $args = $_[ARG0];

    # ��Ҫ����
    if ( $args->{version} > $self->{version} ) {
        $logger->info( "begin upgrade from version[$self->{version}] to version[$args->{version}]");
        $self->{new_version} = $args->{version};
        $_[KERNEL]->yield('on_upgrade_list');
        return 1;
    }

    # ���μ�鲻��Ҫ����, �����ٷ��͸�������...
    $_[KERNEL]->delay( 'on_upgrade_check' => $self->{chk_interval} );

    return 1;
}

###########################################
# ��ȡ�����б�
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
# �����ļ�
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

    # �����ļ������سɹ�, ��ʼ����
    unless ( @{ $self->{progress} } ) {
        $_[KERNEL]->yield('on_restart');
    }

    return 1;
}

###########################################
# ����
###########################################
sub on_restart {

    my $self     = $_[OBJECT];
    my $logger   = $self->{logger};
    my $download = delete $self->{download};

    # �������������ص��ļ�
    for (@$download) {
    }

    # д��汾�ŵ��汾�ļ�
    my $vfh = IO::File->new("> $self->{app_home}/.version");
    unless ($vfh) {
        $logger->error("can not open(> $self->{app_home}/.version)");
        return 1;
    }
    $vfh->print( $self->{new_version} );

    # ����ϵͳ
    $self->restart();

}

###########################################
# �õ���������Ӧ
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
