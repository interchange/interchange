UserTag table-organize Order cols
UserTag table-organize attrAlias columns cols
UserTag table-organize Interpolate
UserTag table-organize addAttr
UserTag table-organize hasEndTag
UserTag table-organize Documentation <<EOD

=head1 table-organize

	[table-organize <options>]
		[loop ....] <td> [loop-tags] </td> [/loop]
	[/table-organize]

Takes an unorganized set of table cells and organizes them into
rows based on the number of columns; it will also break them into
separate tables.

If the number of cells are not on an even modulus of the number of columns,
then "filler" cells are pushed on.

Parameters:

=over 4

=item cols (or columns)

Number of columns. This argument defaults to 2 if not present.

=item rows

Optional number of rows. Implies "table" parameter.

=item table

If present, will cause a surrounding <TABLE > </TABLE> pair with the attributes
specified in this option.

=item caption

Table <CAPTION> container text, if any. Can be an array.

=item td

Attributes for table cells. Can be an array.

=item tr

Attributes for table rows. Can be an array.

=item columnize

Will display cells in (newspaper) column order, i.e. rotated.

=item pretty

Adds newline and tab characters to provide some reasonable indenting.

=item filler

Contents to place in empty cells put on as filler. Defaults to C<&nbsp;>.

=item min_rows

On small result sets, can be ugly to build more than necessary columns.
This will guarantee a minimum number of rows -- columns will change
as numbers change. Formula: $num_cells % $opt->{min_rows}.

=item limit

Maximum number of cells to use. Truncates extra cells silently.

=item embed

If you want to embed other tables inside, make sure they are called with
lower case <td> elements, then set the embed tag and make the cells you wish
to organize be <TD> elements. To switch that sense, and make the upper-case
or mixed case be the ignored cells, set the embed parameter to C<lc>.

    [table-organize embed=lc]
		<td>
			<TABLE>
				<TR>
				<TD> something 
				</TD>
				</TR>
			</table>
		</td>
    [/table-organize

or

    [table-organize embed=uc]
		<TD>
			<table>
				<tr>
				<td> something 
				</td>
				</tr>
			</table>
		</TD>
	[/table-organize]

=back

The C<tr>, C<td>, and C<caption> attributes can be specified with indexes;
if they are, then they will alternate according to the modulus.

The C<td> option array size should probably always equal the number of columns;
if it is bigger, then trailing elements are ignored. If it is smaller, no attribute
is used.

For example, to produce a table that 1) alternates rows with background
colors C<#EEEEEE> and C<#FFFFFF>, and 2) aligns the columns RIGHT CENTER
LEFT, do:

        [table-organize
            cols=3
            pretty=1
            tr.0='bgcolor="#EEEEEE"'
            tr.1='bgcolor="#FFFFFF"'
            td.0='align=right'
            td.1='align=center'
            td.2='align=left'
            ]
            [loop list="1 2 3 1a 2a 3a 1b"] <td> [loop-code] </td> [/loop]
        [/table-organize]

which will produce:

        <tr bgcolor="#EEEEEE">
                <td align=right>1</td>
                <td align=center>2</td>
                <td align=left>3</td>
        </tr>
        <tr bgcolor="#FFFFFF">
                <td align=right>1a</td>
                <td align=center>2a</td>
                <td align=left>3a</td>
        </tr>
        <tr bgcolor="#EEEEEE">
                <td align=right>1b</td>
                <td align=center>&nbsp;</td>
                <td align=left>&nbsp;</td>
        </tr>

If the attribute columnize=1 is present, the result will look like:

        <tr bgcolor="#EEEEEE">
                <td align=right>1</td>
                <td align=center>1a</td>
                <td align=left>1b</td>
        </tr>
        <tr bgcolor="#FFFFFF">
                <td align=right>2</td>
                <td align=center>2a</td>
                <td align=left>&nbsp;</td>
        </tr>
        <tr bgcolor="#EEEEEE">
                <td align=right>3</td>
                <td align=center>3a</td>
                <td align=left>&nbsp;</td>
        </tr>

See the source for more ideas on how to extend this tag.

=cut

EOD
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
				$out .= "<CAPTION>" . $attr{caption}[$idx] . "</CAPTION>";
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

