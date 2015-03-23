package Zeta::Wheel::Queue;
use strict;
use warnings;

use Carp qw/cluck/;
sub new {  
  my $class = shift; 
  my $queue = shift;
  bless \$queue, $class;
}

sub put {  
  my $self = shift;
  # warn "put->send($_[0], $$)";
  unless($$self->send($_[0], $$)) {
    cluck "send failed";  
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

