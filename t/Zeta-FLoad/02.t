use Zeta::FLoad;
use Zeta::Log;
use DBI;
use Test::More;
use Test::Differences;

plan tests => 1;

$ENV{DSN} = 'SQLite';
my $dbh = DBI->connect(
    "dbi:SQLite:dbname=./fload.db",
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

$dbh->do("delete from fload");
$dbh->commit();

my $logger = Zeta::Log->new(logurl => stderr,  loglevel => ERROR);
Zeta::FLoad->new(
    logger   => $logger,
    dbh      => $dbh,
    table    => 'fload',
    exclude  => [ qw/memo oid ts_c ts_u/ ],
    pkey     => [ qw/k1 k2/ ],

    rsplit   => [ 0..5 ],
    rhandle  => \&fload_handle,
    batch    => 2,
)->load_xls("./fload.xls", 0, 0);

$sth = $dbh->prepare("select count(*) from fload");
$sth->execute();
my ($cnt) = $sth->fetchrow_array();

ok( $cnt == 8 );

####################################
# details
####################################
sub fload_handle {
    [ @{+shift} ];
}
