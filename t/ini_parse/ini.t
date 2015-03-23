
use Data::Dump;

use lib qw(../lib);
use Zeta::IniParse;

my $hash = ini_parse("./ltl.ini");

Data::Dump->dump($hash);


