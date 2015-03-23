package Zeta::Wheel::MB;

use strict;
use warnings;

use IO::Handle;
use Carp qw/cluck/;
use POE;
use POE::Wheel::ReadWrite;
use POE::Filter::Block;
use Zeta::IPC::MB;

############################################################
# args:
#   reader       => "reader mbox name"
#   writer       => "writer mbox name"
#   InputEvent   => 'input_event_name';
#   ErrorEvent   => 'error_event_name';
#   FlushedEvent => 'flush_event_name';
############################################################
sub new {  

  my $class = shift; 
  my $args  = { @_ };

  my $self = bless {}, $class;

  my $mbi = Zeta::IPC::MB->new();
  unless($mbi) {
    cluck "can not Zeta::IPC::MB->new()";
    return undef;
  }

  my @args;
  my $len;
  {
    use bytes;
    $len = length pack('ssi', 1,1,1);
  }

  #########################################
  # create reader MB
  #########################################
  if ($args->{reader} && $args->{InputEvent} ) { 
    my $reader = $mbi->create($args->{reader}, { mode => 'fifo'} );
    unless($reader) {
      cluck "can not Zeta::IPC::MB->create($args->{reader}, fifo)";
      return undef;
    }
    my $rfh = $reader->{channel};
    $self->{reader} = $reader;

    my $input_ev_name  = delete $args->{InputEvent};

    # 安装 event
    my $input_ev_name_ = 'MB_FIFO_R_' . $rfh->fileno();
    $poe_kernel->state($input_ev_name_ =>
      sub {

        # warn "$input_ev_name called";
        my ($sid, $bid, $size) = unpack('ssi', $_[ARG0]);
        unless(defined $sid && defined $bid && defined $size) {
          cluck "invalid msg";
          return undef;
        }
  
        # slab id 非法  
        if($sid > @{$reader->{slab}}) {
          cluck "invalid sid[$sid]";
          return undef;
        }
  
        # bid 非法  
        my $slab = $reader->{slab}->[$sid];
        if($bid >= $slab->{blkcnt}) {
          cluck "invalid bid:[$bid], slab[$sid].blkcnt:[$slab->{blkcnt}]";
          return undef;
        }
  
        # 读数据
        my $data;
        unless($slab->read($bid, \$data, $size)) {
          $slab->free($bid);
          cluck "read sid[$sid] bid[$bid] failed";
          return undef;
        }
        $slab->free($bid);
  
        # 转到 InputEvent
        $_[KERNEL]->yield($input_ev_name, $data);
      }
    );
    push @args, "Handle",      $rfh;
    push @args, "InputEvent",  $input_ev_name_;

  } 
  else {
    return undef;
  }

  #########################################
  # create writer MB
  #########################################
  if ($args->{writer}) { 
    my $writer = $mbi->create($args->{writer}, { mode => 'fifo' } );
    unless($writer) {
      cluck "can not Zeta::IPC::MB->create($args->{writer}, fifo)";
      return undef;
    }
    my $wfh = $writer->{channel};
    $self->{writer} = $writer;
    push @args, "OutputHandle", $wfh;

    my $flush_ev_name  = delete $args->{FlushedEvent};
    if ($flush_ev_name) {
      push @args, "FlushedEvent", $flush_ev_name;
    }
  }

  my $error_ev_name  = delete $args->{ErrorEvent};
  if ($error_ev_name) {
    push @args, "FlushedEvent", $error_ev_name;
  }

  push @args, "Filter", POE::Filter::Block->new(BlockSize => $len);

  Data::Dump->dump(\@args);
  my $wheel = POE::Wheel::ReadWrite->new(
     @args,
  );
  unless($wheel) {
    return undef;
  }

  $self->{wheel} = $wheel;

  return $self;
}

############################################################
#
############################################################
sub put {  
  my $self = shift;
  $self->{writer}->write(\$_[0]);
}


1;

__END__

=head1 NAME

  Zeta::Wheel::MB  - wheel for fifo-base mbox reading and writing


=head1 SYNOPSIS

  #!/usr/bin/perl
  use strict;
  use warnings;

  use POE;
  use Zeta::Wheel::MB;
  
  POE::Session->create(
    inline_states => {
      _start   => \&on_start,
      on_data  => \&on_data,
      on_tick  => \&on_tick,
    }
  );

  $poe_kernel->run(); 

  sub on_start {
    $_[HEAP]{wheel} = Zeta::Wheel::MB->new(
      reader     =>  'test',
      writer     =>  'test',
      InputEvent =>  'on_data',
      ErrorEvent =>  'on_error',
    );

   $_[HEAP]{serial} = 0;
   $_{KERNEL]->delay('on_tick'  => 1);
  }

  sub on_data {
    warn "got data[$_[ARG0]]"; 
  }

  sub on_tick {
    $_[HEAP]{serial}++;
    $_[HEAP]{wheel}->put("hary $_[HEAP]{serial}");
  }

=head1 API


=head1 Author & Copyright


=cut

