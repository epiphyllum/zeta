package Zeta::Comet::TC::HTTP;

use strict;
use warnings;

use base qw/Zeta::Comet::TC/;

use Data::Dump;
use POE;
use POE::Wheel::ReadWrite;
use POE::Filter::HTTP::Parser;
use HTTP::Request::Common;
use Time::HiRes qw/gettimeofday/;

#
# 设置filter
#
sub _on_start {

    my $class  = shift;
    my $heap   = shift;
    my $kernel = shift;
    my $args   = shift;
    $heap->{filter} = 'POE::Filter::HTTP::Parser';
    $heap->{fargs}  = [];

}

#
# 接收到服务器应答
#
sub _packet {

    my $class = shift;
    my $heap  = shift;
    my $res   = shift;

    my $data =  $res->content();
    $heap->{logger}->debug_hex("recv data<<<<<<<<:", $data);

    return $data;

}

#
# 发送请求
#
sub _adapter {

    my $class = shift;
    my $heap  = shift;
    my $data  = shift;

    $heap->{logger}->debug_hex("send data>>>>>>>>:",  $data);

    my $config = $heap->{config};
    my $url = "http://$config->{remoteaddr}:$config->{remoteport}" . $data->{path};
    my $request = POST $url, Content => $data->{packet};
    $heap->{logger}->debug( "send request:\n" . Data::Dump->dump($request) );
    return $request;
}

1;

