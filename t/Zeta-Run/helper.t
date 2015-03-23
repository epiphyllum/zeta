#!perl

use Zeta::Run;
use Test::More;

helper  hello => sub {
    my $self = shift;
    warn "hello";
    return "hello";
};

plan tests => 1;

ok( zkernel->hello eq 'hello');

done_testing();




