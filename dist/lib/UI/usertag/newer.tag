UserTag newer Order source target
UserTag newer Routine <<EOR
sub {
	my ($source, $file2) = @_;
	my $file1 = $source;
	if(! $file2 and $source !~ /\./) {
		if($Global::GDBM) {
			$file1 .= '.gdbm';
		}
		elsif($Global::DB_File) {
			$file1 .= '.db';
		}
		else {
			return undef;
		}
		$file2 = $Vend::Cfg->{Database}{$source}{'file'}
			or return undef;
		$file1 = $Vend::Cfg->{ProductDir} . '/' . $file1
			unless $file1 =~ m:/:;
		$file2 = $Vend::Cfg->{ProductDir} . '/' . $file2
			unless $file2 =~ m:/:;
	}
	my $time1 = (stat($file1))[9]
		or return undef;
	my $time2 = (stat($file2))[9];
	return 1 if $time1 > $time2;
	return 0;
}
EOR

