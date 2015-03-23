#!/usr/bin/perl

use Zeta::Comet;
use Zeta::Log;
use POE;
use Zeta::Serializer::JSON;

my $ser = Zeta::Serializer::JSON->new();
Zeta::Comet->spawn(
    logger => Zeta::Log->new( logurl => 'file://./comet-1/Zcomet.log', loglevel => 'DEBUG'),
    ins => {
        icbc => {
            codec  => 'ins 2',
            mode   => 'tc',
            module => 'Zeta::Comet::TC',
            lines  => [
                {
                    remoteaddr => '127.0.0.1',
                    remoteport => '7771',
                    timeout    => 40,
                }
            ],
        },

        cups => {
            codec  => 'ins 4',
            mode   => 'si',
            module => 'Zeta::Comet::SI',
            lines  => [
                {
                    localaddr  => '127.0.0.1',
                    localport  => '8880',
                    remoteaddr => '127.0.0.2',
                    remoteport => '8881',
                    timeout    => 10,
                    interval   => 5,
                }
            ],
        },

        posp => {
            codec  => 'nac 2',
            mode   => 'da',
            module => 'Zeta::Comet::DA',
            lines  => [
                {
                    remoteaddr => '127.0.0.1',
                    remoteport => '6661',
                    timeout    => 5,
                    interval   => 4,
                }
            ],
        },
    },
    adapter => 'Zeta::Comet::Adapter::Pipe',
    ad_args => {
        reader     => \*STDIN,
        writer     => \*STDOUT,
        serializer => $ser,
    },
);

#
#
#
Zeta::Comet->spawn(

    logger => Zeta::Log->new( logurl => 'file://./comet-2/Zcomet.log', loglevel => 'DEBUG'),

    ins    => {
        icbc_k => {
            codec  => 'ins 2',
            mode   => 'ts',
            module => 'Zeta::Comet::TS',
            lines  => [
                {
                    localaddr => '127.0.0.1',
                    localport => '7771',
                    timeout   => 40,
                }
            ],
        },

        aip => {
            codec  => 'ins 4',
            mode   => 'si',
            module => 'Zeta::Comet::SI',
            lines  => [
                {
                    localaddr  => '127.0.0.2',
                    localport  => '8881',
                    remoteaddr => '127.0.0.1',
                    remoteport => '8880',
                    timeout    => 10,
                    interval   => 5,
                }
            ],
        },


        aps => {
            codec  => 'nac 2',
            mode   => 'dr',
            module => 'Zeta::Comet::DR',
            lines  => [
                {
                    localaddr  => '127.0.0.1',
                    localport  => '6661',
                    timeout    => 5,
                    interval   => 4,
                }
            ],
        },
    },
    adapter => 'Zeta::Comet::Adapter::Pipe',
    ad_args => {
        reader     => \*STDIN,
        writer     => \*STDOUT,
        serializer => $ser,
    },
);

$poe_kernel->run();

__END__

