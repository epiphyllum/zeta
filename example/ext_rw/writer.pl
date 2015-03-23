#!/usr/bin/perl

use Zeta::Run;
use IO::Handle;
use Time::HiRes qw/sleep/;

zkernel->load_plugin('channel');
my $name = zkernel->channel_option->{name};

zkernel->load_plugin('logger');
zkernel->init_plugin('logger', logurl => "file://./$name.log", loglevel => 'DEBUG');


STDOUT->autoflush(1);
my $i = 0;
while(1) {
    print  "$$ i = $i\n";
    $i++;
    sleep 2;
}

