# Copyright 2003 Interchange Development Group (http://www.icdevgroup.org/)
# Licensed under the GNU GPL v2. See file LICENSE for details.
# $Id: bar_button.tag,v 1.3 2005-02-10 14:38:39 docelic Exp $

UserTag bar-button Order     page current
UserTag bar-button PosNumber 2
UserTag bar-button HasEndTag 1
UserTag bar-button Version   $Revision: 1.3 $
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
