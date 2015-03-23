package Zeta::Comet::Adapter::Pipe;
use base qw/Zeta::Comet::Adapter/;
use Zeta::Wheel::Block;

#
# send wheel
#
sub _send_wheel {

    my $class  = shift;
    my $heap   = shift;
    my $writer = shift;

    my $w = Zeta::Wheel::Block->new( handle => $writer );
    unless ($w) {
        $heap->{logger}->error("Zeta::Wheel::Block->new error");
        return undef;
    }
    return $w;
}

1;

