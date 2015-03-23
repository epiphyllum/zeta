zeta tutorial
====

1、准备工作, 安装zeta框架。 应用程序默认zeta安装在用户home目录下的opt目录下

    [gardenia:tmp zhouchao] cd ~/opt; git clone https://github.com/haryzhou/zeta.git

2、生成框架

    [gardenia:tmp zhouchao] zgen app kiss
    建立目录结构...
    mkdir kiss
    mkdir kiss/bin
    mkdir kiss/sbin
    mkdir kiss/conf
    mkdir kiss/etc
    mkdir kiss/lib
    mkdir kiss/libexec
    mkdir kiss/log
    mkdir kiss/scratch
    mkdir kiss/t
    mkdir kiss/tmp
    生成框架文件...
    generate kiss/etc/profile.mak
    generate kiss/conf/zeta.conf
    generate kiss/conf/kiss.con
    generate kiss/libexec/plugin.pl
    generate kiss/libexec/main.pl
    generate kiss/.gitignore
    generate kiss/Makefile.PL
    generate kiss/sbin/stopall
    generate kiss/sbin/runall
    generate kiss/sbin/restart
    **************************************
    1、定制开发, 请编辑:
       kiss/Makefile.PL
       kiss/etc/profile.mak
       kiss/conf/kiss.conf
       kiss/conf/zeta.conf
       kiss/libexec/plugin.pl
       kiss/libexec/main.pl
    **************************************
    2、测试运行: 
       . kiss/etc/profile.mak
       runall; ps -ef | grep Z;
    **************************************
    3、停止
       stopall; sleep 1; ps -ef | grep Z;
    **************************************
    4、重启 
       restart; sleep 1; ps -ef | grep Z;
    **************************************
    5、查看日志
       ls -lrt kiss/log/
       tail -f kiss/log/Zhello.log
    **************************************
    6、初始化github项目(请在github创建repository)
       cd kiss;
       git init
       git add .
       git commit -m "first commit"
       git remote add origin git@github.com:haryzhou/kiss.git
       git push -u origin master
    **************************************

3、测试运行

    [gardenia:tmp zhouchao] . kiss/etc/profile.mak;   runall

4、查看进程

    [gardenia:tmp zhouchao] ps -ef | grep Z
    501 51969     1   0  9:46上午 ??         0:00.04 Zkiss   
    501 51970 51969   0  9:46上午 ??         0:00.00 Zhello   
    501 51971 51969   0  9:46上午 ??         0:00.11 Zstomp   
    501 51972 51969   0  9:46上午 ??         0:00.01 Zmlogd   
    501 51975 51971   0  9:46上午 ??         0:00.01 Zstomp poe-generic read  

    默认生成的框架里包含:
    * Zkiss    : 主控进程
    * Zhello   : 一个hello模块     
    * Zstomp   : 一个测试用的stomp服务器， 
    * Zmlogd   : 日志监控HTTPD

5、查看日志

    [gardenia:tmp zhouchao] ls kiss/log/
    Zhello.log	Zmlogd.log	Zstomp.log	zeta.log	zeta.pid

    [gardenia:tmp zhouchao] tail -f kiss/log/Zhello.log
    09:55:04 20130608 <bexec/hello.pl>:0015 DEBUG-> [    Zhello]: hello 0
    09:55:05 20130608 <bexec/hello.pl>:0015 DEBUG-> [    Zhello]: hello 1
    09:55:06 20130608 <bexec/hello.pl>:0015 DEBUG-> [    Zhello]: hello 2
    09:55:07 20130608 <bexec/hello.pl>:0015 DEBUG-> [    Zhello]: hello 3
    09:55:08 20130608 <bexec/hello.pl>:0015 DEBUG-> [    Zhello]: hello 4


zeta运行原理
====

perl library for process management, IPC, logging etc...

1、规范

    1.1、假设你要开发的应用的HOME目录是$APP_HOME

    1.2、主要配置文件:
         1.2.1、$APP_HOME/conf/zeta.conf         : zeta主配置文件
         1.2.2、$APP_HOME/libexec/main.pl        : 主控模块loop钩子函数
         1.2.3、$APP_HOME/libexec/plugin.pl      : 插件钩子, 负责加载helper
         1.2.4、$APP_HOME/libexec/module-A.pl    : 模块A的loop函数
         1.2.5、$APP_HOME/libexec/module-B.pl    : 模块B的loop函数

