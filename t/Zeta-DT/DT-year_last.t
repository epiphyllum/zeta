#！perl
use Test::More;
use Zeta::Run;
use Zeta::DT;
use DateTime;

plan tests => 24;

use DBI;
my $dbh = DBI->connect(
    "dbi:SQLite:dbname=holi.db",
    "",
    "",
    {
        RaiseError       => 1,
        PrintError       => 0,
        AutoCommit       => 0,
        FetchHashKeyName => 'NAME_lc',
        ChopBlanks       => 1,
        InactiveDestroy  => 1,
        sqlite_unicode   => 1,
    },
);

my $zdt = Zeta::DT->new($dbh);



ok $zdt->year_last('2013-01-27') eq '2013-12-31';
ok $zdt->year_last('2013-02-27') eq '2013-12-31';
ok $zdt->year_last('2013-03-27') eq '2013-12-31';
ok $zdt->year_last('2013-04-27') eq '2013-12-31';
ok $zdt->year_last('2013-05-27') eq '2013-12-31';
ok $zdt->year_last('2013-06-27') eq '2013-12-31';
ok $zdt->year_last('2013-07-27') eq '2013-12-31';
ok $zdt->year_last('2013-08-27') eq '2013-12-31';
ok $zdt->year_last('2013-09-27') eq '2013-12-31';
ok $zdt->year_last('2013-10-27') eq '2013-12-31';
ok $zdt->year_last('2013-11-27') eq '2013-12-31';
ok $zdt->year_last('2013-12-27') eq '2013-12-31';

ok $zdt->year_last('2012-01-27') eq '2012-12-31';
ok $zdt->year_last('2012-02-27') eq '2012-12-31';
ok $zdt->year_last('2012-03-27') eq '2012-12-31';
ok $zdt->year_last('2012-04-27') eq '2012-12-31';
ok $zdt->year_last('2012-05-27') eq '2012-12-31';
ok $zdt->year_last('2012-06-27') eq '2012-12-31';
ok $zdt->year_last('2012-07-27') eq '2012-12-31';
ok $zdt->year_last('2012-08-27') eq '2012-12-31';
ok $zdt->year_last('2012-09-27') eq '2012-12-31';
ok $zdt->year_last('2012-10-27') eq '2012-12-31';
ok $zdt->year_last('2012-11-27') eq '2012-12-31';
ok $zdt->year_last('2012-12-27') eq '2012-12-31';

done_testing();
