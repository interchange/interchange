UserTag report-table addAttr
UserTag report-table Documentation <<EOD

By Chris Wenham of Synesmedia, Inc. - www.synesmedia.com
This software is distributed under the terms of the GNU Public License.
Version 1.2, November 20, 2003.

Generate an HTML table based on the results of a query, with bells and
whistles. Can do horizontal (colspan) and vertical (rowspan) subheaders,
apply any Interchange filter or widget to any column, add a CSS class to
any column, link cell contents (and add parameters to the link based on
any column in the query results), add virtual columns based on internal
variables (such as the line number), and skip rows based on an array of
toggles you specify.
Good for making quick tables, sophisticated reports, and easy forms.

Synopsis and minimum syntax

	<table>
	[report-table
		query="SELECT * FROM addresses"
		columns="address city state zip"
	]
	</table>

Or something fancier:

	<form action="[process]">
	<table>
	[report-table
		query="SELECT * FROM addresses"
		columns="state city address sales"
		column_defs="{
			state => {
				header => 'vert',
			},

			city => {
				header => 'vert',
			}

			zip => {
				title  => "Zip code:",
				header => 'horiz',
			}

			address => {
				width  => '40%',
				widget => 'text',
				widget_cols => '20'
			}

			sales => {
				prefix => '$',
			}
		}"
	]
	<tr>
	  <td colspan="4" align="right">
	    <input type="hidden" name="rows" value="[scratch report_table_linecount]"/>
	    <input type="submit" value="Save addresses"/>
	  </td>
	</tr>
	</table>
	</form>

This last example could give you something like this:

 +-------------------------------------------------------+
 | state | city      | address                | sales    |
 |-------+-----------+-----------------------------------|
 |  NY   | Levittown |          Zip code: 11756          |
 |       |           |-----------------------------------|
 |       |           | [123 Return Lane_____] | $240.12  |
 |       |           | [321 Raspberry Lane__] | $43.52   |
 |       |-----------+-----------------------------------|
 |       | Bellmore  |          Zip code: 11710          |
 |       |           |-----------------------------------|
 |       |           | [23 Merrick Road_____] | $354.06  |
 |       |           | [43 Bellmore Ave_____] | $11.34   |
 |-------+-----------+-----------------------------------|
 |  PA   | Anytown   |          Zip code: 23456          |
 |       |           |-----------------------------------|
 |       |           | [63 Some Street______] | $771.35  |
 |-------------------------------------------------------|
 |                                    [ Save addresses ] |
 +-------------------------------------------------------+


The columns to include in the report are passed in the "columns"
tag parameter.

Column definitions are defined in a perl hash of hash references.
The tag will display only the columns you specify, and in that order.
Pagination is not supported, but you can easily construct the logic for
that outside of the report-table tag, and then use OFFSET and LIMIT in
the query.

Vertical headers (state and city in this example) are always sorted
to the left of the table, but they can be nested to any level. The tag
does not support vertical headers within the scope of a horizontal
header.

Horizontal headers can also be nested to any level. You might want to
pass a "class" value in the column definition so you can style them
later and make it easier to tell them apart.
NOTE: Columns used for horizontal headers should *not* be included in
the "columns" parameter of the report-table tag. Defining them in
column_defs is sufficient.

Advanced column definitions

