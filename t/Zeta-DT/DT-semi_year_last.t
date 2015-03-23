#！perl
use Test::More;
use Zeta::Run;
use Zeta::DT;
use DateTime;
use DBI;

plan tests => 16;

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


ok $zdt->semi_year_last('2013-02-28')  eq '2013-06-30';
ok $zdt->semi_year_last('2013-03-28')  eq '2013-06-30';
ok $zdt->semi_year_last('2013-04-28')  eq '2013-06-30';
ok $zdt->semi_year_last('2013-05-29')  eq '2013-06-30';

ok $zdt->semi_year_last('2013-07-02')  eq '2013-12-31';
ok $zdt->semi_year_last('2013-08-01')  eq '2013-12-31';
ok $zdt->semi_year_last('2013-10-03')  eq '2013-12-31';
ok $zdt->semi_year_last('2013-11-04')  eq '2013-12-31';

ok $zdt->semi_year_last('2012-02-29')  eq '2012-06-30';
ok $zdt->semi_year_last('2012-03-28')  eq '2012-06-30';
ok $zdt->semi_year_last('2012-04-28')  eq '2012-06-30';
ok $zdt->semi_year_last('2012-05-29')  eq '2012-06-30';

ok $zdt->semi_year_last('2012-07-02')  eq '2012-12-31';
ok $zdt->semi_year_last('2012-08-01')  eq '2012-12-31';
ok $zdt->semi_year_last('2012-10-03')  eq '2012-12-31';
ok $zdt->semi_year_last('2012-11-04')  eq '2012-12-31';

done_testing();
