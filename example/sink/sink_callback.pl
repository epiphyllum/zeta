#!/usr/bin/perl
use Zeta::POE::Sink;
use POE;

Zeta::POE::Sink->spawn( 
     port     => 8888, 
     codec    => 'ascii 4',
     callback => sub { 
         my $req = shift;
         warn "got request:\n" . $req;
         'hello world'; 
     },
);
$poe_kernel->run();
exit 0;

