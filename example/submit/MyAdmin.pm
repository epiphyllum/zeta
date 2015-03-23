package MyAdmin;

use Zeta::Run;
use Data::Dump;

sub new {
   bless {}, shift;
}

sub child {
    my ($para) = @_;
    sleep 10; 
    warn time, ": I got " . Data::Dump->dump($para);
    exit 0;
}

#
# $req =  {
#     action => 'run',
#     param  => {
#         name => 'xxxx',
#     },
# }
#
sub handle {
    my ($self, $req) = @_;

    my $name = $req->{param}{name};
    zkernel->process_submit(
        $name, 
        {
            code => \&child,
            para => [ $name ],
            reap => 0,
            size => 1,
        }, 
    );

    return {  status => 0, result => [ 1, 2, 3, 4] };
}

1;

__END__

test:
{"action":"run","param":{"name":"Zhary"}}
echo '{"action":"run","param":{"name":"Zhary"}}' | POST 'http://localhost:8888/'





