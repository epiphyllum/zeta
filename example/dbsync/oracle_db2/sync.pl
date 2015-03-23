#!/usr/bin/perl
use strict;
use warnings;
use Data::Dump;
use Zeta::Log;
use Zeta::Sync::DB;

my $logger = Zeta::Log->new(
    logurl   => 'stderr',
    loglevel => 'DEBUG',
);

my $ora_host = '192.168.1.1';
my $ora_sid  = 'orcl';
my $user     = 'kyweb';
my $pass     = 'kyweb'; 

my $sync = Zeta::Sync::DB->new(
    logger => $logger,
    src => {
        dsn => "dbi:Oracle:host=$ora_host;sid=$ora_sid", $user, $pass);
        user => 'yeepay',
        pass => 'yeepay',
    },
    dst => {
        dsn => 'dbi:DB2:zdb',
        user => 'db2inst',
        pass => 'db2inst',
    }
);
Data::Dump->dump($sync);

$sync->sync('translog_yeepay');

exit 0;

__END__

