use Zeta::Run;
use Zeta::IPC::MsgQ;

sub {
	my $q = Zeta::IPC::MsgQ->new(zkernel->tapp_config->{qkey});
	my $msg;
	my $type = 0;
	while($q->recv(\$msg, \$type)) {
		zkernel->child_func();     # 子进程加载的插件函数
		zkernel->parent_func();    # 父进程加载的插件函数
		print STDOUT $msg, "\n";    
                $type = 0;
	}
};
