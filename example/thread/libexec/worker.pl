#!/usr/bin/perl
use strict;
use warnings;
use Zeta::Run;
use threads;
use threads::shared;
use Thread::Queue;
use Data::Dump;

#
# host => '127.0.0.1',
# port => '9999',
# dir  => '/tmp',
#
sub {
    my $logger = zlogger;
    my $cnt = 0;
    threads->create(
        sub {
            my $log = $logger->clone('thread.log');
            while(1) {
                $log->debug("thread is running $cnt");
                $cnt++;
                sleep 5;
            };
        },
    );
    $_->join for threads->list();
    exit 0;
};
