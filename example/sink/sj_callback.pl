#!/usr/bin/perl
use Zeta::POE::Sink::JSON;
use POE;
use Data::Dump;

Zeta::POE::Sink::JSON->spawn( 
     port     => 8888, 
     codec    => 'ascii 4',
     callback => sub { 
         my $req = shift;
         warn "got request:\n" . Data::Dump->dump($req);
         'hello world'; 
     },
);
$poe_kernel->run();
exit 0;

__END__
0009{"a":"b"}0009{"a":"b"}0009{"a":"b"}0009{"a":"b"}0009{"a":"b"}0009{"a":"b"}

