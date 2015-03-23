#!/usr/bin/env perl;
use Zeta::DT;
use DBI;
use Data::Dumper;

system("sqlite3 holi.db < dict_holi.sql");

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
Zeta::DT->add_holi($dbh, '2012', './2012.ini');
Zeta::DT->add_holi($dbh, '2013', './2013.ini');

my $zdt = Zeta::DT->new($dbh);
print Dumper($zdt);





