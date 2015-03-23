package Zeta::DT;
use strict;
use warnings;
use DateTime;
use DateTime::Duration;
use Zeta::IniParse qw/ini_parse/;
use Carp;

#--------------------------------------------------
# 参数: $dbh
#
# 对象结构
# {
#    2012 => { days => 365, holiday => [] },
#    2013 => { days => 365, holiday => [] },
#    2014 => { days => 365, holiday => [] }
# }
#--------------------------------------------------
sub new {
    my ($class, $dbh) = @_;
    my $self = bless {}, $class;
    $self->_init($dbh);
    return $self;
}

#
# Zeta::DT->create( 2012 => '2012.ini', 2013 => '2013.ini' ...);
#
sub create {
    
    my ($class, %files) = @_;
    my %info;
    for my $year (sort keys %files) {
        my ($days, $holiday) = &_holi_year($year, $files{$year});
        my @map;
        $map[$_] = 1 for @$holiday;
        $info{$year} = { days => $days, holiday => \@map };
    }
    
    bless \%info, $class;
}

#
# Zeta::DT->add_holi($dbh, $year, $file);
#
sub add_holi {
    my ($class, $dbh, $year, $file) = @_;
    my $sth = $dbh->prepare("insert into dict_holi(year, days, holiday) values(?,?,?)");

    my ($days, $holiday)  = &_holi_year($year, $file);
    my $holi_str = join ',', @$holiday;
    $sth->execute($year, $days, $holi_str);
    $dbh->commit();
    $sth->finish();
    return 1;
}

#
# &_holi_year($year, $file)
#
sub _holi_year {
 
    my ($year, $file) = @_;

    my $dt = DateTime->new(
        year      => $year,
        month     => 1,
        day       => 1,
        hour      => 0,
        minute    => 0,
        second    => 1,
        time_zone => 'local',
    );
    my $dur = DateTime::Duration->new(days => 1);
    my $days = $dt->is_leap_year ? 366 : 365;
    
    my %holiday;
    my $cnt = $days;
    
    # 设置周六周日为节假日
    while($cnt) {
        my $day = $dt->ymd('-');
        my $flag = 0;
        if ($dt->day_of_week == 6 || $dt->day_of_week == 7) {
            $holiday{$day} = 1;
        }
        $dt->add($dur);
        --$cnt;
    }

    # 解析yyyy.ini    
    my $holi = ini_parse($file);

    # 更新国家假日表
    for my $h( keys %$holi) {
        $holi->{$h}->{begin} =~ /(\d{4})(\d{2})(\d{2})/;
        my $beg = DateTime->new( 
            time_zone => 'local', 
            year  => $1, 
            month => $2, 
            day   => $3
        );
        my $d1 = $beg->day_of_year();

        $holi->{$h}->{end} =~ /(\d{4})(\d{2})(\d{2})/;
        my $d2 = DateTime->new( 
            time_zone => 'local', 
            year => $1, 
            month => $2, 
            day => $3)->add($dur)->day_of_year();
        my $all = $d2 - $d1;

        while ($all > 0) {
            $holiday{$beg->ymd('-')} = 1;
            $all--;
            $beg->add($dur);
        }

        my $adj = $holi->{$h}->{adjust};
        for (split ',', $adj) {
            s/(\d{4})(\d{2})(\d{2})/$1-$2-$3/;
            delete $holiday{$_};
        }
    }
    
    # 组织插入数据库
    my @holiday;
    for (sort keys %holiday) {
        /(\d{4})-(\d{2})-(\d{2})/;
        my $dt = DateTime->new( time_zone => 'local', year => $1, month => $2, day => $3);
        push @holiday, $dt->day_of_year();
    }

    return ( $days,  \@holiday );
}


