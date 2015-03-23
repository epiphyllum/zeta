#!/usr/bin/perl

use Zeta::Run;
use Zeta::POE::HTTPD;
use POE;

Zeta::POE::HTTPD->spawn( 
     alias  => 'httpd',
     port   => 8888, 
     module => 'MyAdmin',
     para   => [ ],
);
$poe_kernel->run();

exit 0;

