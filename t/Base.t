use lib qw/./;

use Hary;
use Data::Dump;

my $h = Hary->new();

warn $h->name;

$h->tap(
    sub {
        my $self = shift;
        Data::Dump->dump($self);
        warn "args: [@_]";
     }, 
)->tap(
    sub {
        my $self = shift;
        Data::Dump->dump($self);
        warn "args: [@_]";
     }, 
);

my $h2 = $h->new();

Data::Dump->dump($h);
warn "----------\n";
Data::Dump->dump($h2);
warn $h2->name;

