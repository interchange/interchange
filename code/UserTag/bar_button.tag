# Copyright 2003-2007 Interchange Development Group and others
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.
# 
# $Id: bar_button.tag,v 1.5 2007-03-30 23:40:56 pajamian Exp $

UserTag bar-button Order     page current
UserTag bar-button PosNumber 2
UserTag bar-button HasEndTag 1
UserTag bar-button Version   $Revision: 1.5 $
UserTag bar-button Routine   <<EOR
sub {
	use strict;
	my ($page, $current, $html) = @_;
	$current = $Global::Variable->{MV_PAGE}
		if ! $current;
	$html =~ s:\[selected\]([\000-\377]*)\[/selected]::i;
	my $alt = $1;
	return $html if $page ne $current;
	return $alt;
}
EOR
