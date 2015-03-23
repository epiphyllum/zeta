#!/usr/bin/perl
use strict;
use warnings;
use Zeta::Run;
use POE;

use constant {
    DEBUG => $ENV{THREAD_DEBUG} || 0,
};

BEGIN {
    require Data::Dump if DEBUG;
}

sub { 
    while(1) { 
        pause(); 
    } 
};

__END__
