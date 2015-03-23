package Zeta::Proto::VSep::ICBC;

use strict;
use warnings;

use base qw/Zeta::Proto::VSep/;


###################################
# 将swt数据转化成vsep数据  
###################################
sub _out {
  my $self = shift;
  my $swt  = shift;
  return $swt;
}

###################################
# 将vset数据转化成swt数据 
###################################
sub _in {
  my $self = shift;
  my $out  = shift;
  return $out;
}

1;

