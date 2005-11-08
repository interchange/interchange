# Vend::Document - Document object for Interchange embedded Perl/ASP
# 
# $Id: Document.pm,v 2.3 2005-11-08 18:14:45 jon Exp $
#
# Copyright (C) 2002-2005 Interchange Development Group
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
# Software Foundation, Inc., 59 Temple Place, Suite 330, Boston,
# MA  02111-1307  USA.

package Vend::Document;

use strict;
use vars qw/@Out/;

my $Hot;

sub new { return bless {}, shift }

sub hot {
	shift;
	$Hot = shift;
}

sub send {
	shift;
	::response(join "", @_);
}

sub header {
	return undef if $Vend::ResponseMade;
	shift;
	my ($text, $opt) = @_;
	$Vend::StatusLine = '' if ref $opt and $opt->{replace};
	$Vend::StatusLine = '' if !defined $Vend::StatusLine;
	$Vend::StatusLine .= shift;
}

sub insert {
	shift;
	unshift(@Out, @_);
	return;
}

sub ref {
	return \@Out;
}

sub review {
	shift;
	my $idx;
	if( defined ($idx = shift) ) {
		return $Out[$idx];
	}
	else {
		return @Out;
	}
}

sub replace {
	shift;
	@Out = @_;
	return;
}

#sub HTML (@) {
sub HTML {
	push @Out, @_;
	return if ! $Hot;
	Vend::Document::send( undef, join("", splice(@Out, 0)) );
}

sub write {
	shift;
	HTML(@_);
}

1;
