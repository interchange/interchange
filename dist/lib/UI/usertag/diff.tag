UserTag diff Order current previous
UserTag diff attrAlias curr current prev previous
UserTag diff addAttr
UserTag diff Routine <<EOR
sub {
    my ($curr, $prev, $opt) = @_;

	$opt->{flags} .= ' -c' if $opt->{context};
	$opt->{flags} .= ' -u' if $opt->{unified};

    unless($opt->{flags} =~ /^[-\s\w.]*$/) {
        Log("diff tag: Security violation with flags: $opt->{flags}");
        return "Security violation with flags: $opt->{flags}. Logged.";
    }

    my $currfn;
    my $prevfn;
    my $codere = '[-\w#/.]+';
    my $coderex = '[-\w:#=/.%]+';
    if($curr =~ /^(\w+)::(.*?)::(.*)/) {
        my $table = $1;
        my $col = $2;
        my $key = $3;
        $currfn = "tmp/$Vend::SessionName.current";
		my $data = tag_data($table, $col, $key);
		$data =~ s/\r\n?/\n/g if $opt->{ascii};
        Vend::Util::writefile(">$currfn", $data);
    }
    else {
        $currfn = $curr;
    }
    if($prev =~ /^(\w+)::(.*?)::(.*)/) {
        my $table = $1;
        my $col = $2;
        my $key = $3;
        $prevfn = "tmp/$Vend::SessionName.previous";
		my $data = tag_data($table, $col, $key);
		$data =~ s/\r\n?/\n/g if $opt->{ascii};
        Vend::Util::writefile(">$prevfn", $data);
    }
    else {
        $prevfn = $prev;
    }
#Debug("diff command: 'diff $opt->{flags} $prevfn $currfn'");
    return `diff $opt->{flags} $prevfn $currfn`;
}
EOR
