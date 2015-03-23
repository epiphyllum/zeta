package Zeta::Pack::JSON;
use JSON::XS;

sub new {
    bless {}, shift;
}

# 打包
sub pack {
    my $self = shift;
    return encode_json(shift);
}

# 解包
sub unpack {
    my $self = shift;
    return decode_json(shift);
}

1;
