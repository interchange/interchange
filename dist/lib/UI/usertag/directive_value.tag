
UserTag directive_value order name unparse
UserTag directive_value PosNumber 2
UserTag directive_value Routine <<EOR
sub {
	my($name,$unparse) = @_;
	my ($value, $parsed) = UI::Primitive::read_directive($name);
	if($unparse) {
		$parsed =~ s/\@\@([A-Z]\w+?)\@\@/$Global::Variable->{$1}/g;
		$parsed =~ s/__([A-Z]\w+?)__/$Vend::Cfg->{Variable}{$1}/g;
	}
	return ($parsed || $value);
}
EOR

