package Zeta::Log;
use strict;
use warnings;
use File::Basename;
use Data::Dump;
use Data::Hexdumper qw/hexdump/;
use JSON::XS;

BEGIN {
    no strict;
    *{'loggerd'} = \&{"new"};
}

use IO::File;
use Zeta::IniParse;
use File::Basename;
use IO::Socket::INET;
use File::Path qw/mkpath/;

use Zeta::IPC::MsgQ;

# static data
my %lmap = (
   debug => [ 'DEBUG->', 5 ],
   info  => [ 'INFO-->', 4 ],
   warn  => [ 'WARN-->', 3 ],
   error => [ 'ERROR->', 2 ],
   fatal => [ 'FATAL->', 1 ],
   crit  => [ 'CRIT-->', 0 ],
);

#
# usage example:
#####################################
# 1> from file
# Zeta::log->new(
#   'log_conf' => '/path/of/log.conf',
#    module    => tgp
# );
#
# 2> pipereader for loggerd
# Zeta::log->new(
#   logurl     =>
#   pipereader =>
# );
#
# 3> file handle
# Zeta::Log->new(
#   loglevel  => DEBUG
#   handle    => $handle
# );
#
# 4> proto:
#   4.1: stderr
#   4.2  stdout
#   4.3  file:///tmp/logfile.log
#   4.4  logserver://u@p/ip:port/path/of/logfile.log
#
# Zeta::Log->new(
#   loglevel  =>
#   logurl    => stdout,stderr,....
# );
#
#----------------------------
# log.conf format:
#----------------------------
# loglevel = DEBUG
# logurl   = file:///path/of/logpath/a.log
#            logsever://username@passord/192.168.1.29:12345/a.log
#            stderr
#            stdout
#
sub new {

    my $class  = shift;
    my %config = @_;
    my $logdata;
    my $logall;
    my $logc;

    #
    # read config from config file
    #
    if ( exists $config{'log_conf'} && exists $config{'module'} ) {
        $logall = ini_parse( $config{'log_conf'} );
        unless ($logall) {
            warn "$0:$$> ini_parse failed";
            return undef;
        }
        $logc = $logall->{ $config{'module'} };
    }

    #
    # 函数参数优先级高于配置文件
    #
    if ( exists $config{'loglevel'} ) { $logc->{'loglevel'} = $config{'loglevel'}; }
    if ( exists $config{'handle'}   ) { $logc->{'handle'}   = $config{'handle'};   }
    if ( exists $config{'logurl'}   ) { $logc->{'logurl'}   = $config{'logurl'};   }
    if ( exists $config{'logmonq'}  ) { $logc->{'logmonq'}  = $config{'logmonq'};     }

    #
    # 非pipereader模式下:  loglevel必须存在
    #
    unless ( exists $config{'pipereader'} ) {
        unless ( exists $logc->{'loglevel'} ) {
            warn "$0:$$> loglevel failed";
            return undef;
        }
        if ( $logc->{'loglevel'} =~ /^\d+$/ ) {
            $logdata->{'loglevel'} = $logc->{'loglevel'};
        }
        else {
            $logdata->{'loglevel'} = $lmap{ lc $logc->{'loglevel'} }->[1];
        }
        unless ( defined $logdata->{'loglevel'} ) {
            warn "$0:$$> loglevel illegal";
            return undef;
        }
    }

    #
    # use filehandle
    #
    if ( $logc->{'handle'} ) {
        $logdata->{'proto'} = 'handle';
        $logdata->{'logfh'} = $logc->{'handle'};
        $logdata->{'logfh'}->autoflush(1);
    }

    #
    # use logurl for proto
    #
    else {

        # check logurl..
        unless ( exists $logc->{'logurl'} ) {
            warn "$0:$$> logurl failed";
            return undef;
        }

        my $proto;
        my $address;
        my $logfh;

        ############################################################
        # logurl analysis
        ############################################################
        #
        # 标准出错作为日志文件
        #
        if ( $logc->{'logurl'} =~ /^stderr/ ) {

            # warn "$0:$$> proto:  stderr";
            $logfh = \*STDERR;
            $logdata->{'proto'} = "stderr";
            $logfh->autoflush(1);
            $logdata->{'logfh'} = $logfh;
        }

        #
        # 标准输出作为日志文件
        #
        elsif ( $logc->{'logurl'} =~ /^stdout/ ) {

            # warn "$0:$$> proto:  stdout";
            $logfh = \*STDOUT;
            $logdata->{'proto'} = "stdout";
            $logfh->autoflush(1);
            $logdata->{'logfh'} = $logfh;
        }

        #
        # file:///tmp/logfile.log
        # logserver://u@p/ip:port/dir/of/logfile.log
        #
        else {
            ( $proto, $address ) = split ':\/\/', $logc->{'logurl'};

            # warn "$0:$$> proto      :  $proto\n";
            # warn "$0:$$> proto_info :  $address\n";
            $logdata->{'proto'} = $proto;

            #
            # 本地文件作为日志文件
            #
            if ( $proto =~ /^file/ ) {
                $logdata->{'address'} = $address;
            }

            #
            # 日志服务器作为日志文件
            #
            elsif ( $proto =~ /^logserver/ ) {

                # address now likes:  u@p/ip:port/path/of/logfile.log

                unless ( $address =~ /^(.+)@(.+)\/([\d\.]+:[\d\.]+)(\/.+)/ ) {
                    return undef;
                }
                my ( $u, $p, $address, $logname ) = ( $1, $2, $3, $4 );
                $logdata->{'username'} = $u;
                $logdata->{'password'} = $p;
                $logdata->{'address'}  = $address;
                $logdata->{'logname'}  = $logname;
                warn "$0:$$> user    : $u\n";
                warn "$0:$$> pass    : $p\n";
                warn "$0:$$> address : $address\n";
                warn "$0:$$> logname : $logname\n";
            }
            else {
                warn "$0:$$> unsupported proto $proto";
                return undef;
            }
        }
    }
    my $self = bless $logdata, $class;

    $self->open_log();  # only file:///dir  and logserver://user@password/ip:port need open_log

    #
    # 专用日志进程
    # 从日志管道读取日志， 发送到日志文件
    #
    if ( $config{'pipereader'} ) {

        my $reader = $config{'pipereader'};

        # SIGTERM handling
        $SIG{TERM} = sub {
            $self->print_log( __FILE__, __LINE__,
                "WARN-->", "got signal term, exit now..."
            );
            exit 0;
        };

        #
        # SIGALRM handling
        #
        $SIG{ALRM} = sub {
            unless ( defined $self->{'logfh'} ) {
                warn "$0 is alive";
            }
            else {
                $self->print_log( __FILE__, __LINE__, "INFO-->", "I am alive" );
            }
            alarm(60);
        };

        alarm(60);

        #
        # in the begignning, connect to logserver error
        #
        while (<$reader>) {
            unless ( defined $self->{'logfh'} ) {
                $self->open_log();
                next;
            }
            last;
        }

        #
        # normal situation
        #
        $self->print_log( __FILE__, __LINE__,
            "INFO-->", "normal now! begin pipe log to logfile...."
        );
        while (<$reader>) {
            unless ( $self->{'logfh'}->print($_) ) {
                $self->open_log();
            }
        }
        exit 0;
    }

    # 监控队列
    if ( $logc->{logmonq} ) {
        $self->{logmonq} = Zeta::IPC::MsgQ->new($logc->{logmonq});
    }

    {
        no strict 'refs';
        no warnings 'redefine';
        my $mlevel = $lmap{info}->[1];  # 监控报警级别
        for my $name ( keys %lmap ) {
            my $level  = $lmap{$name}->[1];
            my $prefix = $lmap{$name}->[0];

            *{ __PACKAGE__ . "::$name" } = sub {
                my $self = shift;
                my ( $pkg, $line ) = (caller)[ 1, 2 ];
                
                # 写日志文件
                if ( $self->{'loglevel'} >= $level ) {
                    $self->print_log( $pkg, $line, $prefix, @_ );
                }
                # 发送报警信息到监控队列
                if ($self->{logmonq} && $level < $mlevel) {
                    my $mod = $0;
                    my $msg = encode_json({ mod => $mod, pkg => $pkg, line => $line, err => \@_ });
                   
                    # 监控队列满再发一次 
                    unless($self->{logmonq}->send($msg, $$)) {
                        # warn "发送失败, 重发";
                        my $g1;
                        my $g2 = 0;
                        $self->{logmonq}->recv_nw(\$g1, \$g2);
                        # warn "got old[$g1]";
                        $self->{logmonq}->send($msg, $$) or warn "重发失败";
                    }
                }
                return $self;
            };
        }
    }

    return $self;
}

