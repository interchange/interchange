
UserTag list_pages order options ext keep base
UserTag list_pages PosNumber 4 
UserTag list_pages Routine <<EOR
sub {
	my ($return_options, $ext, $keep, $base) = @_;
	my $out;
	if($return_options) {
		$out = "<OPTION> " . (join "<OPTION> ", UI::Primitive::list_pages($keep,$ext,$base));
	} else {
		$out = join " ", UI::Primitive::list_pages($keep,$ext, $base);
	}
}
EOR

