package Zeta::MCache;
use strict;
use warnings;
use constant CACHE_SIZE => 5;

my $size = CACHE_SIZE;

#
#  Zeta::MCache->new( t => 10, T => 10, default_size => 10 )
#
sub new {
    my $class = shift;

    my $cfg = { @_ };
    $size = delete $cfg->{default_size} if $cfg->{default_size};
    my $self = bless {
        mcache => {},
        mlru   => {},
        size   => $cfg,
    }, $class;
}

#
# $mc->size(t => 10);
# $mc->size('t');
#
sub size {
    if    (@_ == 3) { shift->{size}{+shift} = shift; }
    elsif (@_ == 2) { return shift->{size}{+shift};  }
}

# Zeta::MCache->get('type', 'key');
# --- sub get { (shift->{cache} || {})->{shift()} }
sub get {
    return (shift->{mcache}{+shift} || {})->{+shift};
}

#  Zeta::MCache->set('type', 'key', 'value');
sub set {
    my ($self, $t, $k, $v) = @_;
    $self->{mcache}{$t}{$k} = $v;
    push @{ $self->{mlru}{$t} }, $k;

    delete $self->{mcache}{$t}{shift @{$self->{mlru}{$t}}} 
        if @{$self->{mlru}{$t}} > ( $self->{size}{$t} ||= $size );
}

1;

__END__
