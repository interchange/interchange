UserTag diff Order current previous
UserTag diff attrAlias curr current prev previous
UserTag diff addAttr
UserTag diff Routine <<EOR
sub {
    my ($curr, $prev, $opt) = @_;

	$opt->{flags} .= ' -c' if $opt->{context};
	$opt->{flags} .= ' -u' if $opt->{unified};

	my $data_opt = {};
	$data_opt->{safe_data} = 1 if $opt->{safe_data};

    unless($opt->{flags} =~ /^[-\s\w.]*$/) {
        Log("diff tag: Security violation with flags: $opt->{flags}");
        return "Security violation with flags: $opt->{flags}. Logged.";
    }

    my ($currfn, $prevfn);

    if($curr =~ /^(\w+)::(.*?)::(.*)/) {
        my ($table, $col, $key) = ($1, $2, $3);
        $currfn = "tmp/$Vend::SessionName.current";
		my $data = tag_data($table, $col, $key, $data_opt);
		if ($opt->{ascii}) {
			$data =~ s/\r\n?/\n/g;
			$data .= "\n" unless substr($data, -1, 1) eq "\n";
		}
        Vend::Util::writefile(">$currfn", $data);
    }
    else {
        $currfn = $curr;
    }

    if($prev =~ /^(\w+)::(.*?)::(.*)/) {
        my ($table, $col, $key) = ($1, $2, $3);
        $prevfn = "tmp/$Vend::SessionName.previous";
		my $data = tag_data($table, $col, $key, $data_opt);
		if ($opt->{ascii}) {
			$data =~ s/\r\n?/\n/g;
			$data .= "\n" unless substr($data, -1, 1) eq "\n";
		}
        Vend::Util::writefile(">$prevfn", $data);
    }
    else {
        $prevfn = $prev;
    }

#Debug("diff command: 'diff $opt->{flags} $prevfn $currfn'");
    return `diff $opt->{flags} $prevfn $currfn`;
}
EOR
