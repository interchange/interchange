# Copyright 2002 Interchange Development Group (http://www.icdevgroup.org/)
# Licensed under the GNU GPL v2. See file LICENSE for details.
# $Id: fortune.tag,v 1.5 2005-02-10 14:38:39 docelic Exp $

UserTag fortune Order   short
UserTag fortune addAttr
UserTag fortune Version $Revision: 1.5 $
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
