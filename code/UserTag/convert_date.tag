UserTag convert-date Order adjust
UserTag convert-date PosNumber 1
UserTag convert-date addAttr
UserTag convert-date AttrAlias fmt format
UserTag convert-date AttrAlias days adjust
UserTag convert-date HasEndTag
UserTag convert-date Interpolate
UserTag convert-date Routine <<EOR
sub {
    my ($adjust, $opt, $text) = @_;
    my @t;
    my $now;

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
					$now = time();
					@t = localtime($now) unless $adjust;
	}

	if ($adjust) {
		$now ||= POSIX::mktime(@t);
		$adjust .= ' days' if $adjust =~ /^[-\s\d]+$/;

		if ($adjust =~ s/^\s*-\s*//) {
			@t = localtime($now - Vend::Config::time_to_seconds($adjust));
		}
		else {
			@t = localtime($now + Vend::Config::time_to_seconds($adjust));
		}
	}

	if (defined $opt->{raw} and Vend::Util::is_yes($opt->{raw})) {
					$fmt = $t[2] && $text ?  '%Y%m%d%H%M' : '%Y%m%d';
	}

	if (! $fmt) {
		if ($t[1] || $t[2]) {
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