#
# clone an log with the same loglevel, but different logfile
#
sub clone {

    my $self   = shift;
    my $newlog = shift;
    my $nlevel = shift;

    my $new = {%$self};
    bless $new, __PACKAGE__;

    $nlevel ||= $self->loglevel();

    $new->loglevel($nlevel);

    if ( $new->{proto} =~ /file/ ) {
        $new->{address} =~ s/[^\/]+$/$newlog/;
    }
    elsif ( $new->{proto} =~ /logserver/ ) {
        $new->{logname} =~ $newlog;
    }
    else {
        $self->warn("$self->{proto} is not clonable");
        return $self;
    }

    unless ( $new->open_log() ) {
        warn "can not open_log";
        return undef;
    }

    return $new;
}

#
# proto: file|logserver need reopen
#
sub open_log {

    my $self = shift;
    if ( $self->{'proto'} =~ /^file/ ) {

        # warn "$0:$$> begin open log:", $self->{'address'}, "\n";
        my $dir = dirname( $self->{address} );
        unless ( -d $dir ) {
            warn "$0:$$> directory $dir does not exists";
            mkpath( $dir, { verbose => 0, mode => 0711 } )
              ;    # bugfix:  verbose must be set to 0
        }
        my $logfh = IO::File->new(">> $self->{'address'}");
        unless ($logfh) {
            return undef;
        }
        $logfh->autoflush(1);
        $self->{logfh} = $logfh;
    }
    elsif ( $self->{'proto'} =~ /^logserver/ ) {

        # connect to logserver
        # warn "$0:$$> begin open log:", $self->{'address'}, "\n";
        my $logfh = IO::Socket::INET->new("$self->{'address'}");
        unless ($logfh) {
            return undef;
        }
        autoflush $logfh, 1;
        $logfh->blocking(1);

        # log in request
        my $u = $self->{'username'};
        my $p = $self->{'password'};
        warn "$0:$$> begin login: $u @ $p\n";
        unless ( $logfh->print("$u:$p\n") ) {
            warn "$0:$$> print login with[$u:$p] failed";
            return undef;
        }

        # log in response
        my $res = <$logfh>;
        unless ( $res =~ /^success/ ) {
            warn "$0:$$> login with[$u:$p] failed";
            return undef;
        }

        # send logname
        warn "$0:$$> begin send logname: ", $self->{'logname'}, "\n";
        $logfh->print( $self->{'logname'}, "\n" );

        $self->{logfh} = $logfh;

        return $self;
    }

    # open STDERR, ">&", $self->{'logfh'} if $self->{'logfh'} != \*STDERR;
}

