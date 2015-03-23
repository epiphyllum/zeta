package Zeta::Serializer::MP;
use Data::MessagePack;
use Carp;

my $mp = Data::MessagePack->new();

sub new {
    bless {}, shift;
}

# 打包
sub serialize {
    my $self = shift;
    return $mp->pack(shift);
}

# 解包
sub deserialize {
    my $self = shift;
    return $mp->unpack(shift);
}

1;
__END__
    my $packet = shift;
    my $swt;
    eval { 
        $swt =  $mp->unpack($packet);
    };
    if ($@) {
       confess "can not unpack[" . unpack('H*', $packet) . "]";
    } 
    return $swt; 
}

1;
