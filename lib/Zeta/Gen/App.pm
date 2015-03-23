package Zeta::Gen::App;
use strict;
use warnings;
use base qw/Zeta::Gen/;
use File::Path qw/mkpath/;
use IO::File;
use Cwd;

#
# $class->_gen_all($prj, $uprj, $cur_dir);
#
sub _gen_all {
    my ($prj, $uprj, $cur_dir) = @_;

    # 1. 建立目录
    print "建立目录结构...\n";
    mkpath( [ map { "$prj/$_" } qw/bin sbin conf etc lib libexec log scratch t tmp / ], 0771 );
    
    # 2. 产生skeleton
    print "生成框架文件...\n";
    &gen_skeleton($prj, $uprj, $cur_dir);;
    
    # 3. 提示
    print <<EOF;
                 useful hints
    **************************************
    1、定制开发, 请编辑:
       $prj/Makefile.PL
       $prj/etc/profile.mak
       $prj/conf/$prj.conf
       $prj/conf/zeta.conf
       $prj/libexec/plugin.pl
       $prj/libexec/main.pl
    **************************************
    2、测试运行: 
       . $prj/etc/profile.mak
       runall; ps -ef | grep Z;
    **************************************
    3、停止
       stopall; sleep 1; ps -ef | grep Z;
    **************************************
    4、重启 
       restart; sleep 1; ps -ef | grep Z;
    **************************************
    5、查看日志
       ls -lrt $prj/log/
       tail -f $prj/log/Zhello.log
    **************************************
    6、初始化github项目(请在github创建repository)
       cd $prj;
       git init
       git add .
       git commit -m "first commit"
       git remote add origin git\@github.com:haryzhou/$prj.git
       git push -u origin master
    **************************************
EOF
}

sub gen_skeleton {
    my ($prj, $uprj, $cur_dir) = @_;
    &gen_profile(@_);   warn "generate 环境变量: $prj/etc/profile.mak\n";
    &gen_zeta(@_);      warn "generate 主配置  : $prj/conf/zeta.conf\n";
    &gen_appconf(@_);   warn "generate 应用配置: $prj/conf/$prj.conf\n";
    &gen_plugin(@_);    warn "generate 插件加载: $prj/libexec/plugin.pl\n";
    &gen_main(@_);      warn "generate 主控loop: $prj/libexec/main.pl\n";
    &gen_gitignore(@_); warn "generate git文件 : $prj/.gitignore\n";
    &gen_makefile(@_);  warn "generate Makefile: $prj/Makefile.PL\n";
    &gen_stopall(@_);   warn "generate 停止    : $prj/sbin/stopall\n";
    &gen_runall(@_);    warn "generate 启动    : $prj/sbin/runall\n";
    &gen_restart(@_);   warn "generate 重启    : $prj/sbin/restart\n";
}

sub gen_profile {
    my ($prj, $uprj, $cur_dir) = @_;
    my $profile =<<EOF;
export ZETA_HOME=\$HOME/opt/zeta
export ${uprj}_HOME=$cur_dir/$prj
export PERL5LIB=\$ZETA_HOME/lib::\$${uprj}_HOME/lib
export PLUGIN_PATH=\$${uprj}_HOME/plugin
export PATH=\$${uprj}_HOME/bin:\$${uprj}_HOME/sbin:\$ZETA_HOME/bin:\$PATH

export DB_NAME=zdb_dev
export DB_USER=ypinst
export DB_PASS=ypinst
export DB_SCHEMA=ypinst
alias dbc='db2 connect to \$DB_NAME user \$DB_USER using \$DB_PASS'

alias cdl='cd \$${uprj}_HOME/log';
alias cdd='cd \$${uprj}_HOME/data';
alias cdlb='cd \$${uprj}_HOME/lib/$uprj';
alias cdle='cd \$${uprj}_HOME/libexec';
alias cdb='cd \$${uprj}_HOME/bin';
alias cdsb='cd \$${uprj}_HOME/sbin';
alias cdc='cd \$${uprj}_HOME/conf';
alias cde='cd \$${uprj}_HOME/etc';
alias cdt='cd \$${uprj}_HOME/t';
alias cdh='cd \$${uprj}_HOME';
alias cdtb='cd \$${uprj}_HOME/sql/table';
EOF
    &write_file("$prj/etc/profile.mak", $profile);
}

