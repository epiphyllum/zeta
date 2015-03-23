#！perl
use Test::More;
use Zeta::Run;
use Zeta::DT;
use DateTime;
use Data::Dump;

my $zdt = Zeta::DT->create(
   2012 => '2012.ini',
   2013 => '2013.ini',
);
# Data::Dump->dump($zdt);

plan tests => 8;

ok !$zdt->is_wday('2013-10-01');
ok !$zdt->is_wday('2013-10-02');
ok !$zdt->is_wday('2013-10-03');
ok !$zdt->is_wday('2013-10-04');
ok !$zdt->is_wday('2013-10-05');
ok !$zdt->is_wday('2013-10-06');
ok !$zdt->is_wday('2013-10-07');
ok $zdt->is_wday('2013-10-08');

done_testing();


