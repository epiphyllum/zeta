package  Zeta::Run;
use strict;
use warnings;
use Carp;
use File::Basename;

our $VERSION = '0.04';

use constant {
    DEBUG => $ENV{ZETA_RUN_DEBUG} || 0,
};

#
# 插件
my %plugin;

# singleton模式对象数据结构
our $run_kernel = {};
sub import {

    my $pkg = shift;
    
    # stdin stdout pre-processing
    require IO::Handle;
    STDOUT->autoflush(1);
    STDIN->blocking(1);

    bless $run_kernel, __PACKAGE__;
    my ($callpkg, $fname, $line) = (caller)[0,1,2];
    {
        no strict 'refs';
        no warnings 'redefine';
        *{"$callpkg\::zkernel"}    = sub { $run_kernel };
        *{"$callpkg\::zlogger"}    = sub { $run_kernel->logger };
        *{"$callpkg\::helper"}     = sub { add_helper->($callpkg, $fname, $line, @_); };
        return 1;
    }
}

#
sub launch {
    my ($self, $config) = @_;
    
    # 参数检查
    $self->load_plugin('check');
    # warn "init_plugin check with" . Data::Dump->dump($config);
    # $self->init_plugin('check', $config);
    $self->check_mode($config);
    $self->check_log($config);
    
    # 后台运行
    $self->load_plugin('daemonize');
    $self->init_plugin('daemonize', @{$config}{qw/name pidfile/}); 
    
    # 日志初始化
    $self->load_plugin('logger');
    $self->init_plugin('logger',
        logurl   => $config->{logurl}, 
        loglevel => $config->{loglevel}, 
        logmonq  => $config->{logmonq}
    );
    
    # 加载plugin
    for my $name ( qw/process channel /) {
        $self->load_plugin($name);
    }
        
    # 检查
    # 初始化channel   : 创建初始管道
    # 初始化process   : 主要是设置信号处理
    # warn "launch init_channel with: ";
    # Data::Dump->dump($config);
    $self->init_plugin('channel', @{$config->{channel}});
    $self->init_plugin('process');

    # 模式为logger时, 构建loggerd进程后， 重新初始化logger
    if ($config->{mode} =~ /loggerd/) {
        my $channel = $self->channel_new();
        # 启动logger子进程
        $self->process_loggerd($config->{logname}, $config->{logurl},  $channel);
        
        $self->logger_reset(
            Zeta::Log->new(
                handle    => $channel->{writer},
                loglevel  => $config->{loglevel}
            ),
        );
    }
   
    return $self;    
}

#
# 提交主控制模块，子进程模块参数运行
# $args = {
#     main   => \&mcode,
#     marg   => [],
#     module => {
#     }
# }
#
#
sub run {
    my ($self, $args) = @_;

    warn "[$0]" if DEBUG;

    # 模块检查
    $self->check_mlist($args->{module});

    # 启动进程模块
    $self->process_runall($args->{module});

    # 运行主控进程
    $args->{main}->(@{$args->{args}}) or confess "can not run main[@{$args->{args}}]";
    
    exit 0;
};

#
# 装饰器
#
sub add_helper {
    my ($class, $fname, $line, $name, $helper)  = @_;
    
    warn sprintf("helper[%-16s] is defined at[%s:%s:%s]\n",  $name, $class, $fname, $line) if $ENV{ZETA_DEBUG};
    my $cref = ref $helper;
    unless ($cref && $cref =~ /CODE/) {
        confess sprintf("helper[%-16s] defined at[%s:%s:%s] is not code ref\n",  $name, $class, $fname, $line);
    }

    # 重复定义
    if (__PACKAGE__->can($name)) {
        confess __PACKAGE__ . "::$name already exists";
    }

    no strict 'refs';
    *{ __PACKAGE__ . "::" . $name} = \&{$helper};
}


#
#  加载插件
#
sub load_plugin {
    my ($self, $name) = @_;

    # 先从PLUGIN_PATH环境变量找插件
    my @plugin_path  = split ':', $ENV{PLUGIN_PATH} if $ENV{PLUGIN_PATH} && -d $ENV{PLUGIN_PATH};
    my $pfile;
    for (@plugin_path) {
        next unless -f "$_/$name.plugin";
        $pfile = "$_/$name.plugin";
        last; 
    }

    # 系统插件
    unless( $pfile ) {
        $pfile = dirname(__FILE__) . "/Run/Plugin/$name.plugin";
    }
    
    # 插件文件不存在
    unless(-f $pfile) {
        confess "can not find plugin[$name] in[$ENV{PLUGIN_PATH}]";
    }

    my $initor = do $pfile or confess "can not do file[$pfile] error[$@]";

    $plugin{$name} = $initor;
}

#
# 初始化插件
#
# use Carp qw/cluck/;
sub init_plugin {
    my ($self, $name) = (shift, shift);
    if ('CODE' eq ref $plugin{$name} ) {
        $plugin{$name}->(@_);
    }
}

1;

__END__

=head1 NAME


=head1 SYNOPSIS


=head1 API


=head1 Author & Copyright


=cut