The following parameters are supported for the column definitions.

	title => 'Column Header'
	The tag will default to the database column name, but you
	can override it with a title. All titles are put in <th>
	tags at the top of each column, or in the case of
	horizontal subheaders they're put just before the value
	(eg: "Zip code: 11756" from above)

	header => 'vert'
	Indicates that this column is a header, and whether it's
	vertical ('vert') or horizontal ('horiz').
	Headers are generated every time the value in that column
	changes between rows. Let's say that the following are
	the rows returned by the query:

	NY,Levittown,11756,123 Return Lane
	NY,Levittown,11756,321 Raspberry Lane
	NY,Bellmore,11710,23 Merrick Road

	If city was a header, then it would spit out "Levittown"
	first, then two rows later spit out "Bellmore".

	NOTE: To make headers work properly, you must sort by those
	columns in your query, or you may get redundant headers.

	prefix => '$', postfix => '%'
	Something to insert just before and after the value. Will
	appear after the title in a horizontal header, and outside any
	widget or link.

	filter => 'digits_dot'
	Any Interchange filter. Will be applied to the cell value
	before it's put into any link or widget.

	widget => 'date'
	Any Interchange form widget. The widget will be passed the
	contents of the cell as the default value. The name of the
	form widget will be the column name plus the line number.
	Eg: "address_1", "address_2", and so-on.
	You can pass any addtional parameter supported by the [widget]
	tag (such as rows and cols) by prefixing them with "widget_".
	EG: "widget_cols => '30'".

	Any column can be a widget, even vertical and horizontal
	headers.

	class => 'currency'
	Will give you <td class="currency"> for each cell in that
	column.

	align => 'right', valign => 'top'
	Sets the alignment of each cell in the column. Vertical headers
	are valign="top" by default, but this can override.

	width => '50%'
	Set the column width.

	link      => 'show_customer'
	link_parm => 'id'
	link_key  => 'cust_id'
	Link a cell's contents using Interchange's [page] tag, and
	optionally passing a parameter based on any column in the
	query results. So let's say "cust_id" is a column returned in
	the database query, but not actually displayed in the result.
	The cells in your customer column could be linked to the
	"show_customer" page, passing the value of "cust_id" in a
	parameter named "id". Like this:
	http://www.store.com/cgi-bin/catalog/show_customer?id=523

	NOTE: You can't use a link and a widget at the same time. If you
	set the 'link' parameter, any widget in the same column def will
	be ignored.

	empty => '&nbsp;'
	What to use instead if the cell is empty for that row. For
	tables with borders set, you might want to use a nonbreaking
	space (&nbsp;), or 0.00 for currency columns, or whatever.
	NOTE: The tag can't tell the difference between an empty cell
	and a NULL cell.

	dynamic => 'linecount'
	Indicates a column that does not draw its data from the query
	results, but from an internal value. Most of these aren't
	terribly useful, but 'linecount' is good for adding line numbers.
	Dynamic values can be used with links, widgets and filters, but
	they can't be used as subheaders. Available dynamic values are:

		realrow
		The absolute current row from the query results. Is not
		affected by the row_toggle parameter (described later).
		Begins at zero.

		rowcount
		The current row, including any used by horizontal
		subheaders.
		Begins at zero.

		linecount
		The current data line. Does not include lines used by
		horizontal subheaders.
		Begins at 1.

		parity
		1 if we're on an odd numbered line, 0 if we're on an
		even numbered line.

Other parameters

	row_toggle="1,1,1,1,1,1,0,1,1,0,1"
	This is a comma separated list of toggles ('1' or '0') that
	can be used to make the report skip individual rows in the
	results. The number of toggles must either equal the number
	of results from the query, or the remainder will be skipped.
	Eg: passing row_toggle="1,1,0,1,1,1" and a query that returns
	six rows will give you a five-row report, where the third
	row from the results had been skipped. If the query returns
	more than six rows, then the remainder will be skipped.

	(Ideally, what you should probably do is just modify your
	query so it doesn't return those rows anyway, but this feature
	was added for a special application.)

	row_hidden_id="address_id"
	The name of a column in the query results to use in a
	type="hidden" form element. This is for forms that need to pass
	the database key's value for each row, and is added just before
	the first data cell, like this:

	<tr><input type="hidden" name="id_1" value="523"/><td...

	The number appended after "id_" in the name is the linecount,
	and will match the number appended to the name of any other
	widgets on the same row.

	title_horiz="0"
	If you want the value of horizontal subheaders to stand on
	their own (without a title), then set title_horiz="0".
	Otherwise the tag will use the database name or title of
	the column.

	reset_horiz="0"
	By default, the scope of a horizontal header does not cross
	the scope of a vertical header. It looks confusing and
	doesn't follow the typical way subheaders are used. So when
	a vertical header goes out of scope, it resets all the
	horizontal headers so they begin anew with the next row.
	Example: Some zip codes cross city boundaries, so the
	"Levittown" vertical header could end, but the next address
	might still be in the "11756" zip code. By default, the
	report table will simply run the "Zip code: 11756" header
	again before the next row.
	If you don't want it to do this, meaning you want the scope of
	horizontal headers to cross the scope of vertical headers,
	then pass reset_horiz="0".

	display_colheaders="0"
	When set to zero, don't bother to display the column headers.

	no_results="<tr><td>Woah dude, nothing to see!</td></tr>"
	Override the default message when there are no results from
	the query.


