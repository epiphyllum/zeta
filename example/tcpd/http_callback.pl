#!/usr/bin/perl
use Zeta::POE::HTTPD;
use POE;

Zeta::POE::HTTPD->spawn( 
     port     => 8888, 
     callback => sub { 'hello world'; },
);
$poe_kernel->run();
exit 0;

