#!/usr/bin/perl
use Zeta::POE::XMLD;
use POE;

Zeta::POE::XMLD->spawn( 
     port     => 8888, 
     RootName => 'opreq',
     codec    => 'ascii 8',
     permanent => 1,
     callback => sub {  { now => `date +%H%M%S` } },
     debug => 1,
);
$poe_kernel->run();
exit 0;

