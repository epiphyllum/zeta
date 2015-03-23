package Zeta::Cache;

sub new {
    my $class = shift;
    my $size  = shift;
    bless { size => $size }, $class;
}

sub get { (shift->{cache} || {})->{shift()} }

sub set {
  my ($self, $key, $value) = @_;

  my $cache = $self->{cache} ||= {};
  my $queue = $self->{queue} ||= [];
  delete $cache->{shift @$queue} if @$queue >= $self->max_keys;
  push @$queue, $key unless exists $cache->{$key};
  $cache->{$key} = $value;

  return $self;
}

1;