#
# 初始化对象结构
#
sub _init {
    my ($self, $dbh) = @_;
    return unless $dbh;
   
    my $sel = $dbh->prepare(<<EOF);
select year, days, holiday from dict_holi where year > ? and year < ? order by year asc
EOF
  
    # 加载前年，去年，今年，明年，一共4年数据
    my $year = DateTime->now(time_zone => 'local')->year();
    $sel->execute($year - 3, $year + 2); 
    while(my $row = $sel->fetchrow_hashref()) {
        my @bitmap;
        for (split ',', $row->{holiday}) {
            $bitmap[$_] = 1;
        }
        $self->{$row->{year}} = {
            days    => $row->{days},
            holiday => \@bitmap,
        };
    }
    $sel->finish();
   
    return $self;
}

#
# 获取工作日期
#
sub get_range {
    my ($self, $y_m_d) = @_;

    # 当前日期必须是工作日
    unless($self->is_wday($y_m_d)) {
        return;
    }
    my $prev_w = $self->next_n_wday($y_m_d, -1);   # 前一个工作日
    my $prev   = $self->next_n_day($y_m_d, -1);   # 前一自然日
    if ($prev_w eq $prev) {
        return [ $prev ];
    }
    my @range;
    while(1) {
        push @range, $prev_w;
        $prev_w = $self->next_n_day($prev_w, 1);
        last if $prev_w eq $y_m_d;
    }

    return \@range;
}

#
# 下n个工作日
# 参数:
#     $date :  日期
#     $n    :  下几个工作, 小于0为前几个工作日
#
sub next_n_wday {
    my ($self, $date, $n) = @_;
    return $date if $n == 0;
    $date =~ /(\d{4})-(\d{2})-(\d{2})/;
    return $self->next_n_wday_dt(
        DateTime->new(time_zone => 'local', year => $1, month => $2, day => $3), $n)->ymd('-');
}

#
#  下n个工作日dt版本
#  $self->next_n_wday_dt($dt, $n);
#
sub next_n_wday_dt {
    my ($self, $dt, $n) = @_;
    return $dt if $n == 0 ;

    my $day  = $dt->day_of_year();   # 当年的第几天
    my $year = $dt->year();          # 哪一年

    if ($n > 0 ) {
        my $dur = 0;
        while ($n > 0 ) {
           ++$day;
           if ($day > $self->{$year}->{days}) {
               ++$year;
               $day = DateTime->new(
                   time_zone => 'local', 
                   year      => $year, 
                   month     => 1, 
                   day       => 1
               )->day_of_year();
               unless ($self->{$year}) {
                   confess "ERROR: only[" . join(',', sort keys %{$self}) . "], need[$year]";
               }
           }
           # 如果是节假日
           if ($self->{$year}->{holiday}[$day]) {
               ++$dur;
               next;
           }
           $n--;
           ++$dur; 
        }
        return $dt->add(days => $dur);
    }
    else {
        my $dur = 0;
        while($n != 0) {
            --$day;
            if ( $day < 0 ) {
                --$year;
                $day = DateTime->new(
                    time_zone => 'local', 
                    year      => $year, 
                    month     => 12, 
                    day       => 31
                )->day_of_year();
                unless($self->{$year}) {
                    confess "only[" . join(',', sort keys %{$self}) . "], need[$year]";
                }
            }
            if ( $self->{$year}->{holiday}[$day]) {
                 ++$dur;
                 next; 
            }
            ++$n;
            ++$dur;
        }
        return $dt->subtract(days => $dur);
    }
}

#
#  下n个自然日
#  $self->next_n_day($date, $n);
#
sub next_n_day {
    my ($self, $date, $n) = @_;
    return $date if $n == 0;

    $date =~ /(\d{4})-(\d{2})-(\d{2})/;
    my $dt = DateTime->new( time_zone => 'local', year => $1, month => $2, day => $3);

    return $n > 0 ? $dt->add(days => $n)->ymd('-') :
                    $dt->subtract(days => -$n)->ymd('-');
}

