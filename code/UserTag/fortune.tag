UserTag fortune Order short
UserTag fortune addAttr
UserTag fortune Documentation <<EOF

=pod

This tag uses the fortune(1) command to display a random saying.

Options:

    short=yes|no*       Select only short (< 1
		60 chars) fortunes
    no-computer=yes|no* No computer fortunes.
    a=1                 Select from all fortunes, even potentially offensive ones.
    o=1                 Select only from potentially offensive fortunes.
    raw=1               Don't do any HTML formatting

Example:

	[fortune short=yes]

=cut

EOF

UserTag fortune Routine <<EOR
sub {
	my ($short, $opt) = @_;
	my $cmd = $Global::Variable->{MV_FORTUNE_COMMAND} || '/usr/games/fortune';
	my @flags;
	push @flags, '-s' if is_yes($short);
	for(grep length($_) == 1, keys %$opt) {
		push @flags, "-$_" if $opt->{$_};
	}

	if(is_yes($opt->{no_computer}) ) {
     	push @flags, qw/
			6% education 
			6% food 
			6% humorists 
			6% kids 
			6% law 
			6% literature 
			6% love 
			6% medicine 
			6% people 
			6% pets 
			6% platitudes 
			6% politics 
			6% science 
			6% sports 
			6% work
			10% wisdom
		/;
	}

	my $out = '';
	open(FORT, '-|') || exec ($cmd, @flags);

	while (<FORT>) {
		$out .= $_
	}
	
	unless($opt->{raw}) {
		$out = filter_value('text2html', $out);
		$out =~ s/--(?!:.*--)/<br>--/s;
	}
	return $out;
}
EOR
