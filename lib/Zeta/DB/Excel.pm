package Zeta::DB::Excel;
use strict;
use warnings;
use Carp;
use Spreadsheet::WriteExcel;
use Data::Dumper;
use Encode;

#
# Zeta::DB::Excel->new( dbh => $dbh);
#
sub new {
    my $class = shift;
    bless { @_ }, $class;
}

#---------------------------------------------------------------------------------------------
#  filename => '/tmp/xxx.xls',
#  sheet => {
#      分润明细 => {
#          hmap   => {  fld1  => '姓名',  .... }, # 表头映射, 每个域的中文名称
#          select => "select * from xxxx",        # select 语句
#          flist  => [ qw/fld3 fld2 fld1/ ],      # 域排列顺序
#          sum    => [ qw/fld2 fld1/ ],           # 哪些域需要汇总
#          filter => \&filter,                    # 行过滤, 如有的域需要decode('utf8', $fld);
#      },
#      sheet1 => {
#      }
#  }
#
#  返回值:
#  {
#      sheet => $原来的sheet_增加了stat包含了[$col, $]
#      book  => $book
#      
#  }
#---------------------------------------------------------------------------------------------
sub excel {
    my $self = shift;
    my $args = { @_ };

    # excel文件
    my $book  = Spreadsheet::WriteExcel->new(delete $args->{filename});
    my $hfmt  = $book->add_format(border => 1, bg_color => 'gray');
    my $rfmt  = $book->add_format(border => 1);
    
    my $res = bless {
        dbh   => $self->{dbh},
        sheet => $args->{sheet},
        book  => $book,
        hfmt  => $hfmt,
        rfmt  => $rfmt,
    },  __PACKAGE__ . '::Resource';
    
    for my $name (keys %{$args->{sheet}}) {
        $res->add_worksheet($name, $args->{sheet}->{$name});
    }

    return $res;
}

package Zeta::DB::Excel::Resource;
use Carp;
use Encode;
use Data::Dumper;

# $res->cols('Sheet1');
# $res->rows('Sheet1');
sub  rows { shift->{sheet}{+shift}{rows};              }
sub  cols { scalar @{+shift->{sheet}{+shift}{flist}};  } 

#----------------------------------------------------------------
# 
# $self = {
#     book  => $book
#     sheet => {},
#     hfmt  => $hfmt,
#     rfmt  => $rfmt,
# }
#
# $self->add_chart(
#     type  => 'line|area|bar|column|pie|scatter|stock',
#     name  => 'chart name',
#     position => [ '分润1', 'A8'],   # embedded or new sheet
#     series => [
#          {
#              categories => {
#                  sheet => $sheet_name, 
#                  field => $fld, 
#                  range => [ $beg, $end],
#              },
#              values => {
#                  sheet => $sheet_name, 
#                  field => $fld, 
#                  range => [ $beg, $end],
#              },
#              name       => 'Test data series 1',
#          },
#          {
#              
#          }
#     ],
#     title => '标题',
#     legend => 'none|bottom',
#     axis_x => 'Sample number',
#     axis_y => 'Sample length(cm)',
# );
#----------------------------------------------------------------
sub add_chart {
    my $self = shift;
    my $args = { @_ };
    
    my $chart;
    if ($args->{position}) {
        $chart = $self->{book}->add_chart(
            type     => $args->{type},
            name     => $args->{name},
            embedded => 1
        );
    } else {
        $chart = $self->{book}->add_chart(
            type => $args->{type},
            name => $args->{name},
        );
    }
    my $series = $args->{series};
    
    for (@$series) {
        # Data::Dump->dump($_);
        
        my $catidx = &index($self->{sheet}{$_->{categories}{sheet}}{flist}, $_->{categories}{field});
        my $validx = &index($self->{sheet}{$_->{values}{sheet}    }{flist}, $_->{values    }{field});
        my $catbeg = $_->{categories}{range}[0];
        my $catend = $_->{categories}{range}[1];
        my $valbeg = $_->{values}{range}[0];
        my $valend = $_->{values}{range}[1];
        
        # warn "catidx : $catidx";
        # warn "catbeg : $catbeg";
        # warn "catend : $catend";
        # warn "validx : $validx";
        # warn "valbeg : $valbeg";
        # warn "valend : $valend";
        # my $csname = $_->{categories}{sheet};
        # my $vsname = $_->{values}{sheet};
        # my $catstr = "=$_->{categories}{sheet}!\$$catidx\$$catbeg:\$$catidx\$$catend";
        # my $valstr = "=$_->{values}{sheet}!\$$validx\$$valbeg:\$$validx\$$valend";
        
        my $csname = decode('utf8', $_->{categories}{sheet});
        my $vsname = decode('utf8', $_->{values}{sheet});
        my $catstr = "=$csname!\$$catidx\$$catbeg:\$$catidx\$$catend";
        my $valstr = "=$vsname!\$$validx\$$valbeg:\$$validx\$$valend";
        
        # warn "catstr : $catstr";
        # warn "valstr : $valstr";
        $chart->add_series(
            categories => $catstr,
            values     => $valstr,
            name       => $_->{name},
        );
    }
    
    if ($args->{title} ) {$chart->set_title (name => $args->{title}); }
    if ($args->{axis_x}) {$chart->set_x_axis(name => $args->{axis_x});}
    if ($args->{axis_y}) {$chart->set_y_axis(name => $args->{axis_y});}
    if ($args->{legend}) {$chart->set_legend(name => $args->{axis_y});}
    
    if ($args->{position}) {
        $self->{sheet}{$args->{position}[0]}{handle}->insert_chart($args->{position}[1], $chart);
    }
}

