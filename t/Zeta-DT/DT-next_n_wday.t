#！perl
use Test::More;
use Zeta::Run;
use Zeta::DT;
use DateTime;
plan tests=>38;


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


=pod
my %map = (
  '2013-02-09' => [ 10,   '2013-02-27' ],
  '2013-02-01' => [ 10,   '2013-02-27' ],
  '2013-02-02' => [ 10,   '2013-02-27' ],
  '2013-02-03' => [ 10,   '2013-02-27' ],
  '2013-02-04' => [ 10,   '2013-02-27' ],
);
my $cnt = keys %map; 
warn "cnt = $cnt";
plan tests => $cnt;

for my $date (keys %map) {
   ok $zdt->next_n_wday($date, $map{$date}->[0]) eq $map{$date}->[1];
}
=cut


ok $zdt->next_n_wday( '2013-02-09', 10 ) eq '2013-02-27';
ok $zdt->next_n_wday( '2013-02-12', 11 ) eq '2013-02-28';
ok $zdt->next_n_wday( '2013-02-15', 12 ) eq '2013-03-01';

ok $zdt->next_n_wday( '2013-02-09', -10 ) eq '2013-01-28';
ok $zdt->next_n_wday( '2013-02-12', -11 ) eq '2013-01-25';
ok $zdt->next_n_wday( '2013-02-15', -12 ) eq '2013-01-24';

ok $zdt->next_n_wday( '2013-02-01', 10 ) eq '2013-02-20';
ok $zdt->next_n_wday( '2013-02-08', 11 ) eq '2013-02-28';
ok $zdt->next_n_wday( '2013-02-16', 12 ) eq '2013-03-04';
ok $zdt->next_n_wday( '2013-02-28', 13 ) eq '2013-03-19';

ok $zdt->next_n_wday( '2013-02-01', -10 ) eq '2013-01-18';
ok $zdt->next_n_wday( '2013-02-08', -11 ) eq '2013-01-24';
ok $zdt->next_n_wday( '2013-02-16', -12 ) eq '2013-01-24';
ok $zdt->next_n_wday( '2013-02-28', -13 ) eq '2013-02-06';
### 4-5-6 month ####27-38row
ok $zdt->next_n_wday( '2013-04-29', 10 ) eq '2013-05-15';
ok $zdt->next_n_wday( '2013-04-30', 10 ) eq '2013-05-15';
ok $zdt->next_n_wday( '2013-05-01', 10 ) eq '2013-05-15';

ok $zdt->next_n_wday( '2013-04-29', -10 ) eq '2013-04-17';
ok $zdt->next_n_wday( '2013-04-30', -10 ) eq '2013-04-17';
ok $zdt->next_n_wday( '2013-05-01', -10 ) eq '2013-04-17';

ok $zdt->next_n_wday( '2013-04-28', 10 ) eq '2013-05-15';
ok $zdt->next_n_wday( '2013-05-02', 10 ) eq '2013-05-16';
ok $zdt->next_n_wday( '2013-05-31', 10 ) eq '2013-06-17';

ok $zdt->next_n_wday( '2013-04-28', -10 ) eq '2013-04-16';
ok $zdt->next_n_wday( '2013-05-02', -10 ) eq '2013-04-17';
ok $zdt->next_n_wday( '2013-05-31', -10 ) eq '2013-05-17';
### 10-11-12 month 39-50 row
ok $zdt->next_n_wday( '2013-10-01', 10 ) eq '2013-10-18';
ok $zdt->next_n_wday( '2013-10-04', 11 ) eq '2013-10-21';
ok $zdt->next_n_wday( '2013-10-07', 12 ) eq '2013-10-22';

ok $zdt->next_n_wday( '2013-10-01', -10 ) eq '2013-09-17';
ok $zdt->next_n_wday( '2013-10-04', -11 ) eq '2013-09-16';
ok $zdt->next_n_wday( '2013-10-07', -12 ) eq '2013-09-13';

ok $zdt->next_n_wday( '2013-09-30', 10 ) eq '2013-10-18';
ok $zdt->next_n_wday( '2013-10-08', 10 ) eq '2013-10-21';
ok $zdt->next_n_wday( '2013-10-31', 10 ) eq '2013-11-14';

ok $zdt->next_n_wday( '2013-09-30', -10 ) eq '2013-09-16';
ok $zdt->next_n_wday( '2013-10-01', -10 ) eq '2013-09-17';
ok $zdt->next_n_wday( '2013-10-31', -10 ) eq '2013-10-17';
done_testing();
