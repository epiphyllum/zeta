#!/usr/bin/perl

use Zeta::Run;
use Time::HiRes qw/sleep/;

sub {
   Data::Dump->dump(zkernel);
   my $i = 0;
   my $fh = zkernel->channel_writer('Zchnl');
   while(1) {
      print  $fh "$$ i = $i\n";
      $i++;
      sleep 2;
   }
};

