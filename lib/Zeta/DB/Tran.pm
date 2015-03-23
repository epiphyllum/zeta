package Zeta::DB::Tran;
# 
#  Zeta::DB::Tran.pm
#  zeta
#      数据库迁移
#  Created by zhou chao on 2013-10-13.
#  Copyright 2013 zhou chao. All rights reserved.
# 
use strict;
use warnings;
use Carp;
use Data::Dumper;
use Time::HiRes qw/gettimeofday tv_interval/;
use constant {
    BATCH_SIZE => 500
};

#
# Zeta::DB::Tran->new( 
#    logger => $logger, 
#    dbh    => $dbh, 
#    batch  => 1000
# );
#
sub new {
    my $class = shift;
    my $self = bless { @_ }, $class;
    unless($self->{logger}) {
        confess "logger needed";
    }
    unless($self->{dbh}) {
        confess "dbh needed";
    }
    $self->{batch} ||= BATCH_SIZE; # 提交批次大小
    return $self;
}

#
# 数据库迁移
# $self->tran(
#     tbl_name => [ 
#         [ $pre, $pre ],  
#         \&conv, 
#         [ $post, $post ] 
#     ],
#     tbl_name => [ 
#         \@pre, 
#         \&conv, 
#         \@post
#     ],
# )
#
sub tran {
    my $self = shift;
    my $job = { @_ };
    
    my $logger = $self->{logger};
    my $fail = 0;
    my $success = 0;
    for my $tbl (keys %$job) {
        my $pre = $job->{$tbl}->[0];
        my $conv = $job->{$tbl}->[1];
        my $post = $job->{$tbl}->[2];
        unless( $self->table($tbl, $pre, $conv, $post) ) {
            $logger->info("移表[$tbl] 失败!!!!");
            ++$fail;
        } 
        else {
            $logger->info("移表[$tbl] 成功");
            ++$success;
        }
    }
    $logger->info("成功[$success] 失败[$fail]");
    return $self;
}

#
# 表迁移
#
sub table {
    my ($self, $tbl, $pre, $conv, $post) = @_;
    my $dbh = $self->{dbh};
    my $logger = $self->{logger};
    
    # 将当前表重命名为old
    my $old = "$tbl" . "_$$";
    $self->rename($tbl, $old);
        
    # 建立新表
    for (@$pre) {
        $dbh->do($_);
    }
    $dbh->commit();
    
    # 准备新表插入语句
    my $qdst = $dbh->prepare("select * from $tbl");
    my $size = scalar keys %{$qdst->{NAME_hash}};
    my $markstr = join(',', ('?') x $size);
    my $idst_sql = "insert into $tbl values($markstr)";
    $logger->debug("idst_sql[$idst_sql] size[$size]");
    my $idst =  $dbh->prepare($idst_sql);
    
    # 查询旧表, 转换, 插入新表
    my $qsrc = $dbh->prepare("select * from $old");
    $qsrc->execute();
    my $cnt = 0;
    my $batch = 0;
    my $ts_beg = [gettimeofday];
    while(my $row = $qsrc->fetchrow_hashref()) {
        my $drow = &{$conv}($row);
        unless($drow) {
            $logger->error();
            $dbh->rollback();
            $self->restore($old, $tbl);
            return;
        }
        $logger->debug("drow:\n" . Dumper($drow));
        $idst->execute(@$drow);
        $cnt++;
        if ($cnt == $self->{batch}) {
            $dbh->commit();
            $batch++;
            $logger->info(sprintf("batch[%04d] cnt[%04d] elapse[%f]", $batch, $cnt, tv_interval($ts_beg)));
            $ts_beg = [gettimeofday];
        }
    }
    if ($cnt) {
        $dbh->commit();
        $batch++;
        $logger->info(sprintf("batch[%04d] cnt[%04d] elapse[%f] -- last", $batch, $cnt, tv_interval($ts_beg)));
    }
    
    $dbh->do("drop table $old");
    $dbh->commit();

    # 数据升级后处理
    for (@$post) {
        $dbh->do($_);
    }

    return $self;
}

#
# 将表重命名回去
#
sub restore {
    my $self = shift;
    my ($old, $new) = @_;
    my $dbh = $self->{dbh};
    $dbh->do("drop table $new");
    $self->rename($old, $new);
    $dbh->commit();
    return $self;
}

sub rename {
    my ($self, $old, $new) = @_;
    if ($ENV{DSN} =~ /SQLite/) {
        $self->{dbh}->do("alter table $old rename to $new");
    }
    elsif($ENV{DSN} =~ /DB2/) {
        $self->{dbh}->do("rename table $old to $new");
    }
}

1;
