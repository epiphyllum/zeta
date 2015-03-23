#!/usr/bin/perl

use Zeta::Run;

sub {
  while(1) {
    zkernel->plugin_parent();
    zkernel->plugin_child();
    sleep 2;
  }
};
