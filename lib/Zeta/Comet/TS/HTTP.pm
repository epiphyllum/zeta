package Zeta::Comet::TS::HTTP;

use strict;
use warnings;

use base qw/Zeta::Comet::TS/;

use Time::HiRes qw/gettimeofday tv_interval/;
use POE;
use POE::Wheel::ReadWrite;
use POE::Wheel::ListenAccept;
use POE::Filter::HTTPD;
use HTTP::Response;

sub _on_start {
    my $class  = shift;
    my $heap   = shift;
    my $kernel = shift;
    my $args   = shift;
    $heap->{filter} = 'POE::Filter::HTTPD';   # 关键!!!!!
    $heap->{fargs}  = [];                     # !!!!!!!!
}

#
# 接收到客户数据后
#
sub _packet {
    my $class = shift;
    my $heap  = shift;
    my $rd    = shift;

    warn "_packet is called with:\n" . Data::Dump->dump($rd);
    my $data =  $rd->content();
    $heap->{logger}->debug_hex("recv data<<<<<<<<:", $data);
    return $data;
}

#
# 在发送给客户数据前的处理
#
sub _adapter {
    my $class = shift;
    my $heap  = shift;
    my $ad    = shift;

    $heap->{logger}->debug_hex("send data>>>>>>>>:", $ad->{packet});

    # $heap->{logger}->debug( "_response got data:\n" . Data::Dump->dump($data) );
    my $response = HTTP::Response->new( 200, "OK" );
    $response->header( "Content-Length" => length $ad->{packet} );
    $response->header( "Content-Type"   => "text/html;charset=utf-8" );
    $response->header( "Cache-Control"  => "private" );
    $response->content( $ad->{packet} );
    return $response;
}

1;
