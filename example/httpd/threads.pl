#!/usr/bin/perl

use threads;

my $thr = threads->create(
    sub {
        my $cnt = 0;
        while(1) {
            warn '$poe_kernel->post("hj", "on_data", $cnt++);';
            sleep 1;
        }
    },
);

while(1) {
    sleep 10;
}
exit 0;

