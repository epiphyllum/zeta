package Zeta::Comet::Adapter::Inline;
use base qw/Zeta::Comet::Adapter/;
use Zeta::Wheel::Block;

###################################################
# must args:
#   reader     => $reader_file
#   writer     => $writer_file || $writer_qid
#   serializer => $serializer,
#   logger     => $logger,
# -------------------------------------------------
# optional:
###################################################


#
# 定制初始化
#
sub _on_start {
    my $class  = shift;
    my $heap   = shift;
    my $kernel = shift;
    my $args   = shift;
    return 1;
}

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

