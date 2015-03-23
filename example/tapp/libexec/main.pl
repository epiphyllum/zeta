use Zeta::Run;
use POSIX qw/pause/;
use Data::Dump;
sub {
      while(1) { 
          eval {
              warn zkernel->daemonize_cmdline;
          };
          if ($@) {
              zlogger->error("cmdline failed");
          }
          sleep 5;
          zkernel->daemonize_restart();
      }
};
