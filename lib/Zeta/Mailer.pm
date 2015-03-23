package Zeta::Mailer;

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
    );

    # 是否有抄送
    if ( defined $cc ) {
        push @args, Cc => $self->{'cc'};
    }

    # 签名
    my $sig_dir = $ENV{XMAIL_SIGNATURE};
    my $sig;      # 签名文件内容
    my @sig_imgs; # 签名文件相关的图片路径
    if ( -d $sig_dir ) {
        my $sig_file = (<$sig_dir/*.html>)[0];
        @sig_imgs = <$sig_dir/*.jpg>;
        warn "sig_file[$sig_file] sig_imgs[@sig_imgs]" if $self->{debug};

        # 如果有签名文件, 并且有图片)
        if ($sig_file) {
            if (@sig_imgs) {
                push @args, Type => 'multipart/related';
                my $sig_fh = IO::File->new("<$sig_file");
                $sig = join '', <$sig_fh>;
            }
            else {
                push @args, Type => 'multipart/mixed';
            }
        }
        else {
            push @args, Type => 'multipart/mixed';
        }
    }
    else {
        push @args, Type => 'multipart/mixed';
    }
    $self->{body} .= $sig if $sig;

    my $msg = MIME::Lite->new(@args);
    $msg->attr('content-type.charset' => 'UTF-8');

    # 添加消息体
    $msg->attach(
        Type => 'text/html;charset=UTF-8',
        Data => $self->{'body'},
    );

    # 签名中的图片-如果有图片的话
    for (@sig_imgs) {
        /([^\/]+)$/;
        $msg->attach(
            Type => 'image/jpg',
            Id   => $1,
            Path => $_,
        );
    }

    # 设置附件
    if ( exists $self->{'attach'} ) {
        for my $attach ( @{ $self->{'attach'} } ) {

            $attach =~ /\/([\w\.]+)$/;
            my $fname = $1;
            warn "begin attach $attach with name $fname..." if $self->{'debug'};
            $msg->attach(
                # Type     => 'Text',      # the attachment mime type
                Path        => $attach,        # local address of the attachment
                Filename    => $fname,         # the name of attachment in email
                Encoding    => 'base64',
                Disposition => 'attachment',
            );
        }

    }

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

  Zeta::Mailer - a simple http server class

=head1 SYNOPSIS

  use Zeta::Mailer;

  my $m = Zeta::Mailer->new( debug => 1,);
  
  $m->set_all(
    'from'    => 'zhouchao@allinpay.com'
    'to'      => [ 'zhouchao@allinpay.com', 'wangjia@allinpay.com' ] ,
    'subject' => 'subject1',
    'body'    => 'body',
    'attach'  => ['./Log.pm', './Mailer.pm' ],
  );
  
  $m->send();
  
  $m->set_all(
    'from'    => 'zhouchao@allinpay.com',
    'to'      => [ 'zhouchao@allinpay.com', 'wangjia@allinpay.com' ] ,
    'cc'      => [ 'zhouchao@allinpay.com', 'wangjia@allinpay.com' ] ,
    'subject' => 'subject2',
    'body'    => 'body',
    'attach'  => ['./DB.pm' ],
  );
  
  $m->send();


=head1 API



=head1 Author & Copyright

  zcman2005@gmail.com


=cut

