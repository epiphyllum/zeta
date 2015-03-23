#!/usr/bin/perl
use strict;
use warnings;
use Zeta::Run;
use DBI;
use Carp;
use POE;
use Time::HiRes qw/sleep/;

#
# monq => 
# host =>
# port =>
#
sub {
    my $args = { @_ };
    
    my $cnt = 0;
    my $msvr;
    my $logger = zlogger;

    # 连接监控服务器
    while(1) {
        $msvr = IO::Socket::INET->new(
            PeerAddr => $args->{host},
            PeerPort => $args->{port}
        );
        
        unless($msvr) {
            $logger->error("无法连接到监控服务器[$args->{host}:$args->{port}], retry...");
            sleep(0.5);
            next if $cnt++ < 10;
            exit 0;
        }
        last;
    }

    # 连接监控消息队列
    my $monq = Zeta::IPC::MsgQ->new($args->{monq});
    unless($monq) {
    }

    # 不断从监控队列中读取监控消息, 发送到监控服务器上
    my $bytes;
    my $mtype = 0;
    while($monq->recv(\$bytes, \$mtype)) {
        my $len = sprintf("%04d", length $bytes);
        $logger->debug("recv msg[$len] <<<<<<<<:\n". $bytes);
        $msvr->print($len . $bytes);
        $mtype = 0;
    }
};