2、配置文件$APP_HOME/conf/zeta.conf, 配置文件里主要包含以下信息：

    2.1、zeta.conf主要包含两个部分配置kernel与module
         for example: 
         {
                 kernel => {
                        pidfile     => "$ENV{TAPP_HOME}/log/zeta.pid",
                        mode        => 'logger',
                        logurl      => "file://$ENV{TAPP_HOME}/log/zeta.log",
                        loglevel    => 'DEBUG',
                        logmonq     -> 9493,   
                        channel     => [ qw/dispatch/ ],
                        name        => 'Zixapp',
                        plugin      => "$ENV{TAPP_HOME}/libexec/plugin.pl",
                        main        => "$ENV{TAPP_HOME}/libexec/main.pl",
                        args        => [ ],

                        # 一些预定义的模块
                        with        => {
                            mlogd   => { host => '127.0.0.1', port => '9999', size => 20   },
                            magent  => { host => '127.0.0.1', port => '9999', monq => 9494 },
                            stomp   => { host => '127.0.0.1', port => '9999',}
                        },
                 },

                 module => {
                       Zdispatch => {
                           writer    =>  'dispatch',
                           plugin    =>  { child => undef, },
                           code      =>  "$ENV{TAPP_HOME}/libexec/dispatch.pl",
                           para      =>  [],
                           reap      =>  1,
                           size      =>  1,
                           enable    =>  1,
                       },
                 },
         };

    2.2、zeta - kernel配置
         2.2.1、pid文件
         2.2.2、运行模式:process_tree, logger, loggerd
         2.2.3、日志路径、级别、日志监控队列key
         2.2.4、插件加载钩子文件
         2.2.5、主控函数钩子文件以及参数
         2.2.6、预先建立的管道
         2.2.7、主控进程的显示名称(prctl name)
         2.2.8、预定义模块(with)

    2.3、zeta - module配置
         2.3.1、 reader: STDIN从哪个管道读
         2.3.2、 writer: STDOUT往哪个管道写
         2.3.3、 mreader: 从哪些管道读
         2.3.4、 mwriter: 往哪些管道写
         2.3.5、 code: 模块钩子函数文件
         2.3.6、 exec: 模块可执行文件(code, exec不能同时有)
         2.3.7、 para: 模块钩子函数参数、或是模块可执行文件参数
         2.3.8、 reap: 此模块的进程异常退出后是否自动重启
         2.3.9、 size: 次模块启动几个进程
         2.3.10、plugin: 子进程插件{ plugin_name => para, ... }

3、zeta读zeta.conf配置后, zeta会加载:
    
    3.1、plugin.pl   可以在plugin.pl放置你的helper函数   : 这将给zkernel增加一些helper
    3.2、code.pl     你的模块函数                        : 返回一个函数指针,模块的loop函数
    3.3、main.pl     主控函数文件                        : 主控函数指针

4、zeta为每个模块fork相应数量的子进程, 同时:

    4.1、每个子进程要么用exec对应的文件执行exec($file).
    4.2、要么调用code.pl返回的loop函数指针, 如果子进程有插件配置的话, 子进程在执行这个loop函数之前会加载子进程插件

5、zeta然后调用main.pl返回的函数指针


zeta advanced example
====

1、任务描述

   1.1、基本描述

        有一个消息队列， 2个模块分别为Zdispatch, Zworker.

        Zdispatch : 负责从消息队列中读取任务，通过管道分发给Zworker模块

        Zworker   : 负责处理Zdispatch分发的任务

   1.2 、 下面将描述zeta框架如何简化应用开发。 根据前面描述，zeta将会产生如下进程树:

        Zeta
          |         
          |        消息队列
          |          || 
          |          || 
          |         \||/
          |   --------------
          |---|Zdispatch.0 |
          |---|Zdispatch.1 |.>..>..>..>.>.
          |---|Zdispatch.N |             .
          |   --------------            \./  
          |                              . 通过管道
          |   --------------            \./
          |---|Zworker.0 |               .
          |---|Zworker.1 |.<.<..<..<..<...
          |---|Zworker.N |
          |   --------------
          |
      ------------
      |  主控loop|
      |----------|

2、开始建立应用结构

   2.1、建立应用tapp的目录
 
       midir -p ~/workspace/tapp 
       cd ~/workspace/tapp
       mkdir -p conf etc libexec plugin log sbin t

   2.2、安装zeta

       mkdir ~/opt
       cd ~/opt
       git clone https://github.com/haryzhou/zeta.git

