#!/usr/bin/perl
use strict;
use warnings;
use Zeta::Run;
use Getopt::Long;

#############################################################
#
#   -----------
#   |  Zmain |          
#   ----------- 
#       |
#       |               -----------------|
#       |               |                |       
#       |              \|/               |
#       |      --------------------      |
#       |------|      mwriter     |      |
#       |      --------------------      |
#       |       |       |        |       |
#       |       A       B        C       |
#       |       |       |        |       |
#       |      \|/     \|/      \|/      |
#       |     --------------------       |
#       |-----|      mreader     |-------|
#       |     -------------------- 
#############################################################
#  mwriter read from stdin, and  randomly dispatch it (A,B,C)
#############################################################

zkernel->load_plugin('channel');
my $options = zkernel->channel_option();
my $mwriter = $options->{mwriter};

zkernel->load_plugin('logger');
zkernel->init_plugin('logger', logurl => "file://./$options->{name}.log", loglevel => 'DEBUG');

my $size   = keys %$mwriter;
my @module = keys %$mwriter;

while(my $line = <STDIN>) {
    $line =~ s/\s+$//g;
    my $midx = int(rand($size));
    my $m    = $module[$midx];
    zlogger->debug("got $line, and write to stdout and $m");
    $mwriter->{$m}->print("$line\n");
    sleep 1;
}


