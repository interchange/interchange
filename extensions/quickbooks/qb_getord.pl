#!/usr/bin/perl

my $SERVER  = 'http://10.10.10.21';
my $CGICALL = '/cgi-bin/YOURCAT/admin/quickbooks/get_orders';

### These need to be a valid IC UI username/password with
### the "orders" permission.
my $USER    = 'USERNAME';
my $PASS    = 'something';

### Where the output files should go....
my $LOCDIR  = 'c:\Program Files\Intuit\QuickBooks Pro';
my $DEC_CMD  = 'gpg --passphrase-fd 0 --batch -d';

unless($^O =~ /win/i) {
	$LOCDIR  = '.';
	$DEC_CMD  = 'gpg --passphrase-fd 0 --batch -d';
}

my $begin = shift;

use LWP::UserAgent;

my $entity = "mv_username=$USER";
$entity .= "&mv_password=$PASS";
$entity .= "&begin=$begin" if $begin;

my $content_length = length $entity;

my $ua = new LWP::UserAgent;

my $base_url = "$SERVER$CGICALL";
my $req = new HTTP::Request ('POST', $base_url);

$req->content($entity);

my $response = $ua->request($req);

my $code = $response->code();
if ($code != 200) {
	die "Error code $code. Returned: \n" . $response->as_string() . "\n";
}

my $data = $response->content();

use POSIX;
use File::Spec;
my $date = POSIX::strftime("%Y%m%d%H%M%S", localtime());

my $dest = File::Spec->catfile($LOCDIR, "qb$date.iif");

my $origdata = $data;

sub gpg_decode {
	my($data) = @_;
	#warn "entering GPG decode, data = $data\n";

	open(FIN, ">tmp.gpg")
		or die "open tmp.gpg: $!\n";
	print FIN $data;
	close FIN;

	open(CMD, "| $DEC_CMD tmp.gpg >tmp.out")
		or die "Can't do command (fork): $!\n";
	print CMD "$ENV{PGPPASS}\n";
	close CMD;
	if($?) {
		die "Error from gpg: $!\n";
	}

	open(FOUT, "<tmp.out")
		or die "read tmp.out: $!\n";
	my $out = join "", <FOUT>;
	close FOUT;

	open(FOUT, ">tmp.out")
		or die "read tmp.out: $!\n";
	print FOUT join("", 1 .. 100);
	close FOUT;

	#warn "out=$out\n";

	unlink 'tmp.out', 'tmp.gpg';

	$out =~ s/^.*\D(\d{12}\d+).*$/$1/s;
	$out =~ s/\D+//g;
	#warn "GPG decode: '$out'\n";
	return $out;
}


if($data =~ /---\s*BEGIN\s+(GPG|PGP)\s+MESSAGE/) {
	if(! $ENV{PGPPASS}) {
		print "Enter PGP pass phrase: ";
		my $phrase = <>;
		chomp $phrase;
		$ENV{PGPPASS} = $phrase;
	};
	$data =~ s/(---+\s*BEGIN\s+(GPG|PGP)\s+MESSAGE.*?--\s*END\s+\w+\s+MESSAGE\s*-+\n)/gpg_decode($1)/egs;
}
open(OUT, ">>$dest")
	or die "open $dest: $!\n";

print OUT $data;
close OUT and print "OK\n";
