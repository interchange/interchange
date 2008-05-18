# Copyright 2004-2007 Interchange Development Group and others
# Copyright 2001 Ed LaFrance <edl@newmediaems.com>
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.
# 
# $Id: env.tag,v 1.11 2007-03-30 23:40:57 pajamian Exp $

Usertag env Order      arg
Usertag env PosNumber  1
UserTag env attrAlias  name arg
UserTag env Version    $Revision: 1.11 $
Usertag env Routine    <<EOR
sub {
	my $arg = shift;
	my $env = ::http()->{env};
	my $out;
	if (! $arg) {
		$out = "<table cellpadding='2' cellspacing='1' border='1'>\n";
		foreach ((keys %$env)) {
			$out .= "<tr><td><b>$_</b></td><td>";
			$out .= "$env->{$_}</td>\n</tr><tr>\n";
		}
		$out .= "</table>\n";
	}
	else {
		$out = $env->{$arg};
	}
	return $out;
}
EOR
