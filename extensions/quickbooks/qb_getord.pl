From johnkay@edge.net  Fri Dec 29 17:55:04 2000
Received: from localhost (localhost [127.0.0.1])
	by bill.minivend.com (8.9.3/8.9.3) with ESMTP id RAA29260
	for <mike@localhost>; Fri, 29 Dec 2000 17:55:04 -0500
Received: from mv
	by localhost with POP3 (fetchmail-5.1.0)
	for mike@localhost (single-drop); Fri, 29 Dec 2000 17:55:04 -0500 (EST)
Received: from mail.edge.net (mail.edge.net [199.0.68.4])
	by mail.minivend.com (8.9.3/8.9.3) with ESMTP id RAA28479
	for <mike@minivend.com>; Fri, 29 Dec 2000 17:54:54 -0500
Received: from Compaq400 ([208.21.81.203]) by mail.edge.net
          (Post.Office MTA v3.1.2 release (PO203-101c)
          ID# 0-58127U5600L300S0V35) with SMTP id AAA28044
          for <mike@minivend.com>; Fri, 29 Dec 2000 16:52:18 -0600
Message-Id: <3.0.32.20001229164023.0080abe0@mail.edge.net>
X-Sender: johnkay@mail.edge.net (Unverified)
X-Mailer: Windows Eudora Pro Version 3.0 (32)
Date: Fri, 29 Dec 2000 16:40:25 -0600
To: mike@minivend.com
From: Michael Wilk <mwilk@steppenwolf.com>
Subject: Qb script
Mime-Version: 1.0
Content-Type: multipart/mixed; boundary="=====================_978151225==_"
X-Filter: mailagent [version 3.0 PL65] for mike@bill.minivend.com
Status: RO
Content-Length: 2404
Lines: 113

--=====================_978151225==_
Content-Type: text/plain; charset="us-ascii"

Mike...Here's the QB script.
--=====================_978151225==_
Content-Type: text/plain; charset="us-ascii"
Content-Disposition: attachment; filename="qb_getord.pl"

#!/usr/bin/perl

my $SERVER  = 'http://10.10.10.21';
my $CGICALL = '/cgi-bin/wolf/admin/quickbooks/get_orders';
my $USER    = 'mwilk';
my $PASS    = 'moog';
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




--=====================_978151225==_--

