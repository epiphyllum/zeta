package Zeta::Upgrade::Server;
use strict;
use warnings;

use POE;
use POE::Wheel::ListenAccept;
use POE::Wheel::ReadWrite;
use POE::Filter::JSON;
use IO::File;
use Zeta::Run;

#######################################################################
# args:
#   app_home       => /home/hary/mcenter/client/version.txt     # Ӧ�õ���Ŀ¼
#                     /home/hary/mcenter/client/0.1
#                     /home/hary/mcenter/client/0.2
#                     /home/hary/mcenter/client/0.3
#######################################################################
sub new {
    my $class = shift;
    my $args  = {@_};
    my $self  = bless $args, $class;
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
                'on_start'         => 'on_start',            #
                'on_socket_error'  => 'on_socket_error',     # socket����
                'on_request'       => 'on_request',          # ��Ӧ
                'on_upgrade_list'  => 'on_upgrade_list',     # ��������б�
                'on_request_file'  => 'on_request_file',     # �����ļ�
                'on_upgrade_check' => 'on_upgrade_check',    # �������
                'on_restart'       => 'on_restart',          # ����
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

    my $sock = IO::Socket::INET->new(
        LocalAddr => $self->{localaddr},
        LocalPort => $self->{localport},
        Reuse     => 1,
    );
    unless ($sock) {
        $logger->error(
            "can not start LA on[$self->{localaddr}:$self->{localport}]");
        $_[KERNEL]->delay( 'on_start' => 2 );
        return 1;
    }

    my $la = POE::Wheel::ListenAccept->new(
        Handle      => $sock,
        AcceptEvent => "on_accept",
        ErrorEvent  => "on_socket_error",
    );
    unless ($la) {
        $logger->error("can not create LA wheel");
        $_[KERNEL]->delay( 'on_start' => 2 );
        return 1;
    }

    $_[HEAP]{la} = $la;

    return 1;
}

###########################################
# �ͻ�������
###########################################
sub on_accept {
    my $self   = $_[OBJECT];
    my $logger = $self->{logger};
    my $client = $_[ARG0];
    $_[HEAP]{client}{ $client->ID } = $client;
}

###########################################
# ͨѶ����
###########################################
sub on_socket_error {
    my $self   = $_[OBJECT];
    my $logger = $self->{logger};
    $logger->error("on_socket_error");
    $_[KERNEL]->yield('on_start');
}

###########################################
# �յ��ͻ��˷����������
# req:
#   {
#      action   => 'upgrade_check',
#      version  => 0.1,
#   }
###########################################
sub on_upgrade_check {

    my $self   = $_[OBJECT];
    my $logger = $self->{logger};
    my $req    = $_[ARG0];
    my $client = $_[HEAP]{client}{ $_[ARG1] };

    # ��ȡ�汾������ʷ
    my $vfile = "$self->{upgrade_home}/version";
    my $vfh   = IO::File->new("<$vfile");
    unless ($vfh) {
        $req->{status} = 1;
        $req->{errmsg} = '500 server error';
        $client->put($req);
        return 1;
    }
    my @version;
    while (<$vfh>) {
        push @version, chomp;
    }

    my $idx;
    for ( $idx = 0 ; $idx < @version ; ++$idx ) {
        last if $req->{version} == $version[$idx];
    }
    if ( $idx == @version ) {
        $req->{status} = 2;
        $req->{errmsg} = "server nerver published version $req->{version}";
        $client->put($req);
        return 1;
    }

    # �Ѿ������°汾
    if ( $idx == $#version ) {
        $req->{status} = 0;
        $client->put($req);
        return 1;
    }

    # ��Ҫ����
    $req->{version} = $version[ $idx + 1 ];
    $req->{status}  = 0;
    $client->put($req);

    return 1;

}

###########################################
# �յ� �ͻ��˷����ȡ�����б�
# req:
#   {
#     action  => 'upgrade_list',
#     version => 0.4,
#   }
###########################################
sub on_upgrade_list {

    my $self   = $_[OBJECT];
    my $logger = $self->{logger};
    my $req    = $_[ARG0];
    my $client = $_[HEAP]{client}{ $_[ARG1] };

    my $lfile = $self->{upgrade_home} . "/$client->{version}/list.txt";
    unless ( -f $lfile ) {
        $logger->error("file $lfile does not exist");
        $req->{status} = 1;
        $req->{errmsg} = "500 server error";
        $client->put($req);
        return 1;
    }

    # ��ȡ�����ļ��б�
    my $lfh = IO::File->new("<$lfile");
    unless ($lfh) {
        $logger->error("can not open file $lfile");
        $req->{status} = 1;
        $req->{errmsg} = "500 server error";
        $client->put($req);
    }
    my @list;
    while (<$lfh>) {
        push @list, chomp;
    }

    # ��Ӧ����
    $req->{status} = 0;
    $req->{list}   = \@list;
    $client->put($req);

    return 1;
}

###########################################
# �ͻ��˷��������ļ�
# req:
#   {
#     version  => 0.4,
#     filename => "libexec/monitor.pl",
#   }
###########################################
sub on_request_file {

    my $self   = $_[OBJECT];
    my $logger = $self->{logger};
    my $req    = $_[ARG0];
    my $client = $_[HEAP]{client}{ $_[ARG1] };

    my $file = $self->{upgrade_home} . "/$req->{version}/$req->{filename}";
    unless ( -f $file ) {
        $logger->error();
        $req->{status} = 1;
        $req->{errmsg} = "file $file does not exist";
        $client->put($req);
        return 1;
    }
    my $fh = IO::File->new("<$file");
    unless ($fh) {
        $logger->error();
        $req->{status} = 1;
        $req->{errmsg} = "$file can not be opened";
        $client->put($req);
        return 1;
    }
    local $/;
    $req->{content} = <$fh>;
    $req->{status}  = 0;
    $client->put($req);

    return 1;
}

###########################################
# �յ��ͻ�������
###########################################
sub on_request {
    my $self   = $_[OBJECT];
    my $logger = $self->{logger};
    my ( $req, $id ) = @_[ ARG0, ARG1 ];

    if ( $req->{action} =~ /upgrade_check/ ) {
        $_[KERNEL]->yield( 'on_upgrade_check', $req, $id );
        return 1;
    }

    if ( $req->{action} =~ /upgrade_list/ ) {
        $_[KERNEL]->yield( 'on_upgrade_list', $req, $id );
        return 1;
    }

    if ( $req->{action} =~ /request_file/ ) {
        $_[KERNEL]->yield( 'on_request_file', $req, $id );
        return 1;
    }

    if ( $req->{action} =~ /end/ ) {
        delete $_[HEAP]{client}{$id};
        $logger->info("");
        return 1;
    }

    my $client = $_[HEAP]{client}{$id};
    $logger->warn( "unrecognized request from:\n" . Data::Dump->dump($req) );
    delete $_[HEAP]{client}{$id};
    return 1;
}

1;
