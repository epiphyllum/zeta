#!/usr/bin/perl

use Zeta::Run;
use Zeta::POE::HTTPD;
use POE;

sub {
    Zeta::POE::HTTPD->spawn( 
         port   => 8888, 
         module => 'MyAdmin',
         para   => [ ],
    );
    $poe_kernel->run();
    zkernel->process_stopall();
    exit 0;
};

