package Zeta::Codec::Frame;
use strict;
use warnings;

use base qw/Exporter/;
use Carp qw/cluck/;
use Zeta::Encode;
use Encode;

our @EXPORT_OK = qw(
  ascii_n
  binary_n
  bcd_n
  ins
  nac
);
our @EXPORT = @EXPORT_OK;

sub codec_ins { return ascii_n(4);  }
sub codec_nac { return binary_n(2); }

#
# return [ascii_enc, ascii_dec]
#
sub ascii_n {

    my $n      = shift;
    my $format = "%0$n" . "d";

    return [

        # encode
        sub {
            my $stuff = shift;
            unless ( defined $$stuff ) {
                cluck "enc error";
                return;
            }

            my $len_part = sprintf( $format, length $$stuff );
            $$stuff = $len_part . $$stuff;
            # warn "codec send[$$stuff]";
            return;
        },

        # decode
        sub {
            my $stuff = shift;
            unless ( defined $$stuff ) {
                cluck "dec error";
                return;
            }

            unless ( $$stuff =~ s/^(.{$n})// ) {
                return;
            }
            my $len_part = $1;
            $len_part =~ s/^0+//g;
            # warn "codec recv[$len_part, $$stuff][" . length($$stuff) . "]";
            return $len_part;
        },

    ];

}

#
#
#
sub binary_n {

    my $n = shift;
    return [

        # encoder
        sub {
            my $stuff = shift;
            unless ( defined $$stuff ) {
                cluck "enc error";
                return;
            }
            my $len      = length $$stuff;
            my $len_part = num2bin($len);

            # warn unpack("H*", $len_part);

            $$stuff = $len_part . $$stuff;

            my $padding = "\x00" x ( $n - length $len_part );

            $$stuff = $padding . $$stuff;

        },

        # decoder
        sub {

            my $stuff = shift;
            unless ( defined $$stuff ) {
                cluck "dec error";
                return;
            }

            unless ( length $$stuff >= $n ) {
                return;
            }
            my $frame;
            ( $frame, $$stuff ) = unpack( "a${n}a*", $$stuff );

            return bin2num($frame);
        },
    ];

}

#
#
#
sub bcd_n {
    my $n = shift;
    return [
        sub {

            my $stuff = shift;
            unless ( defined $$stuff ) {
                cluck "enc error";
                return;
            }

            my $len_part = num2bcd( length $$stuff );
            $$stuff = $len_part . $$stuff;
            return;

        },

        sub {

            my $stuff = shift;
            unless ( defined $$stuff ) {
                cluck "dec error";
                return;
            }

            unless ( length $$stuff >= $n ) {
                return;
            }
            my $frame;
            ( $frame, $$stuff ) = unpack( "A${n}A*", $$stuff );

            return bcd2num($frame);
        },
    ];
}

1;

__END__

