
UserTag check-upload Order file same
UserTag check-upload PosNumber 2
UserTag check-upload Routine <<EOR
sub {
	use File::Copy;
	my $file = shift;
	my $same = shift;
	my $dir = $Vend::Cfg->{ProductDir};
	$same = $same ? '' : '+';
	if (-s "upload/$file") {
		File::Copy::copy "upload/$file", "$dir/$file$same"
			or return "Couldn't copy uploaded file!";
		unlink "upload/$file";
	}
	return '';
}
EOR

