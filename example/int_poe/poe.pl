#!/usr/bin/perl

use POE;

sub {

  POE::Session->create(
    inline_states => {
      _start => sub {
        zlogger->debug("I am started");
        $_[KERNEL]->delay('tick' => 1);
      },
      tick => sub {
        zlogger->debug("I am ticking");
        $_[KERNEL]->delay('tick' => 1);
      },
    },
  );
  
 #  $SIG{TERM} = sub { $logger->debug("I am exiting"); CORE::exit; warn "I am alive";};
  $poe_kernel->run();
  exit 0;
};

