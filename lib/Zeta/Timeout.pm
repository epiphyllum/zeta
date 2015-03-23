package Zeta::Timeout;
use strict;
use warnings;
use base qw/Exporter/;

our @EXPORT = qw/ztimeout/;

#
# ztimeout(
#    \&connect, 
#    [$dsn, $user, $pass, $opts], 
#    15, 
#    $logger, 
#    '连接数据库15秒超时'
# );
#
sub ztimeout {
    my ($func, $args, $timeout, $logger, $msg) = @_;

    my $rtn;
    eval {
        local $SIG{ALRM} = sub { die $msg; };
        alarm($timeout);
        $rtn = &$func(@$args);
        alarm(0); #所需的程序已经运行完成，取消超时处理
    };
    if ($@) {
        if ($@ =~ /$msg/) {
            $logger->debug($msg);
        }
        else {
            $logger->debug($@);
        }
        return;
    }
    return $rtn;
}


1;

__END__

use Zeta::Timeout;

ztimeout(
    sub {
       return \@_;
    },
    [ 1, 2 ],
    10,
    $logger,
    "10秒超时"
);

