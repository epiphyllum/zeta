package Zeta::POE::TCPD::JSON;
use strict;
use warnings;
use base qw/Zeta::POE::TCPD/;
use JSON::XS;

sub _in {
    my ($class, $in) = @_;
    return decode_json($class->SUPER::_in($in));
}

sub _out {
    my ($class, $out) = @_;
    return $class->SUPER::_out(encode_json($out));
}

1;

__END__

