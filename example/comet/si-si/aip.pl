#!/usr/bin/perl

use Zeta::Comet;
use Zeta::Log;
use POE;
use Zeta::Serializer::JSON;
use POE::Filter::Block;
use POE::Wheel::ReadWrite;
use Zeta::Codec::Frame qw/ascii_n binary_n/;

my $ser = Zeta::Serializer::JSON->new();

my ($si_r1, $si_w1);
my ($si_r2, $si_w2);
pipe($si_r1, $si_w1);
pipe($si_r2, $si_w2);

#
# SI
#
my $slog = Zeta::Log->new( logurl => 'file://./Zcomet-aip.log', loglevel => 'DEBUG');
Zeta::Comet->spawn(
    logger => $slog,
    ins    => {
        aip => {
            codec  => 'nac 2',
            mode   => 'si',
            module => 'Zeta::Comet::SI',
            lines  => [
                {
                    localaddr  => '127.0.0.1',
                    localport  => '7772',

                    remoteaddr => '127.0.0.1',
                    remoteport => '7771',

                    timeout    => 40,
                    interval   => 30,
                }
            ],
        },
    },
    adapter => 'Zeta::Comet::Adapter::Pipe',
    ad_args => {
        reader     => $si_r1,
        writer     => $si_w2,
        serializer => $ser,
    },
);

#
# 发起测试的业务进程
#
POE::Session->create(
    inline_states => {
        _start => sub {
            $_[HEAP]{reader} = POE::Wheel::ReadWrite->new(
                Handle     => $si_r2,
                InputEvent => 'on_data',
                Filter     => POE::Filter::Block->new( LengthCodec => &ascii_n(4)),
            );
            $_[HEAP]{writer} = POE::Wheel::ReadWrite->new(
                Handle     => $si_w1,
                Filter     => POE::Filter::Block->new( LengthCodec => &ascii_n(4)),
            );
            $_[KERNEL]->yield('on_test');
        },
        on_data => sub {
            $slog->debug("SI on_data got:\n" . Data::Dump->dump($_[ARG0]));
        },

        on_test => sub {
           $slog->debug("开始测试...");
           my $req = {
               dst     => 'aip',
               packet  => $ser->serialize({
                   greet => 'hello world',
                   time  => `date +%H%M%S`,
              }),
           };
           $_[HEAP]{writer}->put($ser->serialize($req));
           $_[KERNEL]->delay('on_test', 1);
        },
    }
);

$poe_kernel->run();

__END__


