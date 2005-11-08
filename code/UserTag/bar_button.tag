# Copyright 2003-2005 Interchange Development Group (http://www.icdevgroup.org/)
# Licensed under the GNU GPL v2. See file LICENSE for details.
# $Id: bar_button.tag,v 1.4 2005-11-08 18:14:42 jon Exp $

UserTag bar-button Order     page current
UserTag bar-button PosNumber 2
UserTag bar-button HasEndTag 1
UserTag bar-button Version   $Revision: 1.4 $
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
