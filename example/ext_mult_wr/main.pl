#!/usr/bin/perl

use POSIX qw/:sys_wait_h pause/;
use Zeta::IPC::MsgQ;
sub {
    while(1) { pause(); }
};


