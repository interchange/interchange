use Cwd;
use Config;
use Errno;

$cur_dir = cwd();
$failed = 0;

if($^O =~ /cygwin|win32/) {
	print "no tests supported on Windows platform.\n";
	exit;
}

die "Must be in build directory\n" unless -d 'blib';
die "No tests defined for Windows\n" if $^O =~ /win32/i;

$ENV{MINIVEND_ROOT} = "$cur_dir/blib";
$ENV{MINIVEND_PORT} = 8786 unless defined $ENV{MINIVEND_PORT};

open(CONFIG, ">$ENV{MINIVEND_ROOT}/interchange.cfg")
	or die "open: $!\n";

print CONFIG <<EOF;
Catalog  test $ENV{MINIVEND_ROOT} /test
TcpMap $ENV{MINIVEND_PORT} -
TagDir 0
TagDir etc
EOF

open(CONFIG, ">$ENV{MINIVEND_ROOT}/catalog.cfg")
	or die "open: $!\n";

print CONFIG <<'EOF';
MailOrderTo  info@icdevgroup.org
VendURL      http:/test
SecureURL    http:/test
Database     products products.asc DEFAULT
EOF

mkdir ("$ENV{MINIVEND_ROOT}/etc", 0777);
mkdir ("$ENV{MINIVEND_ROOT}/pages", 0777);
mkdir ("$ENV{MINIVEND_ROOT}/products", 0777);
mkdir ("$ENV{MINIVEND_ROOT}/session", 0777);
if( $ENV{PERL5LIB} ) {
	$ENV{PERL5LIB} .= ":$cur_dir/extra:$cur_dir/blib/lib";
}
else {
	$ENV{PERL5LIB} = "$cur_dir/extra:$cur_dir/blib/lib";
}

my $testnum = 1;

open(CONFIG, ">$ENV{MINIVEND_ROOT}/products/products.asc")
	or die "open: $!\n";

print CONFIG <<EOF;
sku	description	price
test	test product	1
EOF

open(CONFIG, ">$ENV{MINIVEND_ROOT}/pages/catalog.html")
	or die "open: $!\n";

for(1 .. 100) {
	print CONFIG <<EOF;
test succeeded test succeeded
EOF
}

close CONFIG;

$| = 1;

print "server/unixmode.......";
if ( system qq{$Config{'perlpath'} blib/script/interchange -q -r -u} ) {
	print "not ok $testnum\n";
	$failed++;
}
else {
	print "ok $testnum\n";
}
$testnum++;

print "server/startup........";
for(1 .. 5) {
	open(PID, "$ENV{MINIVEND_ROOT}/etc/interchange.pid") or sleep $_, next;
	$pid = <PID>;
	$pid =~ s/\D+//g;
	last;
}

for(1 .. 5) {
	unless (-e "$ENV{MINIVEND_ROOT}/etc/socket") {
		system "ls -l $ENV{MINIVEND_ROOT}/*";
		sleep $_;
		next;
	}
	$LINK_FILE = "$ENV{MINIVEND_ROOT}/etc/socket";
	last;
}

if(! $pid or ! $LINK_FILE) {
	print "not ok $testnum\n";
	$failed++;
}
else {
	print "ok $testnum\n";
}
$testnum++;

use Socket;
my $LINK_HOST    = '127.0.0.1';
my $LINK_PORT    = $ENV{MINIVEND_PORT};
my $LINK_TIMEOUT = 15;
my $ERROR_ACTION = "-none";

$ENV{SCRIPT_NAME} = "/test";
$ENV{PATH_INFO} = "/catalog";
$ENV{REMOTE_ADDR} = "TEST";
$ENV{REQUEST_METHOD} = "GET";

sub send_arguments {

	my $count = @ARGV;
	my $val = "arg $count\n";
	for(@ARGV) {
		$val .= length($_);
		$val .= " $_\n";
	}
	return $val;
}

sub send_environment () {
	my (@tmp) = keys %ENV;
	my $count = @tmp;
	my ($str);
	my $val = "env $count\n";
	for(@tmp) {
		$str = "$_=$ENV{$_}";
		$val .= length($str);
		$val .= " $str\n";
	}
	return $val;
}

$SIG{PIPE} = sub { die("signal"); };
$SIG{ALRM} = sub { die("not communicating with server\n"); exit 1; };



print "link/unixmode.........";
eval {
	socket(SOCK, PF_UNIX, SOCK_STREAM, 0)	or die "socket: $!\n";

	my $ok;
	do {
	   $ok = connect(SOCK, sockaddr_un($LINK_FILE));
	} while ( ! defined $ok and $!{EINTR} || $!{ENOENT});

	my $undef = ! defined $ok;
	die "ok=$ok def: $undef connect: $!\n" if ! $ok;

	select SOCK;
	$| = 1;
	select STDOUT;

	print SOCK send_arguments();
	print SOCK send_environment();
	print SOCK "end\n";


	while(<SOCK>) {
		$result .= $_;
	}

	close (SOCK)								or die "close: $!\n";

};

if(length($result) > 500 and $result =~ /test succeeded/i) {
	print "ok $testnum\n";
}
else {
	print "not ok $testnum";
	print " ($@)" if $@;
	print "\n";
	print <<EOF;

# When the above test fails, it may be due to your ISP or some other
# mechanism blocking port 8786.

EOF
	$failed++;
}
$testnum++;

print "server/inetmode.......";
if ( system qq{$Config{'perlpath'} blib/script/interchange -q -r -i} ) {
	print "not ok $testnum\n";
	$failed++;
}
else {
	print "ok $testnum\n";
}
$testnum++;

alarm 0;
alarm $LINK_TIMEOUT;

$result = '';

print "link/inetmode.........";
eval {
	$remote = $LINK_HOST;
	$port   = $LINK_PORT;

	if ($port =~ /\D/) { $port = getservbyname($port, 'tcp'); }

	die("no port") unless $port;

	$iaddr = inet_aton($remote);
	$paddr = sockaddr_in($port,$iaddr);

	$proto = getprotobyname('tcp');

	socket(SOCK, PF_INET, SOCK_STREAM, $proto)	or die "socket: $!\n";

	my $ok;

	do {
	   $ok = connect(SOCK, $paddr);
	} while ( ! defined $ok and $!{EINTR});

	my $undef = ! defined $ok;
	die "ok=$ok def: $undef connect: $!\n" if ! $ok;

	select SOCK;
	$| = 1;
	select STDOUT;

	print SOCK send_arguments();
	print SOCK send_environment();
	print SOCK "end\n";


	while(<SOCK>) {
		$result .= $_;
	}

	close (SOCK)								or die "close: $!\n";

};

alarm 0;

if(length($result) > 500 and $result =~ /test succeeded/i) {
	print "ok $testnum\n";
}
else {
	print "not ok $testnum\n";
	$failed++;
}
$testnum++;

print "server/control........";
if ( system qq{$Config{'perlpath'} blib/script/interchange -q -stop} ) {
	print "not ok $testnum\n";
	$failed++;
}

my $pid_there;

for(1 .. 5) {
	$pid_there = -f 'blib/etc/interchange.pid';
	last unless $pid_there;
	sleep 1;
}

if ($pid_there) {
	print "not ok $testnum\n";
	$failed++;
}
else {
	print "ok $testnum\n";
}
$testnum++;


$testnum--;
print "$testnum tests run";
if($failed) {
	print " -- $failed/$testnum failed.\n";
	exit 1;
}
else {
	print ", all tests successful.\n";
	exit 0;
}

END {
	kill 'KILL', $pid if $pid;
}