HTML output

Outputs XHMTL compliant markup*.

This tag will not generate the <table> tags in the final HTML because
it's trivial to add those yourself, and it was designed to be used in
cases where the table might not be "finished" even when the report-table
tag was (such as when you're using it to create a form).

The column headers row will be written with <tr class="headers">.

Every odd-numbered row will be written with <tr class="odd">.

The total number of columns it will use will always be the same as what
you pass in the "columns" parameter*. Even when the query returns no
results, it will still return one complete row with an apropriate
colspan (unless overridden by the no_results parameter).

* Except if you use a widget that doesn't output XHTML.

** Except if you were naughty and listed a column that is later defined
as a horizontal header, then it will get stripped out. You shouldn't list
horizontal headers in the colums="" parameter. Simply defining them in
column_defs is sufficient.


Side-effects

The following temporary scratch variables are set prior to tag completion.

	[scratch report_table_rowcount]
	The total number of rows created by the tag. This includes rows
	used up by horizontal subheaders, and the column header row.

	[scratch report_table_linecount]
	Total number of data rows returned by the tag, NOT including rows
	used by horizontal subheaders or the column headers. Useful if
	you're using widgets and your mv_nextpage needs to know how many
	values there are.

	[scratch report_table_colspan]
	Total number of columns it used.


Tips and Tricks

To get a blank column:

	columns="city state zip x customer"
	column_defs="{
		x => {
			title      => '&nbsp;',
			empty_cell => '&nbsp;'
		}
	}"


EOD
UserTag report-table Routine <<EOR
sub prep_cell {
	my ($def,$datum,$linecount,$record) = @_;

	#Debug("prep_cell datum: $datum");

	my $cell;
	if ($def->{filter}) {
		$datum = $Tag->filter({ op => $def->{filter}, }, $datum);
	}

	if ($def->{link}) {
		my $page_parms = { href => $def->{link}, };
		if ($def->{link_parm}) {
		  $page_parms->{form} = $def->{link_parm} .'='. $record->{$def->{link_key}};
		}
		$cell = $Tag->page($page_parms);
		$cell .= $datum;
		$cell .= '</a>';
	} elsif ($def->{widget}) {
		if ($def->{widget} =~ /^checkonly$/) {
			# This was a quick hack to support standalone checkboxes
			# for "delete/edit checked rows" type forms.
			my $checked = '';
			if ($datum) {
				$checked = ' CHECKED';
			}
			$cell = '<input type="checkbox" name="'. $def->{colname} .'_'. $linecount ."\" value=\"1\"$checked/>";
		} else {
			my $widget_name = $def->{colname} .'_'. $linecount;
			# We need to bludgeon Interchange over the head with the proper value
			# becuase set,default,value, and passed are ignored when there's an
			# existing value.
			$::Values->{$widget_name} = $datum;
			$cell = $Tag->widget($widget_name, {
				type       => $def->{widget},
				set        => $datum,
				attribute  => $def->{widget_attribute},
				db         => $def->{widget_db},
				field      => $def->{widget_field},
				extra      => $def->{widget_extra},
				cols       => $def->{widget_cols},
				rows       => $def->{widget_rows},
				delimiter  => $def->{widget_delimiter},
				key        => $def->{widget_key},
				year_begin => $def->{widget_year_begin},
				year_end   => $def->{widget_year_end},
				filter     => $def->{widget_filter},
				set        => $def->{widget_set},
				});
		}
	} else {
		$cell = $datum;
	}

	$cell = $def->{prefix} . $cell . $def->{postfix};

	#Debug("prep_cell returning: $cell");

	return $cell;
}

