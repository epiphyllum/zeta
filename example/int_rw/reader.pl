#!/usr/bin/perl

use Zeta::Run;

sub {
  my $fh = zkernel->channel_reader('Zchnl');
  while(<$fh>) {
    chomp;
    zlogger->debug("reader got [$_]"); 
    zkernel->test_a(); 
  }
};
