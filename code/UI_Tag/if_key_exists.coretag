UserTag if-key-exists  Routine <<EOR
sub {
		my($table,$key,$text) = @_;
		$text =~ s:\[else\](.*)\[/else\]::si;
		my $else = $1 || '';
		my $db = $Vend::Database{$table} || do { logError "Bad database $table"; return $else; };
		$db = $db->ref() unless $Vend::Interpolate::Db{$table};
		my $status;
		eval {
			$status = $db->record_exists($key);
		};
		return $else if $@;
		return $else unless $status;
		return $text;
}
EOR
UserTag if-key-exists Order table key
UserTag if-key-exists hasEndTag