#
# book写入文件关闭
# $res->close();
#
sub close {
    my $self = shift;
    $self->{book}->close();
}

#
# $resource->add_worksheet;
#
sub add_worksheet {

    my ($self, $name, $args) = @_;
    my $sheet = $self->{book}->add_worksheet(decode('utf8', $name));
    # my $sheet = $self->{book}->add_worksheet($name);
    my $hfmt  = $self->{hfmt};
    my $rfmt  = $self->{rfmt};

    # sql语句准备
    my $sth = $self->{dbh}->prepare($args->{select});
    unless($sth) {
        warn "can not prepare[$args->{select}]";
        return;
    }
    my $line = 1;  # 当前行

    # 写入表头, 按flist描述的顺序写入表头
    my @head = map { decode('utf8', $_) } @{$args->{hmap}}{@{$args->{flist}}};
    $sheet->write('A1', \@head, $hfmt);
    $line++;
   
    # 写入数据行 
    $sth->execute();
    while(my $row = $sth->fetchrow_hashref()){
        # warn "got row: " . Dumper($row);
        # 数据行过滤处理
        if ($args->{filter}) {
            unless($args->{filter}->($row)) {
                confess "can not filter line: " . Dumper($row);
            }
        }
        my @flds = @{$row}{@{$args->{flist}}}; 
        $sheet->write("A$line", \@flds, $rfmt);
        $line++;
    }
  
    # 合计部分
    if ($args->{sum}) {
        my $end = $line - 1;
        my %sum = map { $_ => undef } @{$args->{flist}};
        for (@{$args->{sum}}) {
            my $idx = &index($args->{flist}, $_);
            $sum{$_} = "=SUM(${idx}2:${idx}$end)";
        }
        my @sum = @sum{@{$args->{flist}}};
        $sum[0] = decode('utf8', '合计');
        $sheet->write("A$line", \@sum, $hfmt);
    }

    # 返回
    $self->{sheet}{$name}{handle} = $sheet;  # sheet handle
    $self->{sheet}{$name}{rows}   = $line;   # 数据行数
    return $self;
}

#
#
#
sub index {
    my ($flist, $fld) = @_;
    # warn "index called with: " . Dumper(\@_);
    my $idx = 0;
    for (@$flist) {
        if ($fld eq $_) {
            return &to_excel_col($idx);
        }
        $idx++;
    }
}

#  Excel的列index计算
# sub _index {
#     my $idx = shift;
#     # warn "calc _index($idx)";
#     my @data;
#     while(1) {
#         my $res = $idx % 26;
#         unshift @data, chr(ord('A')+$res); 
#         $idx = int($idx/26);
#         # warn "idx now[$idx]";
#         last if $idx == 0;
#     } 
#     return join '', @data;
# }

1;

