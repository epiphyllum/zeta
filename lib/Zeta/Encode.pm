package Zeta::Encode;

use strict;
use warnings;
use base qw/Exporter/;
use POSIX qw/isxdigit/;

our @EXPORT = qw/
  bcd2num
  num2bcd
  bin2num
  num2bin

  to_excel_col
  from_excel_col
  to_excel_cell
  from_excel_cell
/;

############################################
# \x12\x13  =>  "1234"
############################################
sub bcd2num {
    my $num = unpack( "H*", shift );
    $num =~ s/^0+//g;
    return $num;
}

############################################
#  右靠左补0
# "123"  => "\x01\x23";
############################################
sub num2bcd {
    my $num = shift;
    my $len = length $num;
    if ( $len % 2 ) {
        $num = "0$num";
    }
    return pack( "H*", $num );
}

############################################
# 8   => \x08
# 16  => \x10
# 24  => \x18
############################################
sub num2bin {
    my $num = shift;
    my @data;
    use integer;
    while (1) {
        my $res = $num % 16;
        if ( $res > 9 ) {
            $res = chr( ord('A') + $res - 10 );
        }
        unshift @data, $res;
        $num = int($num/16);
        last if $num == 0;
    }
    my $str = join '', @data;
    if ( ( length $str ) % 2 ) {
        $str = "0$str";
    }
    return pack( "H*", $str );
}

############################################
# "\x08"  => 8
# "\x10"  => 16
# "\x18   => 24
############################################
sub bin2num {
    my $bin   = shift;
    my @digit = split '', uc unpack( "H*", $bin );
    my $num   = 0;
    my $base  = 1;

    my $a = ord('A');
    for ( reverse @digit ) {
        if ( $_ =~ /[A-F]/ ) {
            $_ = 10 + ord($_) - $a;
        }
        $num += $_ * $base;
        $base *= 16;
    }
    return $num;
}

#
# 数字变Excel字母
# 27 => BA
#
sub to_excel_col {
    my $idx = shift;
    # warn "calc _index($idx)";
    my @data;
    while(1) {
        my $res = $idx % 26;
        unshift @data, chr(ord('A')+$res);
        $idx = int($idx/26);
        # warn "idx now[$idx]";
        last if $idx == 0;
    }
    return join '', @data;
}

#
# 从excel column to index(0..);
# A - Z,  BA
# 0 - 26, 27
#
sub from_excel_col {
    my @chr = split '', +shift;
    my $i = 0;
    my $idx = 0;
    while(@chr) {
        my $c = pop @chr;
        my $k = ord($c) - ord('A');
        $idx += $k * (26 ** $i++);
    }
    return $idx;
}

#
#  'A1'  =>  [0, 0]
#
sub from_excel_cell {
    my $str = shift;
    $str =~ /([A-Z]+)(\d+)$/;
    return [ $2 - 1,  from_excel_col($1) ];
}

#
# [0,0] => 'A1'
#
sub to_excel_cell {
    my ($x, $y) = @_;
    return [ $x + 1,  to_excel_col($y) ];
}

1;

__END__

=head1 NAME

  Zeta::Encode  - a simple module for encode && decode between bcd/bin/num

=head1 SYNOPSIS

  #!/usr/bin/perl -w
  use strict;

  use Zeta::Encode;

=head1 API

  bin2num:
  num2bin:
  num2bcd:
  bcd2num:

=head1 Author & Copyright

  zcman2005@gmail.com

=cut


