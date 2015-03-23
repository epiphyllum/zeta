#！perl
use Test::More;
use Test::Differences;
use Zeta::Encode qw/
from_excel_col
from_excel_cell
to_excel_col
to_excel_cell
/;

plan tests => 8;

ok(from_excel_col('A')  == 0,    'result is ' . from_excel_col('A'));
ok(from_excel_col('BA') == 26,   'result is ' . from_excel_col('BA'));
ok(to_excel_col(0)      eq 'A',  'result is ' . to_excel_col(0));
ok(to_excel_col(26)     eq 'BA', 'result is ' . to_excel_col(26));

eq_or_diff(from_excel_cell('A1'), [0,0]);
ok(to_excel_cell(0,0), 'A1');
eq_or_diff(from_excel_cell('BA11'), [10,26]);
ok(to_excel_cell(10,26), 'BA11');

done_testing();

