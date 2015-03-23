#!/usr/bin/perl

use Zeta::Comet;
use Zeta::Log;
use POE;
use Zeta::Serializer::JSON;
use POE::Filter::Block;
use POE::Wheel::ReadWrite;
use Zeta::Codec::Frame qw/ascii_n binary_n/;

my $ser = Zeta::Serializer::JSON->new();

my ($dr_r1, $dr_w1);
my ($dr_r2, $dr_w2);
pipe($dr_r1, $dr_w1);
pipe($dr_r2, $dr_w2);

#
# DR
#
my $slog = Zeta::Log->new( logurl => 'file://./Zcomet-dr.log', loglevel => 'DEBUG');
Zeta::Comet->spawn(
    logger => $slog,
    ins    => {
        icbc_dr => {
            codec  => 'nac 2',
            mode   => 'dr',
            module => 'Zeta::Comet::DR',
            lines  => [
                {
                    localaddr => '127.0.0.1',
                    localport => '7771',
                    timeout   => 40,
                }
            ],
        },
    },
    adapter => 'Zeta::Comet::Adapter::Pipe',
    ad_args => {
        reader     => $dr_r1,
        writer     => $dr_w2,
        serializer => $ser,
    },
);

#
# DR-业务进程
#
POE::Session->create(
    inline_states => {
        _start => sub {
            $_[HEAP]{reader} = POE::Wheel::ReadWrite->new(
                Handle     => $dr_r2,
                InputEvent => 'on_data',
                Filter     => POE::Filter::Block->new( LengthCodec => &ascii_n(4)),
            );
            $_[HEAP]{writer} = POE::Wheel::ReadWrite->new(
                Handle     => $dr_w1,
                Filter     => POE::Filter::Block->new( LengthCodec => &ascii_n(4)),
            );
        },
        on_data => sub {
            $slog->debug("DR on_data got:\n" . Data::Dump->dump($_[ARG0]));

            my $ad = $ser->deserialize($_[ARG0]);
            $ad->{dst} = delete $ad->{src};

            # $ad->{packet = $ser->deserialize(
            $_[HEAP]{writer}->put($ser->serialize($ad));
        }
    },
);


$poe_kernel->run();

__END__