sub cell_open_tag {
	my ($def,$rowspan,$colspan) = @_;

	my @tag_parms;
	push @tag_parms, "colspan=\"$colspan\"" if $colspan;
	push @tag_parms, "rowspan=\"$rowspan\"" if $rowspan;
	push @tag_parms, "class=\"$def->{class}\"" if $def->{class};
	push @tag_parms, "width=\"$def->{width}\"" if $def->{width};
	push @tag_parms, "valign=\"$def->{valign}\"" if $def->{valign};
	push @tag_parms, "align=\"$def->{align}\"" if $def->{align};

	my $type = $def->{header} ? 'th' : 'td';

	if (@tag_parms) {
		return "<$type ". join( ' ', @tag_parms) .'>';
	}

	return '<td>';
}

sub {
	#Debug("Entering report-table");
	# Options gathering ------------------------------------------
	my $opt = shift;

	my @columns           = split ' ', $opt->{columns};
	my @row_toggle        = split ',', $opt->{row_toggle};

	if ($opt->{reset_horiz} eq '') {
		$opt->{reset_horiz} = 1;
	}

	if ($opt->{title_horiz} eq '') {
		$opt->{title_horiz} = 1;
	}

	if ($opt->{colheaders} eq '') {
		$opt->{colheaders} = 1;
	}

	#Debug("Gathered options. Query is: ". $opt->{query});

	# Data structure preparation ---------------------------------
	my @vertheads = ();
	my @subheader_cols = ();

	my (%cols,$column_defs);
	if ($opt->{column_defs}) {
		$column_defs = eval( $opt->{column_defs} );
		%cols = %{$column_defs};
	} else {
		foreach my $col (@columns) {
			$cols{$col}->{title} = $col;
		}
	}

	my @tcols;
	my $headpos = 0;
	foreach my $col (@columns) {
		if ($cols{$col}->{header}) {
			# Horizontal headers should never be in the 'columns' list
			if ($cols{$col}->{header} eq 'vert') {
				$cols{$col}->{pos} = $headpos;
				$headpos++;
				push @subheader_cols, $col;
				push @vertheads, $col;
				$cols{$col}->{valign} ||= 'top';
			}
		} else {
			push @tcols, $col;
		}
	}
	foreach my $col (keys(%cols)) {
		$cols{$col}->{colname} = $col;
		$cols{$col}->{title} ||= $col;
		if ($cols{$col}->{header} =~ /horiz/) {
			push @subheader_cols, $col;
		}
	}
	@columns = @tcols;
	# ----------------------------------------------------------##

	my $output;
	my $db = ::database_exists_ref('products');
	my $results = $db->query({ sql => $opt->{query}, hashref => 'results' });

	# Output column headers --------------------------------------
	if (($results) and (@{$results}) and ($opt->{colheaders})) {
		$output .= '<tr class="headers">';

		foreach my $c (@vertheads) {
			$output .= "<th>$cols{$c}->{title}</th>";
		}
		foreach my $c (@columns) {
			$output .= "<th>$cols{$c}->{title}</th>";
		}
		$output .= "</tr>\n";
	}

	if (!(($results) and (@{$results}))) {
		return $opt->{no_results} || '<tr><td colspan="'. (scalar(@columns) + scalar(@vertheads)) .'">No results</td></tr>';
	}
	# ----------------------------------------------------------##

	# Process results --------------------------------------------
	my @rows = ();
	my @vh_stack = ();   # Stack of vertical headers we're working on
	my $vh;
	my $rowcount = 0;
	my $linecount = 1;
	for (my $i = 0; $i < scalar(@{$results}); $i++) {
		if (@row_toggle) {
			next if !$row_toggle[$i];
		}
		my $record = $results->[$i];
		my $row;

		#Debug("Row: ". ::uneval($record));

		# Dynamic values that can be used as column data
		my %dynamic = (
			realrow    => $i,
			rowcount   => $rowcount,
			rownumber  => $linecount,
			linecount  => $linecount,
			parity     => $linecount % 2 ? 1 : 0,
		);

		$row->{dynamic} = \%dynamic;

		foreach my $subhead (@subheader_cols) {
			if ($record->{$subhead} ne $cols{$subhead}->{value}) {
			  if ($cols{$subhead}->{header} ne 'vert') {
				$row->{html} = cell_open_tag($cols{$subhead},0,$#columns + 1);

				if ($opt->{title_horiz}) {
					$row->{html} .= $cols{$subhead}->{title} .' ';
				}
				my $datum = $record->{$subhead};
				$row->{html} .= prep_cell($cols{$subhead},$datum,$linecount,$record) .'</th>';
				$cols{$subhead}->{value} = $record->{$subhead};
			  } else {
			  	# Vertical headers must be inserted at the end, because that's
				# the only time we know what the rowspan is going to be.
				# So we keep track of them with a stack and a notation in the
				# row hash.
				my $old;
				if ($cols{$vh->{column}}->{pos} >= $cols{$subhead}->{pos}) {
				  while (($old->{column} ne $subhead) and (@vh_stack)) {
					$old = pop @vh_stack;
					$old->{end} = $rowcount;
					$cols{$old->{column}}->{value} = '';
					#::Debug("Popped vh_stack. Old is: ". ::uneval($old));
				  }
				}
				if ($opt->{reset_horiz}) {
					# Don't let horizontal headers apply across vertical headers
					foreach my $tmp (@subheader_cols) {
						if ($cols{$tmp}->{header} eq 'horiz') {
							$cols{$tmp}->{value} = '';
						}
					}
				}
				my $datum = $record->{$subhead};
				my $new = {
					content => prep_cell($cols{$subhead},$datum,$linecount,$record),
					column => $subhead,
					begin => $rowcount,
				};
				push @vh_stack, $new;
				#::Debug("vh_stack now: ". ::uneval(\@vh_stack));
				unshift @{$row->{'vert_headers'}}, $new;
				$cols{$subhead}->{value} = $record->{$subhead};
				$vh = $new;
			  }
			  if ($row->{html}) {
				push @rows, $row;
				$rowcount++;
				my %newrow = ();
				$row = \%newrow;
			  }
			}
		}
		if ($opt->{row_hidden_id}) {
			$row->{id} = $record->{$opt->{row_hidden_id}};
		}
		foreach my $col (@columns) {
			$row->{html} .= cell_open_tag($cols{$col});

			my $datum;
			if ($cols{$col}->{dynamic}) {
				$datum = $dynamic{$cols{$col}->{dynamic}};
			} else {
				$datum = $record->{$col};
			}
			if ((!$datum) and ($cols{$col}->{empty_cell})) {
				$datum = $cols{$col}->{empty_cell};
			}

			$row->{html} .= prep_cell($cols{$col},$datum,$linecount,$record);

			$row->{html} .= '</td>';
		}

		push @rows, $row;
		$rowcount++;
		$linecount++;
	}
	# ----------------------------------------------------------##


	# Do post-processing table assembly --------------------------
	foreach my $row (@rows) {
		my $html = $row->{'html'};
		if ($row->{'vert_headers'}) {
			foreach my $vert (@{$row->{'vert_headers'}}) {
				my $end = $vert->{end} || $rowcount;
				my $cell = cell_open_tag($cols{$vert->{column}},$end - $vert->{begin});
				$cell .= $vert->{content};
				$cell .= '</th>';
				$html = $cell . $html;
			}
		}
		my ($odd,$id);
		if ($row->{dynamic}->{parity}) {
			$odd = ' class="odd"';
		}
		if ($row->{id}) {
			my $name = $opt->{row_hidden_id} .'_'. $row->{dynamic}->{linecount};
			$id = "<input type=\"hidden\" name=\"$name\" value=\"$row->{id}\"/>";
		}
		$output .= "<tr$odd>$id$html</tr>\n";
	}
	# ----------------------------------------------------------##

	# Set some side-effect scratch variables
	if ($opt->{colheaders}) { $rowcount++; }
	$Tag->tmp('report_table_rowcount',$rowcount);
	$Tag->tmp('report_table_linecount',$linecount - 1);
	$Tag->tmp('report_table_colspan',(scalar(@columns) + scalar(@vertheads)));

	return $output;
}
EOR

