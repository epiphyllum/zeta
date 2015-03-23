#!/usr/bin/perl

use Zeta::Comet;
use Zeta::Log;
use POE;
use Zeta::Serializer::JSON;
use Zeta::Codec::Frame qw/ascii_n/;
use Zeta::Wheel::Block;

my $ser = Zeta::Serializer::JSON->new();
my $lfd = IO::Socket::INET->new(
        Listen    => 5,
        LocalAddr => 'localhost',
        LocalPort => 7771,
        Proto     => 'tcp',
        ReuseAddr => 1,
);


my ($r1, $w1);
my ($r2, $w2);

pipe ($r1, $w1);
pipe ($r2, $w2);

Zeta::Comet->spawn(

    logger => Zeta::Log->new( logurl => 'file://./httpd/Zcomet.log', loglevel => 'DEBUG'),

    ins    => {
        httpd => {
            mode   => 'ts',
            module => 'Zeta::Comet::TS::HTTP',
            lines  => [
                {
                    lfd       => $lfd,
                    localaddr => '127.0.0.1',
                    localport => '7771',
                    timeout   => 40,
                }
            ],
        },
    },
    adapter => 'Zeta::Comet::Adapter::Pipe',
    ad_args => {
        reader     => $r1,
        writer     => $w2,
        serializer => $ser,
    },
);

#
#
#
POE::Session->create(
    inline_states => {
        _start => sub {
            my $reader = POE::Wheel::ReadWrite->new(
                Handle => $r2,
                Filter => POE::Filter::Block->new( LengthCodec => ascii_n(4)),
                InputEvent => 'on_request',
            );
            my $writer = Zeta::Wheel::Block->new(
                handle => $w1,
            );
            $_[HEAP]{reader} = $reader;
            $_[HEAP]{writer} = $writer;
        },

        on_request => sub {
            my $req = $_[ARG0];
            my $req_hash = $ser->deserialize($req);

            my $packet = `date +%H:%M:%S`;
            my $res_hash = {
                dst    => 'httpd',
                packet => $packet,
                sid    => $req_hash->{sid},
            };
            my $res = $ser->serialize($res_hash);

            warn "got:$req";
            warn "snd:$res";
            $_[HEAP]{writer}->put($res);
        },
    },
);

$poe_kernel->run();

__END__

echo '{"a":"b"}' | POST 'http://localhost:7771'

