package Zeta::Command::run;

use strict;
use warnings;

use Getopt::Long;
use POSIX qw/pause/;
use Carp;
use Zeta::Run;
use Data::Dump;

#
#  debug测试 -- 环境变量ZETA_DEBUG
#
#  命令行参数处理
my $cfg_file;
my $rtn = GetOptions( "file|f=s" => \$cfg_file,);
unless($rtn){
    &usage;
    exit 0;
}

unless( -f $cfg_file) {
    warn "file $cfg_file does not exists";
    &usage;
    exit 0;
}

# 解析zeta配置文件 
my $zcfg = do $cfg_file or &usage and confess "can not do file $cfg_file";
warn "zeta.conf:\n" if $ENV{ZETA_DEBUG};
Data::Dump->dump($zcfg) if $ENV{ZETA_DEBUG};

# [kernel] section 配置文件
my $kcfg = delete $zcfg->{kernel};  # kernel配置段

# 检查args
my $args = delete $kcfg->{args};
unless($args) {
    $args = [];
}
unless( 'ARRAY' eq ref $args) {
    die "invalid kernel->args";
}

# main处理
my $main_file = delete $kcfg->{main};
my $main;
unless(defined $main_file) {
   $main = sub {
       while(1) { pause(); };
   }
}
else {
    unless( -f $main_file ) {
        die "file[$main_file] invalid"; 
    }
    $main = do $main_file or confess "can not do file[$main_file] error[$@]";
}

# 检查channel
$kcfg->{channel} ||= [];
unless( 'ARRAY' eq ref $kcfg->{channel}) {
    die "invalid kernel->channel";
}

#
# 模块参数配置 
# para    => [ qw/A B C file.conf/ ],
# reader  => 'II',
# mreader => [ qw/X Y Z/ ],
# mwriter => [ qw/T U W/ ],
# size    => 2,
# code    => "${apphome}/code.pl",
# exec    => "${apphome}/exec.pl"
# plugin  => { db => [], xx => [] }
# 
#
my $mcfg = delete $zcfg->{module};
for my $mname (keys %$mcfg) {
    my $m = $mcfg->{$mname};
    $m->{para}    ||= [];
    $m->{mwriter} ||= [];
    $m->{mreader} ||= [];
    $m->{size}    ||= 1; 

    if ($m->{code} && $m->{exec}) {
        confess "[$mname] code and exec are mutual execlusive";
    }

    if ($m->{code})  {
        my $cref = do $m->{code} or  croak "can not do file[$m->{code}] error[$@]";
        confess "[$mname] code for $mname is not cref" unless 'CODE' eq ref $cref;
        $m->{code} = $cref;
    }
    else {
       unless( $m->{exec} ) {
          confess "[$mname] exec and code both don't exist";
       }
       unless( -f $m->{exec} ) {
           confess "[$mname] file $m->{exec} does not exist";
       } 
    }
}

# 件文件
my $pcfg = delete $kcfg->{plugin};

# 启动 kernel
zkernel->launch($kcfg);

# 加载插件
if ( $pcfg ) {
    if ( -f $pcfg) {
       do $pcfg or die "can not do file[$pcfg] error[$@]";
    }
    else {
       die "plugin file[$pcfg] does not exists";
    }
}

# 运行
zkernel->run(
    {
        main   => $main,
        args   => $args,
        module => $mcfg
    }
);


sub usage {
    my $usage =<<EOF;
    zeta -f[--file] zeta.conf
EOF
    warn $usage;
}


1;

__END__
