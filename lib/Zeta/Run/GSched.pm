package Zeta::Run::GSched;

use strict;
use warnings;

use POE;
use POE::Wheel::Run;

use Graph;
use Graph::Reader::Dot;
use Graph::Writer::Dot;

use File::Path qw/mkpath/;
use POSIX qw/mktime/;

use Data::Dump;

use Zeta::Log;
use Zeta::Run;
use Zeta::IniParse qw/ini_parse/;

sub run {

  my $logger = $run_kernel->{logger};

  Zeta::Run->launch(
    mode      => 'process_tree',
    logurl    => 'stderr',
    logllevel => $logger->loglevel(),
  );

  __PACKAGE__->spawn();

  $poe_kernel->run();

}


#
# vjob      => 'nr.job',               # 工作文件 
# vdot      => 'nr.dot',               # 图文件 
# lastfile  => '/file/last/graph',     # 未能完成是保存文件  
# name      => 'new_req",              # 本次schedule名称  
#
# alias  => 'gsched',
# logger => $logger,
#
sub spawn {

  my $class = shift;
  my $args  = { @_ };

  my $logger = delete $args->{logger};
  my $alias  = delete $args->{alias};
  
  POE::Session->create(
    inline_states  => {
      _start          => \&on_start,
      on_dispatch     => \&on_dispatch,
      on_stdout       => \&on_stdout,
      on_stderr       => \&on_stderr,
      on_child_signal => \&on_child_signal,
      on_post         => \&on_post,
      on_schedule     => \&on_schedule,
    },
    args => [ $alias, $logger, $args ],
  );
}

sub on_start {

  my ($alias, $logger, $args) = @_[ARG0, ARG1, ARG2 ];
  $_[KERNEL]->alias_set($alias);
  $_[HEAP]{logger}  = $logger;
  $_[HEAP]{greader} = Graph::Reader::Dot->new();
  $_[HEAP]{gwriter} = Graph::Writer::Dot->new();
  $_[HEAP]{running} = 0;

  $_[KERNEL]->sig('TERM', \&sig_term);

  if (%$args) {
    $_[KERNEL]->yield('on_post' => $args );
  }

}

sub sig_term {
}

sub on_stdout { 
  
  $$_[HEAP]{logger}->debug("on_stdout got:", $_[ARG0]);
}

sub on_stderr {
  $$_[HEAP]{logger}->debug("on_stderr got:", $_[ARG0]);
}

#
# child died
#
sub on_child_signal {

  my $logger = $_[HEAP]{logger};
  my $graph  = $_[HEAP]{graph};

  $_[KERNEL]->sig_handled();
  my ($sig, $pid, $status) = @_[ARG0, ARG1, ARG2];
  my $child = delete $_[HEAP]{pchild}{$pid};
  unless(defined $child) {
    $logger->error("internal error");
    exit 0;
  }

  $_[HEAP]{running}--;

  my $job   = $child->[1];
  my $jname = $child->[2];
  $logger->info("job[$jname] pid[$pid] exited status[$status]");

  if( $status != 0 ) {
    $job->{'count'}++;
    $job->{'status'} = 'fail';
  } 
  else {
    $job->{'status'} = 'success';
    for my $suc ($graph->successors($jname)) {
      # $logger->debug("begin delete edge[$jname, $suc]");
      $graph->delete_edges($jname, $suc);
    }
    # $logger->debug("begin delete vertex[$jname]");
    $graph->delete_vertices($jname);
  }

  $_[KERNEL]->yield('on_dispatch');

}

