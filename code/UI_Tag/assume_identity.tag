UserTag assume-identity   Order        file locale
UserTag assume-identity   addAttr
UserTag assume-identity   PosNumber    2
UserTag assume-identity   Routine      <<EOR
sub {
	my ($file, $locale, $opt) = @_;
	my $pn;
	if($opt and $opt->{name}) {
		$pn = $opt->{name};
	}
	else {
		$pn = $file;
		$pn =~ s/\.\w+$//;
		$pn =~ s:^pages/::;
	}
	$Global::Variable->{MV_PAGE} = $pn;
	$locale = 1 unless defined $locale;
	return Vend::Interpolate::interpolate_html(
		Vend::Util::readfile($file, undef, $locale)
	);
}
EOR
