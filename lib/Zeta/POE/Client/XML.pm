package Zeta::POE::Client::XML;
use strict;
use warnings;
use base qw/Zeta::POE::Client/;
use XML::Simple;
use Encode;
use Data::Dumper;

#
# charset  => 'utf8',
# RootName => 'NoRoot',
# XMLDecl  => '<?xml version="1.0" encoding="GBK"?>
#
sub spawn {
    my $class = shift;
    my $args = { @_ };
    $args->{charset} ||= 'utf8';
    $args->{RootName} ||= 'NoRoot';
    $class->_spawn(%$args);
}

#
# 
#
sub _in {
    my ($class, $args, $in) = @_;
    unless($args->{charset} eq 'utf8') {
        # warn "begin decode('gbk', [$in])";
        # $in = encode('utf8', decode($args->{charset}, $in));
        $in = decode($args->{charset}, $in);
        # warn "got now[$in]";
    }
    warn "_in utf8[$in]";
    $in =~ s/^\s*<\?.+\?>//;
    return XMLin($in);
}

#
#
#
sub _out {
    my ($class, $args, $out) = @_;
    # warn "begin XMLout(" . Dumper($out) . ")";
    my $res = XMLout($out, 
        NoAttr   => 1, 
        RootName => $args->{RootName},
    );
    if ($args->{XMLDecl}) {
        $res = $args->{XMLDecl} . "\n" . $res;
    }
    warn "_out utf8[$res]";

    unless($args->{charset} eq 'utf8') {
        $res = encode($args->{charset}, $res);
    }
    else {
        eval {
           $res = encode('utf8', $res);
        };
        if ($@) {
            warn "can not decode('utf8', [$res]) error[$@]";
            die __PACKAGE__ . "_out eror";
        }
    }
    return $res;
}

1;

__END__
=head1 NAME


=head1 SYNOPSIS


=head1 API


=head1 Author & Copyright


=cut


