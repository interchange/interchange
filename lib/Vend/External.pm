# Vend::External - Interchange routines for calling external programs
# 
# $Id: External.pm,v 1.2.4.1 2003-01-25 22:21:27 racke Exp $
#
# Copyright (C) 1996-2002 Red Hat, Inc. <interchange@redhat.com>
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

package Vend::External;

use strict;
use Vend::Util;

sub check_html {
	my($out) = @_;

	unless($Global::CheckHTML) {
		logError("Can't check HTML: No global CheckHTML defined. Contact admin.", '');
	}

	my $file = POSIX::tmpnam();
	open(CHECK, "|$Global::CheckHTML > $file 2>&1")	or die "Couldn't fork: $!\n";
	print CHECK $$out;
	close CHECK;
	my $begin = "<!-- HTML Check via '$Global::CheckHTML'\n";
	my $end   = "\n-->";
	my $check = readfile($file);
	unlink $file					or die "Couldn't unlink temp file $file: $!\n";
	$$out .= $begin . $check . $end;
	return;
}

1;
