package Zeta::IPC::SEM;

use strict;
use warnings;
use Errno;
use Carp qw/confess/;
use IPC::SysV
  qw(IPC_NOWAIT MSG_NOERROR S_IRUSR S_IWUSR IPC_CREAT IPC_EXCL SEM_UNDO SETVAL);

##################################################
# 信号灯初始化
##################################################
sub init {

    my $class = shift;
    my $self  = $class->new(@_);
    unless ($self) {
        confess "can not connect to semaphore";
        return;
    }

    unless ( semctl( $self->{id}, 0, SETVAL, 1 ) ) {
        confess "semctl error";
        return;
    }

    return $self;
}

##################################################
#  连接到信号灯
##################################################
sub new {

    my $class = shift;
    my $key   = shift;

    unless ( defined $key ) {
        confess "msget key undefined";
    }

    # 试图创建...
    my $id = semget( $key, 1, S_IRUSR | S_IWUSR | IPC_CREAT | IPC_EXCL );
    unless ( defined $id ) {
        if ( $!{EEXIST} ) {
            $id = semget( $key, 0, S_IRUSR | S_IWUSR );
            unless ( defined $id ) {
                confess "semget error: [$!]";
            }
        }
        else {
            confess "semget error: [$!]";
        }
    }

    bless {
        id     => $id,
        lock   => pack( "s!3", 0, -1, SEM_UNDO ),
        unlock => pack( "s!3", 0, 1,  SEM_UNDO ),
    }, $class;

}

##################################################
# 解锁
##################################################
sub lock {
    my $self = shift;

RETRY:
    unless ( semop( $self->{id}, $self->{lock} ) ) {
        # 被中断的系统调用
        if ( $!{EINTR} ) {
            goto RETRY;
        }
        confess("semop error: [$!]");
    }
    return $self;
}

##################################################
# 加锁
##################################################
sub unlock {
    my $self = shift;
    unless ( semop( $self->{id}, $self->{unlock} ) ) {
        confess("semop error: [$!]");
        return;
    }
    return $self;
}

##################################################
# id
##################################################
sub id {
    my $self = shift;
    return $self->{id};
}

1;

__END__

=head1 NAME

  Zeta::IPC::SEM  - a simple wrapper for semaphore operation

=head1 SYNOPSIS

  #!/usr/bin/perl -w
  use strict;
  use Zeta::IPC::SEM;

  my $sem1 = Zeta::IPC::SEM->init($key);

  my $sem2 = Zeta::IPC::SEM->new($key);

  while(1) {
    $sem2->lock();
    $sem1->unlock();
    sleep 1;
  }
  exit 0;

=head2 API

  init
  new
  lock
  unlock


=head1 Author & Copyright

  zcman2005@gmail.com

=cut


