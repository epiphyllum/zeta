#!/usr/bin/perl
use strict;
use warnings;
use Zeta::Run;

#
# host => '127.0.0.1',
# port => '9999',
# dir  => '/tmp',
#
sub {
    my $logger = zlogger;
    my $cnt = 0;
    while(1) {
        $logger->debug("hello $cnt");
        $cnt++;
        sleep 1;
    }
};
