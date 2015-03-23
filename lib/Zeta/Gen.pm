package Zeta::Gen;
use strict;
use warnings;
use Cwd;

#
#
#
sub gen_all {
    my ($class, $prj) = @_;
    my $uprj = uc $prj;
    my $cur_dir = cwd;
    $class->_gen_all($prj, $uprj, $cur_dir);
}

#
#
#
sub write_file {
    my ($class, $fname) = @_;
    IO::File->new("> $fname")->print(+shift);
}

#
#
#
sub usage {
    my ($class) = @_;
    die <<EOF;
usage: 
    1. zgen app myapp
    2. zgen web myweb
EOF
}

1;

__END__
