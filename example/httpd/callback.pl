#!/usr/bin/perl

use Zeta::Run;
use Zeta::POE::HTTPD::JSON;
use POE;
use threads;

Zeta::POE::HTTPD::JSON->spawn( 
     alias    => 'hj',
     port     => 8888, 
     callback =>  sub {
          return {
              msg  => 'hello world',
              time =>  `date +%H%M%S`,
          };
     },
     events => {
         on_data => sub {
             warn "@_";
         },
     },
);

$poe_kernel->run();
exit 0;

