use Zeta::Run;
sub {
	while(<STDIN>) {
		zlogger->debug("got job[$_]");
	}
};