#
# 日志级别
#
sub loglevel {

    my $self  = shift;
    my $level = shift;
    unless ( defined $level ) {
        return $self->{'loglevel'};
    }

    # 传入的是数字
    if ( $level =~ /[0-5]/ ) {
        $self->{'loglevel'} = $level;
        return $self;
    }

    # 传入的是DEBUG ...
    $self->{'loglevel'} = $lmap{lc $level}->[1];

    return $self;

}

#
# sub
#
sub logfh {
    my $self = shift;
    return $self->{'logfh'};
}

#
# debug hex log
# $self->debug_hex($prompt, $data);
#
sub debug_hex {
    my $self = shift; 
    unless(@_ == 2) {
        warn "debug_hex参数必须是三个";
        return $self;
    }

    my ($prompt, $data) = @_;
    $self->debug($prompt);

    my $len = length $data;
    return $self unless $len;
   
    if ( $self->{'loglevel'} >= $lmap{debug}->[1] ) {
        $self->{logfh}->print( "  length : [$len]\n");
        $self->{logfh}->print( hexdump( $data, { suppress_warnings => 1 } ) )
    }
    return $self;
}

#
# 打印日志到文件
#
sub print_log {

    my $self = shift;
    my $pkg  = shift;
    my $line = shift;
    my $flag = shift;
    my $name = $0;

    if ( $pkg =~ /(.{14})$/ ) {
        $pkg = $1;
    }
    if ( $name =~ /(.{10})$/ ) {
        $name = $1;
    }

    #
    # 采用本地文件
    #
    if ( $self->{'proto'} =~ /^file/ ) {
        unless ( -f $self->{'address'} ) {    # 发生logrotate
            my $dir = dirname( $self->{address} );
            mkpath( $dir, { verbose => 0, mode => 0711 } )
              ;                               # bugfix  verbose must be set to 0
            my $logfh = IO::File->new(">> $self->{'address'}");
            unless ($logfh) {
                return $self;
            }
            autoflush $logfh, 1;
            $self->{'logfh'} = $logfh;
        }
    }

    #
    # 输出日志
    #
    my ( $y, $m, $d, $H, $M, $S ) = (localtime)[ 5, 4, 3, 2, 1, 0 ];
    unless (
        $self->{'logfh'}->print(
            sprintf(
                "%02d:%02d:%02d %04d%02d%02d <%14s>:%04d %s [%10s]: ",
                $H, $M, $S,    # HH:MM:SS
                $y + 1900, $m + 1, $d,    # YYYY-MM-DD
                $pkg, $line, $flag,
                $name
              )
              . "@_\n"
        )
      )
    {
        $self->open_log();
    }

    return $self;

}

1;
__END__

=head1 NAME

  Zeta::Log - a simple Log module
  
=head1 SYNOPSIS
  
  use Zeta::Log;
  
  my $l1 = Zeta::Log->new(
    'loglevel' => 'DEBUG',
    'handle'   => \*STDOUT,
  ) or die "can not Zeta::Log->new";
  
  $l1->debug("this is a debug");
  
  my $l2 = Zeta::Log->new(
    loglevel  => 'DEBUG',
    logurl    => 'stderr',
  ) or die "can not Zeta::Log->new";
  
  $l2->debug("this is a debug");
  
  my $l3 = Zeta::Log->new(
    loglevel  => 'DEBUG',
    logurl    => 'file://$A_HOME/a.log',
    logmonq   => 9898,      # monitor queue for warning!!!!
  ) or die "can not Zeta::Log->new";
  
  $l3->debug("this is a debug");
  
  my $l4 = Zeta::Log->new(
    loglevel  => 'DEBUG',
    logurl    => 'logserver://apsrisk@jessie/192.168.1.29:12345/apsrisk.log',
  ) or die "can not Zeta::Log->new";
  
  $l4->debug("this is a debug");
  
=head1 API

  debug :
  info  :
  warn  :
  error :
  crit  :
  fatal :

=over 4

=back

