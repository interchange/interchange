From root@new.minivend.com  Mon Apr 16 00:47:49 2001
Received: from localhost (localhost [127.0.0.1])
	by bill.minivend.com (8.9.3/8.9.3) with ESMTP id AAA01987
	for <mike@localhost>; Mon, 16 Apr 2001 00:47:49 -0400
Received: from new [199.6.32.160]
	by localhost with POP3 (fetchmail-5.7.6)
	for mike@localhost (single-drop); Mon, 16 Apr 2001 00:47:49 -0400 (EDT)
Received: (from root@localhost)
	by mail.minivend.com (8.9.3/8.9.3) id AAA05900
	for mike@mail.minivend.com; Mon, 16 Apr 2001 00:47:26 -0400
Resent-Message-Id: <200104160447.AAA05900@mail.minivend.com>
Date: Fri, 6 Apr 2001 15:23:53 -0400
From: root <root@internetrobotics.com>
To: greg@valuemedia.com
Subject: get_quicken_orders
Message-ID: <20010406152353.A21800@mail.minivend.com>
Reply-To: nobody@internetrobotics.com
Mime-Version: 1.0
Content-Type: text/plain; charset=us-ascii
X-Mailer: Mutt 0.95.4us
Resent-From: root@mail.minivend.com
Resent-Date: Mon, 16 Apr 2001 00:47:26 -0400
Resent-To: Mike Heins <mike@mail.minivend.com>
X-Filter: mailagent [version 3.0 PL65] for mike@bill.minivend.com
Status: RO
Content-Length: 1259
Lines: 48

UserTag get_quicken_orders Order begin end
UserTag get_quicken_orders addAttr 
UserTag get_quicken_orders Routine <<EOR
sub {
	my ($begin, $end, $opt) = @_;
	my $die_err = sub {
		my $msg = ::errmsg(@_);
		::logError($msg);
		return undef unless $opt->{show_error};
		return $msg;
	};
	my $dir = $::Variable->{QUICKEN_ORDER_DIR} || 'orders';
	my @files = glob("$dir/qb*.iif");
	my @t = localtime();
	my @out;
	my $currdate = POSIX::strftime( '%Y%m%d', @t );
	my $date = POSIX::strftime( '%Y%m%d%H%M%S', @t );
	local($/);
	for(@files) {
		my $fn = $_;
		my $ofn = $fn;
		open(QF, "+<$fn")
			or return $die_err->("open quicken file %s: %s", $_, $!);
		Vend::Util::lockfile(\*QF, 1, 1)
			or return $die_err->("lock quicken file %s: %s", $_, $!);
		my $bu = $fn;
		$bu =~ s:.*/qb::;
		$bu =~ s/\.iif$//;
Log("gqo -- bu=$bu currdate=$currdate fn=$fn ofn=$ofn date=$date");
		if($bu eq $currdate) {
			$fn = "$dir/qb$date.iif";
			rename $ofn, $fn;
		}
		my $check = "$fn.got";
		next if $begin and $begin > $bu;
		next if $end and $end < $bu;
		if (! $begin and ! $end) {
			next if -f $check;
		}
		push @out, <QF>;
		close QF;
		open(QC, ">$check")
			or return $die_err->("create check file %s: %s", $check, $_);
		close QC;
	}
	return join "\n", @out;
}
EOR

