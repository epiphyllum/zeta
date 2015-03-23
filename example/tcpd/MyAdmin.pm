package MyAdmin;

sub new {
   bless {}, shift;
}

sub handle {
    (my $ctx, $req) = @_;
    use Data::Dump;
    Data::Dump->dump(\@_);
    return {
       count => $self->{count}++,
    };
}

1;

