UserTag output-to Order name
UserTag output-to addAttr
UserTag output-to hasEndTag
UserTag output-to Routine <<EOR
sub {
	my ($name, $opt, $body) = @_;
	$name ||= '';
	$name = lc $name;
	my $nary = $Vend::OutPtr{$name} ||= [];
	push @Vend::Output, \$body;
	push @$nary, $#Vend::Output;
	return;
}
EOR
