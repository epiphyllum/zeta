#!/usr/bin/perl
use strict;
use warnings;
use Data::Dump;
use Zeta::Log;
use Zeta::Sync::DB;

my $logger = Zeta::Log->new(
    logurl => 'stderr',
    loglevel => 'DEBUG',
);

my $sync = Zeta::Sync::DB->new(
    logger => $logger,
    src => {
        dsn => 'dbi:DB2:zdb_ypcs',
        user => 'ypinst',
        pass => 'ypinst',
    },
    dst => {
        dsn => 'dbi:DB2:zdb_ypcs',
        user => 'ypinst',
        pass => 'ypinst',
    }
);
Data::Dump->dump($sync);

$sync->sync('src_tbl');

exit 0;
