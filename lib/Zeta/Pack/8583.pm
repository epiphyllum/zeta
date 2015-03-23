package Zeta::Pack::8583;

use strict;
use warnings;

use IO::File;
use Data::Dump;
use Zeta::Log;
use integer;
use Encode;
use Carp;

use constant  ID_IDX    => 0;
use constant  TYPE_IDX  => 1;
use constant  LEN_IDX   => 2;
use constant  CLASS_IDX => 3;
use constant  LENC_IDX  => 4;
use constant  DENC_IDX  => 5;

#
#  conf  =>  $xxx/conf/tlpos.conf
#
sub new {
    my $self = bless {}, shift;
    $self->_init(@_);
    return $self;
}

#
#  conf  => /path/of/config/file
#  conf  => \*DATA
#
sub _init {

    my $self = shift;
    my $args = { @_ };  
    
    # load the config file
    my $conf_data = [];
    my $fh;
    my $rname = ref $args->{conf};
    if ( $rname eq 'IO' || $rname eq 'IO::File' || $rname eq 'GLOB') {
        $fh = $args->{conf};
    }
    else {
        $fh = IO::File->new("< $args->{conf}");
        unless($fh) {
            confess "config file : $args->{conf} not exist";
            exit;
        }
    }
    while (<$fh>) {
        next if /^#/;
        # remove the first empty element
        s/^\s+//;
        s/\s+$//;
        next if /^$/;
        my $data = [split /\s+/, $_];
        # store the first 5 elements
        $conf_data->[@{$data}[0]] = [@{$data}[0..5]];
    }
    for (my $i = 0; $i < @$conf_data; ++$i) {
        $_ = $conf_data->[$i];
    }
    $fh->close;
    $self->{config} = $conf_data;
    $self->{hdr}    = $args->{hdr};
}

sub pack {
    
    my $self   = shift;
    my $fld    = shift;
    my @conf   = @{$self->{config}};
        
    my $data;
  
    ######################################
    # bitmap部分 
    ######################################
    
    my @bitmap;
    if (@$fld > 65) {
      @bitmap = (0) x 128;
      $bitmap[0] = 1;
    } else {
      @bitmap = (0) x 64;
    }
    my @fld;
    for (my $i = 1; $i < @$fld; ++$i) {
      my $idx = $i + 1;
      next unless defined $fld->[$idx];
      my $cfg     = $conf[$idx];
      $bitmap[$i] = 1;
      ######################################
      # 固定长度  
      ######################################
      if ($cfg->[CLASS_IDX] =~ /^fix/) {
        
        if (length $fld->[$idx] > $cfg->[LEN_IDX]){
            die "fld $idx is too long!";
            return '';
        }
        
        if ($cfg->[DENC_IDX] =~ /^ascii/) {
          $data .= $fld->[$idx]; 
          next;
        }
  
        if ($cfg->[DENC_IDX] =~ /^bcd/) {
          if ($cfg->[LEN_IDX] % 2){
            if ($cfg->[DENC_IDX] !~ /^bcdl/) {
                $fld->[$idx] = '0'.$fld->[$idx];
            } else {
                $fld->[$idx] = $fld->[$idx].'0';
            }
          }
          $data .= pack('H*', $fld->[$idx]);
          next;
        }
      }
  
      ######################################
      # LLLVAR
      ######################################
      if ($cfg->[CLASS_IDX] =~ /^lllvar/) {
        
        # 长度部分 
        my $dlen;
        my $len = length $fld->[$idx];
        if ($len > $cfg->[LEN_IDX]) {
            die "fld $idx is too long!";
            return '' 
        }
        if ($cfg->[LENC_IDX] =~ /^bcd/) {
            $dlen = sprintf("%04d", $len);
            $dlen = pack("H*", $dlen);
        } else {
            $dlen = sprintf("%03d", $len);
        }
        
        $data .= $dlen;

        if ($cfg->[DENC_IDX] =~ /^bcd/) {
          if ((length $fld->[$idx]) % 2){
            if ($cfg->[DENC_IDX] !~ /^bcdl/) {
                $fld->[$idx] = '0'.$fld->[$idx];
            } else {
                $fld->[$idx] = $fld->[$idx].'0';
            }
          }
          $data .= pack('H*', $fld->[$idx]);
          next;
        }
  
        if ($cfg->[DENC_IDX] =~ /^ascii/) {
          $data .= $fld->[$idx]; 
          next;
        }
      }
      
      ######################################
      # LLVAR
      ######################################
      if ($cfg->[CLASS_IDX] =~ /^llvar/) {
  
         # 长度部分
        my $dlen;
        my $len  =  length $fld->[$idx];
        if ($len > $cfg->[LEN_IDX]) {
            die "fld $idx is too long!";
            return '' 
        }
        if ($cfg->[LENC_IDX] =~ /^bcd/) {
            $dlen = sprintf("%02d", $len);
            $dlen = pack("H*", $dlen);
        } else {
            $dlen = sprintf("%02d", $len);
        }
        
        $data .= $dlen;
        
        if ($cfg->[DENC_IDX] =~ /^bcd/) {
          if ((length $fld->[$idx]) % 2){
            if ($cfg->[DENC_IDX] !~ /^bcdl/) {
              $fld->[$idx] = '0'.$fld->[$idx];
            } else {
              $fld->[$idx] = $fld->[$idx].'0';
            }
          }
          $data .= pack('H*', $fld->[$idx]);
          next;
        }
  
        if ($cfg->[DENC_IDX] =~ /^ascii/) {
          $data .= $fld->[$idx];
          next;
        }
      }
      
      ######################################
      # 十六进制
      ######################################
      if ($cfg->[CLASS_IDX] =~ /^binary/) {
        $fld->[$idx] =~ s/\<HEX\>//g;
        if (length $fld->[$idx] > $cfg->[LEN_IDX]){
            die "fld $idx is too long!";
            return '';
        }
        $data .= $fld->[$idx];
        next;
      }
  
    }
  
    my $bstr   = join '', @bitmap;
    my $bitmap = pack('B*', $bstr);

    return pack('H*',$fld->[0]).$bitmap.$data;
}

