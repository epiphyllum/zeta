use Zeta::Run;

my $cfg = do "$ENV{TAPP_HOME}/conf/tapp.conf";
helper  tapp_config => sub {  $cfg; }; 
helper  parent_func => sub { zlogger->debug( "parent_func is called" ); }; 
