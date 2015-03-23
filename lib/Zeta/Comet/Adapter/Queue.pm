package Zeta::Comet::Adapter::Queue;
use base qw/Zeta::Comet::Adapter/;
use Zeta::Wheel::Queue;

#
# send wheel
#
sub _send_wheel {

    my $class  = shift;
    my $heap   = shift;
    my $writer = shift;

    # $heap->{logger}->debug("begin create Zeta::Wheel::Queue...");
    my $w = Zeta::Wheel::Queue->new( $writer );
    unless ($w) {
        $heap->{logger}->error("Zeta::Wheel::Queue->new($writer) error");
        return undef;
    }
    return $w;
}


1;