#
#  下n个自然日dt版本
#  $self->next_n_day($dt, $n);
#
sub next_n_day_dt {
    my ($self, $dt, $n) = @_;
    return $dt if $n == 0;
  
    return $n > 0 ? $dt->add(days => $n) :
                    $dt->subtract( days => -$n);
}

#
# 是否为工作日
#
sub is_wday {
    my ($self, $date ) = @_;
    $date =~ /(\d{4})-(\d{2})-(\d{2})/;
    my $year = $1;
    return $self->is_wday_dt(DateTime->new( time_zone => 'local', year => $1, month => $2, day => $3));
}

#
# 是否为工作dt版
#
sub is_wday_dt {
    my ($self, $dt) = @_;
    my $year = $dt->year();
    my $day = $dt->day_of_year();
    unless($self->{$year}) {
        confess "ERROR: only[" . join(',', sort keys %{$self}) . "], need[$year]";
    }
    return $self unless $self->{$year}->{holiday}[$day];
    return; 
}

#
# 周最后一天
#
sub week_last {
    my ($self, $date) = @_;
    $date =~ /(\d{4})-(\d{2})-(\d{2})/;
    my $dt = DateTime->new( time_zone => 'local', year => $1, month => $2, day => $3);
    $dt->add(days => 7 - $dt->day_of_week);
    return $dt->ymd('-');
}

#
# 周最后一天dt版本
#
sub week_last_dt {
    my ($self, $dt) = @_;
    return $dt->add(days => 7 - $dt->day_of_week);
}


#
# 月最后一天
#
sub month_last {
    my ($self, $date) = @_;
    $date =~ /(\d{4})-(\d{2})-(\d{2})/;
    return DateTime->last_day_of_month(time_zone => 'local', year => $1, month => $2)->ymd('-');
}

#
# 月最后一天dt版
#
sub month_last_dt {
    my ($self, $dt) = @_;
    return DateTime->last_day_of_month(time_zone => 'local', year => $1, month => $dt->month());
}

#
# 季度最后一天
#
sub quarter_last {
    my ($self, $date) = @_;
    $date =~ /(\d{4})-(\d{2})-(\d{2})/;
    my $year = $1;
    my $dt = DateTime->new( time_zone => 'local', year => $year, month => $2, day => $3);
    my $month =  $dt->quarter * 3;
    return DateTime->last_day_of_month( time_zone => 'local', year => $year, month => $month)->ymd('-');
}

#
# 季度最后一天dt版
#
sub quarter_last_dt {
    my ($self, $dt) = @_;
    return DateTime->last_day_of_month( time_zone => 'local', year => $dt->year, month => $dt->quarter * 3);
}
 
 

#
# 半年最后一起
#
sub semi_year_last {
    my ($self, $date) = @_;
    $date =~ /(\d{4})-(\d{2})-(\d{2})/;
    return $2 > 6 ? "$1-12-31" : "$1-06-30";
}

#
# 半年最后一天dt版
#
sub semi_year_last_dt {
    my ($self, $dt) = @_;
    return $dt->month() > 6 ? $dt->set_month(12)->set_day(31) : $dt->set_month(6)->set_day(30);
}

#
# 年最后一天
#
sub year_last {
    my ($self, $date) = @_;
    $date =~ /^(\d{4})-/;
    return "$1-12-31";
}

#
# 年最后一天dt版
#
sub year_last_dt {
    my ($self, $dt) = @_;
    return $dt->set_month(12)->set_day(31);
}

1;

__END__

[元旦]
begin = 20120101
end = 20120103
adjust = 20111231

[春节]
begin = 20120101
end = 20120103
adjust = 20120121,20120129

[清明节]
begin = 20120402
end = 20120404
adjust = 20120331,20120401

[劳动节]
begin = 20120429
end = 20120501
adjust = 20120428

[端午节]
begin = 20120622
end = 20120624
adjust =

[中秋国庆]
begin = 20120930
end = 20121007
adjust = 20120929
