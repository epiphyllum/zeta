#!/usr/bin/perl
use Zeta::POE::TCPD::JSON;
use POE;
use Data::Dump qw/dump/;

Zeta::POE::TCPD::JSON->spawn( 
     port     => 8888, 
     codec    => 'ascii 4',
     callback => sub {  
         dump(\@_);
         { now => `date +%H%M%S` };
     },
     context => 'hello',
);
$poe_kernel->run();
exit 0;

