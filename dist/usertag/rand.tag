UserTag rand Order file
UserTag rand posNumber 1
UserTag rand addAttr
UserTag rand hasEndTag
UserTag rand Routine <<EOR
sub {
	my ($file, $opt, $inline) = @_;
	my $sep = $opt->{separator} || '\[alt\]';
	$inline = ::readfile($file)
		if $file;
	my @pieces = split /$sep/, $inline;
	return $pieces[int(rand(scalar @pieces))] ;
}
EOR
