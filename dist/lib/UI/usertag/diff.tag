UserTag diff Order current previous
UserTag diff attrAlias curr current prev previous
UserTag diff addAttr
UserTag diff Routine <<EOR
sub {
    my ($curr, $prev, $opt) = @_;
    if($opt->{context}) {
        $opt->{flags} = ' -c';
    }
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
        Vend::Util::writefile(">$currfn", tag_data($table, $col, $key));
    }
    else {
        $currfn = $curr;
    }
    if($prev =~ /^(\w+)::(.*?)::(.*)/) {
        my $table = $1;
        my $col = $2;
        my $key = $3;
        $prevfn = "tmp/$Vend::SessionName.previous";
        Vend::Util::writefile(">$prevfn", tag_data($table, $col, $key));
    }
    else {
        $prevfn = $prev;
    }
    return `diff $opt->{flags} $prevfn $currfn`;
}
EOR
