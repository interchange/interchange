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
#Log("gqo -- bu=$bu currdate=$currdate fn=$fn ofn=$ofn date=$date");
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

