UserTag convert-date Order days
UserTag convert-date PosNumber 1
UserTag convert-date addAttr
UserTag convert-date AttrAlias fmt format
UserTag convert-date HasEndTag
UserTag convert-date Interpolate
UserTag convert-date Routine <<EOR
sub {
    my ($days, $opt, $text) = @_;
    my @t;

	if(! ref $opt) {
		my $raw = $opt ? 1 : 0;
		$opt = {};
		$opt->{raw} = 1 if $raw;
	}

	my $fmt = $opt->{format} || '';
	if($text =~ /^(\d\d\d\d)-(\d?\d)-(\d?\d)$/) {
		$t[5] = $1 - 1900;
		$t[4] = $2 - 1;
		$t[3] = $3;
	} 
	elsif($text =~ /\d/) {
					$text =~ s/\D//g;
					$text =~ /(\d\d\d\d)(\d\d)(\d\d)(?:(\d\d)(\d\d))?/;
					$t[2] = $4 || undef;
					$t[1] = $5 || undef;
					$t[3] = $3;
					$t[4] = $2 - 1;
					$t[5] = $1;
					$t[5] -= 1900;
	}
	else {
					my $now = time();
					if ($days) {
									$now += $days * 86400;
					}
					@t = localtime($now);
	}

	if (defined $opt->{raw} and Vend::Util::is_yes($opt->{raw})) {
					$fmt = $t[2] && $text ?  '%Y%m%d%H%M' : '%Y%m%d';
	}

	if (! $fmt) {
		if ($t[2]) {
			$fmt = '%d-%b-%Y %I:%M%p';
		} else {
			$fmt = '%d-%b-%Y';
		}
	}

	my ($current, $out);
	my $locale = $opt->{locale} || $Scratch->{mv_locale};
	if ($locale) {
		$current = POSIX::setlocale(&POSIX::LC_TIME);
		POSIX::setlocale(&POSIX::LC_TIME, $locale);
		$out = POSIX::strftime($fmt, @t);
		POSIX::setlocale(&POSIX::LC_TIME, $current);
	} else {
		$out = POSIX::strftime($fmt, @t);
	}
	$out =~ s/\b0(\d)\b/$1/g if $opt->{zerofix};
	return $out;
}
EOR

