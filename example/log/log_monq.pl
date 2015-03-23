#!/usr/bin/perl
use Zeta::Log;

warn "n => $n";

my $log = Zeta::Log->new(
    logurl   => "file://./t.log",
    loglevel => 'DEBUG',
    logmonq  => 9999,
);

for (1..10) {
    #    warn "$_";
    $log->error($_ . "-heloooooooooooooooooooooooooo" x 15 );
}
