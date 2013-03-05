# Copyright 2002-2007 Interchange Development Group and others
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.
# 
# $Id: convert_date.tag,v 1.9 2009-05-01 13:50:00 pajamian Exp $

UserTag convert-date Order       adjust
UserTag convert-date PosNumber   1
UserTag convert-date addAttr
UserTag convert-date AttrAlias   fmt format
UserTag convert-date AttrAlias   days adjust
UserTag convert-date HasEndTag
UserTag convert-date Interpolate
UserTag convert-date Version     $Revision: 1.9 $
UserTag convert-date Routine     <<EOR
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
	elsif (exists $opt->{empty}) {
		return $opt->{empty};
	}
	else {
					$now = time();
					@t = localtime($now) unless $adjust;
	}

	if ($adjust) {
		if ($#t < 8) {
			$t[8] = -1;
		}
		$now ||= POSIX::mktime(@t);
		$adjust .= ' days' if $adjust =~ /^[-\s\d]+$/;
		@t = localtime(adjust_time($adjust, $now, $opt->{compensate_dst}));
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
        if (($::Variable->{MV_UTF8} || $Global::Variable->{MV_UTF8})
            && $locale !~ /\.utf-?8$/i) {
            POSIX::setlocale(&POSIX::LC_TIME, "$locale.utf8");
        }
        else {
            POSIX::setlocale(&POSIX::LC_TIME, $locale);
        }
		$out = POSIX::strftime($fmt, @t);
		POSIX::setlocale(&POSIX::LC_TIME, $current);
	} else {
		$out = POSIX::strftime($fmt, @t);
	}
	$out =~ s/\b0(\d)\b/$1/g if $opt->{zerofix};
	return $out;
}
EOR
