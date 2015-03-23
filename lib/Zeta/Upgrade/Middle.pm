package Zeta::Upgrade::Middle;

use strict;
use warnings;

use POE;
use Zeta::Upgrade::Server;
use Zeta::Upgrade::Client;

sub new {
    my $self;
}

sub run {
    my $self = shift;
    $self->{server}->spawn();
    $self->{client}->spawn();
    $poe_kernel->run();
}
 

1;

__END__

