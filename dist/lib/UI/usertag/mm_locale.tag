UserTag mm_locale Routine <<EOR
sub {
	my $locale = $Values->{ui_locale} || $Tag->var('UI_LOCALE', 2);

	# first delete locale settings from catalog
	$Vend::Cfg->{Locale_repository} = {};

	if ($locale && exists $Global::Locale_repository->{$locale}) {
		$Vend::Cfg->{Locale_repository}{"$locale"} 
			= $Global::Locale_repository->{$locale};
		$Tag->setlocale("$locale");
		$Tag->tmp({name => 'mv_locale'}, $locale);
	}	
	1;
}
EOR