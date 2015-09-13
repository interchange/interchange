UserTag div-organize Order         cols
UserTag div-organize attrAlias     columns cols
UserTag div-organize Interpolate
UserTag div-organize addAttr
UserTag div-organize hasEndTag
UserTag div-organize Documentation <<EOD

=head1 div-organize

	[div-organize <options>]
		[loop ....] <div> [loop-tags] </div> [/loop]
	[/div-organize]

Takes an unorganized set of div cells and organizes them into
rows based on the number of columns; it will also break them into
separate divs.
All of this assumes using bootstrap 3 and higher classes of: "row" for rows, 
and "col-xx-6" for two col for example, "col-xx-4" for 3 column combined with
option of cols=3.

If the number of cells are not on an even modulus of the number of columns,
then "filler" cells are pushed on.

Parameters:

=over 4

=item cols (or columns)

Number of columns. This argument defaults to 2 if not present.

=item rows

Optional number of rows. Implies "table" parameter.

=item table

If present, will cause a surrounding <div> </div> pair with the attributes
specified in this option. ie for bootstrap you might use table="class='container'"

=item caption

Table <CAPTION> container text, if any. Can be an array.

=item div

Attributes for div table cells. Can be an array. ie could be col-md-6 if using 2 col

=item row_attr

Attributes for div table rows. Can be an array. typically would be class="row"

=item columnize

Will display cells in (newspaper) column order, i.e. rotated.

=item pretty

Adds newline and tab characters to provide some reasonable indenting.

=item filler

Contents to place in empty cells put on as filler. Defaults to C<&nbsp;>.

=item filler_class

Class to place in empty cells put on as filler. Defaults to C<filler_class>.
With bootstrap you may want this to be the same as target divs to keep columns straight ie 
col-md-6 for 2 col display

=item min_rows

On small result sets, can be ugly to build more than necessary columns.
This will guarantee a minimum number of rows -- columns will change
as numbers change. Formula: $num_cells % $opt->{min_rows}.

=item limit

Maximum number of cells to use. Truncates extra cells silently.

=item embed

If you want to embed other divs inside, make sure they are called with
lower case <div> elements, then set the embed tag and make the cells you wish
to organize be <DIV> elements. To switch that sense, and make the upper-case
or mixed case be the ignored cells, set the embed parameter to C<lc>.

    [div-organize embed=lc]
		<div>
			<TABLE>
				<TR>
				<TD> something 
					<DIV> something </DIV>
				</TD>
				</TR>
			</table>
		</div>
    [/div-organize]

or

    [div-organize embed=uc]
		<DIV>
			<div>
				something
			</div>
		</DIV>
	[/div-organize]

=back

Need to experiment with this stuff, for div only.
Also note, we should update current table organize with Bootstrap
class considerations

The C<row_attr>, C<td>, and C<caption> attributes can be specified with indexes;
if they are, then they will alternate according to the modulus.

The C<td> option array size should probably always equal the number of columns;
if it is bigger, then trailing elements are ignored. If it is smaller, no attribute
is used.

For example, to produce a table that 1) alternates rows with background
colors C<#EEEEEE> and C<#FFFFFF>, and 2) aligns the columns RIGHT CENTER
LEFT, do:

        [div-organize
            cols=3
            pretty=1
			filler_class='col-md-4'
            ]
            [loop list="1 2 3 1a 2a 3a 1b"] <div class="col-md-4"> [loop-code] </div> [/loop]
        [/div-organize]

which will produce:

        <div class="row">
                <div class="col-md-4">1</div>
                <div class="col-md-4">2</div>
                <div class="col-md-4">3</div>
        </div>
        <div class="row">
                <div class="col-md-4">1a</div>
                <div class="col-md-4">2a</div>
                <div class="col-md-4">3a</div>
        </div>
        <div class="row">
                <div class="col-md-4">1b</div>
                <div class="col-md-4">&nbsp;</div>
                <div class="col-md-4">&nbsp;</div>
        </div>

If the attribute columnize=1 is present, the result will look like:

        <div class="row">
                <div class="col-md-4">1</div>
                <div class="col-md-4">1a</div>
                <div class="col-md-4">1b</div>
        </div>
        <div class="row">
                <div class="col-md-4">2</div>
                <div class="col-md-4">2a</div>
                <div class="col-md-4">&nbsp;</div>
        </div>
        <div class="row">
                <div class="col-md-4">3</div>
                <div class="col-md-4">3a</div>
                <div class="col-md-4">&nbsp;</div>
        </div>

See the source for more ideas on how to extend this tag.

=cut

EOD
UserTag div-organize Routine <<EOR
sub {
	my ($cols, $opt, $body) = @_;
	$cols = int($cols) || 2;
	$body =~ s/(.*?)(<div)\b/$2/is
		or return;
	my $out = $1;
	$body =~ s:(</div>)(?!.*</div>)(.*):$1:is;
	my $postamble = $2;

	my @cells;
	if($opt->{cells} and ref($opt->{cells}) eq 'ARRAY') {
		@cells = @{$opt->{cells}};
	}
	elsif($opt->{embed}) {
		if($opt->{embed} eq 'lc') {
			push @cells, $1 while $body =~ s:(<div\b.*?</div>)::s;
		}
		else {
			push @cells, $1 while $body =~ s:(<DIV\b.*?</DIV>)::s;
		}
	}
	else {
		push @cells, $1 while $body =~ s:(<div\b.*?</div>)::is;
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

##Left off here
	my @div;

	if(! $opt->{div}) {
		@div = '' x $cols;
	}
	elsif (ref $opt->{div} ) {
		@div = @{$opt->{div}};
		push @div, '' while scalar(@div) < $cols;
	}
	else {
		@div = (" $opt->{div}") x $cols;
	}

##Have not touched

	my %attr;
	for(qw/caption row_attr pre post/) {
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
##Have not touched

	my $pretty = $opt->{pretty};

	my @rest;
	my $rows;

	my $rmod;
	my $tmod = 0;
	my $total_mod;

	$opt->{filler} = '&nbsp;' if ! defined $opt->{filler};

	my $td_beg;
	my $td_end;

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

		my $fclass = $opt->{filler_class} || 'filler_class';
		while (scalar(@cells) % $cols) {
			push @cells, qq|<div class="$fclass">$opt->{filler}</div>|;
		}

		#$out .= "<!-- starting table tmod=$tmod -->";
		if($opt->{table}) {
			$out .= "<div$opt->{table}>";
			$out .= "\n" if $pretty;
		}
		$rmod = 0;
		while(@cells) {
			$out .= "\t" if $pretty;
			$out .= qq{<div};
			if($opt->{row_attr}) {
				my $idx = $rmod % scalar(@{$attr{row_attr}});
				$out .= " " . $attr{row_attr}[$idx];
			}
			else {
				$out .= ' class="row"';
			}
			$out .= ">";
			$out .= "\n\t\t" if $pretty;
			my @op =  splice (@cells, 0, $cols);
			if($opt->{div}) {
				for ( my $i = 0; $i < $cols; $i++) {
					$op[$i] =~ s/(<div)/$1 $div[$i]/i;
				}
			}
			@op = map { s/>/>$td_beg/; $_ }			 @op	if $td_beg;
			@op = map { s/(<[^<]+)$/$td_end$1/; $_ } @op	if $td_end;

			$out .= join($joiner, @op);
			$out .= "\n\t" if $pretty;
			$out .= "</div>";
			$out .= "\n" if $pretty;
			$rmod++;
		}
		if($opt->{table}) {
			$out .= "</div>";
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
