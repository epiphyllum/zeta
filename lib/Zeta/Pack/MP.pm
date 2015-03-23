package Zeta::Pack::MP;
use Data::MessagePack;

my $mp = Data::MessagePack->new();

sub new {
    bless {}, shift;
}

# 打包
sub pack {
    my $self = shift;
    return $mp->pack(shift);
}

# 解包
sub unpack {
    my $self = shift;
    return $mp->unpack(shift);
}

1;
