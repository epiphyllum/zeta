#!/usr/bin/perl
use Zeta::Run;

#
helper plugin_parent => sub {
   zlogger->debug("plugin_parent functioin is called");
};

zlogger->debug("plugin.pl is called");

