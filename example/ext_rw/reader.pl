#!/usr/bin/perl

use Zeta::Run;
use IO::Handle;
use Getopt::Long;


zkernel->load_plugin('channel');
my $name = zkernel->channel_option->{name};

zkernel->load_plugin('logger');
zkernel->init_plugin('logger', logurl => "file://./$name.log", loglevel => 'DEBUG');

STDIN->blocking(1);
while(<STDIN>) {
    chomp;
    zlogger->debug("reader got [$_]"); 
}

