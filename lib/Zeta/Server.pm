package Zeta::Server;
use strict;
use warnings;
use Carp;
use JSON::XS;
use Time::HiRes qw/gettimeofday tv_interval/;

######################################################################
# 0 : crit
# 1 : error
# 2 : warn
# 3 : info
# 4 : debug
######################################################################
sub debug { my $self = shift; $self->log(4, $self->log_time . ' DEBUG-> ' . join ' ', @_);}
sub info  { my $self = shift; $self->log(3, $self->log_time . ' INFO--> ' . join ' ', @_);}
sub warn  { my $self = shift; $self->log(2, $self->log_time . ' WARN--> ' . join ' ', @_);}
sub error { my $self = shift; $self->log(1, $self->log_time . ' ERROR-> ' . join ' ', @_);}
sub crit  { my $self = shift; $self->log(0, $self->log_time . ' CRIT--> ' . join ' ', @_);}

#
#  设置配置, 全局共享参数
#
sub configure_hook {
    my $self = shift;
    my $prop = $self->{server};
    $prop->{port}     = $ENV{ZFT_PORT};
    $prop->{log_file} = "$ENV{ZFT_HOME}/log/zft.ns.log",
    $prop->{pid_file} = "$ENV{ZFT_HOME}/log/zft.ns.pid",
    return $self;
}

#
# 将服务对象构建
#
sub child_init_hook {
    my $self = shift;

    # 连接数据库
    my $dbh = DBI->connect(
        $ENV{DSN},
        $ENV{DB_USER},
        $ENV{DB_PASS},
        {
            RaiseError       => 1,
            PrintError       => 0,
            AutoCommit       => 0,
            FetchHashKeyName => 'NAME_lc',
            ChopBlanks       => 1,
            InactiveDestroy  => 1,
        }
    );
    unless($dbh) {
        return;
    }

    # 保存zft对象到servant
    $self->{zft} = ZFT->new(
        dbh    => $dbh, 
        logger => $self,
    );
    # $self->debug("child_ini_hook is called");
    return $self;
}

#
# 连接验证
# request {
#     name:  hary
#     pass:  jessie
# }
# response {
#     success: 1
# }
#
sub auth {
    my $self = shift;
    my $req  = $self->request();
}

#
# 读取请求
# [4个字节长度] + 报文
#
sub request {
    my $self = shift;
    read(\*STDIN, my $len, 4);
    $len =~ s/^0//g;
    read(\*STDIN, my $packet, $len);
    return decode_json($packet);
}

#
# 发送响应
#
sub response {
    my ($self, $res) = @_;
    my $packet = encode_json($res);
    my $len = sprintf("%04d", length $packet);
    print STDOUT $len . $packet;
    return $self;
}

#
# 处理请求
#
sub process_request {
    my $self = shift;

    # 连接验证
    my $auth = $self->auth();
    unless( defined $auth ) {
        $self->error("auth failed");
        return 1;
    }

    # 用child_init_hook中构建的服务对象服务客户端
    my $zft = $self->{zft};
    my $ts_login = [gettimeofday];
    my $req;
    my $res;
    my $cnt = 0;
    while(1) {
        eval {
            my $req = $self->request();
            $self->debug(Dumper($req));

            my $res = $zft->handle($req);
            $self->response($res);
        };
        if ($@) {
            $self->error("process failed error[$@]");
            goto EXIT;
        }
        $cnt++;
    }
EXIT:
    my $elapse = tv_interval($ts_login);
    $self->info("session last[$elapse] processed[$cnt]");
    return 1;
}

1;

