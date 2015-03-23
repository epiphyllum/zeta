package Zeta::POE::Log;

use Zeta::Run;
use POE;
use Carp;
use POE::Wheel::ReadWrite;
use Zeta::Log;

###################################
#   logurl   =>
#   loglevel =>
###################################
sub spawn {
    my $class = shift;
    my $args  = { @_ };
    my $logger = Zeta::Log->new();

    POE::Session->create(
        inline_states => {
            _start => sub {
                my $w = POE::Wheel::ReadWrite->new(
                );
                $_[HEAP]{logw} = $w;
            },
            on_log => sub {
                
            },
             
        },
    );
}

1;

__END__

