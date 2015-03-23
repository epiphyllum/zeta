package Zeta::SSN;
use strict;
use warnings;
use Carp;

sub new {
    my ($class, $dbh, $seq_ctl) = @_;
    my $self = bless {
        dbh => $dbh,
    }, $class;
    if ($ENV{DSN} =~/SQLite/) {
        $self->_sqlite();
    }
    elsif($ENV{DSN} =~ /DB2/) {
        $self->_db2();
    }
    else {
        confess "only support SQLite DB2";
    }
    return $self;
}

sub _sqlite {
    my $self = shift;
    my $dbh  = $self->{dbh};
    my $sth_sel = $dbh->prepare("select cur, min, max  from seq_ctl where key = ?");
    my $sth_upd  = $dbh->prepare("update seq_ctl set cur = ?, ts_u = current_timestamp where key = ?");
    $self->{sel} = $sth_sel;
    $self->{upd} = $sth_upd;
    return $self;
}

sub _db2 {
    my $self = shift;
    my $dbh  = $self->{dbh};
    my $sth_sel = $dbh->prepare("select cur, min, max  from seq_ctl where key = ? for update of cur"); 
    my $sth_upd  = $dbh->prepare("update seq_ctl set cur = ?, ts_u = current timestamp where key = ?");
    $self->{sel} = $sth_sel;
    $self->{upd} = $sth_upd;
    return $self;
}


#
# 取下一个
#
sub next {
    my ($self, $key, $commit) = @_;
    $self->{sel}->execute($key);
    my ($id, $min, $max) = $self->{sel}->fetchrow_array();

    my $new;
    if (defined $max && defined $min) {
        if ($id == $max) {
            $new = $min;
        } 
        else {
            $new = $id + 1;
        }
    }
    else {
        $new = $id + 1;
    }
    
    $self->{upd}->execute($new, $key);
    if ($commit) {
       $self->{dbh}->commit();
    }
    return $id;
}

sub _get_n {

    my ($self, $key, $n, $commit) = @_;

    $self->{sel}->execute($key);
    my ($id, $min, $max) = $self->{sel}->fetchrow_array();
    $min ||= 1;
    $max ||= 99999999999999999;

    my $new = $id + $n;
    if ($new > $max) {
        $new = ($new - $max) + $min - 1;
    }
    
    $self->{upd}->execute($new, $key);

    if ($commit) {
        $self->{dbh}->commit();
    }

    return [$id, $min, $max, $n];
}

#
# $self->('yspz', 1000, $commit)
# [10, 5, 100000];
# [$id, $min, $max, $cache];
#
sub next_n {
    my ($self, $key, $n, $commit) = @_;

    unless($n) {
        confess "should be called like \$zs->next_n('mykey', 100)";
    }

    # 返回一个函数
    my $cache = $self->_get_n($key, $n, $commit);
    return sub {
        # cache的序列号用完了
        if ($cache->[3] == 0 ) {
            $cache = $self->_get_n($key, $n, $commit);
        }

        my $id = $cache->[0];
        $cache->[0]++;   # id   ++
        $cache->[3]--;   # size -- 
        if ($cache->[0] > $cache->[2]) {
            $cache->[0] = $cache->[1];
        }
        return $id;
    };
}

1;

__END__
create table seq_ctl (
    key    char(8),
    cur    bigint,
    min    bigint,
    max    bigint
);

-- key   :  流水号类型
-- cur   :  当前可用流水号
-- max   :  最大流水号

