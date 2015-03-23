package Zeta::Wheel::Block;

use strict;
use warnings;

use IO::Handle;
use Carp qw/cluck/;

#
# Zeta::Wheel::Block->new(
#   handle  => $fh
#   bsize   => 4
# )
#
#
sub new {  

  my $class = shift; 
  my $args  = { @_ };
  my $fh    = $args->{handle};
  my $bsize = $args->{bsize};
  
  $bsize ||= 4;
#   $fh    ||= \*STDOUT;

  $fh->autoflush(1);

  my $format = "%0${bsize}d";
  bless [ $fh, $format, $bsize ], $class;
}

#
# block write
#
sub put {  

  my $self = shift;
  my $len  = length $_[0]; 

  # my @callinfo = caller;
  # warn "[@callinfo] write data: "  . sprintf($self->[1], $len) . $_[0], $len + $self->[2];
  # unless( $self->[0]->write(sprintf($self->[1], $len) . $_[0], $len + $self->[2]) ) {

  unless( syswrite($self->[0], sprintf($self->[1], $len) . $_[0], $len + $self->[2]) ) {
    cluck "write failed";
    return;
  }
  return $self;

}


1;

__END__

=head1 NAME


=head1 SYNOPSIS


=head1 API


=head1 Author & Copyright


=cut


