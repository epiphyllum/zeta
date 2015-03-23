use Zeta::Log;

my $logger = Zeta::Log->new(
    logurl   => 'file://./t.log',
    loglevel => 'DEBUG',
);

$logger->debug("test");
$logger->info("test");
$logger->crit("test");
$logger->debug_hex("test");

my $logger = Zeta::Log->new(
    logurl   => 'stderr',
    loglevel => 'DEBUG',
);
$logger->debug("test");
$logger->info("test");
$logger->crit("test");
$logger->debug_hex("test");

my $logger = Zeta::Log->new(
    handle   => \*STDOUT,
    loglevel => 'DEBUG',
);
$logger->debug("test");
$logger->info("test");
$logger->crit("test");
$logger->debug_hex("test");


