use Zeta::MCache;
use Data::Dump;

my $mc = Zeta::MCache->new(T => 2, default_size => 3);

# type  t cache size   3
unless($mc->get(qw/t 1/)) { $mc->set(qw/t 1 1/); warn 't => 1'; }
unless($mc->get(qw/t 2/)) { $mc->set(qw/t 2 2/); warn 't => 2'; }
unless($mc->get(qw/t 3/)) { $mc->set(qw/t 3 3/); warn 't => 3'; }
unless($mc->get(qw/t 4/)) { $mc->set(qw/t 4 4/); warn 't => 4'; }

# type  T cache size   2
unless($mc->get(qw/T 1/)) { $mc->set(qw/T 1 1/); warn 'T => 1'; }
unless($mc->get(qw/T 2/)) { $mc->set(qw/T 2 2/); warn 'T => 2'; }
unless($mc->get(qw/T 3/)) { $mc->set(qw/T 3 3/); warn 'T => 3'; }
unless($mc->get(qw/T 4/)) { $mc->set(qw/T 4 4/); warn 'T => 4'; }

warn $mc->get('T', 4);
warn $mc->get('T', 3);
warn $mc->get('T', 2);
warn $mc->get('T', 1);

Data::Dump->dump($mc);

