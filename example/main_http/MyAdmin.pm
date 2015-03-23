package MyAdmin;

sub new {
   bless {}, shift;
}

sub handle {
    return {
       now => localtime(),
    };
}

1;

