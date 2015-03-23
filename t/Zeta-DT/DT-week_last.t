#！perl
use Test::More;
use Zeta::Run;
use Zeta::DT;
use DateTime;


plan tests => 8;

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

ok $zdt->week_last('2013-09-30')  eq '2013-10-06';
ok $zdt->week_last('2013-10-01')  eq '2013-10-06';
ok $zdt->week_last('2013-10-02')  eq '2013-10-06';
ok $zdt->week_last('2013-10-03')  eq '2013-10-06';
ok $zdt->week_last('2013-10-04')  eq '2013-10-06';
ok $zdt->week_last('2013-10-05')  eq '2013-10-06';
ok $zdt->week_last('2013-10-06')  eq '2013-10-06';
ok $zdt->week_last('2013-10-07')  eq '2013-10-13';


done_testing();
