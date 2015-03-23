#!/usr/bin/perl
use Zeta::POE::HTTPD::JSON;
use POE;

Zeta::POE::HTTPD::JSON->spawn( 
     port     => 8888, 
     callback => sub {  { now => `date +%H%M%S` } },
);
$poe_kernel->run();
exit 0;

