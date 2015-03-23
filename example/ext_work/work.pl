#!/usr/bin/perl

use Zeta::Log;

my $logger = Zeta::Log->new(
   logurl => 'stderr',
   loglevel => 'DEBUG',     
);

while(1) {
   $logger->debug("ARGV is @ARGV");
   sleep 2;
}

