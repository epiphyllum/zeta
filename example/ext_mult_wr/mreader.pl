#!/usr/bin/perl
use strict;
use warnings;
use Zeta::Run;
use Getopt::Long;
use Data::Dump;

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
#
#############################################################
# read from A B C and write to stdou
#############################################################
use POE;
use POE::Wheel::ReadWrite;

#
# 获取通道
#
zkernel->load_plugin('channel');
my $options = zkernel->channel_option();
my $mreader = $options->{mreader};


# Data::Dump->dump($options);

zkernel->load_plugin('logger');
zkernel->init_plugin('logger', logurl => "file://./$options->{name}.log", loglevel => 'DEBUG'); 

POE::Session->create(
    inline_states => {
        _start  => \&on_start,
        on_init => \&on_init,
        on_data => \&on_data,
    },

);
$poe_kernel->run();

sub on_start {

    #
    # $mreader->{stdin} = \*STDIN;
    #
    for my $module ( keys %$mreader ) {
        $mreader->{$module}->blocking(0);
        my $module_w = POE::Wheel::ReadWrite->new(
            Handle     => $mreader->{$module},
            InputEvent => 'on_data',
            Filter     => POE::Filter::Line->new(),
        );
        $_[HEAP]{in}{ $module_w->ID() } = [ $module_w, $module ];
    }

    #
    # stdout
    #
    my $stdout = POE::Wheel::ReadWrite->new(
        Handle => \*STDOUT,
        Filter => POE::Filter::Line->new(),
    );
    $_[HEAP]{stdout} = $stdout;

    $stdout->put("initial_data 0");

}

#############################################################
#
#############################################################
sub on_data {

    my ( $input, $wid ) = @_[ ARG0, ARG1 ];
    my $wheel  = $_[HEAP]{in}{$wid}->[0];
    my $module = $_[HEAP]{in}{$wid}->[1];

    zlogger->debug("got data[$input] from module[$module]");
    $input =~ /^([\S]+) (\d+)$/;
    my $cnt = $2 + 1;
    $_[HEAP]{stdout}->put("$1 $cnt");

}



