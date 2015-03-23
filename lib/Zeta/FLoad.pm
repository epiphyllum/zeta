#######################################################################
#  Zeta::FLoad.pm
#      从文件读取记录, 处理生成记录， 插入表的基本框架
#
#     xls_row    :  load_xls时的可选钩子
#     pre        :  load时的行预处理 返回undefined 则不处理次行
#     rsplit     :  load时行的分割处理， load_xls时为数组引用, 或是返回数组引用的函数
#     rhandle    :  分割后的字段调整处理
#     dbh        :  数据库连接
#     table      :  插入那张表
#     field      :  哪些字段
#     exclusive  :  插入除exclusive字段意外的所有其他字段
#     batch      :  提交批次的大小
#     logger     :  日志对象
#
#  Created by zhou chao on 2013-09-05.
#  Copyright 2013 zhou chao. All rights reserved.
#######################################################################
package Zeta::FLoad;
use Carp;
use strict;
use warnings;
use IO::File;
use Time::HiRes qw/gettimeofday tv_interval/;
use Spreadsheet::ParseExcel;


# ===================================================================
# my $load = ZSTL::Load->new(
#    dbh      => $dbh, 
#    table    => 'table_name',
#    exclude  => [ qw/ts_c oid ts_u/ ],
#    pkey     => [ qw/fld2 fld4 .../ ],
#
#    xls_row  => \&xls_row,   # 如果是xls文件, xls获取row的函数, 可选
#
#    pre      => \&pre,       # 预处理, 可选, xls文件不需要此项目
#    rsplit   => \&rsplit,    # 分割处理
#    rhandle  => \&rhandle,   # 分割后处理
#
#    batch    => 100,         # 批次大小
# ) 
# $load->load($file);
# $load->load_xls($file, 0, 0);
# ===================================================================
sub new {
    my $class = shift;
    my $self = bless { @_ }, $class;

    my $nhash  = $self->nhash();   # name  => index
    my %rhash  = reverse %$nhash;  # index => name
   
    # 1> 插入语句 
    # 组织fldstr
    my @fld =  @rhash{ sort { $a <=> $b } keys %rhash };
    return unless @fld;
    my $fldstr  = join ', ', @fld;
    my $markstr = join ', ',  ('?') x @fld;
    my $isql    = "insert into $self->{table}($fldstr) values($markstr)";   # warn "[$isql]";
    my $isth    = $self->{dbh}->prepare($isql) or die "can not prepare[$isql]";

    # 2> 更新语句 
    # use Data::Dump;
    # Data::Dump->dump(\%rhash);
    # Data::Dump->dump($nhash);
    # Data::Dump->dump($self); 
    my @pkey   = @rhash{sort { $a <=> $b } @{$nhash}{@{$self->{pkey}}}};  #  主键列表(按数据库定义顺序)
    #warn "now pkey[@pkey]";
    my @fkey;  # 主键域在提供文件中的位置
    my @fval;  # 更新域在提供文件中的位置
    my @dfld;  # 更新字段(按数据库定义顺序)
    delete @{$nhash}{@pkey};
    %rhash = reverse %$nhash;
    @dfld = @rhash{ sort { $a <=> $b } keys %rhash };
    for my $k (@pkey) { 
        for (my $i = 0; $i < @fld; ++$i) {
            if ($fld[$i] eq $k) {
                push @fkey, $i;
            }
        }
    }
    
    for my $f (@dfld) {
        for (my $i = 0; $i < @fld; ++$i) {
            if ($fld[$i] eq $f) {
                push @fval, $i;
            }
        }
    }
    my $setstr = join ', ',    map { "$_ = ?" } @dfld;
    my $keystr = join ' and ', map { "$_ = ?" } @pkey;
    my $usql = "update $self->{table} set $setstr where $keystr"; # warn "$usql";
    my $usth = $self->{dbh}->prepare($usql) or die "can not prepare[$usql]";

    # fload对象    
    $self->{fkey} = \@fkey;
    $self->{fval} = \@fval;
    $self->{isth} = $isth;
    $self->{usth} = $usth;
    $self->{batch} ||= 300;

    # use Data::Dump;
    # Data::Dump->dump($self);
    
    return $self;
}

###########################################################
#  $self->flist();
#    获取表的插入字段: 按定义顺序, 同时删除exclude的字段
###########################################################
sub nhash {
    my $self    = shift;
    my $table   = $self->{table};
    my $exclude = delete $self->{exclude};
    
    my $sth   = $self->{dbh}->prepare("select * from $table");
    my %nhash = %{$sth->{NAME_lc_hash}};
    delete @nhash{@$exclude} if $exclude and @$exclude;
    return \%nhash;
}

