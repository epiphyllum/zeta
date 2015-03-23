use Zeta::SSN;
use DBI;
use Test::More;
use Test::Differences;

$ENV{DSN} = 'SQLite';
plan tests => 58;
my $dbh = DBI->connect(
    "dbi:SQLite:dbname=./seq.db",
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
$dbh->do("delete from seq_ctl");
$dbh->do("insert into seq_ctl(key, cur, min, max) values('HUNCK', 1, 1, 5)");
$dbh->do("insert into seq_ctl(key, cur, min, max) values('CACHE1', 1, 1, 10)");
$dbh->do("insert into seq_ctl(key, cur, min, max) values('CACHE2', 1, 1, 10)");
my $zs = Zeta::SSN->new($dbh);

#
# 10
# 
ok( $zs->next('HUNCK') == 1);
ok( $zs->next('HUNCK') == 2);
ok( $zs->next('HUNCK') == 3);
ok( $zs->next('HUNCK') == 4);
ok( $zs->next('HUNCK') == 5);
ok( $zs->next('HUNCK') == 1);
ok( $zs->next('HUNCK') == 2);
ok( $zs->next('HUNCK') == 3);
ok( $zs->next('HUNCK') == 4);
ok( $zs->next('HUNCK') == 5);

#
#  6 * 4 = 24
#
$cache1 = $zs->next_n('CACHE1', 6);
$cache2 = $zs->next_n('CACHE2', 6);
ok( $cache1->() == 1);  ok( $cache2->() == 1);
ok( $cache1->() == 2);  ok( $cache2->() == 2);
ok( $cache1->() == 3);  ok( $cache2->() == 3);
ok( $cache1->() == 4);  ok( $cache2->() == 4);
ok( $cache1->() == 5);  ok( $cache2->() == 5);
ok( $cache1->() == 6);  ok( $cache2->() == 6);
ok( $cache1->() == 7);  ok( $cache2->() == 7);
ok( $cache1->() == 8);  ok( $cache2->() == 8);
ok( $cache1->() == 9);  ok( $cache2->() == 9);
ok( $cache1->() == 10); ok( $cache2->() == 10);

ok( $cache1->() == 1);  ok( $cache2->() == 1);
ok( $cache1->() == 2);  ok( $cache2->() == 2);
ok( $cache1->() == 3);  ok( $cache2->() == 3);
ok( $cache1->() == 4);  ok( $cache2->() == 4);
ok( $cache1->() == 5);  ok( $cache2->() == 5);
ok( $cache1->() == 6);  ok( $cache2->() == 6);
ok( $cache1->() == 7);  ok( $cache2->() == 7);
ok( $cache1->() == 8);  ok( $cache2->() == 8);
ok( $cache1->() == 9);  ok( $cache2->() == 9);
ok( $cache1->() == 10); ok( $cache2->() == 10);

ok( $cache1->() == 1);  ok( $cache2->() == 1);
ok( $cache1->() == 2);  ok( $cache2->() == 2);
ok( $cache1->() == 3);  ok( $cache2->() == 3);
ok( $cache1->() == 4);  ok( $cache2->() == 4);

done_testing();

__END__
