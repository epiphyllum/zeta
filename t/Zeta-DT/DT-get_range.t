#！perl
use Test::More;
use Zeta::Run;
use Zeta::DT;
use DateTime;
use Data::Dump;

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
# Data::Dump->dump($zdt);
# exit 0;

# plan tests => 8;

my $range = $zdt->get_range('2013-10-08');

Data::Dump->dump($range);


# done_testing();