sub on_dispatch {

  my $logger   = $_[HEAP]{logger};
  my $graph    = $_[HEAP]{graph};
  my $vjob     = $_[HEAP]{vjob}; 
  my $lastfile = $_[HEAP]{lastfile};
  my $name     = $_[HEAP]{name};
  my $gwriter  = $_[HEAP]{gwriter};

  while(1) {

    my @vertices = $graph->vertices();
    if ( @vertices ==0 ) {
      $logger->info("schedule-$name jobs completed");
      $_[HEAP]{graph}     = undef;
      $_[HEAP]{vjob}      = undef;
      $_[HEAP]{lastfile}  = undef;
      $_[HEAP]{name}      = undef;
      $_[HEAP]{running}   = 0;
      $_[KERNEL]->yield('on_schedule');
      return 1;
    }

    # 检查各点的出度和入度, 来派发任务  
    for my $jname (@vertices) {

      # 有失败任务， 如果连续失败10次 则保存图后退出  
      if ( $vjob->{$jname}->{'status'} =~ /fail/ ) {
        if ( $vjob->{$jname}->{'count'} > 2 ) {
          $gwriter->write_graph($graph, $lastfile);
          $logger->error("$jname failed too many times, please fix it mannually, graph file saved");
          return;
        }
      }

      if ( $vjob->{$jname}->{'status'} =~ /running/ ) {
        next;
      }

      # 成功的任务应该被摘除，  
      if( $vjob->{$jname}->{'status'} =~ /success/ ) {
        $logger->error("internal error");
        exit 0;
      }

      # 入度为0可以被调度  
      if ( $graph->in_degree($jname) == 0 ) {
        my $child = POE::Wheel::Run->new(
          Program     => $vjob->{$jname}->{'program'},
          StdoutEvent => 'on_stdout',
        );
        unless($child) {
          $logger->error("can not create wheel run");
          exit 0;
        }
        $logger->info("job[$jname] dispatched");
       
        $_[HEAP]{pchild}{$child->PID()} = [$child, $vjob->{$jname}, $jname];
        $_[KERNEL]->sig_child($child->PID(), 'on_child_signal');
        $_[HEAP]{running}++; 
        $vjob->{$jname}->{'status'} = "running";
      }
     
      # 提前退出for, 保持并发量  
      if ($_[HEAP]{running} > 15 ) {
        $logger->debug("now 15 child running");
        goto MAX_PROC;
      }

    }
    return;
  }

MAX_PROC:
  return;

}

#
#  args:  
#  { 
#      vdot     => 'vdot file', 
#      vjob     => 'vjob file' 
#      lastfile => 'last file'
#  }
#
#
sub on_post {
  my $args = $_[ARG0];
  push @{$_[HEAP]{slist}}, $args;
  $_[HEAP]{logger}->debug("schedule[$args->{name}] is posted");
  unless( $_[HEAP]{graph} ) {
    $_[KERNEL]->yield('on_schedule');
  }
}

sub on_schedule {

  my $logger = $_[HEAP]{logger};

  # 在调度中  
  if ($_[HEAP]{graph}) {
    $logger->debug("can not scheduling, I am in scheduling[" . $_[HEAP]{name} . "]");
    return 1;
  }

  my $ssize = @{$_[HEAP]{slist}};
  $logger->debug("on_schedule slist[$ssize]");
  unless($ssize) {
    $logger->warn("no more scheduling in the list");
    return 1;
  }
  
  # 取出一个调度任务 
  my $args    = shift @{$_[HEAP]{slist}};
  $logger->debug(">>>>>>>>>>>begin scheduling\n". Data::Dump->dump($args));

  my $vdot     = $args->{vdot};
  my $vjob     = $args->{vjob};
  my $lastfile = $args->{lastfile};

  my $graph = Graph::Reader::Dot->new()->read_graph($vdot);
  unless($graph) {
    $logger->error("can not read dot file[$vdot]");
    return undef;
  }
  Data::Dump->dump($graph);

  my %vjob;
  my $jobs = ini_parse($vjob);
  for my $jname (keys %$jobs) {
    my $job = $jobs->{$jname};
    $vjob{$jname} = {
      program => [ $job->{prog}, split '\s', $job->{args} ],
      status  => 0,
      count   => 0,
    };
  }
  Data::Dump->dump(\%vjob);

  # 检查 vjob vdot是否匹配 
  my @vertices = $graph->vertices();
  for (@vertices) {
    unless( exists $vjob{$_} ) {
      $logger->error( "vjob $_ does not exists");
      return undef;
    }
  }

  $_[HEAP]{lastfile} = $lastfile;
  $_[HEAP]{graph}    = $graph;
  $_[HEAP]{vjob}     = \%vjob;
  $_[HEAP]{name}     = $args->{name};

  $_[KERNEL]->yield('on_dispatch');

  return 1;
}

1;

__END__

this is a directed-graph based job scheduler

