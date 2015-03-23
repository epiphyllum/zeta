package Zeta::Pack::Null;

sub new {
    bless {}, shift;
}

# 打包
sub pack {
    my ($self, $data) = @_;
    return $data;
}

# 解包
sub unpack {
    my ($self, $data) = @_;
    return $data;
}

1;
