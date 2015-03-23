use Zeta::Log;


use Zeta::Log;

my $logger = Zeta::Log->new(
    logurl   => 'stderr',
    loglevel => 'DEBUG',
    monq     => '9898',
);

$logger->debug("test");
$logger->info("test");
$logger->crit("test");
$logger->fatal("fatal test");
