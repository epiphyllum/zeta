package Zeta::Pack::VSep;
use strict;
use warnings;

###########################################
#  logger   => $logger
###########################################
sub new {
    my $self = bless {}, shift;
    $self->_init(@_);
}

sub _init {
    shift;
}

###########################################
# 
###########################################
sub pack {
    my $self = shift;
    my $swt  = shift;
    my @data;
    for my $k ( keys %{$swt} ) {
        push @data, "$k:$swt->{$k}";
    }
    return join '|', @data;
}

###########################################
#
###########################################
sub unpack {
    my $self = shift;
    my $data = shift;
    my %out;
    my @part = split '\|', $data;
    for (@part) {
        my ($k, $v) = split ':', $_;
        $out{$k} = $v;
    }
    return \%out;
}

1;


