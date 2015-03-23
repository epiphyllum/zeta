#！perl
use Test::More;
use Zeta::Run;
use Zeta::DT;
use DateTime;
use DBI;

plan tests => 20;

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



ok $zdt->month_last('2013-09-27')  eq '2013-09-30';
ok $zdt->month_last('2013-09-28')  eq '2013-09-30';
ok $zdt->month_last('2013-09-29')  eq '2013-09-30';
ok $zdt->month_last('2013-09-30')  eq '2013-09-30';
ok $zdt->month_last('2013-10-01')  eq '2013-10-31';
ok $zdt->month_last('2013-10-02')  eq '2013-10-31';
ok $zdt->month_last('2013-10-03')  eq '2013-10-31';
ok $zdt->month_last('2013-10-04')  eq '2013-10-31';
ok $zdt->month_last('2013-02-02')  eq '2013-02-28';
ok $zdt->month_last('2013-02-01')  eq '2013-02-28';


ok $zdt->month_last('2012-02-27')  eq '2012-02-29';
ok $zdt->month_last('2012-02-27')  eq '2012-02-29';
ok $zdt->month_last('2012-09-27')  eq '2012-09-30';
ok $zdt->month_last('2012-09-28')  eq '2012-09-30';
ok $zdt->month_last('2012-09-29')  eq '2012-09-30';
ok $zdt->month_last('2012-09-30')  eq '2012-09-30';
ok $zdt->month_last('2012-10-01')  eq '2012-10-31';
ok $zdt->month_last('2012-10-02')  eq '2012-10-31';
ok $zdt->month_last('2012-10-03')  eq '2012-10-31';
ok $zdt->month_last('2012-10-04')  eq '2012-10-31';
done_testing();
