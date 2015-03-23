package MyAdmin;

use HTTP::Response;
use Data::Dump;

sub new {
   bless {}, shift;
}

sub handle {

    my ($self, $req) = @_;

    Data::Dump->dump($req);

    return 'hello world';

}

1;
