UserTag if-sql  Routine  <<EOR
sub {
		my($table,$text) = @_;
		$text =~ s:\[else\](.*)\[/else\]::si;
		my $else = $1 || '';
		my $db = $Vend::Cfg->{Database}{$table} || return $else;
		return $else unless $db->{'type'} eq '8';
		return $text;
}
EOR
UserTag if-sql Order table
UserTag if-sql hasEndTag

