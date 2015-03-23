package Zeta::Mailer::Simple;

use Net::SMTP;
use MIME::Lite;
use Env qw/
  XMAIL_HOST
  XMAIL_USER
  XMAIL_PASS
  XMAIL_DEBUG
/;
use Encode;

#
# 'mailhost' => '10.7.1.16';
# 'username' => 'am_dept_yw@allinpay.com';
# 'password' => 'Shouli1yewu';
# 'debug'    => 1
#
sub new {

    my $class = shift;
    my $args  = {@_};

    # setting
    my $mailhost = $args->{'mailhost'} || $XMAIL_HOST;
    my $username = $args->{'username'} || $XMAIL_USER;
    my $password = $args->{'password'} || $XMAIL_PASS;
    my $debug    = $args->{'debug'}    || $XMAIL_DEBUG;

    my $smtp = Net::SMTP->new( $mailhost, Timeout => 120, Debug => $debug );
    unless ($smtp) {
        warn "can not Net::SMTP->new($mailhost)";
        return undef;
    }

    unless ( $smtp->auth( $username, $password ) ) {
        warn "can not auth($username, $password)";

        #  return undef;
    }

    my $self = bless { 'smtp' => $smtp, 'debug' => $debug }, $class;
    return $self;

}

#
# get setter
#
sub from {
    my $self = shift;
    unless (@_) {
        return $self->{'from'};
    }
    $self->{'from'} = $_[0];
}

#
# get setter
#
sub to {
    my $self = shift;
    unless (@_) {
        return $self->{'to'};
    }
    $self->{'to'} = [@_];
    return $self;
}

#
# get setter
#
sub cc {
    my $self = shift;
    unless (@_) {
        return $self->{'cc'};
    }
    $self->{'cc'} = [@_];
    return $self;
}

#
#
sub subject {
    my $self = shift;
    unless (@_) {
        return $self->{'subject'};
    }
    $self->{'subject'} = $_[0];
    return $self;
}

#
#
sub body {
    my $self = shift;
    unless (@_) {
        return $self->{'body'};
    }
    $self->{'body'} = $_[0];
    return $self;
}

#
#
sub attach {
    my $self = shift;
    unless (@_) {
        return $self->{'attach'};
    }

    push @{ $self->{'attach'} }, @_;
    return $self;
}

#
#  from   =>  'from name'
#  to     =>  [ t1@mail.com,  t2@mail.com ]
#  cc     =>  [ t1@mail.com,  t2@mail.com ]
#  sub    =>
#  body   =>
#  attach => []
#
#
sub set_all {

    my $self = shift;
    my $args = {@_};

    my $from   = $args->{'from'};      # from
    my $to     = $args->{'to'};        # to
    my $cc     = $args->{'cc'};        # cc
    my $sub    = $args->{'subject'};       # 主题
    my $body   = $args->{'body'};      # 正文
    my $attach = $args->{'attach'};    # 附件绝对路径

    $self->{'from'}   = $from;
    $self->{'to'}     = $to;
    $self->{'cc'}     = $cc;
    $self->{'subject'}    = $sub;
    $self->{'body'}   = $body;
    $self->{'attach'} = $attach;

    return $self;

}

#
#
#
sub send {

    my $self = shift;

    my $smtp = $self->{'smtp'};

    # 构造消息
    my $msg;
 
    # 消息构造参数 
    my @args = (
        From    => $self->{'from'},
        To      => $self->{'to'},
        Subject => $self->{'subject'},
        Type    => 'text/plain',
        Data    => $self->{body}
    );

    # 是否有抄送
    if ( defined $cc ) {
        push @args, Cc => $self->{'cc'};
    }

    my $msg = MIME::Lite->new(@args);
    $msg->attr('content-type.charset' => 'UTF-8');

    # 开始发送
    $smtp->mail( $self->{from} );
    $smtp->to( @{ $self->{'to'} } );
    $smtp->cc( @{ $self->{'cc'} } ) if defined $self->{'cc'};
    $smtp->data();
    $smtp->datasend( $msg->as_string );
    $smtp->dataend();
}

sub quit {
    my $self = shift;
    $self->{'smtp'}->quit();
}

1;

__END__

head1 NAME

  Zeta::Mailer::Simple - a simple http server class

=head1 SYNOPSIS

  use Zeta::Mailer;

  my $m = Zeta::Mailer::Simple->new( debug => 1,);
  
  $m->set_all(
    'from'   => 'zhouchao@allinpay.com'
    'to'     => [ 'zhouchao@allinpay.com', 'wangjia@allinpay.com' ] ,
    'subject'    => 'subject1',
    'body'   => 'body',
    'attach' => ['./Log.pm', './Mailer.pm' ],
  );
  
  $m->send();
  
  $m->set_all(
    'from'   => 'zhouchao@allinpay.com',
    'to'     => [ 'zhouchao@allinpay.com', 'wangjia@allinpay.com' ] ,
    'cc'     => [ 'zhouchao@allinpay.com', 'wangjia@allinpay.com' ] ,
    'subject'    => 'subject2',
    'body'   => 'body',
    'attach' => ['./DB.pm' ],
  );
  
  $m->send();


=head1 API



=head1 Author & Copyright

  zcman2005@gmail.com


=cut

