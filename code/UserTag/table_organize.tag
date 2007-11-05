# Copyright 2002-2007 Interchange Development Group and others
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.
# 
# $Id: table_organize.tag,v 1.11 2007-11-05 20:15:27 docelic Exp $

UserTag table-organize Order         cols
UserTag table-organize attrAlias     columns cols
UserTag table-organize Interpolate
UserTag table-organize addAttr
UserTag table-organize hasEndTag
UserTag table-organize Version       $Revision: 1.11 $
UserTag table-organize Routine <<EOR
sub {
	my ($cols, $opt, $body) = @_;
	$cols = int($cols) || 2;
	$body =~ s/(.*?)(<td)\b/$2/is
		or return;
	my $out = $1;
	$body =~ s:(</td>)(?!.*</td>)(.*):$1:is;
	my $postamble = $2;

	my @cells;
	if($opt->{cells} and ref($opt->{cells}) eq 'ARRAY') {
		@cells = @{$opt->{cells}};
	}
	elsif($opt->{embed}) {
		if($opt->{embed} eq 'lc') {
			push @cells, $1 while $body =~ s:(<td\b.*?</td>)::s;
		}
		else {
			push @cells, $1 while $body =~ s:(<TD\b.*?</TD>)::s;
		}
	}
	else {
		push @cells, $1 while $body =~ s:(<td\b.*?</td>)::is;
	}

	while ($opt->{min_rows} and ($opt->{min_rows} * ($cols - 1)) > scalar(@cells) ) {
		$cols--;
		last if $cols == 1;
	}

	if(int($opt->{limit}) and $opt->{limit} < scalar(@cells) ) {
		splice(@cells, $opt->{limit});
	}

	for(qw/ table/) {
		$opt->{$_} = defined $opt->{$_} ? " $opt->{$_}" : '';
	}

	my @td;

	if(! $opt->{td}) {
		@td = '' x $cols;
	}
	elsif (ref $opt->{td} ) {
		@td = @{$opt->{td}};
		push @td, '' while scalar(@td) < $cols;
	}
	else {
		@td = (" $opt->{td}") x $cols;
	}

	my %attr;
	for(qw/caption tr pre post/) {
		if( ! $opt->{$_} ) {
			#do nothing
		}
		elsif (ref $opt->{$_}) {
			$attr{$_} = $opt->{$_};
		}
		else {
			$attr{$_} = [$opt->{$_}];
		}
	}

	my $pretty = $opt->{pretty};

	#$opt->{td} =~ s/^(\S)/ $1/;
	#$opt->{tr} =~ s/^(\S)/ $1/;

	my @rest;
	my $rows;

	my $rmod;
	my $tmod = 0;
	my $total_mod;

	$opt->{filler} = '&nbsp;' if ! defined $opt->{filler};

	my $td_beg;
	my $td_end;
	if($opt->{font}) {
		$td_beg = qq{<FONT $opt->{font}>};
		$td_end = qq{</FONT>};
	}

	if($rows = int($opt->{rows}) ) {
		$total_mod = $rows * $cols;
		@rest = splice(@cells, $total_mod)
			if $total_mod < @cells;
		$opt->{table} = ' ' if ! $opt->{table};
	}

	my $joiner = $opt->{joiner} || ($pretty ? "\n\t\t" : "");
	while(@cells) {
		if ($opt->{columnize}) {
			my $cell_count = scalar @cells;
			my $row_count_ceil = POSIX::ceil($cell_count / $cols);
			my $row_count_floor = int($cell_count / $cols);
			my $remainder = $cell_count % $cols;
			my @tmp = splice(@cells, 0);
			my $index;
			for (my $r = 0; $r < $row_count_ceil; $r++) {
				for (my $c = 0; $c < $cols; $c++) {
					if ($c >= $remainder + 1) {
						$index = $r + $row_count_floor * $c + $remainder;
					}
					else {
						$index = $r + $row_count_ceil * $c;
					}
					push @cells, $tmp[$index];
					last if $r + 1 == $row_count_ceil and $c + 1 == $remainder;
				}
			}
		}

		while (scalar(@cells) % $cols) {
			push @cells, "<td>$opt->{filler}</td>";
		}

		#$out .= "<!-- starting table tmod=$tmod -->";
		if($opt->{table}) {
			$out .= "<table$opt->{table}>";
			$out .= "\n" if $pretty;
			if($opt->{caption}) {
				my $idx = $tmod % scalar(@{$attr{caption}});
				#$out .= "<!-- caption index $idx -->";
				$out .= "\n" if $pretty;
				$out .= "<caption>" . $attr{caption}[$idx] . "</caption>";
				$out .= "\n" if $pretty;
			}
		}
		$rmod = 0;
		while(@cells) {
			$out .= "\t" if $pretty;
			$out .= "<tr";
			if($opt->{tr}) {
				my $idx = $rmod % scalar(@{$attr{tr}});
				$out .= " " . $attr{tr}[$idx];
			}
			$out .= ">";
			$out .= "\n\t\t" if $pretty;
			my @op =  splice (@cells, 0, $cols);
			if($opt->{td}) {
				for ( my $i = 0; $i < $cols; $i++) {
					$op[$i] =~ s/(<td)/$1 $td[$i]/i;
				}
			}
			@op = map { s/>/>$td_beg/; $_ }			 @op	if $td_beg;
			@op = map { s/(<[^<]+)$/$td_end$1/; $_ } @op	if $td_end;

			$out .= join($joiner, @op);
			$out .= "\n\t" if $pretty;
			$out .= "</tr>";
			$out .= "\n" if $pretty;
			$rmod++;
		}
		if($opt->{table}) {
			$out .= "</table>";
			$out .= "\n" if $pretty;
		}
		if(@rest) {
			my $num = $total_mod < scalar(@rest) ? $total_mod : scalar(@rest);
			@cells = splice(@rest, 0, $num);
		}
		$tmod++;
	}
	return $out . $postamble;
}
EOR
