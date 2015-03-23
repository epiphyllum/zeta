#!/usr/bin/perl
use Zeta::POE::TCPD;
use POE;

Zeta::POE::TCPD->spawn( 
     port     => 8888, 
     callback => sub { 'hello world'; },
     codec    => 'ascii 4',
);
$poe_kernel->run();
exit 0;

