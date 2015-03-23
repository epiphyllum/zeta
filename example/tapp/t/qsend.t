use Zeta::IPC::MsgQ;

my $cfg = do "$ENV{TAPP_HOME}/conf/tapp.conf";
my $q = Zeta::IPC::MsgQ->new($cfg->{qkey});

$q->send("job [" . localtime() . "]", $$);