###########################################################
# $self->load($file, \%opt);
#    加载文件
###########################################################
sub load {
    my ($self, $file, $opt) = @_;

    my $fh = IO::File->new("<$file");
    
    my $batch = 0;
    my $cnt = 0;
    my $ts_beg = [gettimeofday];
    my $elapse;
   
    my $pre = $self->{pre}; 
    while(<$fh>) {
       
        if ($pre) { 
            next unless $_ = $pre->($_, $opt);      # 预处理
        }
        my $fld = $self->{rsplit}->($_, $opt);      # 分割处理
        my $row = $self->{rhandle}->($fld, $opt);   # 分割后处理
        # warn "execute[@$row]\n";
        # use Data::Dumper;
        # print Dumper($self->{sth});
        eval {
            $self->{isth}->execute(@$row);
        };
        if ($@) {
            if ($@ =~ /(0803|not unique)/) {
                my @pk = @{$row}[@{$self->{fkey}}];
                $self->{logger}->warn("主键[@pk]重复, 开始更新..."); 
                $self->{usth}->execute(@{$row}[@{$self->{fval}}], @pk);
            }
            else {
                $self->{logger}->error("system error[$@]");
                confess($@);
            }
        }
        $cnt++;
        if ($cnt == $self->{batch}) {
            $self->{dbh}->commit();
            $batch++;
            $elapse = tv_interval($ts_beg);
            $self->{logger}->info("batch[$batch] cnt[$cnt] elapse[$elapse]") if $self->{logger};
            $cnt = 0;
        }
    }
    
    if ($cnt) {
        $self->{dbh}->commit();
        $batch++;
        $elapse = tv_interval($ts_beg);
        $self->{logger}->info("batch[$batch] cnt[$cnt] elaspe[$elapse] last batch!!!") if $self->{logger};
        $cnt = 0;
    }
 
    return $self;
}

###########################################################
# $load->load_xls(
#     $file,    # xls文件名称
#     $sheet,   # sheet名称, 或者是index
#     $rmin,    # 从哪一行开始
#     \%opt     # 其他定制参数, 给回调函数用的
# )
# 加载xls文件
###########################################################
sub load_xls {
    my ($self, $file, $shidx, $rmin, $opt) = @_;
    
    my $parser = Spreadsheet::ParseExcel->new();
    my $wb     = $parser->parse($file);
    my $sheet  = $wb->worksheet($shidx);      # 可能是个bug, 如果sheet名称为中文
    my $rmax   = ($sheet->row_range())[1];
    
    my $cidx;
    if ('ARRAY' eq ref $self->{rsplit}) {
        $cidx = $self->{rsplit};
    }
    elsif('CODE' eq ref $self->{rsplit}) {
        $cidx = $self->{rsplit}->($opt);
    }
    unless($cidx && 'ARRAY' eq ref $cidx && @$cidx ) {
        die "load_xls need rsplit [] or subroutine return []";
    }
        
    my $xls_row = $self->{xls_row};
    if ($xls_row && "CODE" ne ref $xls_row) {
        die "xls_row must be code ref";
    }
    
    $xls_row ||= \&xls_row;
    
    my $ts_beg = [gettimeofday];
    my $elapse;
    my $batch = 0;
    my $cnt = 0;
    for my $ridx ($rmin .. $rmax) {
        my $fld = $xls_row->($sheet, $ridx, $cidx, $opt);
        my $row = $self->{rhandle}->($fld, $opt);
       
        # use Data::Dump;
        # Data::Dump->dump($row); 
        eval {
            $self->{isth}->execute(@$row);
        };
        if ($@) {
            if ($@ =~ /(0803|not unique)/) {
                my @pk = @{$row}[@{$self->{fkey}}];
                $self->{logger}->warn("主键[@pk]重复, 开始更新..."); 
                $self->{usth}->execute(@{$row}[@{$self->{fval}}], @pk);
            }
            else {
                confess "system error[$@]";                
            }
        }
        $cnt++;
        if ($cnt == $self->{batch}) {
            $self->{dbh}->commit();
            $batch++;
            $elapse = tv_interval($ts_beg);
            $self->{logger}->info("batch[$batch] cnt[$cnt] elapse[$elapse]") if $self->{logger};
            $cnt = 0;
        }
    }
    
    if ($cnt) {
        $elapse = tv_interval($ts_beg);
        $self->{logger}->info("batch[$batch] cnt[$cnt] elaspe[$elapse] last batch!!!") if $self->{logger};
        $cnt = 0;
    }
 
    return $self;
}

###########################################################
# &xls_row(
#     $sheet,                # Sheet对象
#     $ridx,                 # 第几行
#     [qw/cidx1 cidx2 .../], # 取哪些列
#     $opt                   # 其他参数
# );
#    默认的获取xls行的函数
###########################################################
sub xls_row {
    my ($sheet, $ridx, $cidx, $opt) = @_;
    my @row;
    for (@$cidx) {
        my $cell = $sheet->get_cell($ridx, $_);
        unless ($cell) {
            push @row, undef;
            next;
        }
        my $val = $cell->value();
        # warn "cell($ridx, $_) = $val";
        push @row, $val;
    }
    return \@row;
}

1;

