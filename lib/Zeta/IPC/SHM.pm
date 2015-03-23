package Zeta::IPC::SHM;
use strict;
use warnings;
use Errno;
use IPC::SysV qw(S_IRUSR S_IWUSR IPC_CREAT IPC_EXCL);
use Carp qw/confess/;
use Data::Dump;

#####################################################
#  $class->($key,$size);
#####################################################
sub new {
    my $class = shift;
    my ( $key, $size ) = @_;

    unless ( defined $key ) {
        confess "shmget key undefined";
    }

    my $id = shmget( $key, $size, S_IRUSR | S_IWUSR | IPC_CREAT | IPC_EXCL );
    unless ( defined $id ) {
        if ( $!{EEXIST} ) {
            $id = shmget( $key, 0, S_IRUSR | S_IWUSR );
            unless ( defined $id ) {
                confess "shmget error: [$!]";
            }
        }
        else {
            confess "shmget error: [$!]";
        }
    }

    unless ($id) {
        confess( "shmget error:[$!] with:\n" . Data::Dump->dump( \@_ ) );
    }

    bless \$id, $class;
}

#####################################################
# $class->attach($key);
#####################################################
sub attach {

    my $class = shift;
    my $key   = shift;

    unless ( defined $key ) {
        confess "invalid key";
        return;
    }
    my $id = shmget( $key, 0, S_IRUSR | S_IWUSR );
    unless ($id) {
        confess "can not shmat($key)";
    }
    bless \$id, $class;
}

#####################################################
#  $shm->write($mref, $offset, $len);
#####################################################
sub write {
    my $self = shift;
    my ( $mref, $offset, $len ) = @_;

    unless ( shmwrite( $$self, $$mref, $offset, $len ) ) {
        confess("shmwrite error:[$!]");
    }
    return $self;
}

#####################################################
#  $shm->read($mref, offset, $length);
#####################################################
sub read {
    my $self = shift;
    my ( $mref, $offset, $len ) = @_;

    unless ( defined $mref && defined $offset && $len > 0 ) {
        confess "error offset needed:\n" . Data::Dump->dump( \@_ );
    }

    unless ( shmread( $$self, $$mref, $offset, $len ) ) {
        confess("shmread error:[$!]");
    }

    return $self;
}

1;

__END__


=head1 NAME

  Zeta::IPC::SHM  - a simple wrapper for shmget shmwrite shmread

=head1 SYNOPSIS

  #!/usr/bin/perl -w
  use strict;
  use Zeta::IPC::SHM;

  my $shm1 = Zeta::IPC::SHM->new(99990000,1024);
  my $shm2 = Zeta::IPC::SHM->attach(99990000);

  my $data;
  $shm1->write(\("this is a test"), 10, 20);  # offset = 10, length = 20
  $shm2->read(\$data, 10, 20);                # offset = 10, length = 20
  warn "read: [$data]\n";

  exit 0;


=head1 API

  new
  attach
  read
  write


=head1 Author & Copyright

  zcman2005@gmail.com

=cut

