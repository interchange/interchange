#
# Interchange UserTag env - see documentation for more information
#
# Copyright 2001 by Ed LaFrance <edl@newmediaems.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free
# Software Foundation, Inc., 59 Temple Place, Suite 330, Boston,
# MA  02111-1307  USA.
#
#
# SUMMARY:	Provides read only access to the http evironment
#		variables; individually by name, or the full
#		list.
#
# USEAGE:	to see a the full list as a table:
#		[env]
#
#		to return one the value of one variable:
#		[env VARNAME]
#		[env arg="VARNAME"]
#
# NOTES:	Works when configured in either catalog.cfg
#		or interchange.cfg. Thanks to Mike Heins and 
#		the programming team at RH/Akopia for the
#		numerous examples in the demos and UI - I
#		don't think I could come up with stuff like
#		this without it.

Usertag env Order arg
Usertag env PosNumber 1
Usertag env Routine <<EOR
sub {
	my $arg = shift;
	my $env = ::http()->{env};
	my $out;
	if (! $arg) {
		$out = "<table cellpadding=2 cellspacing=1 border=1>\n";
		foreach ((keys %$env)) {
			$out .= "<tr><td><b>$_\&nbsp;<\/b><\/td><td>";
			$out .= "$env->{$_}\&nbsp;<\/td>\n<\/tr><tr>\n";
		}
		$out .= "<\/table>\n";
	}
	else {
		$out = $env->{$arg};
	}
	return $out;
}
EOR
