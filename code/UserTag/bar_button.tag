UserTag bar-button Order page current
UserTag bar-button PosNumber 2
UserTag bar-button HasEndTag 1
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

