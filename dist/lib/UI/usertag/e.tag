UserTag e HasEndTag
UserTag e Routine <<EOR
sub {
	my $text = shift;
	HTML::Entities::encode($text);
}
EOR

