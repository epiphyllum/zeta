#!/usr/bin/perl
use strict;
use warnings;
use Carp;
use Zeta::Run;
use DBI;

#
# 加载集中配置文件
#
my $cfg  = do "$ENV{THREAD_HOME}/conf/thread.conf";
confess "[$@]" if $@;

1;
