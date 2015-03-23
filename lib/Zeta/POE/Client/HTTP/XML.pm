package Zeta::POE::Client::HTTP::XML;
use strict;
use warnings;
use base qw/Zeta::POE::Client::HTTP::JSON/;
use JSON::XS;
use XML::Simple;

sub spawn {

}

sub _in {
    my ($class, $args, $in) = @_;
    return decode_json($class->SUPER::_in($args, $in));
}

sub _out {
    my ($class, $args, $out) = @_;
    return $class->SUPER::_out($args, encode_json($out));
}

1;

__END__
=head1 NAME


=head1 SYNOPSIS


=head1 API


=head1 Author & Copyright


=cut