3、开始配置、开发

    3.1、etc设置 
        进入etc目录, vi profile.mak, 添加:
        export ZETA_HOME=~/opt/zeta
        export TAPP_HOME=~/workspace/tapp
        export PERL5LIB=$ZETA_HOME/lib:$TAPP_HOME/lib
        export PATH=$ZETA_HOME/bin:$TAPP_HOME/sbin:$PATH
        export PLUGIN_PATH=$TAPP_HOME/plugin

    3.2、conf设置, 进入conf目录
        3.2.1、编辑应用主配置文件tapp.conf

            # 此文件是应用的集中配置点，应用的所有参数都在这里集中配置
            {
               qkey => 9898,   # 任务消息队列key
            };

        3.2.2、编辑zeta主配置文件zeta.conf

            {
                 # 核心配置
                 kernel => {
                        pidfile     => "$ENV{TAPP_HOME}/log/zeta.pid",
                        mode        => 'logger',
                        logurl      => "file://$ENV{TAPP_HOME}/log/zeta.log",
                        loglevel    => 'DEBUG',
                        channel     => [ qw/dispatch/ ],
                        name        => 'Zixapp',
                        plugin      => "$ENV{TAPP_HOME}/libexec/plugin.pl",
                        main        => "$ENV{TAPP_HOME}/libexec/main.pl",
                        args        => [ ],
                 },
           
                 # 模块列表配置
                 module => {
                       Zdispatch => {
                           writer    =>  'dispatch',
                           plugin    =>  { child => undef, },
                           code      =>  "$ENV{TAPP_HOME}/libexec/dispatch.pl",
                           para      =>  [],
                           reap      =>  1,
                           size      =>  2,
                       },

                       Zworker => {
                           reader    =>  'dispatch',
                           plugin    =>  undef,
                           code      =>  "$ENV{TAPP_HOME}/libexec/worker.pl",
                           para      =>  [],
                           reap      =>  1,
                           size      =>  2,
                       },
                 }
            };

    3.3、plugin开发,  进入plugin目录, 编辑child.plugin

         use Zeta::Run;
        
         helper child_func => sub {
             zlogger->debug("child_func is called");
         };

         # 插件的初始化函数
         sub {
             1;
         };

    3.4、libexec开发,  进入libexec目录

         3.4.1、zeta辅助配置文件-主控加载plugin文件, 编辑plugin.pl

                use Zeta::Run;

                my $cfg = do "$ENV{TAPP_HOME}/conf/tapp.conf";
                helper  tapp_config => sub { $cfg; }; 
                helper  parent_func => sub { zlogger->debug( "parent_func is called" ); }; 

         3.4.2、zeta辅助配置文件-主控loop, 编辑main.pl

                use Zeta::Run;
                use POSIX qw/pause/;
                sub {
                    while(1) { pause(); }
                };

         3.4.3、dispatch模块开发, 编辑dispatch.pl

                use Zeta::Run;
                use Zeta::IPC::MsgQ;
                sub {
                    my $q = Zeta::IPC::MsgQ->new(zkernel->tapp_config->{qkey});
                    my $msg;
                    my $type = 0;
                    while($q->recv(\$msg, \$type)) {
                        zkernel->child_func();     # 子进程加载的插件函数
                        zkernel->parent_func();    # 父进程加载的插件函数
                        print STDOUT $msg, "\n";    
                        $type = 0;
                    }
                };
        
         3.4.4、worker模块开发, 编辑worker.pl
            
                use Zeta::Run;
                sub {
                    while(<STDIN>) {
                        zlogger->debug("got job[$_]");
                    }
                };


    3.5、测试驱动开发,  进入t目录, 编辑qsend.t

         use Zeta::IPC::MsgQ;
 
         my $cfg = do "$ENV{TAPP_HOME}/conf/tapp.conf";
         my $q = Zeta::IPC::MsgQ->new($cfg->{qkey});

         $q->send('job [' . localtime() . ']', $$);

    3.6、sbin开发,  进入sbin目录 
  
         4.4.1、runall开发, 编辑runall

                cd $TAPP_HOME/log;
                zeta -f $TAPP_HOME/conf/zeta.conf

         4.4.1、stopall开发
         
                cd $TAPP_HOME/log;
                kill `cat zeta.pid`;


4、观察日志、运行、停止

    4.1  cd ~/workspace/tapp/etc
    4.2  . profile.mak
    4.3  runall
    4.4  cd $TAPP_HOME/log
    4.5  tail -f Zworker.0.log
    4.6  测试, perl t/qsend.t
    4.7  stopall

5、整个工程， 参见$ZETA_HOME/t/example/tapp


have a try, good luck!!!!!!



