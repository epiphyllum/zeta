#!/usr/bin/perl
use POE;
use Data::Dumper;
use Zeta::POE::Client::XML;

Zeta::POE::Client::XML->spawn(
    host     => '127.0.0.1',
    port     => '8888',
    codec    => 'ascii 8',
    RootName => 'opreq',
    ocb      => \&ocb,
    icb      => \&icb,
    single   => 0,
    debug    => 1,
);

$poe_kernel->run();

my $cnt = 0;
sub ocb {
    my $req = {  hary => 'zhouchao', cnt => $cnt++};
    warn "-----------\n ocb snd:\n-----------\n" . Dumper($req);
    return $req;
}

sub icb {
    my $res = shift;
    warn "-----------\n icb rcv:\n-----------\n" . Dumper($res);
}

