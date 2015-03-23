#!/usr/bin/perl
use strict;
use warnings;
use Zeta::DB::Tran;
use Zeta::Log;
use DBI;

my $logger = Zeta::Log->new(
    logurl => 'stderr',
    loglevel => 'DEBUG',
);
my $dbh = DBI->connect(
    "dbi:SQLite:dbname=dbtran.db",
    "",
    "",
    {
        RaiseError       => 1,
        PrintError       => 0,
        AutoCommit       => 0,
        FetchHashKeyName => 'NAME_lc',
        ChopBlanks       => 1,
        InactiveDestroy  => 1,
    },
);

my $dbtran = Zeta::DB::Tran->new(
    logger => $logger,
    dbh    => $dbh,
);

my $nsql_1 =<<EOF;
create table tbl_test(
    a  integer,
    b  integer,
    c  integer
)
EOF

my $post_1 =<<EOF;
create index idx_tbl_test on tbl_test(a)
EOF

$dbtran->tran(
    tbl_test => [
        [ $nsql_1 ],
        sub {
            my $row = shift;
            my ($a, $b) = @{$row}{qw/a b/};
            return [ $a, $b, $a + $b ];
        },
        [ $post_1 ],
    ]
);
