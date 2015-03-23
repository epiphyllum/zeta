#!/usr/bin/perl

use Zeta::Comet;
use Zeta::Log;
use POE;
use Zeta::Serializer::JSON;
use POE::Filter::Block;
use POE::Wheel::ReadWrite;
use Zeta::Codec::Frame qw/ascii_n binary_n/;

my $ser = Zeta::Serializer::JSON->new();

my $clog = Zeta::Log->new( 
    logurl   => 'file://./Zcomet-tc.log', 
    loglevel => 'DEBUG',
);
my ($tc_r1, $tc_w1);
my ($tc_r2, $tc_w2);
pipe($tc_r1, $tc_w1);
pipe($tc_r2, $tc_w2);

#
#  TC
#
Zeta::Comet->spawn(
    logger => $clog,
    ins => {
        icbc_tc => {
            codec  => 'nac 2',
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
    },
    adapter => 'Zeta::Comet::Adapter::Pipe',
    ad_args => {
        reader     => $tc_r1,
        writer     => $tc_w2,
        serializer => $ser,
    },
);

#
# tc-业务进程不断发起请求....
#
POE::Session->create(
    inline_states => {
        _start => sub {
            $_[HEAP]{reader} = POE::Wheel::ReadWrite->new(
                Handle     => $tc_r2,
                InputEvent => 'on_data',
                Filter     => POE::Filter::Block->new( LengthCodec => &ascii_n(4)),
            );
            $_[HEAP]{writer} = POE::Wheel::ReadWrite->new(
                Handle     => $tc_w1,
                Filter     => POE::Filter::Block->new( LengthCodec => &ascii_n(4)),
            );
            $_[KERNEL]->yield('on_test');
        },
        on_data => sub {
            $clog->debug("TC on_data got:\n" . Data::Dump->dump($_[ARG0]));
        },

        on_test => sub {
           $clog->debug("开始测试...");
           my $req = {
               dst     => 'icbc_tc',
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

