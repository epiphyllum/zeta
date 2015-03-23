package Zeta::Gateway::Sync;
use strict;
use warnings;
use POE;
use POE::Wheel::ReadWrite;
use POE::Wheel::ListenAccept;
use POE::Filter::HTTPD;
use POE::Filter::Block;
use Zeta::Codec::Frame qw/ascii_n binary_n/;
use Getopt::Long;
use Mojo::JSON;
use Zeta::Log;
use Data::Dumper;
use feature qw/state/;   # 相当于C里面的static
use Encode;
use Carp qw/cluck/;

my $host;      # 服务地址
my $port;      # 服务端口
my $iterm;     # 终端信息同步接口
my $iconsume;  # 消费终端信息同步接口

# 参数解析
my $rtn = GetOptions(
    'host|h=s'     => \$host,
    'port|p=i'     => \$port,
    'iterm|t=s'    => \$iterm,
    'iconsume|c=s' => \$iconsume,
);
unless($port && $iterm && $iconsume) {
    &usage();
}

# 日志
my $logger = Zeta::Log->new(
    logurl   => 'stderr',
    # logurl   => "$ENV{KSYNC_HOME}/ksync.log",
    loglevel => 'DEBUG',
);

#
# Zeta::Gateway::Sync->spawn(
# );
#
sub spawn {
    my $class = shift;
    my $args  = { @_ };
    POE::Session->create(
        inline_states => {
            _start => sub {
                $_[HEAP]{server} = POE::Wheel::ListenAccept->new(
                    Handle => IO::Socket::INET->new(
                        LocalPort => $args->{port},
                        Listen    => 5,
                        ReuseAddr => 1,
                    ),
                    AcceptEvent => 'on_client_accept',
                    ErrorEvent  => 'on_server_error',
                );
            },
            
            # 内部客户端连接
            on_client_accept => sub {
                my $cli = $_[ARG0];
                my $iow = POE::Wheel::ReadWrite->new(
                    Handle       => $cli,
                    InputEvent   => 'on_client_input',
                    ErrorEvent   => 'on_client_error',
                    FlushedEvent => 'on_client_flush',
                    Filter       => POE::Filter::HTTPD->new(),
                );
                $_[HEAP]{gateway}{$iow->ID()}{in}    = $iow;
                $_[HEAP]{gateway}{$iow->ID()}{in_id} = $iow->ID();
            },
            
            # 服务端错误
            on_server_error => sub {
                my ($operation, $errnum, $errstr) = @_[ARG0, ARG1, ARG2];
                warn "Server $operation error $errnum: $errstr\n";
                delete $_[HEAP]{server};
            },
            
            # 收到内部客户请求
            on_client_input => sub {
                my ($req, $wid) = @_[ARG0, ARG1];
                my $json;
                eval {
                    $json = Mojo::JSON->new->decode($req->content());
                };
                if ($@) {
                    warn "can not decode data" . $req->content(); 
                    warn "Error[$@]";
                    exit 0;
                }
                $logger->debug("收到客户端数据:\n" . Dumper($json));
                # 打包卡友数据
                my $packet = pack_ky($json);
                
                # 连接卡友
                my $ky;
                if ($json->{table} =~ /x_term_info/) {
                    $ky = IO::Socket::INET->new($iterm);
                    unless($ky) {
                        die "can not connect to $iterm";
                    }
                }
                elsif ($json->{table} =~ /consumcontrast/) {
                    $ky = IO::Socket::INET->new($iconsume);
                    unless($ky) {
                        die "can not connect to $iconsume";
                    }
                }
                else {
                    die "unsupported sync type[$req->{table}]";
                }
                
                my $ky_codec = ascii_n(4);
                $ky_codec->[1] = \&ky_codec_decode;
                print Dumper($ky_codec);
                
                my $kyw = POE::Wheel::ReadWrite->new(
                    Handle       => $ky,
                    InputEvent   => 'on_ky_input',
                    ErrorEvent   => 'on_ky_error',
                    Filter       => POE::Filter::Block->new( LengthCodec => $ky_codec),
                );
                
                # 双向关联
                $_[HEAP]{gateway}{$wid}{out} = $kyw;
                $_[HEAP]{gateway}{$wid}{out_id} = $kyw->ID();
                $_[HEAP]{remote}{$kyw->ID()} = $_[HEAP]{gateway}{$wid};
                
                # 发送卡友数据
                $kyw->put($packet);
                
                my $len = sprintf("%04d", length($packet));
                $logger->debug("发送卡友数据[$len$packet]");
            },
            
            # 发送内部客户应答完毕
            on_client_flush => sub {
                my $wid = $_[ARG0];
                $logger->debug("内部客户请求处理完毕[$wid]");
                my $cache = delete $_[HEAP]{gateway}{$wid};
                delete $_[HEAP]{remote}{$cache->{out_id}};
            },
            
            # 内部客户端错误
            on_client_error => sub {
                my $wid = $_[ARG3];
                $logger->error("内部客户错误[$wid]");
                my $cache = delete $_[HEAP]{gateway}{$wid};
                delete $_[HEAP]{remote}{$cache->{out_id}};
            },
            
            # 收到卡友应答
            on_ky_input => sub {
                my ($packet, $wid) = @_[ARG0, ARG1];
                
                $logger->debug("收到卡友数据[$packet]");
                
                my $res = unpack_ky($packet);
                
                # 将卡友应答转换为我们客户端的应答
                my $data = Mojo::JSON->new->encode($res);
                my $http = HTTP::Response->new(200, 'OK');
                $http->header( "Content-Length" => length $data );
                $http->header( "Content-Type"   => "text/html;charset=utf-8" );
                $http->header( "Cache-Control"  => "private" );
                $http->content($data);
                
                # 发送应答HTTP::Response到内部客户端
                $_[HEAP]{remote}{$wid}{in}->put($http);
                
                $logger->debug("发送客户端数据:http($data)");
            },
            
            # 卡友错误
            on_ky_error => sub {
                my ($op, $errno, $errstr, $wid) = @_[ARG0, ARG1, ARG2, ARG3];
                unless($errno == 0)  {
                    $logger->debug("on_ky_error occurred[$op, $errno, $errstr, $wid]");
                    my $cache = delete $_[HEAP]{remote}{$wid};
                    delete $_[HEAP]{gateway}{$cache->{in_id}};
                }
            },
        }
    );
}

sub run {
    $poe_kernel->run();
}

