# Copyright 2002-2007 Interchange Development Group and others
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.
# 
# $Id: fortune.tag,v 1.7 2007-03-30 23:40:57 pajamian Exp $

UserTag fortune Order   short
UserTag fortune addAttr
UserTag fortune Version $Revision: 1.7 $
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