sub gen_zeta {
    my ($prj, $uprj, $cur_dir) = @_;
    my $zeta =<<EOF;
#!/usr/bin/perl
use strict;
use warnings;

#
# zeta 配置
#
{
   # kernel配置
   kernel => {
       pidfile   => "\$ENV{${uprj}_HOME}/log/zeta.pid",
       mode      => 'logger',
       logurl    => "file://\$ENV{${uprj}_HOME}/log/zeta.log",
       loglevel  => 'DEBUG',
       logmonq   => 9394,    # 日志监控队列
       channel   => [],
       name      => 'Z$prj',
       plugin    => "\$ENV{${uprj}_HOME}/libexec/plugin.pl",
       main      => "\$ENV{${uprj}_HOME}/libexec/main.pl",
       args      => [ qw// ],
       with      => {
           stomp => { host => '127.0.0.1', port => 61616, dir => '/tmp' },   # 测试stomp服务器
           mlogd => { host => '127.0.0.1', port => 9999,},                   # 日志监控HTTPD
           # magent => { host => '127.0.0.1', port => 7777, monq => '12345'}, # 应用监控agent
       },
   },

   # 模块配置
   module => {
       Zhello => {
           code      =>  "\$ENV{ZETA_HOME}/libexec/hello.pl",
           para      =>  [],
           reap      =>  1,
           size      =>  1,
           enable    =>  1,   #  0 : 不启用，  1： 启用
       },
   },
};

EOF
    &write_file("$prj/conf/zeta.conf", $zeta);
}


sub gen_appconf {
    my ($prj, $uprj, $cur_dir) = @_;
    my $appconf =<<EOF;
#!/usr/bin/perl
use strict;
use warnings;
use Zeta::Serializer::JSON;
use Carp;
use IO::Socket::INET;
use Zeta::Run;
use DBI;
use Carp;
use Zeta::IPC::MsgQ;
use Net::Stomp;


#
# 返回值
#
my \$cfg = {

    # 数据库配置 
    db => {
        dsn    => "dbi:DB2:\$ENV{DB_NAME}",
        user   => "\$ENV{DB_USER}",
        pass   => "\$ENV{DB_PASS}",
        schema => "\$ENV{DB_SCHEMA}",
    },

    # stomp
    stomp => {
        host => '127.0.0.1',
        port => '61618',
    },

};


#
# 获取应用配置
#
helper zconfig => sub { \$cfg };

#
# 连接数据库
#
helper dbh  => sub {
    my \$cfg = zkernel->zconfig();
    my \$dbh = DBI->connect(
        \@{\$cfg->{db}}{qw/dsn user pass/},
        {
            RaiseError       => 1,
            PrintError       => 0,
            AutoCommit       => 0,
            FetchHashKeyName => 'NAME_lc',
            ChopBlanks       => 1,
            InactiveDestroy  => 1,
        }
    );
    unless(\$dbh) {
        zlogger->error("can not connet db[\@{\$cfg->{db}}{qw/dsn user pass/}], quit");
        exit 0;
    }

    # 设置默认schema
    \$dbh->do("set current schema \$cfg->{db}{schema}")
        or confess "can not set current schema \$cfg->{db}{schema}";
    return \$dbh;
};

#
# 连接stomp
#
helper zstomp => sub {
    my \$cfg = shift->zconfig();
    # 连接stomp
    my \$stp = Net::Stomp->new({
        hostname => \$cfg->{stomp}{host},
        port     => \$cfg->{stomp}{port} ,
    }) or confess <<STOMP;
Net::Stomp failed with 
    { 
        hostname => \$cfg->{stomp}{host}, 
        port     => \$cfg->{stomp}{port} 
}
STOMP
    \$stp->connect({ login => 'hello', passcode => 'there' });
    return \$stp;
};



#
# 子进程需要的通用初始化
#
helper zsetup => sub {
};


EOF
    &write_file("$prj/conf/$prj.conf", $appconf);
}

sub gen_plugin {
    my ($prj, $uprj, $cur_dir) = @_;
    my $plugin =<<EOF;
#!/usr/bin/perl
use strict;
use warnings;
use Carp;
use Zeta::Run;
use DBI;

#
# 加载集中配置文件
#
my \$cfg  = do "\$ENV{${uprj}_HOME}/conf/$prj.conf";
confess "[\$\@]" if \$\@;

1;
EOF
    &write_file("$prj/libexec/plugin.pl", $plugin);
}

sub gen_main {
    my ($prj, $uprj, $cur_dir) = @_;
    my $main =<<EOF;
#!/usr/bin/perl
use strict;
use warnings;
use Zeta::Run;
use POE;

use constant {
    DEBUG => \$ENV{${uprj}_DEBUG} || 0,
};

BEGIN {
    require Data::Dump if DEBUG;
}

sub { 
    while(1) { 
        pause(); 
    } 
};

__END__
EOF
    &write_file("$prj/libexec/main.pl", $main);
}

sub gen_gitignore {
    my ($prj, $uprj, $cur_dir) = @_;
    my $gitignore =<<EOF;
*.log
*.swp
*.tgz
*.tar
*.tar.gz
*.pid
/blib
/Makefile
/MYMETA.*
/pm_to_blib
/tmp
*.komodoproject
EOF
    &write_file("$prj/.gitignore", $gitignore);
}


sub gen_makefile {
    my ($prj, $uprj, $cur_dir) = @_;
    my $makefile =<<EOF;
use ExtUtils::MakeMaker;

my \@exec_files;
push \@exec_files, 'bin/' . \$_ for qw/binary files add here/;

WriteMakefile(
    NAME      => '$prj',
    AUTHOR    => 'haryzhou <zcman2005\@gmail.com>',
    ABSTRACT  => '---------------add here---------------',
    LICENSE   => 'artistic_2',
    VERSION_FROM => 'lib/-----------add-here-------.pm',
    META_MERGE => {
        requires => { perl => '5.10' },
        resources => {
            homepage    => 'http://mojolicio.us',
            license     => 'http://www.opensource.org/licenses/artistic-license-2.0',
            MailingList => 'http://groups.google.com/group/$prj',
            repository  => 'http://github.com/haryzhou/$prj',
            bugtracker  => 'http://github.com/haryzhou/$prj/issues'
        }
    },

    PREREQ_PM => {
        'Data::Dump'        => 1.21,
        'POE'               => 1.354,
        'POE::Filter::JSON' => 0.04,
    },

    EXE_FILES => [ \@exec_files ],
    test      => {
        TESTS => 't/*.t t/*/*.t',
    },
);

EOF
    &write_file("$prj/Makefile.PL", $makefile);
}

sub gen_stopall {
    my ($prj, $uprj, $cur_dir) = @_;
    my $stopall =<<EOF;
#!/bin/bash

kill `cat \$${uprj}_HOME/log/zeta.pid`;
rm -fr \$${uprj}_HOME/log/zeta.pid;

EOF
    &write_file("$prj/sbin/stopall", $stopall);
    chmod 0755, "$prj/sbin/stopall";
}


sub gen_runall {
    my ($prj, $uprj, $cur_dir) = @_;
    my $runall =<<EOF;
#!/bin/bash

cd \$${uprj}_HOME/log;

zeta -f \$${uprj}_HOME/conf/zeta.conf;

EOF
    &write_file("$prj/sbin/runall", $runall);
    chmod 0755, "$prj/sbin/runall";
}


sub gen_restart {
    my ($prj, $uprj, $cur_dir) = @_;
    my $restart =<<EOF;
#!/bin/bash

# 停止应用
if [ -f "\$${uprj}_HOME/log/zeta.pid" ]; then 
    kill `cat \$${uprj}_HOME/log/zeta.pid`;
fi
rm -fr \$${uprj}_HOME/log/zeta.pid;

# 清理日志
cd \$${uprj}_HOME/log;
rm -fr *.log;

zeta -f \$${uprj}_HOME/conf/zeta.conf;

EOF
    &write_file("$prj/sbin/restart", $restart);
    chmod 0755, "$prj/sbin/restart";
}

sub write_file {
    my ($class, $fname) = @_;
    IO::File->new("> $fname")->print(+shift);
}

sub usage {
    my ($class) = @_;
    die <<EOF;
usage: 
    1. zgen app myapp
    2. zgen web myweb
EOF
}

1;

__END__


