#!/usr/bin/perl
use strict;
use warnings;
use Zeta::Run;
use DBI;
use Carp;
use POE;
use Time::HiRes qw/sleep/;
use Zeta::POE::HTTPD::JSON;

#
#
#  host => '192.168.1.10',
#  port => 9999,
#  size => 20
#
sub {
   my $args = { @_ };
    
    # 获取日志
    my $monq = zkernel->logger_monq();
   
    # 启动HTTPD POE
    my $httpd = Zeta::POE::HTTPD::JSON->spawn( 
        alias    => 'httpd',
        port     => $args->{port},
        host     => $args->{host},
        callback => sub {
            my @rtn = ();
            my $msg;
            my $mtype = 0;
            my $cnt++;
            while($monq->recv_nw(\$msg, \$mtype)) {
                push @rtn, $msg;
                last if $cnt++ > $args->{size};
                $mtype = 0;
            }
            return \@rtn;
        },
    );
    $poe_kernel->run();
};

