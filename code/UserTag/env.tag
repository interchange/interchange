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

Usertag env Order arg
Usertag env PosNumber 1
UserTag env attrAlias name arg
Usertag env Routine <<EOR
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
