UserTag available_ups_internal Routine <<EOR
sub {
	my (@files) = glob('products/[0-9][0-9][0-9].csv');
	return '' unless @files;
	my $out = '';
	for(@files) {
		s:/(\d+)::
			or next;
		$out .= "$1\t$1\n";
	}
	return $out;
}
EOR
