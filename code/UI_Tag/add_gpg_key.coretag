UserTag add-gpg-key Order name
UserTag add-gpg-key addAttr
UserTag add-gpg-key Routine <<EOR
sub {
	my ($name, $opt) = @_;
	my $gpgexe = $Global::Variable->{GPG_PATH} || 'gpg';

	my $outfile = "$Vend::Cfg->{ScratchDir}/$Vend::Session->{id}.gpg_results";

	my $flags = "--import --batch 2> $outfile";
#::logDebug("gpg_add flags=$flags");
	
	my $keytext = $opt->{text} || $CGI::values{$name};
	$keytext =~ s/^\s+//;
	$keytext =~ s/\s+$//;
	open(GPGIMP, "| $gpgexe $flags") 
		or die "Can't fork: $!";
	print GPGIMP $keytext;
	close GPGIMP;

	if($?) {
		$::Scratch->{ui_failure} = ::errmsg("Failed GPG key import.");
		return defined $opt->{failure} ? $opt->{failure} : undef;
	}
	else {
		my $keylist = `$gpgexe --list-keys`;
		$::Scratch->{ui_message} =
							::errmsg(
								"GPG key imported successfully.<PRE>\n%s\n</PRE>",
								$keylist,
								);
	}

	if($opt->{return_id}) {
		open(GETGPGID, "< $outfile")
			or do {
				::logGlobal("GPG key ID read -- can't read %s: %s", $outfile, $!);
				return undef;
			};
		my $id;
		while(<GETGPGID>) {
			next unless /\bkey (\w+): public key imported/;
			$id = $1;
			last;
		}
		close GETGPGID;
		return $id || 'Failed ID get?';
		
	}
	elsif (defined $opt->{success}) {
		return $opt->{success};
	}
	else {
		return 1;
	}
}
EOR
