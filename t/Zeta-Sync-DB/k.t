#!/usr/bin/perl
use DBI;

my $src = {
    dsn  => 'dbi:SQLite:sync.db',
    user => undef,
    pass => undef,
};
my $dbh = DBI->connect(@{$src}{qw/dsn user pass/}, {
    RaiseError       => 1,
    PrintError       => 0,
    AutoCommit       => 0,
    FetchHashKeyName => 'NAME_lc',
    ChopBlanks       => 1,
    InactiveDestroy  => 1,
}); 
warn "connect db success";

my $sth = $dbh->prepare("select datetime('now', '+5 second')");

$sth->execute(undef);
my ($t1)  = $sth->fetchrow_array();

$sth->execute(undef);
my ($t2)  = $sth->fetchrow_array();

warn "[$t1] [$t2]";

