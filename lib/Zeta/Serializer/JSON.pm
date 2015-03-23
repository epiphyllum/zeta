package Zeta::Serializer::JSON;
use JSON::XS;

sub new {
    bless {}, shift;
}

# 打包
sub serialize {
    my $self = shift;
    return encode_json(shift);
}

# 解包
sub deserialize {
    my $self = shift;
    return decode_json(shift);
}

1;

