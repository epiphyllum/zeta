package Zeta::POE::Client::HTTP::JSON;
use strict;
use warnings;
use base qw/Zeta::POE::Client::HTTP/;
use JSON::XS;
use Data::Dumper;

sub _in {
    my ($class, $args, $in) = @_;
    # warn Dumper($in);
    return decode_json($class->SUPER::_in($args, $in));
}

sub _out {
    my ($class, $args, $out) = @_;
    # warn "ZPCHJ _out: ";
    # warn Dumper($out);
    return $class->SUPER::_out($args, encode_json($out));
}

1;

__END__
=head1 NAME


=head1 SYNOPSIS


=head1 API


=head1 Author & Copyright


=cut


