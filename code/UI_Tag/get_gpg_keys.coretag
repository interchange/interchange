UserTag get-gpg-keys Order dir
UserTag get-gpg-keys addAttr
UserTag get-gpg-keys Routine <<EOR
sub {
	my ($dir, $opt) = @_;
	my $gpgexe = $Global::Variable->{GPG_PATH} || 'gpg';

	my $flags = "--list-keys";
	if($dir) {
		$dir = filter_value('filesafe', $dir);
		$flags .= "--homedir $dir";
	}
#::logDebug("gpg_get_keys flags=$flags");
	
	open(GPGIMP, "$gpgexe $flags |") 
		or die "Can't fork: $!";

	my $fmt = $opt->{long} ?  "%s=%s (date %s, id %s)" : "%s=%s";

	my @out;
	while(<GPGIMP>) {
		next unless s/^pub\s+//;
		my ($id, $date, $text) = split /\s+/, $_, 3;
		$id =~ s:.*?/::;
		$text = ::errmsg( $fmt, $id, $text, $date, $id );
		$text =~ s/</&lt;/g;
		$text =~ s/>/&gt;/g;
		$text =~ s/,/&#44;/g;
		push @out, $text;
	}
	close GPGIMP;
	my $joiner = $opt->{joiner} || ",\n";
	unshift @out, "=none" if $opt->{none};
	return join($joiner, @out);
}
EOR
