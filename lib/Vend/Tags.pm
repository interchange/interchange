# Vend::Tags - Interpret Interchange tags for Safe
# 
# $Id: Tags.pm,v 2.4 2007-08-09 13:40:54 pajamian Exp $
#
# Copyright (C) 2002-2007 Interchange Development Group
# Copyright (C) 1996-2002 Red Hat, Inc.
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
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA  02110-1301  USA.

package Vend::Tags;

require AutoLoader;

use vars qw($AUTOLOAD @ISA);

sub new {
	return bless {}, shift;
}

sub DESTROY {
	1;
}

sub AUTOLOAD {
	shift;
	my $routine = $AUTOLOAD;
	$routine =~ s/.*:://;
	if(ref($_[0]) =~ /HASH/) {
		@_ = Vend::Parse::resolve_args($routine, @_);
	}
	return Vend::Parse::do_tag($routine, @_);
}

1;

__END__
