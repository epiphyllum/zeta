#!/usr/bin/perl
use Zeta::DB::Excel;
use DBI;
use Data::Dump;

my $dbh = DBI->connect(
    "dbi:SQLite:dbname=dbex.db",
    "",
    "",
    {
        RaiseError       => 1,
        PrintError       => 0,
        AutoCommit       => 0,
        FetchHashKeyName => 'NAME_lc',
        ChopBlanks       => 1,
        InactiveDestroy  => 1,
    },
);

my $dbex = Zeta::DB::Excel->new(dbh => $dbh);

my $excel = $dbex->excel(
    filename => './dbex.xls',
    sheet => {
        '分润1' => {
            hmap   => { f1 => '交易金额',  f2 => '扣率',  f3 => '手续费',  f4 => '分润' },
            select => "select * from dbex",
            flist  => [qw/f2 f1 f4 f3/],
            sum    => [qw/f1 f4/],
            filter => \&filter,
        },

        '分润2' => {
            hmap   => { f1 => '交易金额',  f2 => '扣率',  f3 => '手续费',  f4 => '分润' },
            select => "select * from dbex",
            flist  => [qw/f2 f1 f4 f3/],
            sum    => [qw/f1 f4/],
            filter => \&filter,
        },
    },
);

# Data::Dump->dump($excel->{sheet});

# warn "rows : " . $excel->rows('分润1');
# warn "cols : " . $excel->cols('分润1');

$excel->add_chart(
    type     => 'line',
    name     => 'my chart',
    position => [ '分润1', 'A8'],
    series => [
        {
            categories => {
                sheet => '分润1',
                field => 'f1',
                range => [ 2, $excel->rows('分润1')-1 ],
            },
               
            values => {
                sheet => '分润1',
                field => 'f2',
                range => [ 2, $excel->rows('分润1')-1 ],
            },
            name => 'my series',
        },

        {
            categories => {
                sheet => '分润1',
                field => 'f1',
                range => [ 2, $excel->rows('分润1')-1 ],
            },
               
            values => {
                sheet => '分润1',
                field => 'f2',
                range => [ 2, $excel->rows('分润1')-1 ],
            },
            name => 'my series',
        }
    ],
    title  => 'this is title',
    legend => 'this is legend',
    axis_x => 'axis x',
    axis_y => 'axis y',  
);

$excel->add_chart(
    type     => 'column',
    name     => 'my chart',
    # position => [ '分润1', 'A8'],
    series => [
        {
            categories => {
                sheet => '分润1',
                field => 'f1',
                range => [ 2, $excel->rows('分润1')-1 ],
            },
               
            values => {
                sheet => '分润1',
                field => 'f2',
                range => [ 2, $excel->rows('分润1')-1 ],
            },
            name => 'my series',
        },

        {
            categories => {
                sheet => '分润1',
                field => 'f1',
                range => [ 2, $excel->rows('分润1')-1 ],
            },
               
            values => {
                sheet => '分润1',
                field => 'f2',
                range => [ 2, $excel->rows('分润1')-1 ],
            },
            name => 'my series',
        }
    ],
    title  => 'this is title',
    legend => 'this is legend',
    axis_x => 'axis x',
    axis_y => 'axis y',  
);
$excel->close();

sub filter {
    my $row = shift;
    for (keys %$row) {
        $row->{$_} *= 2;
    }
    return 1;
}


__END__
