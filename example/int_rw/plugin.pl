#!/usr/bin/perl
use Zeta::Run;

helper test_a => sub {
   zlogger->debug("test_a is called");
};

zlogger->debug("plugin.pl is called");

