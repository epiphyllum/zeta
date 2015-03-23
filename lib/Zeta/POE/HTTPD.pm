package Zeta::POE::HTTPD;
use strict;
use warnings;
use base qw/Zeta::POE::TCPD/;
use HTTP::Response;
use constant {
    DEBUG => $ENV{ZETA_POE_HTTPD_DEBUG} || 0,
};

BEGIN {
    require Data::Dump if DEBUG;
}

#
#  lfd   => $lfd,
#  port  => '9999',
#
#  module => 'MyModule',
#  para   => 'para',
#
sub spawn {
    my $class = shift;
    my $args = { @_ };
    $args->{codec} = 'http';
    $class->_spawn(%$args);
}

#
#
#
sub _in {
    my ($class, $args, $in) = @_;
    return $in->content();
}

#
#
#
sub _out {
    my ($class, $args, $out) = @_;
    my $res     = HTTP::Response->new(200, 'OK');
    $res->header( "Content-Length" => length $out );
    $res->header( "Content-Type"   => "text/html;charset=utf-8" );
    $res->header( "Cache-Control"  => "private" );
    $res->content($out);
    return $res;
}

1;

__END__
=head1 NAME


=head1 SYNOPSIS


=head1 API


=head1 Author & Copyright


=cut


