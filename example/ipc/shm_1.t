#!/usr/bin/perl -w
use strict;
use Zeta::IPC::SHM;
use Time::HiRes qw/gettimeofday tv_interval/;

my $shm1 = Zeta::IPC::SHM->new(99990000,1024);
my $shm2 = Zeta::IPC::SHM->attach(99990000);

my $data;

my $const = "this is a test " x 60;

my $len = length $const;
my $ts1 = [gettimeofday];
for ( 0..1000000) {
    $shm1->write(\$const, 10, $len);  # offset = 10, length = 20
    $shm2->read(\$data, 10, $len);                # offset = 10, length = 20
}
warn "consumed: " . tv_interval($ts1) . "\n";
warn "read: [$data]\n";

$ts1 = [gettimeofday];
for ( 0..1000000) {
    $data = "this is a test";
    my $dat2 = $data;
}
warn "consumed: " . tv_interval($ts1) . "\n";


exit 0;

