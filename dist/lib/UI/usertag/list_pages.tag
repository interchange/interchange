UserTag list_pages Order options
UserTag list_pages addAttr
UserTag list_pages Routine <<EOR
sub {
	my ($return_options, $opt) = @_;
	my $out;
	my @pages = UI::Primitive::list_pages($opt->{keep},$opt->{ext},$opt->{base});
	if($return_options) {
		$out = "<OPTION> " . (join "<OPTION> ", @pages);
	}
	elsif ($opt->{arrayref}) {
		return \@pages;
	}
	else {
		$out = join " ", @pages;
	}
}
EOR

