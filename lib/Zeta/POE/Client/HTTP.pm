package Zeta::POE::Client::HTTP;
use strict;
use warnings;
use base qw/Zeta::POE::Client/;
use HTTP::Request::Common;
use Data::Dumper;


#
#
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
    my $req = POST $args->{url}, Content => $out;
    return $req;
}

1;

__END__
=head1 NAME


=head1 SYNOPSIS


=head1 API


=head1 Author & Copyright


=cut