sub unpack {
    
    my $self = shift;
    my $data = shift;
    my $conf = $self->{config};
   
    my @bitmap; 
    
    ########################################
    # 先取2个字节msgtype + 8个字节的bitmap  
    ########################################
    my $mbyte; 
    my $bbyte;
    my $len;
    my $dlen;
    ($mbyte, $bbyte, $data) = unpack("a2a8a*", $data);
    my $type = unpack('H*', $mbyte);
    push  @bitmap, split '', unpack('B*', $bbyte);
    
    ########################################
    # 再看是否还有另外8字节的bitmap 
    ########################################
    if ($bitmap[0] eq '1') {
      ($bbyte, $data) = unpack("a8a*", $data); 
      push  @bitmap, split '', unpack('B*', $bbyte);
    }

    ########################################
    # 根据bitmap解析报文域  
    ########################################
    my @fld;
    $fld[0] = $type;
    $fld[1] = '<HEX>'.uc unpack('H*', CORE::pack('B*', join '', @bitmap));
    
    my ($fbyte, $lbyte); 
    for (my $i = 1; $i < @bitmap; ++$i ) {
  
      next if $bitmap[$i] eq '0';
      my $idx = $i + 1;
      my $cfg = $conf->[$idx];
      ##################################
      # 定长 
      ##################################
      if ($cfg->[CLASS_IDX] =~ /^fix/) {
  
        $dlen = $cfg->[LEN_IDX];
        
        # 定长bcd编码  
        if ($cfg->[DENC_IDX] =~ /^bcd/) {
          $len = $dlen;
          $dlen = ($dlen + 1) / 2;

          ($fbyte, $data) = unpack("a${dlen}a*", $data);
          my $tmp = unpack('H*', $fbyte);

          if($cfg->[DENC_IDX] =~ /^bcdl/){
            $tmp =~ /^(.{$len})/;
            $fld[$idx] = $1;
          } else {
            $tmp =~ /(.{$len})$/;
            $fld[$idx] = $1;
          }
          next;
        }
  
        # 定长ASCII编码  
        if ($cfg->[DENC_IDX] =~ /^ascii/) {
          ($fbyte, $data) = unpack("a${dlen}a*", $data);
          $fld[$idx] = $fbyte;
          next;
        }
      }
  
      ##################################
      # LLLVAR
      ##################################
      if ($cfg->[CLASS_IDX] =~ /^lllvar/) {
  
        # 解开长度部分 
        if ($cfg->[LENC_IDX] =~ /^bcd/) {
            ($fbyte, $data) = unpack("a2a*", $data);
            $dlen = unpack("H*", $fbyte);
        } else {
            ($fbyte, $data) = unpack("a3a*", $data);
            $dlen = $fbyte;
        }
        $dlen =~ s/^0+//g;
  
        # 合法性校验:
        if ($dlen > $cfg->[LEN_IDX]) {
            die 'a error accurred when do : '."$idx $dlen gt $cfg->[LEN_IDX]";
            return undef;
        }
          
        #  LLLVAR BCD
        if ($cfg->[DENC_IDX] =~ /^bcd/) {
          # 保存原始长度
          $len = $dlen;
          # 解数据部分
          if ($dlen % 2 ) {
            $dlen += 1;
          }
          $dlen /= 2;
          ($fbyte, $data) = unpack("a${dlen}a*", $data);
          my $tmp = unpack('H*', $fbyte);
          if($cfg->[DENC_IDX] =~ /^bcdl/){
            $tmp =~ /^(.{$len})/;
            $fld[$idx] = $1;
          } else {
            $tmp =~ /(.{$len})$/;
            $fld[$idx] = $1;
          }
          next; 
  
        }
  
        if ($cfg->[DENC_IDX] =~ /^ascii/) {
          # 解数据部分
          ($fbyte, $data) = unpack("a${dlen}a*", $data);
          $fld[$idx] = $fbyte;
          next; 
        }
      }
  
      ##################################
      # LLVAR
      ##################################
      if ($cfg->[CLASS_IDX] =~ /^llvar/) {
        
        # 解开长度部分    
        if ($cfg->[LENC_IDX] =~ /^bcd/) {
            ($fbyte, $data) = unpack("a1a*", $data);
            $dlen = unpack("H*", $fbyte);
        } else {
            ($fbyte, $data) = unpack("a2a*", $data);
            $dlen = $fbyte;
        }
        $dlen =~ s/^0+//g;
        unless($dlen){
            $dlen = 0;
        }
        # 合法性校验:
        if ($dlen > ($cfg->[LEN_IDX])) {
            die "error! when do:$idx $dlen comp $cfg->[LEN_IDX]";
            return undef;
        }
        #  LLVAR BCD
        if ($cfg->[DENC_IDX] =~ /^bcd/) {
            
          # 保存原始长度
          $len = $dlen;
          
          # 解数据部分
          if ($dlen % 2 ) {
            $dlen += 1;
          }
          $dlen /= 2;
          ($fbyte, $data) = unpack("a${dlen}a*", $data);
          my $tmp = unpack('H*', $fbyte);
          $dlen *= 2;
          if($cfg->[DENC_IDX] =~ /^bcdl/){
            $tmp =~ /^(.{$len})/;
            $fld[$idx] = $1;
          } else {
            $tmp =~ /(.{$len})$/;
            $fld[$idx] = $1;
          }
          next; 
        }
  
        if ($cfg->[DENC_IDX] =~ /^ascii/) {
            
          # 解数据部分
          ($fbyte, $data) = unpack("a${dlen}a*", $data);
          $fld[$idx] = $fbyte;
          next; 
        }
      }
      
      ##################################
      # 十六进制
      ##################################
      if ($cfg->[CLASS_IDX] =~ /^binary/) {

        my $len = $cfg->[LEN_IDX];
        
        # 定长ASCII编码
        ($fbyte, $data) = unpack("a${len}a*", $data);
        $fld[$idx] = $fbyte;
        next;
      }
    }   
    return \@fld; 
}

sub debug_8583 {
    my $self = shift;
    my $fld  = shift;

    my @debug_str;
    push @debug_str, "fld[".sprintf("%03d", 0)."] = [".sprintf("%03d", 4)."][$fld->[0]]";

    # 第一域
    if ( $fld->[1] ) {
        push @debug_str, "fld[".sprintf("%03d", 1)."] = [".sprintf("%03d", ((length $fld->[1]) - 5) / 2)."][$fld->[1]]" 
    }

    my @conf = @{ $self->{config} };
    for (my $i = 2; $i < @$fld; ++$i ) {
        next unless defined $fld->[$i] && defined $conf[ $i ];
        my $tmp = $fld->[$i];
        if ($conf[ $i ] -> [CLASS_IDX] =~ /^binary/){
            $tmp = $tmp;
        }
        push @debug_str, "fld[".sprintf("%03d", $i)."] = [".sprintf("%03d", $conf[$i]->[LEN_IDX])."][$tmp]";
        if ($i == 59){
        }
    }
    join "\n", @debug_str;
}


1;

