# Vend::Table::Editor - Swiss-army-knife table editor for Interchange
#
# $Id: Editor.pm,v 1.12 2002-10-04 13:40:17 mheins Exp $
#
# Copyright (C) 2002 ICDEVGROUP <interchange@icdevgroup.org>
# Copyright (C) 2002 Mike Heins <mike@perusion.net>
#
# This program was originally based on Vend 0.2 and 0.3
# Copyright 1995 by Andrew M. Wilcox <amw@wilcoxsolutions.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free
# Software Foundation, Inc., 59 Temple Place, Suite 330, Boston,
# MA  02111-1307  USA.

package Vend::Table::Editor;

use vars qw($VERSION);
$VERSION = substr(q$Revision: 1.12 $, 10);

use Vend::Util;
use Vend::Interpolate;
use Vend::Data;
use strict;

=head1 NAME

Vend::Table::Editor -- Interchange do-all HTML table editor

=head1 SYNOPSIS

[table-editor OPTIONS] 

[table-editor OPTIONS] TEMPLATE [/table-editor]

=head1 DESCRIPTION

The [table-editor] tag produces an HTML form that edits a database
table or collects values for a "wizard". It is extremely configurable
as to display and characteristics of the widgets used to collect the
input.

The widget types are based on the Interchange C<[display ...]> UserTag,
which in turn is heavily based on the ITL core C<[accessories ...]> tag.

The C<simplest> form of C<[table-editor]> is:

	[table-editor table=foo]

A page which contains only that tag will edit the table C<foo>, where
C<foo> is the name of an Interchange table to edit. If no C<foo> table
is C<defined>, then nothing will be displayed.

If the C<mv_metadata> entry "foo" is present, it is used as the
definition for table display, including the fields to edit and labels
for sections of the form. If C<ui_data_fields> is defined, this
cancels fetch of the view and any breaks and labels must be
defined with C<ui_break_before> and C<ui_break_before_label>. More
on the view concept later.

A simple "wizard" can be made with:

	[table-editor
			wizard=1
			ui_wizard_fields="foo bar"
			mv_nextpage=wizard2
			mv_prevpage=wizard_intro
			]

The purpose of a "wizard" is to collect values from the user and
place them in the $Values array. A next page value (option mv_nextpage)
must be defined to give a destination; if mv_prevpage is defined then
a "Back" button is presented to allow paging backward in the wizard.

=cut

my $Tag = new Vend::Tags;

%Vend::Interpolate::Filter_desc = (
	filesafe        => 'Safe for filename',
	currency        => 'Currency',
	mailto          => 'mailto: link',
	commify         => 'Commify',
	lookup          => 'DB lookup',
	uc              => 'Upper case',
	date_change     => 'Date widget',
	null_to_space   => 'NULL to SPACE',
	null_to_comma   => 'NULL to COMMA',
	null_to_colons  => 'NULL to ::',
	space_to_null   => 'SPACE to NULL',
	colons_to_null  => ':: to NULL',
	last_non_null   => 'Reverse combo',
	nullselect      => 'Combo box',
	tabbed          => 'Newline to TAB',
	lc              => 'Lower case',
	digits_dot      => 'Digits-dots',
	backslash       => 'Strip backslash',
	option_format   => 'Option format',
	crypt           => 'Crypt',
	namecase        => 'Name case',
	name            => 'Last&#44;First to First Last',
	digits          => 'Digits only',
	word            => 'A-Za-z_0-9',
	unix            => 'DOS to UNIX newlines',
	dos             => 'UNIX to DOS newlines',
	mac             => 'UNIX/DOS to Mac OS newlines',
	no_white        => 'No whitespace',
	strip           => 'Trim whitespace',
	sql             => 'SQL quoting',
	textarea_put    => 'Textarea PUT',
	textarea_get    => 'Textarea GET',
	text2html       => 'Simple text2html',
	urlencode       => 'URL encode',
	entities        => 'HTML entities',
);

my $F_desc = \%Vend::Interpolate::Filter_desc;

my $fdesc_sort = sub {
	return 1 if $a and ! $b;
	return -1 if ! $a and $b;
	return lc($F_desc->{$a}) cmp lc($F_desc->{$b});
};

sub expand_values {
	my $val = shift;
	return $val unless $val =~ /\[/;
	$val =~ s/\[cgi\s+([^\[]+)\]/$CGI::values{$1}/ig;
	$val =~ s/\[var\s+([^\[]+)\]/$::Variable->{$1}/ig;
	$val =~ s/\[value\s+([^\[]+)\]/$::Values->{$1}/ig;
	return $val;
}

sub filters {
	my ($exclude, $opt) = @_;
	$opt ||= {};
	my @out = map { $_ . ($F_desc->{$_} ? "=$F_desc->{$_}" : '') } 
				sort $fdesc_sort keys %Vend::Interpolate::Filter;
	if($exclude) {
		@out = grep /=/, @out;
	}
	unshift @out, "=--add--" unless $opt->{no_add};
	$opt->{joiner} = Vend::Interpolate::get_joiner($opt->{joiner}, ",\n");
	return join $opt->{joiner}, @out;
}

sub meta_record {
	my ($item, $view, $mdb) = @_;

#::logDebug("meta_record: item=$item view=$view mdb=$mdb");
	return undef unless $item;

	if(! ref ($mdb)) {
		my $mtable = $mdb || $::Variable->{UI_META_TABLE} || 'mv_metadata';
#::logDebug("meta_record mtable=$mtable");
		$mdb = database_exists_ref($mtable)
			or return undef;
	}
#::logDebug("meta_record has an item=$item and mdb=$mdb");

	my $record;

	my $mkey = $view ? "${view}::$item" : $item;

	if(ref $mdb eq 'HASH') {
		$record = $mdb;
	}
	else {
		$record = $mdb->row_hash($mkey);
#::logDebug("used mkey=$mkey to select record=$record");
	}

	$record ||= $mdb->row_hash($item) if $view;
#::logDebug("meta_record  record=$record");

	return undef if ! $record;

	# Get additional settings from extended field, which is a serialized
	# hash
	my $hash;
	if($record->{extended}) {
		## From Vend::Util
		$hash = get_option_hash($record->{extended});
		if(ref $hash eq 'HASH') {
			@$record{keys %$hash} = values %$hash;
		}
		else {
			undef $hash;
		}
	}

	# Allow view settings to be placed in the extended area
	if($view and $hash and $hash->{view}) {
		my $view_hash = $record->{view}{$view};
		ref $view_hash
			and @$record{keys %$view_hash} = values %$view_hash;
	}
#::logDebug("return meta_record=" . ::uneval($record) );
	return $record;
}

my $base_entry_value;

sub display {
	my ($table,$column,$key,$opt) = @_;

	if( ref($opt) ne 'HASH' ) {
		$opt = get_option_hash($opt);
	}

	my $template = $opt->{type} eq 'hidden' ? '' : $opt->{template};

	if($opt->{override}) {
		$opt->{value} = defined $opt->{default} ? $opt->{default} : '';
	}

	if(! defined $opt->{value} and $table and $column and length($key)) {
		$opt->{value} = tag_data($table, $column, $key);
	}

	my $mtab;
	my $record;

	my $no_meta = $opt->{ui_no_meta_display};

	METALOOK: {
		## No meta display wanted
		last METALOOK if $no_meta;
		## No meta display possible
		$table and $column or $opt->{meta}
			or last METALOOK;

		## We get a metarecord directly, though why it would be here
		## and not in options I don't know
		if($opt->{meta} and ref($opt->{meta}) eq 'HASH') {
			$record = $opt->{meta};
			last METALOOK;
		}

		$mtab = $opt->{meta_table} || $::Variable->{UI_META_TABLE} || 'mv_metadata'
			or last METALOOK;
		my $meta = Vend::Data::database_exists_ref($mtab)
			or do {
				::logError("non-existent meta table: %s", $mtab);
				undef $mtab;
				last METALOOK;
			};

		my $view = $opt->{view} || $opt->{arbitrary};

		## This is intended to trigger on the first access
		if($column eq $meta->config('KEY')) {
			if($view and $opt->{value} !~ /::.+::/) {
				$base_entry_value = ($opt->{value} =~ /^([^:]+)::(\w+)$/)
									? $1
									: $opt->{value};
			}
			else {
				$base_entry_value = $opt->{value} =~ /::/
									? $table
									: $opt->{value};
			}
		}

		my (@tries) = "${table}::$column";
		unshift @tries, "${table}::${column}::$key"
			if length($key)
				and $CGI::values{ui_meta_specific} || $opt->{specific};

		my $sess = $Vend::Session->{mv_metadata} || {};

		push @tries, { type => $opt->{type} }
			if $opt->{type} || $opt->{label};

		for my $metakey (@tries) {
			## In case we were passed a meta record
			last if $record = $sess->{$metakey} and ref $record;
			$record = UI::Primitive::meta_record($metakey, $view, $meta)
				and last;
		}
	}

	my $w;

	METAMAKE: {
		last METAMAKE if $no_meta;
		if( ! $record ) {
			$record = { %$opt };
		}
		else {
			## Here we allow override with the display tag, even with views and
			## extended
			my @override = qw/
								append
								attribute
								db
								extra
								field
								filter
								height
								help
								help_url
								label
								lookup
								lookup_exclude
								lookup_query
								name
								options
								outboard
								passed
								pre_filter
								prepend
								type
								width
								/;
			for(@override) {
				delete $record->{$_} if ! length($record->{$_});
				next unless defined $opt->{$_};
				$record->{$_} = $opt->{$_};
			}
		}

		$record->{name} ||= $column;
#::logDebug("record now=" . ::uneval($record));

		if($record->{options} and $record->{options} =~ /^[\w:]+$/) {
#::logDebug("checking options");
			PASS: {
				my $passed = $record->{options};

				if($passed eq 'tables') {
					my @tables = $Tag->list_databases();
					$record->{passed} = join (',', "=--none--", @tables);
				}
				elsif($passed eq 'filters') {
					$record->{passed} = filters(1);
				}
				elsif($passed =~ /^columns(::(\w*))?\s*$/) {
					my $total = $1;
					my $tname = $2 || $record->{db} || $table;
					if ($total eq '::' and $base_entry_value) {
						$tname = $base_entry_value;
					}
					$record->{passed} = join ",",
											"=--none--",
											$Tag->db_columns($tname),
										;
				}
				elsif($passed =~ /^keys(::(\w+))?\s*$/) {
					my $tname = $2 || $record->{db} || $table;
					$record->{passed} = join ",",
											"=--none--",
											$Tag->list_keys($tname),
										;
				}
			}
		}

#::logDebug("checking for custom widget");
		if ($record->{type} =~ s/^custom\s+//s) {
			my $wid = lc $record->{type};
			$wid =~ tr/-/_/;
			my $w;
			$record->{attribute} ||= $column;
			$record->{table}     ||= $mtab;
			$record->{rows}      ||= $record->{height};
			$record->{cols}      ||= $record->{width};
			$record->{field}     ||= 'options';
			$record->{name}      ||= $column;
			eval {
				$w = $Tag->$wid($record->{name}, $opt->{value}, $record, $opt);
			};
			if($@) {
				::logError("error using custom widget %s: %s", $wid, $@);
			}
			last METAMAKE;
		}

#::logDebug("formatting prepend/append");
		for(qw/append prepend/) {
			next unless $record->{$_};
			$record->{$_} = expand_values($record->{$_});
			$record->{$_} = Vend::Util::resolve_links($record->{$_});
			$record->{$_} =~ s/_UI_VALUE_/$opt->{value}/g;
			$record->{$_} =~ /_UI_URL_VALUE_/
				and do {
					my $tmp = $opt->{value};
					$tmp =~ s/(\W)/sprintf '%%%02x', ord($1)/eg;
					$record->{$_} =~ s/_UI_URL_VALUE_/$tmp/g;
				};
			$record->{$_} =~ s/_UI_TABLE_/$table/g;
			$record->{$_} =~ s/_UI_COLUMN_/$column/g;
			$record->{$_} =~ s/_UI_KEY_/$key/g;
		}

#::logDebug("overriding defaults");
#::logDebug("passed=$record->{passed}") if $record->{debug};
		my %things = (
			attribute	=> $column,
			cols	 	=> $opt->{cols}   || $record->{width},
			column	 	=> $column,
			passed	 	=> $record->{options},
			rows 		=> $opt->{rows}	|| $record->{height},
			table		=> $table,
			value		=> $opt->{value},
		);

		while( my ($k, $v) = each %things) {
			next if length $record->{$k};
			next unless defined $v;
			$record->{$k} = $v;
		}

#::logDebug("calling Vend::Form");
		$w = Vend::Form::display($record);
		if($record->{filter}) {
			$w .= qq{<INPUT TYPE=hidden NAME="ui_filter:$record->{name}" VALUE="};
			$w .= $record->{filter};
			$w .= '">';
		}
	}

	if(! defined $w) {
		my $text = $opt->{value};
		my $iname = $opt->{name} || $column;

		# Count lines for textarea
		my $count;
		$count = $text =~ s/(\r\n|\r|\n)/$1/g;

		HTML::Entities::encode($text, $ESCAPE_CHARS::std);
		my $size;
		if ($count) {
			$count++;
			$count = 20 if $count > 20;
			$w = <<EOF;
	<TEXTAREA NAME="$iname" COLS=60 ROWS=$count>$text</TEXTAREA>
EOF
		}
		elsif ($text =~ /^\d+$/) {
			my $cur = length($text);
			$size = $cur > 8 ? $cur + 1 : 8;
		}
		else {
			$size = 60;
		}
			$w = <<EOF;
	<INPUT NAME="$iname" SIZE=$size VALUE="$text">
EOF
	}

	my $array_return = wantarray;

#::logDebug("widget=$w");

	# don't output label if widget is hidden form variable only
	# and not an array type
	undef $template if $w =~ /^\s*<input\s[^>]*type\s*=\W*hidden\b[^>]*>\s*$/i;

	return $w unless $template || $opt->{return_hash} || $array_return;

	if($template and $template !~ /\s/) {
		$template = <<'EOF';
<TR>
<TD>
	<B>$LABEL$</B>
</TD>
<TD VALIGN=TOP>
	<TABLE CELLSPACING=0 CELLMARGIN=0><TR><TD>$WIDGET$</TD><TD><I>$HELP$</I>{HELP_URL}<BR><A HREF="$HELP_URL$">help</A>{/HELP_URL}</TD></TR></TABLE>
</TD>
</TR>
EOF
	}

	$record->{label} ||= $column;

	my %sub = (
		WIDGET		=> $w,
		HELP		=> $opt->{applylocale}
						? errmsg($record->{help})
						: $record->{help},
        META_URL    => $opt->{meta_url},
		HELP_URL	=> $record->{help_url},
		LABEL		=> $opt->{applylocale}
						? errmsg($record->{label})
						: $record->{label},
	);
#::logDebug("passed meta_url=$opt->{meta_url}");
      $sub{HELP_EITHER} = $sub{HELP} || $sub{HELP_URL};

	if($opt->{return_hash}) {
		$sub{OPT} = $opt;
		$sub{RECORD} = $record;
		return \%sub;
	}
	elsif($array_return) {
		return ($w, $sub{LABEL}, $sub{HELP}, $record->{help_url});
	}
	else {
		# Strip the {TAG} {/TAG} pairs if nothing there
		$template =~ s#{([A-Z_]+)}(.*?){/\1}#$sub{$1} ? $2: '' #ges;
		# Insert the TAG
              $sub{HELP_URL} ||= 'javascript:void(0)';
		$template =~ s/\$([A-Z_]+)\$/$sub{$1}/g;
#::logDebug("substituted template is: $template");
		return $template;
	}
}

sub tabbed_display {
	my ($tit, $cont, $opt) = @_;
	
	$opt ||= {};

	my @chars = reverse(0 .. 9, 'a' .. 'e');
	my @colors;
	$opt->{tab_bgcolor_template} ||= '#xxxxxx';
	$opt->{tab_height} ||= '30';
	$opt->{tab_width} ||= '120';
	$opt->{panel_height} ||= '600';
	$opt->{panel_width} ||= '800';
	$opt->{panel_id} ||= 'mvpan';
	$opt->{tab_horiz_offset} ||= '10';
	$opt->{tab_vert_offset} ||= '8';
	$opt->{tab_style} ||= q{
								text-align:center;
								font-family: sans-serif;
								line-height:150%;
								border:2px;
								border-color:#999999;
								border-style:outset;
								border-bottom-style:none;
							};
	$opt->{panel_style} ||= q{ 
									font-family: sans-serif;
									font-size: smaller;
									border: 2px;
									border-color:#999999;
									border-style:outset;
								};
	$opt->{layer_tab_style} ||= q{
									font-weight:bold;
									text-align:center;
									font-family:sans-serif;
									};
	$opt->{layer_panel_style} ||= q{
									font-family:sans-serif;
									padding:6px;
									};

	my $id = $opt->{panel_id};
	my $vpf = $id . '_';
	my $num_panels = scalar(@$cont);
	my $tabs_per_row = int( $opt->{panel_width} / $opt->{tab_width}) || 1;
	my $num_rows = POSIX::ceil( $num_panels / $opt->{tab_width});
	my $width = $opt->{panel_width};
	my $height = $opt->{tab_height} * $num_rows + $opt->{panel_height};
	my $panel_y =
		$num_rows
		* ($opt->{tab_height} - $opt->{tab_vert_offset})
		+ $opt->{tab_vert_offset};
	my $int1 = $panel_y - 2;
	my $int2 = $opt->{tab_height} * $num_rows;
	for(my $i = 0; $i < $num_panels; $i++) {
		my $c = $opt->{tab_bgcolor_template} || '#xxxxxx';
		$c =~ s/x/$chars[$i] || 'e'/eg;
		$colors[$i] = $c;
	}
	my $cArray = qq{var ${vpf}colors = ['} . join("','", @colors) . qq{'];};
#::logDebug("num rows=$num_rows");
	my $out = <<EOF;
<SCRIPT language="JavaScript">
<!--
var ${vpf}panelID = "$id"
var ${vpf}numDiv = $num_panels;
var ${vpf}numRows = $num_rows;
var ${vpf}tabsPerRow = $tabs_per_row;
var ${vpf}numLocations = ${vpf}numRows * ${vpf}tabsPerRow
var ${vpf}tabWidth = $opt->{tab_width}
var ${vpf}tabHeight = $opt->{tab_height}
var ${vpf}vOffset = $opt->{tab_vert_offset};
var ${vpf}hOffset = $opt->{tab_horiz_offset};
$cArray

var ${vpf}divLocation = new Array(${vpf}numLocations)
var ${vpf}newLocation = new Array(${vpf}numLocations)
for(var i=0; i<${vpf}numLocations; ++i) {
	${vpf}divLocation[i] = i
	${vpf}newLocation[i] = i
}

function ${vpf}getDiv(s,i) {
	var div
	if (document.layers) {
		div = document.layers[${vpf}panelID].layers[panelID+s+i]
	} else if (document.all && !document.getElementById) {
		div = document.all[${vpf}panelID+s+i]
	} else {
		div = document.getElementById(${vpf}panelID+s+i)
	}
	return div
}

function ${vpf}setZIndex(div, zIndex) {
	if (document.layers) div.style = div;
	div.style.zIndex = zIndex
}

function ${vpf}updatePosition(div, newPos) {
	${vpf}newClip=${vpf}tabHeight*(Math.floor(newPos/${vpf}tabsPerRow)+1)
	if (document.layers) {
		div.style=div;
		div.clip.bottom=${vpf}newClip; // clip off bottom
	} else {
		div.style.clip="rect(0 auto "+${vpf}newClip+" 0)"
	}
	div.style.top = (${vpf}numRows-(Math.floor(newPos/${vpf}tabsPerRow) + 1)) * (${vpf}tabHeight-${vpf}vOffset)
	div.style.left = (newPos % ${vpf}tabsPerRow) * ${vpf}tabWidth +	(${vpf}hOffset * (Math.floor(newPos / ${vpf}tabsPerRow)))
}

function ${vpf}selectTab(n) {
	// n is the ID of the division that was clicked
	// firstTab is the location of the first tab in the selected row
	var firstTab = Math.floor(${vpf}divLocation[n] / ${vpf}tabsPerRow) * ${vpf}tabsPerRow
	// newLoc is its new location
	for(var i=0; i<${vpf}numDiv; ++i) {
		// loc is the current location of the tab
		var loc = ${vpf}divLocation[i]
		// If in the selected row
		if(loc >= firstTab && loc < (firstTab + ${vpf}tabsPerRow)) ${vpf}newLocation[i] = (loc - firstTab)
		else if(loc < tabsPerRow) newLocation[i] = firstTab+(loc % tabsPerRow)
		else newLocation[i] = loc
	}
	// Set tab positions & zIndex
	// Update location
	var j = 1;
	for(var i=0; i<${vpf}numDiv; ++i) {
		var loc = ${vpf}newLocation[i]
		var div = ${vpf}getDiv("panel",i)
		var tdiv = ${vpf}getDiv("tab",i)
		if(i == n) {
			${vpf}setZIndex(div, ${vpf}numLocations +1);
			div.style.display = 'block';
			tdiv.style.backgroundColor = ${vpf}colors[0];
			div.style.backgroundColor = ${vpf}colors[0];
		}
		else {
			${vpf}setZIndex(div, ${vpf}numLocations - loc)
			div.style.display = 'none';
			tdiv.style.backgroundColor = ${vpf}colors[j];
			div.style.backgroundColor = ${vpf}colors[j++];
		}
		${vpf}divLocation[i] = loc
		${vpf}updatePosition(tdiv, loc)
		if(i == n) ${vpf}setZIndex(tdiv, ${vpf}numLocations +1)
		else ${vpf}setZIndex(tdiv,${vpf}numLocations - loc)
	}
}

// Nav4: position component into a table
function ${vpf}positionPanel() {
	document.$id.top=document.panelLocator.pageY;
	document.$id.left=document.panelLocator.pageX;
}
if (document.layers) window.onload=${vpf}positionPanel;

//-->
</SCRIPT>
<STYLE type="text/css">
<!--
.${id}tab {
	font-weight: bold;
	width:$opt->{tab_width}px;
	margin:0px;
	height: ${int2}px;
	position:absolute;
	$opt->{tab_style}
	}

.${id}panel {
	position:absolute;
	width: $opt->{panel_width}px;
	height: $opt->{panel_height}px;
	left:0px;
	top:${int1}px;
	margin:0px;
	padding:6px;
	$opt->{panel_style}
	}
-->
</STYLE>
EOF
	my $s1 = '';
	my $s2 = '';
	for(my $i = 0; $i < $num_panels; $i++) {
		my $zi = $num_panels - $i;
		my $pnum = $i + 1;
		my $left = (($i % $tabs_per_row)
					* $opt->{tab_width}
					+ ($opt->{tab_horiz_offset}
					* (int($i / $tabs_per_row))));
		my $top = ( $num_rows - (int($i / $tabs_per_row) + 1))
					- ($opt->{tab_height} - $opt->{tab_vert_offset});
		my $cliprect = $opt->{tab_height} * (int($i / $tabs_per_row) + 1);
		$s1 .= <<EOF;
<DIV id="${id}panel$i"
		class="${id}panel"
		style="
			background-color: $colors[$i]; 
			z-index:$zi
		">
$opt->{panel_prepend}
$cont->[$i]
$opt->{panel_append}
</DIV>
<DIV
	onclick="${vpf}selectTab($i)"
	id="${id}tab$i"
	class="${id}tab"
	style="
		background-color: $colors[$i]; 
		cursor: pointer;
		left: ${left}px;
		top: ${top}px;
		z-index:$zi;
		clip:rect(0 auto $cliprect 0);
		">
$tit->[$i]
</DIV>
EOF
		my $lheight = $opt->{tab_height} * $num_rows;
		my $ltop = $num_rows * ($opt->{tab_height} - $opt->{tab_vert_offset})
					+ $opt->{tab_vert_offset} - 2;
		$s2 .= <<EOF;
<LAYER
	bgcolor="$colors[$i]"
	style="$opt->{layer_tab_style}"
	width="$opt->{tab_width}"
	height="$lheight"
	left="$left"
	top="$top"
	z-index="$zi"
	id="${id}tab$i"
	onfocus="${vpf}selectTab($i)"
	>
<table width="100%" cellpadding=2 cellspacing=0>
$tit->[$i]
</LAYER>
<LAYER
	bgcolor="$colors[$i]"
	style="$opt->{layer_panel_style}"
	width="$opt->{panel_width}"
	height="$opt->{panel_height}"
	left="0"
	top="$ltop"
	z-index="$zi"
	id="${id}panel$i"
	>$cont->[$i]
</LAYER>
EOF
	}

	my $start_index = $opt->{start_at_index} || 0;
	$start_index += 0;
	return <<EOF;
$out
<div style="
		position: relative;
		left: 0; top: 0; width=100%; height=100%;
		z-index: 0;
	">
$s1
<script>
	${vpf}selectTab($start_index);
</script>
</div>
EOF
}

my $tcount_all;
my %alias;
my %exclude;
my %outhash;
my @titles;
my @controls;
my $ctl_index = 0;
my @out;

sub ttag {
	return 'TABLE_STD' . ++$tcount_all;
}

sub add_exclude {
	my ($tag, $string) = @_;
#::logDebug("calling add_exclude tag='$tag' string='$string'");
	return unless $string =~ /\S/;
	$exclude{$tag} ||= ' ';
	$exclude{$tag} .= "$string ";
}

sub col_chunk {
	my $value = pop @_;
	my $tag = shift @_;
	my $exclude = shift @_;
	my @others = @_;

	$tag = "COLUMN_$tag";

#::logDebug("$tag content length=" . length($value));

	die "duplicate tag settor $tag" if exists $outhash{$tag};
	$outhash{$tag} = $value;

	if(@others) {
		$alias{$tag} ||= [];
		push @{$alias{$tag}}, @others;
	}

	my $ctl = $controls[$ctl_index] ||= [];
	add_exclude($tag, $exclude) if $exclude;

	return unless length($value);

	push @$ctl, $tag;
	return;
}

sub chunk_alias {
	my $tag = shift;
	$alias{$tag} ||= [];
	push @{$alias{$tag}}, @_;
	return;
}

sub chunk {
	my $value = pop @_;
	my $tag = shift @_;
	my $exclude = shift @_;
	my @others = @_;

	die "duplicate tag settor $tag" if exists $outhash{$tag};
	$outhash{$tag} = $value;

#::logDebug("$tag exclude=$exclude, content length=" . length($value));

	if(@others) {
		$alias{$tag} ||= [];
		push @{$alias{$tag}}, @others;
	}

	add_exclude($tag, $exclude) if $exclude =~ /\S/;

	return unless length($value);
	push @out, $tag;
}

sub resolve_exclude {
	my $exc = shift;
	while(my ($k, $v) = each %exclude) {
		my %seen;
		my @things = grep /\S/ && ! $seen{$_}++, split /\s+/, $v;
#::logDebug("examining $k for $v");
		for my $thing (@things) {
			if($thing =~ s/^[^A-Z]//) {
#::logDebug("examining $v for $thing!=$exc->{$thing}");
				$outhash{$k} = '' unless $exc->{$thing};
			}
			else {
#::logDebug("examining $v for $thing=$exc->{$thing}");
				$outhash{$k} = '' if $exc->{$thing};
			}
		}
	}
}

sub editor_init {
	undef $base_entry_value;

	## Why?
	Vend::Interpolate::init_calc() if ! $Vend::Calc_initialized;
	@out = ();
	@controls = ();
	@titles = ();
	%outhash = ();
	%exclude = ();
	%alias = ();
	$tcount_all = 0;
	$ctl_index = 0;
}

my %o_default_length = (
	
);

my %o_default_var = (qw/
	color_fail			UI_CONTRAST
	color_success		UI_C_SUCCESS
/);

my %o_default_defined = (
	mv_update_empty		=> 1,
	restrict_allow		=> 'page area',
	widget_cell_class	=> 'cwidget',
	label_cell_class	=> 'clabel',
	data_cell_class	=> 'cdata',
	help_cell_class	=> 'chelp',
	break_cell_class	=> 'cbreak',
	spacer_row_class => 'rspacer',
	break_row_class => 'rbreak',
	title_row_class => 'rmarq',
	data_row_class => 'rnorm',
);

my %o_default = (
	action				=> 'set',
	wizard_next			=> 'return',
	help_anchor			=> 'help',
	wizard_cancel		=> 'back',
	across				=> 1,
	color_success		=> '#00FF00',
	color_fail			=> '#FF0000',
	table_width			=> '60%',
	left_width			=> '30%',
);

# Build maps for ui_te_* option pass
my @cgi_opts = qw/

	append
	check
	database
	default
	extra
	field
	filter
	height
	help
	help_url
	label
	lookup
	options
	outboard
	override
	passed
	pre_filter
	prepend
	template
	widget
	width

/;

my @hmap;

for(@cgi_opts) {
	push @hmap, [ qr/ui_te_$_:/, $_ ];
}

sub resolve_options {
	my ($opt, $CGI) = @_;

	# This may be passed by the caller, but is normally from the form
	# or URL
	$CGI ||= \%CGI::values;

	my $table	= $opt->{mv_data_table};
	my $key		= $opt->{item_id};

	$table = $CGI->{mv_data_table}
		if ! $table and $opt->{cgi} and $CGI->{mv_data_table};

	$opt->{table} = $opt->{mv_data_table} = $table;

	# First we see if something has created a big options munge
	# for us
	if($opt->{all_opts}) {
#::logDebug("all_opts being brought in...=$opt->{all_opts}");
		if(ref($opt->{all_opts}) eq 'HASH') {
#::logDebug("all_opts being brought in...");
			my $o = $opt->{all_opts};
			for (keys %$o ) {
				$opt->{$_} = $o->{$_};
			}
		}
		else {
			my $o = meta_record($opt->{all_opts});
#::logDebug("all_opts being brought in, o=$o");
			if($o) {
				for (keys %$o ) {
					$opt->{$_} = $o->{$_};
				}
			}
			else {
				logError("%s: improper option %s, must be %s, was %s.",
							'table_editor',
							'all_opts',
							'hash',
							ref $opt->{all_opts},
							);
			}
		}
#::logDebug("options now=" . ::uneval($opt));
	}

	my $tmeta;
	if($opt->{no_table_meta}) {
		$tmeta = {};
	}
	else {
		$tmeta = meta_record($table, $opt->{ui_meta_view}) || {};
	}

	# This section checks the passed options and converts them from
	# strings to refs if necessary
	FORMATS: {
		no strict 'refs';
		my $ref;
		for(qw/
                    append
                    default
					database
                    error
                    extra
                    field
                    filter
                    height
                    help
                    help_url
                    label
                    lookup
                    lookup_query
                    meta
                    options
                    outboard
                    override
                    passed
                    pre_filter
                    prepend
                    template
                    widget
                    width
				/ )
		{
			next if ref $opt->{$_};
			($opt->{$_} = {}, next) if ! $opt->{$_};
			my $ref = {};
			my $string = $opt->{$_};
			$string =~ s/^\s+//gm;
			$string =~ s/\s+$//gm;
			while($string =~ m/^(.+?)=\s*(.+)/mg) {
				$ref->{$1} = $2;
			}
			$opt->{$_} = $ref;
		}
	}

	my @mapdirect = qw/
		bottom_buttons
		break_cell_class
		break_cell_style
		break_row_class
		break_row_style
		data_cell_class
		data_cell_style
		data_row_class
		data_row_style
		file_upload
		help_cell_class
		help_cell_style
		help_anchor
		include_before
		include_form
		label_cell_class
		label_cell_style
		left_width
		link_before
		link_table
		link_fields
		link_label
		link_sort
		link_key
		link_view
		link_template
		link_extra
		mv_blob_field
		mv_blob_label
		mv_blob_nick
		mv_blob_pointer
		mv_blob_title
		mv_data_decode
		mv_data_table
		mv_update_empty
		panel_height
		panel_id
		panel_width
		spacer_row_class
		spacer_row_style
		start_at
		tab_bgcolor_template
		tab_cellpadding
		tab_cellspacing
		tab_height
		tab_horiz_offset
		tab_vert_offset
		tab_width
		tabbed
		table_width
		title_row_class
		title_row_style
		top_buttons
		ui_break_before
		ui_break_before_label
		ui_data_fields
		ui_data_fields_all
		ui_data_key_name
		ui_delete_box
		ui_display_only
		ui_hide_key
		ui_meta_specific
		ui_meta_view
		ui_new_item
		ui_nextpage
		ui_no_meta_display
		widget_cell_class
		widget_cell_style
	/;

	for(grep defined $tmeta->{$_}, @mapdirect) {
		$opt->{$_} = $tmeta->{$_} if ! defined $opt->{$_};
	}

	if($opt->{cgi}) {
		unshift @mapdirect, qw/
				item_id
				item_id_left
				ui_clone_id
				ui_clone_tables
				ui_sequence_edit
		/;
		for(@mapdirect) {
			next if ! defined $CGI->{$_};
			$opt->{$_} = $CGI->{$_};
		}
		my @cgi = keys %{$CGI};
		foreach my $row (@hmap) {
			my @keys = grep $_ =~ $row->[0], @cgi;
			for(@keys) {
				/^ui_\w+:(\S+)/
					and $opt->{$row->[1]}{$1} = $CGI->{$_};
			}
		}

		### Why these here?
		#$table = $opt->{mv_data_table};
		#$key = $opt->{item_id};
	}

	if($opt->{wizard}) {
		$opt->{noexport} = 1;
		$opt->{next_text} = 'Next -->' unless $opt->{next_text};
		$opt->{cancel_text} = 'Cancel' unless $opt->{cancel_text};
		$opt->{back_text} = '<-- Back' unless $opt->{back_text};
	}
	else {
		$opt->{cancel_text} = 'Cancel' unless $opt->{cancel_text};
		$opt->{next_text} = "Ok" unless $opt->{next_text};
	}

	for(qw/ next_text cancel_text back_text/ ) {
		$opt->{$_} = errmsg($opt->{$_});
	}

	if (! $opt->{inner_table_width}) {
		if($opt->{table_width} =~ /%/) {
			$opt->{inner_table_width} = '100%';
		}
		elsif ($opt->{table_width} =~ /^\d+$/) {
			$opt->{inner_table_width} = $opt->{table_width} - 2;
		}
		else {
			$opt->{inner_table_width} = $opt->{table_width};
		}
	}

	if($opt->{wizard} || $opt->{notable} and ! $opt->{table}) {
		$opt->{table} = 'mv_null';
		$Vend::Database{mv_null} = 
			bless [
					{},
					undef,
					[ 'code', 'value' ],
					[ 'code' => 0, 'value' => 1 ],
					0,
					{ },
					], 'Vend::Table::InMemory';
	}

	# resolve form defaults

	while( my ($k, $v) = each %o_default_var) {
		$opt->{$k} ||= $::Variable->{$v};
	}

	while( my ($k, $v) = each %o_default_length) {
		$opt->{$k} = $v if ! length($opt->{$k});
	}

	while( my ($k, $v) = each %o_default_defined) {
		$opt->{$k} = $v if ! defined($opt->{$k});
	}

	while( my ($k, $v) = each %o_default) {
		$opt->{$k} ||= $v;
	}

	# init the row styles
	foreach my $rtype (qw/data break combo spacer/) {
		my $mainp = $rtype . '_row_extra';
		my $thing = '';
		for my $ptype (qw/class style align valign width/) {
			my $parm = $rtype . '_row_' . $ptype;
			$opt->{$parm} ||= $tmeta->{$parm};
			if(defined $opt->{$parm}) {
				$thing .= qq{ $ptype="$opt->{$parm}"};
			}
		}
		$opt->{$mainp} ||= $tmeta->{$mainp};
		if($opt->{$mainp}) {
			$thing .= " " . $opt->{$mainp};
		}
		$opt->{$mainp} = $thing;
	}

	# Init the cell styles

	for my $ctype (qw/label data widget help break/) {
		my $mainp = $ctype . '_cell_extra';
		my $thing = '';
		for my $ptype (qw/class style align valign width/) {
			my $parm = $ctype . '_cell_' . $ptype;
			$opt->{$parm} ||= $tmeta->{$parm};
			if(defined $opt->{$parm}) {
				$thing .= qq{ $ptype="$opt->{$parm}"};
			}
		}
		$opt->{$mainp} ||= $tmeta->{$mainp};
		if($opt->{$mainp}) {
			$thing .= " " . $opt->{$mainp};
		}
		$opt->{$mainp} = $thing;
	}


	###############################################################
	# Get the field display information including breaks and labels
	###############################################################
	if( ! $opt->{ui_data_fields} and ! $opt->{ui_data_fields_all}) {
		$opt->{ui_data_fields} = $tmeta->{ui_data_fields} || $tmeta->{options};
	}
#::logDebug("fields were=$opt->{ui_data_fields}");
	$opt->{ui_data_fields} =~ s/\r\n/\n/g;
	$opt->{ui_data_fields} =~ s/\r/\n/g;
	$opt->{ui_data_fields} =~ s/^[ \t]+//mg;
	$opt->{ui_data_fields} =~ s/[ \t]+$//mg;

	if($opt->{ui_data_fields} =~ /\n\n/) {
		my @breaks;
		my @break_labels;
		my $fstring = "\n\n$opt->{ui_data_fields}";
		while ($fstring =~ s/\n+(?:\n[ \t]*=(.*))?\n+[ \t]*(\w[:.\w]+)/\n$2/) {
			push @breaks, $2;
			push @break_labels, "$2=$1" if $1;
		}
		$opt->{ui_break_before} = join(" ", @breaks)
			if ! $opt->{ui_break_before};
		$opt->{ui_break_before_label} = join(",", @break_labels)
			if ! $opt->{ui_break_before_label};
		$opt->{ui_data_fields} = $fstring;
	}

	$opt->{ui_data_fields} ||= $opt->{mv_data_fields};
	$opt->{ui_data_fields} =~ s/^[\s,\0]+//;
	$opt->{ui_data_fields} =~ s/[\s,\0]+$//;
#::logDebug("fields now=$opt->{ui_data_fields}");

	$opt->{mv_nextpage} = $Global::Variable->{MV_PAGE}
		if ! $opt->{mv_nextpage};

	$opt->{form_extra} =~ s/^\s*/ /
		if $opt->{form_extra};
	$opt->{form_extra} ||= '';

	$opt->{form_extra} .= qq{ NAME="$opt->{form_name}"}
		if $opt->{form_name};

	$opt->{form_extra} .= qq{ TARGET="$opt->{form_target}"}
		if $opt->{form_target};

	$opt->{enctype} = $opt->{file_upload} ? ' ENCTYPE="multipart/form-data"' : '';

}
# UserTag table-editor Order mv_data_table item_id
# UserTag table-editor addAttr
# UserTag table-editor AttrAlias clone ui_clone_id
# UserTag table-editor AttrAlias table mv_data_table
# UserTag table-editor AttrAlias fields ui_data_fields
# UserTag table-editor AttrAlias mv_data_fields ui_data_fields
# UserTag table-editor AttrAlias key   item_id
# UserTag table-editor AttrAlias view  ui_meta_view
# UserTag table-editor AttrAlias profile ui_profile
# UserTag table-editor AttrAlias email_fields ui_display_only
# UserTag table-editor hasEndTag
# UserTag table-editor MapRoutine Vend::Table::Editor::editor
sub editor {

	my ($table, $key, $opt, $overall_template) = @_;
show_times("begin table editor call item_id=$key") if $Global::ShowTimes;

	use vars qw/$Tag/;

	editor_init($opt);

	my @messages;
	my @errors;

#::logDebug("key at beginning: $key");
	$opt->{mv_data_table} = $table if $table;
	$opt->{item_id}		  = $key if $key;
	$opt->{table}		  = $opt->{mv_data_table};
	$opt->{ui_meta_view}  ||= $CGI->{ui_meta_view} if $opt->{cgi};

	resolve_options($opt);
	$table = $opt->{table};
	$key = $opt->{item_id};
	if($opt->{save_meta}) {
		$::Scratch->{$opt->{save_meta}} = uneval($opt);
	}
#::logDebug("key after resolve_options: $key");

	my $rowdiv         = $opt->{across}    || 1;
	my $cells_per_span = $opt->{cell_span} || 2;
	my $rowcount = 0;
	my $span = $rowdiv * $cells_per_span;
	my $oddspan = $span - 1;
	my $def = $opt->{default_ref} || $::Values;

	my $append       = $opt->{append};
	my $check        = $opt->{check};
	my $database     = $opt->{database};
	my $default      = $opt->{default};
	my $error        = $opt->{error};
	my $extra        = $opt->{extra};
	my $field        = $opt->{field};
	my $filter       = $opt->{filter};
	my $height       = $opt->{height};
	my $help         = $opt->{help};
	my $help_url     = $opt->{help_url};
	my $label        = $opt->{label};
	my $lookup       = $opt->{lookup};
	my $lookup_query = $opt->{lookup_query};
	my $meta         = $opt->{meta};
	my $options      = $opt->{options};
	my $outboard     = $opt->{outboard};
	my $override     = $opt->{override};
	my $passed       = $opt->{passed};
	my $pre_filter   = $opt->{pre_filter};
	my $prepend      = $opt->{prepend};
	my $template     = $opt->{template};
	my $widget       = $opt->{widget};
	my $width        = $opt->{width};

	my $blabel = $opt->{blabel};
	my $elabel = $opt->{elabel};
	my $mlabel = '';

	my $ntext;
	my $btext;
	my $ctext;
	unless ($opt->{wizard} || $opt->{nosave}) {
		$::Scratch->{$opt->{next_text}} = $Tag->return_to('click', 1);
	}
	else {
		if($opt->{action_click}) {
			$ntext = <<EOF;
mv_todo=$opt->{wizard_next}
ui_wizard_action=Next
mv_click=$opt->{action_click}
EOF
		}
		else {
			$ntext = <<EOF;
mv_todo=$opt->{wizard_next}
ui_wizard_action=Next
mv_click=ui_override_next
EOF
		}
		$::Scratch->{$opt->{next_text}} = $ntext;

		my $hidgo = $opt->{mv_cancelpage} || $opt->{hidden}{ui_return_to} || $CGI->{return_to};
		$hidgo =~ s/\0.*//s;
		$ctext = $::Scratch->{$opt->{cancel_text}} = <<EOF;
mv_form_profile=
ui_wizard_action=Cancel
mv_nextpage=$hidgo
mv_todo=$opt->{wizard_cancel}
EOF
		if($opt->{mv_prevpage}) {
			$btext = $::Scratch->{$opt->{back_text}} = <<EOF;
mv_form_profile=
ui_wizard_action=Back
mv_nextpage=$opt->{mv_prevpage}
mv_todo=$opt->{wizard_next}
EOF
		}
		else {
			delete $opt->{back_text};
		}
	}

	for(qw/next_text back_text cancel_text/) {
		$opt->{"orig_$_"} = $opt->{$_};
	}

	$::Scratch->{$opt->{next_text}}   = $ntext if $ntext;
	$::Scratch->{$opt->{cancel_text}} = $ctext if $ctext;
	$::Scratch->{$opt->{back_text}}   = $btext if $btext;

	$opt->{next_text} = HTML::Entities::encode($opt->{next_text}, $ESCAPE_CHARS::std);
	$opt->{back_text} = HTML::Entities::encode($opt->{back_text}, $ESCAPE_CHARS::std);
	$opt->{cancel_text} = HTML::Entities::encode($opt->{cancel_text});

	$::Scratch->{$opt->{next_text}}   = $ntext if $ntext;
	$::Scratch->{$opt->{cancel_text}} = $ctext if $ctext;
	$::Scratch->{$opt->{back_text}}   = $btext if $btext;

	undef $opt->{tabbed} if $::Scratch->{ui_old_browser};
	undef $opt->{auto_secure} if $opt->{cgi};

	### Build the error checking
	my $error_show_var = 1;
	my $have_errors;
	if($opt->{ui_profile} or $check) {
		$Tag->error( { all => 1 } )
			unless $CGI->{mv_form_profile} or $opt->{keep_errors};
		my $prof = $opt->{ui_profile} || '';
		if ($prof =~ s/^\*//) {
			# special notation ui_profile="*whatever" means
			# use automatic checklist-related profile
			my $name = $prof;
			$prof = $::Scratch->{"profile_$name"} || '';
			if ($prof) {
				$prof =~ s/^\s*(\w+)[\s=]+required\b/$1=mandatory/mg;
				for (grep /\S/, split /\n/, $prof) {
					if (/^\s*(\w+)\s*=(.+)$/) {
						my $k = $1; my $v = $2;
						$v =~ s/\s+$//;
						$v =~ s/^\s+//;
						$error->{$k} = 1;
						$error_show_var = 0 if $v =~ /\S /;
					}
				}
				$prof = '&calc delete $Values->{step_'
					  . $name
					  . "}; return 1\n"
					  . $prof;
				$opt->{ui_profile_success} = "&set=step_$name 1";
			}
		}
		my $success = $opt->{ui_profile_success};
		# make sure profile so far ends with a newline so we can add more
		$prof .= "\n" unless $prof =~ /\n\s*\z/;
		if(ref $check) {
			while ( my($k, $v) = each %$check ) {
				next unless length $v;
				$error->{$k} = 1;
				$v =~ s/\s+$//;
				$v =~ s/^\s+//;
				$v =~ s/\s+$//mg;
				$v =~ s/^\s+//mg;
				$v =~ s/^required\b/mandatory/mg;
				unless ($v =~ /^\&/m) {
					$error_show_var = 0 if $v =~ /\S /;
					$v =~ s/^/$k=/mg;
					$v =~ s/\n/\n&and\n/g;
				}
				$prof .= "$v\n";
			}
		}
		elsif ($check) {
			for (@_ = grep /\S/, split /[\s,]+/, $check) {
				$error->{$_} = 1;
				$prof .= "$_=mandatory\n";
			}
		}
		$opt->{hidden} = {} if ! $opt->{hidden};
		$opt->{hidden}{mv_form_profile} = 'ui_profile';
		my $fail = $opt->{mv_failpage} || $Global::Variable->{MV_PAGE};

		# watch out for early interpolation here!
		$::Scratch->{ui_profile} = <<EOF;
[perl]
#Debug("cancel='$opt->{orig_cancel_text}' back='$opt->{orig_back_text}' click=\$CGI->{mv_click}");
	my \@clicks = split /\\0/, \$CGI->{mv_click};
	
	for( qq{$opt->{orig_cancel_text}}, qq{$opt->{orig_back_text}}) {
#Debug("compare is '\$_'");
		next unless \$_;
		my \$cancel = \$_;
		for(\@clicks) {
#Debug("click is '\$_'");
			return if \$_ eq \$cancel; 
		}
	}
	# the following should already be interpolated by the table-editor tag
	# before going into scratch ui_profile
	return <<'EOP';
$prof
&fail=$fail
&fatal=1
$success
mv_form_profile=mandatory
&set=mv_todo $opt->{action}
EOP
[/perl]
EOF
		$opt->{blabel} = '<span style="font-weight: normal">';
		$opt->{elabel} = '</span>';
		$mlabel = ($opt->{message_label} || '&nbsp;&nbsp;&nbsp;<B>Bold</B> fields are required');
		$have_errors = $Tag->error( {
									all => 1,
									show_var => $error_show_var,
									show_error => 1,
									joiner => '<BR>',
									keep => 1}
									);
		if($opt->{all_errors}) {
			if($have_errors) {
				$mlabel .= '<P>Errors:';
				$mlabel .= qq{<FONT COLOR="$opt->{color_fail}">};
				$mlabel .= "<BLOCKQUOTE>$have_errors</BLOCKQUOTE></FONT>";
			}
		}
	}
	### end build of error checking

	$opt->{clear_image} = "bg.gif" if ! $opt->{clear_image};

	my $die = sub {
		::logError(@_);
		$::Scratch->{ui_error} .= "<BR>\n" if $::Scratch->{ui_error};
		$::Scratch->{ui_error} .= ::errmsg(@_);
		return undef;
	};

	my $db;
	unless($opt->{notable}) {
		# From Vend::Data
		$db = database_exists_ref($table)
			or return $die->("table-editor: bad table '%s'", $table);
	}

	$opt->{ui_data_fields} =~ s/[,\0\s]+/ /g;

	if($opt->{ui_wizard_fields}) {
		$opt->{ui_data_fields} = $opt->{ui_display_only} = $opt->{ui_wizard_fields};
	}

	if(! $opt->{ui_data_fields}) {
		if( $opt->{notable}) {
			::logError("table_editor: no place to get fields!");
			return '';
		}
		else {
			$opt->{ui_data_fields} = join " ", $db->columns();
		}
	}

	my $keycol;
	if($opt->{notable}) {
		$keycol = $opt->{ui_data_key_name};
	}
	else {
		$keycol = $opt->{ui_data_key_name} || $db->config('KEY');
	}

	###############################################################

	my $linecount;

	CANONCOLS: {
		my @cols = split /[,\0\s]/, $opt->{ui_data_fields};
		#@cols = grep /:/ || $db->column_exists($_), @cols;

		$opt->{ui_data_fields} = join " ", @cols;

		$linecount = scalar @cols;
	}

	my $url = $Tag->area('ui');

	my $key_message;
	if($opt->{ui_new_item} and ! $opt->{notable}) {
		if( ! $db->config('_Auto_number') ) {
			$db->config('AUTO_NUMBER', '000001');
			$key = $db->autonumber($key);
		}
		else {
			$key = '';
			$opt->{mv_data_auto_number} = 1;
			$key_message = errmsg('(new key will be assigned if left blank)');
		}
	}

	my $data;
	my $exists;

	if($opt->{notable}) {
		$data = {};
	}
	elsif($opt->{ui_clone_id} and $db->record_exists($opt->{ui_clone_id})) {
		$data = $db->row_hash($opt->{ui_clone_id})
			or
			return $die->('table-editor: row_hash function failed for %s.', $key);
		$data->{$keycol} = $key;
	}
	elsif ($db->record_exists($key)) {
		$data = $db->row_hash($key);
		$exists = 1;
	}

	if ($opt->{reload} and $have_errors) {
		if($data) {
			for(keys %$data) {
				$data->{$_} = $CGI->{$_}
					if defined $CGI->{$_};
			}
		}
		else {
			$data = { %$CGI };
		}
	}


	my $blob_data;
	my $blob_widget;
	if($opt->{mailto} and $opt->{mv_blob_field}) {
		$opt->{hidden}{mv_blob_only} = 1;
		$opt->{hidden}{mv_blob_nick}
			= $opt->{mv_blob_nick}
			|| POSIX::strftime("%Y%m%d%H%M%S", localtime());
	}
	elsif($opt->{mv_blob_field}) {
#::logDebug("checking blob");

		my $blob_pointer;
		$blob_pointer = $data->{$opt->{mv_blob_pointer}}
			if $opt->{mv_blob_pointer};
		$blob_pointer ||= $opt->{mv_blob_nick};
			

		DOBLOB: {

			unless ( $db->column_exists($opt->{mv_blob_field}) ) {
				push @errors, ::errmsg(
									"blob field %s not in database.",
									$opt->{mv_blob_field},
								);
				last DOBLOB;
			}

			my $bstring = $data->{$opt->{mv_blob_field}};

#::logDebug("blob: bstring=$bstring");

			my $blob;

			if(length $bstring) {
				$blob = $Vend::Interpolate::safe_safe->reval($bstring);
				if($@) {
					push @errors, ::errmsg("error reading blob data: %s", $@);
					last DOBLOB;
				}
#::logDebug("blob evals to " . ::uneval_it($blob));

				if(ref($blob) !~ /HASH/) {
					push @errors, ::errmsg("blob data not a storage book.");
					undef $blob;
				}
			}
			else {
				$blob = {};
			}
			my %wid_data;
			my %url_data;
			my @labels = keys %$blob;
			for my $key (@labels) {
				my $ref = $blob->{$_};
				my $lab = $ref->{$opt->{mv_blob_label} || 'name'};
				if($lab) {
					$lab =~ s/,/&#44/g;
					$wid_data{$lab} = "$key=$key - $lab";
					$url_data{$lab} = $Tag->page( {
											href => $Global::Variable->{MV_PAGE},
											form => "
												item_id=$opt->{item_id}
												mv_blob_nick=$key
											",
										});
					$url_data{$lab} .= "$key - $lab</A>";
				}
				else {
					$wid_data{$key} = $key;
					$url_data{$key} = $Tag->page( {
											href => $Global::Variable->{MV_PAGE},
											form => "
												item_id=$opt->{item_id}
												mv_blob_nick=$key
											",
										});
					$url_data{$key} .= "$key</A>";
				}
			}
#::logDebug("wid_data is " . ::uneval_it(\%wid_data));
			$opt->{mv_blob_title} = "Stored settings"
				if ! $opt->{mv_blob_title};
			$opt->{mv_blob_title} = errmsg($opt->{mv_blob_title});

			$::Scratch->{Load} = <<EOF;
[return-to type=click stack=1 page="$Global::Variable->{MV_PAGE}"]
ui_nextpage=
[perl]Log("tried to go to $Global::Variable->{MV_PAGE}"); return[/perl]
mv_todo=back
EOF
#::logDebug("blob_pointer=$blob_pointer blob_nick=$opt->{mv_blob_nick}");

			my $loaded_from;
			my $lfrom_msg;
			if( $opt->{mv_blob_nick} ) {
				$lfrom_msg = $opt->{mv_blob_nick};
			}
			else {
				$lfrom_msg = errmsg("current values");
			}
			$lfrom_msg = errmsg("loaded from %s", $lfrom_msg);
			$loaded_from = <<EOF;
<I>($lfrom_msg)</I><BR>
EOF
			if(@labels) {
				$loaded_from .= errmsg("Load from") . ":<BLOCKQUOTE>";
				$loaded_from .=  join (" ", @url_data{ sort keys %url_data });
				$loaded_from .= "</BLOCKQUOTE>";
			}

			my $checked;
			my $set;
			if( $opt->{mv_blob_only} and $opt->{mv_blob_nick}) {
				$checked = ' CHECKED';
				$set 	 = $opt->{mv_blob_nick};
			}

			unless ($opt->{nosave}) {
				$blob_widget = display(undef, undef, undef, {
									name => 'mv_blob_nick',
									type => $opt->{ui_blob_widget} || 'combo',
									filter => 'nullselect',
									value => $opt->{mv_blob_nick},
									passed => join (",", @wid_data{ sort keys %wid_data }) || 'default',
									});
				my $msg1 = errmsg('Save to');
				my $msg2 = errmsg('Save here only');
				for (\$msg1, \$msg2) {
					$$_ =~ s/ /&nbsp;/g;
				}
				$blob_widget = <<EOF unless $opt->{ui_blob_hidden};
<B>$msg1:</B> $blob_widget&nbsp;
<INPUT TYPE=checkbox NAME=mv_blob_only VALUE=1$checked>&nbsp;$msg2</SMALL>
EOF
			}

			$blob_widget = <<EOF unless $opt->{ui_blob_hidden};
<TR class=rnorm>
	 <td class=clabel width="$opt->{left_width}">
	   <SMALL>$opt->{mv_blob_title}<BR>
		$loaded_from
	 </td>
	 <td class=cwidget>
	 	$blob_widget&nbsp;
	 </td>
</TR>

<tr class=rtitle>
<td colspan=$span><img src="$opt->{clear_image}" width=1 height=3 alt=x></td>
</tr>
EOF

		if($opt->{mv_blob_nick}) {
			my @keys = split /::/, $opt->{mv_blob_nick};
			my $ref = $blob->{shift @keys};
			for(@keys) {
				my $prior = $ref;
				undef $ref;
				eval {
					$ref = $prior->{$_};
				};
				last DOBLOB unless ref $ref;
			}
			for(keys %$ref) {
				$data->{$_} = $ref->{$_};
			}
		}

		}
	}

#::logDebug("data is: " . ::uneval($data));
	$data = { $keycol => $key }
		if ! $data;

	if(! $opt->{mv_data_function}) {
		$opt->{mv_data_function} = $exists ? 'update' : 'insert';
	}

	my $url_base = $opt->{secure} ? $Vend::Cfg->{SecureURL} : $Vend::Cfg->{VendURL};

	$opt->{href} = "$url_base/ui" if ! $opt->{href};
	$opt->{href} = "$url_base/$opt->{href}"
		if $opt->{href} !~ m{^(https?:|)/};

	my $sidstr;
	if ($opt->{get}) {
		$opt->{method} = 'GET';
		$sidstr = '';
	} else {
		$opt->{method} = 'POST';
		$sidstr = qq{<INPUT TYPE=hidden NAME=mv_session_id VALUE="$Vend::Session->{id}">
};
	}

	my $wo = $opt->{widgets_only};

	my $restrict_begin;
	my $restrict_end;
	if($opt->{reparse} and ! $opt->{promiscuous}) {
		$restrict_begin = qq{[restrict allow="$opt->{restrict_allow}"]};
		$restrict_end = '[/restrict]';
	}

	no strict 'subs';

	chunk 'FORM_BEGIN', <<EOF; # unless $wo;
$restrict_begin<FORM METHOD=$opt->{method} ACTION="$opt->{href}"$opt->{enctype}$opt->{form_extra}>
EOF
	chunk 'HIDDEN_ALWAYS', <<EOF;
$sidstr<INPUT TYPE=hidden NAME=mv_todo VALUE="$opt->{action}">
<INPUT TYPE=hidden NAME=mv_click VALUE="process_filter">
<INPUT TYPE=hidden NAME=mv_nextpage VALUE="$opt->{mv_nextpage}">
<INPUT TYPE=hidden NAME=mv_data_table VALUE="$table">
<INPUT TYPE=hidden NAME=mv_data_key VALUE="$keycol">
EOF

	my @opt_set = (qw/
						ui_meta_specific
						ui_hide_key
						ui_meta_view
						ui_data_decode
						mv_blob_field
						mv_blob_label
						mv_blob_title
						mv_blob_pointer
						mv_update_empty
						mv_data_auto_number
						mv_data_function
				/ );

	my @cgi_set = ( qw/
						item_id_left
						ui_sequence_edit
					/ );

	push(@opt_set, splice(@cgi_set, 0)) if $opt->{cgi};

  OPTSET: {
  	my @o;
	for(@opt_set) {
		next unless length $opt->{$_};
		my $val = $opt->{$_};
		$val =~ s/"/&quot;/g;
		push @o, qq{<INPUT TYPE=hidden NAME=$_ VALUE="$val">\n}; # unless $wo;
	}
	chunk 'HIDDEN_OPT', '', join("", @o);
  }

  CGISET: {
	my @o;
	for (@cgi_set) {
		next unless length $CGI->{$_};
		my $val = $CGI->{$_};
		$val =~ s/"/&quot;/g;
		push @o, qq{<INPUT TYPE=hidden NAME=$_ VALUE="$val">\n}; # unless $wo;
	}
	chunk 'HIDDEN_CGI', '', join("", @o);
  }

	if($opt->{mailto}) {
		$opt->{mailto} =~ s/\s+/ /g;
		$::Scratch->{mv_email_enable} = $opt->{mailto};
		$opt->{hidden}{mv_data_email} = 1;
	}

	$Vend::Session->{ui_return_stack} ||= [];

	if($opt->{cgi}) {
		my $r_ary = $Vend::Session->{ui_return_stack};

#::logDebug("ready to maybe push/pop return-to from stack, stack = " . ::uneval($r_ary));
		if($CGI::values{ui_return_stack}++) {
			push @$r_ary, $CGI::values{ui_return_to};
			$CGI::values{ui_return_to} = $r_ary->[0];
		}
		elsif ($CGI::values{ui_return_to}) {
			@$r_ary = ( $CGI::values{ui_return_to} ); 
		}
		chunk 'RETURN_TO', '', $Tag->return_to(); # unless $wo;
#::logDebug("return-to stack = " . ::uneval($r_ary));
	}

	if(ref $opt->{hidden}) {
		my ($hk, $hv);
		my @o;
		while ( ($hk, $hv) = each %{$opt->{hidden}} ) {
			push @o, qq{<INPUT TYPE=hidden NAME="$hk" VALUE="$hv">\n};
		}
		chunk 'HIDDEN_USER', join("", @o); # unless $wo;
	}

	chunk ttag(), <<EOF; # unless $wo;
<table class=touter border="0" cellspacing="0" cellpadding="0" width="$opt->{table_width}">
<tr>
  <td>

<table class=tinner  width="$opt->{inner_table_width}" cellspacing=0 cellmargin=0 width="100%" cellpadding="2" align="center" border="0">
EOF
	chunk ttag(), 'NO_TOP', <<EOF; # unless $opt->{no_top} or $wo;
<tr class=rtitle> 
<td align=right colspan=$span><img src="$opt->{clear_image}" width=1 height=3 alt=x></td>
</tr>
EOF

	  #### Extra buttons
      my $extra_ok =	$blob_widget
	  					|| $linecount > 4
						|| defined $opt->{include_form}
						|| $mlabel;
	if ($extra_ok and ! $opt->{no_top} and ! $opt->{nosave}) {
	  	if($opt->{back_text}) {
		  chunk ttag(), '', <<EOF; # unless $wo;
<TR class=rnorm>
<td>&nbsp;</td>
<td align=left colspan=$oddspan class=cdata>
EOF
			chunk 'COMBINED_BUTTONS_TOP', 'BOTTOM_BUTTONS', <<EOF; # if ! $opt->{bottom_buttons};
<INPUT TYPE=submit NAME=mv_click VALUE="$opt->{back_text}">&nbsp;<INPUT TYPE=submit NAME=mv_click VALUE="$opt->{cancel_text}">&nbsp;<B><INPUT TYPE=submit NAME=mv_click VALUE="$opt->{next_text}"></B>
<BR>
EOF
			chunk 'MLABEL', '', 'MESSAGES', $mlabel;
			chunk ttag(), <<EOF;
</TD>
</TR>

<tr class=rspacer>
<td colspan=$span><img src="$opt->{clear_image}" width=1 height=3 alt=x></td>
</tr>
EOF
		}
		elsif ($opt->{wizard}) {
		  chunk ttag(), 'NO_TOP', <<EOF;
<TR class=rnorm>
<td>&nbsp;</td>
<td align=left colspan=$oddspan class=cdata>
EOF
			chunk 'WIZARD_BUTTONS_TOP', 'BOTTOM_BUTTONS NO_TOP', <<EOF; # if ! $opt->{bottom_buttons};
<INPUT TYPE=submit NAME=mv_click VALUE="$opt->{cancel_text}">&nbsp;<B><INPUT TYPE=submit NAME=mv_click VALUE="$opt->{next_text}"></B>
<BR>
EOF
			chunk 'MLABEL', 'BOTTOM_BUTTONS', 'MESSAGES', $mlabel;
			chunk ttag(), <<EOF;
</TD>
</TR>

<tr class=rspacer>
<td colspan=$span><img src="$opt->{clear_image}" width=1 height=3 alt=x></td>
</tr>
EOF
		}
		else {
		  chunk ttag(), 'BOTTOM_BUTTONS NO_TOP', <<EOF;
<TR class=rnorm>
<td>&nbsp;</td>
<td align=left colspan=$oddspan class=cdata>
EOF

		  $opt->{ok_button_style} = 'font-weight: bold; width: 40px; text-align: center'
		  	unless defined $opt->{ok_button_style};
		  	
		  chunk 'OK_TOP', 'NO_TOP', <<EOF;
<INPUT TYPE=submit NAME=mv_click VALUE="$opt->{next_text}" style="$opt->{ok_button_style}">
EOF
		  chunk 'CANCEL_TOP', 'NOCANCEL BOTTOM_BUTTONS NO_TOP', <<EOF;
&nbsp;
<INPUT TYPE=submit NAME=mv_click VALUE="$opt->{cancel_text}" style="$opt->{cancel_button_style}">
EOF

		  chunk 'RESET_TOP', '_SHOW_RESET BOTTOM_BUTTONS NO_TOP', <<EOF;
&nbsp;
<INPUT TYPE=reset>
EOF

			chunk 'MLABEL', 'BOTTOM_BUTTONS', $mlabel;
			chunk ttag(), 'BOTTOM_BUTTONS NO_TOP', <<EOF;
</TD>
</TR>

<tr class=rspacer>
<td colspan=$span><img src="$opt->{clear_image}" width=1 height=3 alt=x></td>
</tr>
EOF
		}
	}

	chunk 'BLOB_WIDGET', $blob_widget; # unless $wo;

	  #### Extra buttons

	if($opt->{ui_new_item} and $opt->{ui_clone_tables}) {
		my @sets;
		my %seen;
		my @tables = split /[\s\0,]+/, $opt->{ui_clone_tables};
		for(@tables) {
			if(/:/) {
				push @sets, $_;
			}
			s/:.*//;
		}

		my %tab_checked;
		for(@tables, @sets) {
			$tab_checked{$_} = 1 if s/\*$//;
		}

		@tables = grep ! $seen{$_}++ && defined $Vend::Cfg->{Database}{$_}, @tables;

		my $tab = '';
		my $set .= <<'EOF';
[flag type=write table="_TABLES_"]
[perl tables="_TABLES_"]
	delete $::Scratch->{clone_tables};
	return if ! $CGI->{ui_clone_id};
	return if ! $CGI->{ui_clone_tables};
	my $id = $CGI->{ui_clone_id};

	my $out = "Cloning id=$id...";

	my $new =  $CGI->{$CGI->{mv_data_key}}
		or do {
				$out .= ("clone $id: no mv_data_key '$CGI->{mv_data_key}'");
				$::Scratch->{ui_message} = $out;
				return;
		};

	if($new =~ /\0/) {
		$new =~ s/\0/,/g;
		Log("cannot clone multiple keys '$new'.");
		return;
	}

	my %possible;
	my @possible = qw/_TABLES_/;
	@possible{@possible} = @possible;
	my @tables = grep /\S/, split /[\s,\0]+/, $CGI->{ui_clone_tables};
	my @sets = grep /:/, @tables;
	@tables = grep $_ !~ /:/, @tables;
	for(@tables) {
		next unless $possible{$_};
		my $db = database_exists_ref($_);
		next unless $db;
		my $new = 
		my $res = $db->clone_row($id, $new);
		if($res) {
			$out .= "cloned $id to to $new in table $_<BR>\n";
		}
		else {
			$out .= "FAILED clone of $id to to $new in table $_<BR>\n";
		}
	}
	for(@sets) {
		my ($t, $col) = split /:/, $_;
		my $db = database_exists_ref($t) or next;
		my $res = $db->clone_set($col, $id, $new);
		if($res) {
			$out .= "cloned $col=$id to to $col=$new in table $t<BR>\n";
		}
		else {
			$out .= "FAILED clone of $col=$id to to $col=$new in table $t<BR>\n";
		}
	}
	$::Scratch->{ui_message} = $out;
	return;
[/perl]
EOF
		my $tabform = '';
		@tables = grep $Tag->if_mm( { table => "$_=i" } ), @tables;

		for(@tables) {
			my $db = Vend::Data::database_exists_ref($_)
				or next;
			next unless $db->record_exists($opt->{ui_clone_id});
			my $checked = $tab_checked{$_} ? ' CHECKED' : '';
			$tabform .= <<EOF;
<INPUT TYPE=CHECKBOX NAME=ui_clone_tables VALUE="$_"$checked> clone to <b>$_</B><BR>
EOF
		}
		for(@sets) {
			my ($t, $col) = split /:/, $_;
			my $checked = $tab_checked{$_} ? ' CHECKED' : '';
			$tabform .= <<EOF;
<INPUT TYPE=CHECKBOX NAME=ui_clone_tables VALUE="$_"$checked> clone entries of <b>$t</B> matching on <B>$col</B><BR>
EOF
		}

		my $tabs = join " ", @tables;
		$set =~ s/_TABLES_/$tabs/g;
		$::Scratch->{clone_tables} = $set;
		chunk ttag(), <<EOF; # unless $wo;
<tr class=rtitle>
<td colspan=$span>
EOF
		chunk 'CLONE_TABLES', <<EOF;
$tabform<INPUT TYPE=hidden NAME=mv_check VALUE="clone_tables">
<INPUT TYPE=hidden NAME=ui_clone_id VALUE="$opt->{ui_clone_id}">
EOF
		chunk ttag(), <<EOF; # unless $wo;
</td>
</tr>
EOF
	}

	chunk_alias 'TOP_OF_FORM', qw/ FORM_BEGIN /;
	chunk_alias 'TOP_BUTTONS', qw/
								COMBINED_BUTTONS_TOP
								WIZARD_BUTTONS_TOP
								OK_TOP
								CANCEL_TOP
								RESET_TOP
								BLOB_WIDGET
								CLONE_TABLES
								/;

	my %break;
	my %break_label;
	if($opt->{ui_break_before}) {
		my @tmp = grep /\S/, split /[\s,\0]+/, $opt->{ui_break_before};
		@break{@tmp} = @tmp;
		if($opt->{ui_break_before_label}) {
			@tmp = grep /\S/, split /\s*[,\0]\s*/, $opt->{ui_break_before_label};
			for(@tmp) {
				my ($br, $lab) = split /\s*=\s*/, $_;
				$break_label{$br} = $lab;
			}
		}
	}
	if(!$db and ! $opt->{notable}) {
		return "<TR><TD>Broken table '$table'</TD></TR>";
	}

	my $passed_fields = $opt->{ui_data_fields};

	my @extra_cols;
	my %email_cols;
	my %ok_col;
	my @cols;
	my @dbcols;
	my %display_only;

	if($opt->{notable}) {
		@cols = split /[\s,\0]+/, $passed_fields;
	}
	else {

	while($passed_fields =~ s/(\w+[.:]+\S+)//) {
		push @extra_cols, $1;
	}

	my @do = grep /\S/, split /[\0,\s]+/, $opt->{ui_display_only};
	for(@do) {
#::logDebug("display_only: $_");
		$email_cols{$_} = 1 if $opt->{mailto};
		$display_only{$_} = 1;
		push @extra_cols, $_;
	}

		@dbcols  = split /\s+/, $Tag->db_columns( {
										name	=> $table,
										columns	=> $passed_fields,
										passed_order => 1,
									});

	if($opt->{ui_data_fields}) {
		for(@dbcols, @extra_cols) {
			unless (/^(\w+)([.:]+)(\S+)/) {
				$ok_col{$_} = 1;
				next;
			}
			my $t = $1;
			my $s = $2;
			my $c = $3;
			if($s eq '.') {
				$c = $t;
				$t = $table;
			}
			else {
				$c =~ s/\..*//;
			}
			next unless $Tag->db_columns( { name	=> $t, columns	=> $c, });
			$ok_col{$_} = 1;
		}
	}
	@cols = grep $ok_col{$_}, split /\s+/, $opt->{ui_data_fields};
	}

	$keycol = $cols[0] if ! $keycol;

	if($opt->{defaults}) {
			if($opt->{force_defaults}) {
			$default->{$_} = $def->{$_} for @cols;
			}
			elsif($opt->{wizard}) {
			for(@cols) {
				$default->{$_} = $def->{$_} if defined $def->{$_};
			}
		}
			else {
			for(@cols) {
				next if defined $default->{$_};
				next unless defined $def->{$_};
				$default->{$_} = $def->{$_};
			}
		}
	}

	my $super = $Tag->if_mm('super');

	my $refkey = $key;

	my @data_enable = ($opt->{mv_blob_pointer}, $opt->{mv_blob_field});
	my @ext_enable;

	if($opt->{left_width} and ! $opt->{label_cell_width}) {
		$opt->{label_cell_extra} .= qq{ width="$opt->{left_width}"};
	}

	my $show_meta;
	if($super and ! $opt->{no_meta}) {
		$show_meta = defined $def->{ui_meta_force}
					?  $def->{ui_meta_force}
					: $::Variable->{UI_META_LINK};
	}

	if($show_meta) {
		if(! $opt->{row_template} and ! $opt->{simple_row}) {
			$opt->{meta_prepend} = '<br><font size=1>'
				unless defined $opt->{meta_prepend};

			$opt->{meta_append} = '</font>'
				unless defined $opt->{meta_append};
		}
		else {
			$opt->{meta_prepend} ||= '';
			$opt->{meta_append} ||= '';
		}
		$opt->{meta_anchor} ||= errmsg('meta');
		$opt->{meta_anchor_specific} ||= errmsg('item-specific meta');
		$opt->{meta_extra} = " $opt->{meta_extra}"
			if $opt->{meta_extra};
		$opt->{meta_extra} ||= "";
		$opt->{meta_extra} .= qq{ class="$opt->{meta_class}"}
			if $opt->{meta_class};
		$opt->{meta_extra} .= qq{ class="$opt->{meta_style}"}
			if $opt->{meta_style};
	}

 	my $row_template = convert_old_template($opt->{row_template});
	
	if(! $row_template) {
		if($opt->{simple_row}) {
			$row_template = <<EOF;
   <td$opt->{label_cell_extra}> 
     {BLABEL}{LABEL}{ELABEL}
   </td>
   <td$opt->{data_cell_extra}>{WIDGET}{HELP_EITHER?}&nbsp;<a href="{HELP_URL}" title="{HELP}">$opt->{help_anchor}</a>{/HELP_EITHER?}&nbsp;{META_URL?}<A HREF="{META_URL}">$opt->{meta_anchor}</A>{/META_URL?}
   </td>
EOF
		}
		else {
			$row_template = <<EOF;
   <td$opt->{label_cell_extra}> 
     {BLABEL}{LABEL}{ELABEL}{META_STRING}
   </td>
   <td$opt->{data_cell_extra}>
     <table cellspacing=0 cellmargin=0 width="100%">
       <tr> 
         <td$opt->{widget_cell_extra}>
           {WIDGET}
         </td>
         <td$opt->{help_cell_extra}>{TKEY}{HELP?}<i>{HELP}</i>{/HELP?}{HELP_URL?}<BR><A HREF="{HELP_URL}">$opt->{help_anchor}</A>{/HELP_URL?}</td>
       </tr>
     </table>
   </td>
EOF
		}
	}

	$row_template =~ s/~OPT:(\w+)~/$opt->{$1}/g;
	$row_template =~ s/~([A-Z]+)_EXTRA~/$opt->{"\L$1\E_extra"} || $opt->{"\L$1\E_cell_extra"}/g;

	$opt->{row_template} = $row_template;

	$opt->{combo_template} ||= <<EOF;
<tr$opt->{combo_row_extra}><td> {LABEL} </td><td>{WIDGET}</td></tr>
EOF

	$opt->{break_template} ||= <<EOF;
<tr$opt->{break_row_extra}><td colspan=$span $opt->{break_cell_extra}>{ROW}</td></tr>
EOF

	my %serialize;
	my %serial_data;

	if(my $jsc = $opt->{js_changed}) {
		$jsc =~ /^\w+$/
			and $jsc = qq{onChange="$jsc} . q{('$$KEY$$','$$COL$$');"};
		foreach my $c (@cols) {
			next if $extra->{$c} =~ /\bonchange\s*=/i;
			my $tpl = $jsc;
			$tpl .= $extra->{$c} if length $extra->{$c};
			$tpl =~ s/\$\$KEY\$\$/$key/g;
			$tpl =~ s/\$\$COL\$\$/$c/g;
			if ($extra->{$c} and $extra->{$c} =~ /\bonchange\s*=/i) {
				$tpl =~ s/onChange="//;
				$tpl =~ s/"\s*$/;/;
				$extra->{$c} =~ s/\b(onchange\s*=\s*["'])/$1$tpl/i;
			}
			else {
				$extra->{$c} = $tpl;
			}
		}
	}

	my %link_row;
	my %link_before;
	if($opt->{link_table} and $key) {
#::logDebug("In link table routines...");
		my @ltable;
		my @lfields;
		my @lkey;
		my @lview;
		my @llab;
		my @ltpl;
		my @lbefore;
		my @lsort;
		my $tcount = 1;
		if(ref($opt->{link_table}) eq 'ARRAY') {
			@ltable  = @{$opt->{link_table}};
			@lfields = @{$opt->{link_fields}};
			@lview   = @{$opt->{link_view}};
			@lkey    = @{$opt->{link_key}};
			@llab    = @{$opt->{link_label}};
			@ltpl    = @{$opt->{link_template}};
			@lbefore = @{$opt->{link_before}};
			@lsort   = @{$opt->{link_sort}};
		}
		else {
			@ltable  = $opt->{link_table};
			@lfields = $opt->{link_fields};
			@lview   = $opt->{link_view};
			@lkey    = $opt->{link_key};
			@llab    = $opt->{link_label};
			@ltpl    = $opt->{link_template};
			@lbefore = $opt->{link_before};
			@lsort   = $opt->{link_sort};
		}
		while(my $lt = shift @ltable) {
			my $lf = shift @lfields;
			my $lv = shift @lview;
			my $lk = shift @lkey;
			my $ll = shift @llab;
			my $lb = shift @lbefore;
			my $ls = shift @lsort;

			my $rcount = 0;

			$ll ||= errmsg("Settings in table %s linked by %s", $lt, $lk);

			my $whash = {};

			my $ldb = database_exists_ref($lt)
				or do {
					logError("Bad table editor link table: %s", $lt);
					next;
				};

			my $lmeta = $Tag->meta_record($lt, $lv);
			$lf ||= $lmeta->{spread_fields};

			my $l_pkey = $ldb->config('KEY');

			my @cf = grep /\S/, split /[\s,\0]+/, $lf;
			@cf = grep $_ ne $l_pkey, @cf;
			$lf = join " ", @cf;
			my $lextra = $opt->{link_extra} || '';
			$lextra = " $lextra" if $lextra;

			my @lout = q{<table cellspacing=0 cellpadding=1>};
			push @lout, qq{<tr><td$lextra>
<input type=hidden name="mv_data_table__$tcount" value="$lt">
<input type=hidden name="mv_data_fields__$tcount" value="$lf">
<input type=hidden name="mv_data_multiple__$tcount" value="1">
<input type=hidden name="mv_data_key__$tcount" value="$l_pkey">
$l_pkey</td>};
			push @lout, $Tag->row_edit({ table => $lt, columns => $lf });
			push @lout, '</tr>';

			my $tname = $ldb->name();
			my $lfor = $key;
			$lfor = $ldb->quote($key, $lk);
			my $q = "SELECT $l_pkey FROM $tname WHERE $lk = $lfor";
			$q .= " ORDER BY $ls" if $ls;
			my $ary = $ldb->query($q);
			for(@$ary) {
				my $rk = $_->[0];
				my $pp = $rcount ? "${rcount}_" : '';
				my $hid = qq{<input type=hidden name="$pp${l_pkey}__$tcount" value="};
				$hid .= HTML::Entities::encode($rk);
				$hid .= qq{">};
				push @lout, qq{<tr><td$lextra>$rk$hid</td>};
				my %o = (
					table => $lt,
					key => $_->[0],
					extra => $opt->{link_extra},
					pointer => $rcount,
					stacker => $tcount,
					columns => $lf,
					extra => $opt->{link_extra},
				);
				$rcount++;
				push @lout, $Tag->row_edit(\%o);
				push @lout, "</tr>";
			}
			my %o = (
				table => $lt,
				blank => 1,
				extra => $opt->{link_extra},
				pointer => 999999,
				stacker => $tcount,
				columns => $lf,
				extra => $opt->{link_extra},
			);
			push @lout, qq{<tr><td$lextra>};
			push @lout, qq{<input size=8 name="999999_${l_pkey}__$tcount" value="">};
			push @lout, '</td>';
			push @lout, $Tag->row_edit(\%o);
			push @lout, '</tr>';
			push @lout, "</table>";
			$whash->{LABEL}  = $ll;
			$whash->{WIDGET} = join "", @lout;
			my $murl = '';
			if($show_meta) {
				my $murl;
				$murl = $Tag->area({
							href => 'admin/db_metaconfig_spread',
							form => qq(
									ui_table=$lt
									ui_view=$lv
								),
							});
				$whash->{META_URL} = $murl;
				$whash->{META_STRING} = qq{<a href="$murl"$opt->{meta_extra}>};
				$whash->{META_STRING} .= errmsg('meta') . '</a>';

			}
			$whash->{ROW} = 1;
			$link_row{$lt} = $whash;
			if($lb) {
				$link_before{$lb} = $lt;
			}
			my $mde_key = "mv_data_enable__$tcount";
			$::Scratch->{$mde_key} = "$lt:" . join(",", $l_pkey, @cf) . ':';
			$tcount++;
#::logDebug("Made link_table...whash=$whash");
		}
	}

	if($opt->{include_form}) {
#::logDebug("In link table routines...");
		my @icells;
		my @ibefore;
		my $tcount = 1;
		my @includes;
		if(ref($opt->{include_form}) eq 'ARRAY') {
			@icells  = @{delete $opt->{include_form}};
			@ibefore = @{delete $opt->{include_before} || []};
		}
		else {
			@icells  = delete $opt->{include_form};
			@ibefore = delete $opt->{include_before};
		}

		$opt->{include_before} = {};
		while(my $it = shift @icells) {
			my $ib = shift @ibefore;

			my $rcount = 0;

#::logDebug("Made include_before=$it");
			if($ib) {
				$opt->{include_before}{$ib} = $it;
			}
			elsif($it =~ /^\s*<tr\b/i) {
				push @includes, $it;
			}
			else {
				push @includes, "<tr>$it</tr>";
			}
		}
		$opt->{include_form} = join "\n", @includes if @includes;
	}

    if($opt->{tabbed}) {
        my $ph = $opt->{panel_height} || '600';
        my $pw = $opt->{panel_width} || '800';
        my $th = $opt->{tab_height} || '30';
        my $oh = $ph + $th;
        my $extra = $Vend::Session->{browser} =~ /Gecko/
                  ? ''
                  : " width=$pw height=$oh";
        chunk ttag(), qq{<tr><td colspan=$span$extra>\n};
    }

#::logDebug("include_before: " . uneval($opt->{include_before}));

	my @extra_hidden;
	my $icount = 0;
	foreach my $col (@cols) {
		my $t;
		my $c;
		my $k;
		my $tkey_message;
		if($col eq $keycol) {
			if($opt->{ui_hide_key}) {
				my $kval = $key || $override->{$col} || $default->{$col};
				push @extra_hidden,
					qq{<INPUT TYPE=hidden NAME="$col" VALUE="$kval">};
				if($break{$col}) {
					$titles[$ctl_index] = $break_label{$col};
				}
				next;
			}
			elsif ($opt->{ui_new_item}) {
				$tkey_message = $key_message;
			}
		}

		my $w = '';
		my $do = $display_only{$col};
		
		my $currval;
		my $serialize;

		if($col =~ /(\w+):+([^:]+)(?::+(\S+))?/) {
			$t = $1;
			$c = $2;
			$c =~ /(.+?)\.\w.*/
				and $col = "$t:$1"
					and $serialize = $c;
			$k = $3 || undef;
			push @ext_enable, ("$t:$c" . $k ? ":$k" : '')
				unless $do;
		}
		else {
			$t = $table;
			$c = $col;
			$c =~ /(.+?)\.\w.*/
				and $col = $1
					and $serialize = $c;
			push @data_enable, $col
				unless $do and ! $opt->{mailto};
		}

		my $type;
		my $overridden;

		$currval = $data->{$col} if defined $data->{$col};
		if ($opt->{force_defaults} or defined $override->{$c} ) {
			$currval = $override->{$c};
			$overridden = 1;
#::logDebug("hit override for $col,currval=$currval");
		}
		elsif (defined $CGI->{"ui_preload:$t:$c"} ) {
			$currval = delete $CGI->{"ui_preload:$t:$c"};
			$overridden = 1;
#::logDebug("hit preload for $col,currval=$currval");
		}
		elsif( ($do && ! $currval) or $col =~ /:/) {
			if(defined $k) {
				my $check = $k;
				undef $k;
				for( $override, $data, $default) {
					next unless defined $_->{$check};
					$k = $_->{$check};
					last;
				}
			}
			else {
				$k = defined $key ? $key : $refkey;
			}
			$currval = tag_data($t, $c, $k) if defined $k;
#::logDebug("hit display_only for $col, t=$t, c=$c, k=$k, currval=$currval");
		}
		elsif (defined $default->{$c} and ! length($data->{$c}) ) {
			$currval = $default->{$c};
#::logDebug("hit preload for $col,currval=$currval");
		}
		else {
#::logDebug("hit data->col for $col, t=$t, c=$c, k=$k, currval=$currval");
			$currval = length($data->{$col}) ? $data->{$col} : '';
			$overridden = 1;
		}

		my $namecol;
		if($serialize) {
#Debug("serialize=$serialize");
			if($serialize{$col}) {
				push @{$serialize{$col}}, $serialize;
			}
			else {
				my $sd;
				if($col =~ /:/) {
					my ($tt, $tc) = split /:+/, $col;
					$sd = tag_data($tt, $tc, $k);
				}
				else {
					$sd = $data->{$col} || $def->{$col};
				}
#Debug("serial_data=$sd");
				$serial_data{$col} = $sd;
				$opt->{hidden}{$col} = $data->{$col};
				$serialize{$col} = [$serialize];
			}
			$c =~ /\.(.*)/;
			my $hk = $1;
#Debug("fetching serial_data for $col hk=$hk data=$serial_data{$col}");
			$currval = dotted_hash($serial_data{$col}, $hk);
#Debug("fetched hk=$hk value=$currval");
			$overridden = 1;
			$namecol = $c = $serialize;
		}

		$namecol = $col unless $namecol;

#::logDebug("display_only=$do col=$c");
		$type = $widget->{$c} = 'value' if $do and ! ($opt->{wizard} || $opt->{mailto});

		if (! length $currval and defined $default->{$c}) {
			$currval = $default->{$c};
		}

		$template->{$c} ||= $row_template;

		my $err_string;
		if($error->{$c}) {
			my $parm = {
					name => $c,
					std_label => '$LABEL$',
					required => 1,
					};
			if($opt->{all_errors}) {
				$parm->{keep} = 1;
				$parm->{text} = <<EOF;
<FONT COLOR="$opt->{color_fail}">\$LABEL\$</FONT><!--%s-->
[else]{REQUIRED <B>}{LABEL}{REQUIRED </B>}[/else]
EOF
			}
			$err_string = $Tag->error($parm);
			if($template->{$c} !~ /{ERROR\??}/) {
				$template->{$c} =~ s/{LABEL}/$err_string/g
					and
				$template->{$c} =~ s/\$LABEL\$/{LABEL}/g;
			}
		}

		my $meta_string = '';
		my $meta_url;
		my $meta_url_specific;
		if($show_meta) {
			# Get global variables
			my $base = $::Variable->{UI_BASE}
					 || $Global::Variable->{UI_BASE} || 'admin';
			my $page = $Global::Variable->{MV_PAGE};
			my $id = $t . "::$c";
			$id = $opt->{ui_meta_view} . "::$id"
				if $opt->{ui_meta_view} and $opt->{ui_meta_view} ne 'metaconfig';

			my $return = <<EOF;
ui_return_to=$page
ui_return_to=item_id=$opt->{item_id}
ui_return_to=ui_meta_view=$opt->{ui_meta_view}
ui_return_to=mv_return_table=$t
mv_return_table=$table
ui_return_stack=$CGI->{ui_return_stack}
EOF

			$meta_url = $Tag->area({
								href => "$base/meta_editor",
								form => qq{
											item_id=$id
											$return
										}
							});
			my $meta_specific = '';
			if($opt->{ui_meta_specific}) {
				$meta_url_specific = $Tag->area({
										href => "$base/meta_editor",
										form => qq{
													item_id=${t}::${c}::$key
													$return
												}
										});
				$meta_specific = <<EOF;
<br><a href="$meta_url_specific"$opt->{meta_extra}>$opt->{meta_anchor_specific}</A>
EOF
			}
								
			$opt->{meta_append} = '</FONT>'
				unless defined $opt->{meta_append};
			$meta_string = <<EOF;
$opt->{meta_prepend}<a href="$meta_url"$opt->{meta_extra}>$opt->{meta_anchor}</A>
$meta_specific$opt->{meta_append}
EOF
		}

#::logDebug("col=$c currval=$currval widget=$widget->{$c} label=$label->{$c} (type=$type)");
		my $display = display($t, $c, $key, {
										applylocale => 1,
										arbitrary => $opt->{ui_meta_view},
										column => $c,
										default => $currval,
										extra => $extra->{$c},
										fallback => 1,
										field => $field->{$c},
										filter => $filter->{$c},
										height => $height->{$c},
										help => $help->{$c},
										help_url => $help_url->{$c},
										label => $label->{$c},
										key => $key,
										meta => $meta->{$c},
										meta_url => $meta_url,
										meta_url_specific => $meta_url_specific,
										name => $namecol,
										override => $overridden,
										passed => $passed->{$c},
										options => $options->{$c},
										outboard => $outboard->{$c},
										append => $append->{$c},
										prepend => $prepend->{$c},
										lookup => $lookup->{$c},
										lookup_query => $lookup_query->{$c},
										db => $database->{$c},
										pre_filter => $pre_filter->{$c},
										table => $t,
										type => $widget->{$c} || $type,
										width => $width->{$c},
										return_hash => 1,
										ui_no_meta_display => $opt->{ui_no_meta_display},
									});
#::logDebug("finished display of col=$c");
		my $update_ctl;

		if ($display->{WIDGET} =~ /^\s*<input\s[^>]*type\s*=\W*hidden\b[^>]*>\s*$/is) {
			push @extra_hidden, $display->{WIDGET};
			next;
		}
		$display->{TEMPLATE} = $template->{$c};
		$display->{META_STRING} = $meta_string;
		$display->{TKEY}   = $tkey_message;
		$display->{BLABEL} = $blabel;
		$display->{ELABEL} = $elabel;
		$display->{ERROR}  = $err_string;

		$update_ctl = 0;
		if ($break{$namecol}) {
#::logDebug("breaking on $namecol, control index=$ctl_index");
			if(@controls == 0 and @titles == 0) {
				$titles[0] = $break_label{$namecol};
			}
			elsif(@titles == 0) {
				$titles[1] = $break_label{$namecol};
				$update_ctl = 1;
			}
			else {
				push @titles, $break_label{$namecol};
				$update_ctl = 1;
			}
		}
		if($link_before{$col}) {
			col_chunk "_SPREAD_$link_before{$col}",
						delete $link_row{$link_before{$col}};
		}
		if($opt->{include_before} and $opt->{include_before}{$col}) {
#::logDebug("include_before: $col $opt->{include_before}{$col}");
			my $h = { ROW => delete $opt->{include_before}{$col} };
			$h->{TEMPLATE} = $opt->{whole_template} || '<tr>{ROW}</tr>';
			col_chunk "_INCLUDE_$col", $h;
		}
		$ctl_index++ if $update_ctl;
		if($opt->{start_at} and $opt->{start_at} eq $namecol) {
			$opt->{start_at_index} = $ctl_index;
#::logDebug("set start_at_index to $ctl_index");
		}
#::logDebug("control index now=$ctl_index");
		col_chunk $namecol, $display;
	}

	for(sort keys %link_row) {
#::logDebug("chunking link_table to _SPREAD_$_");
		col_chunk "_SPREAD_$_", delete $link_row{$_};
	}

	my $firstout = scalar(@out);

	if($opt->{tabbed}) {
		chunk ttag(), qq{</td></tr>\n};
	}

	while($rowcount % $rowdiv) {
		chunk ttag(), '<td colspan=$cells_per_span>&nbsp;</td>'; # unless $wo;
		$rowcount++;
	}

	$::Scratch->{mv_data_enable} = '';
	if($opt->{auto_secure}) {
		$::Scratch->{mv_data_enable} .= "$table:" . join(",", @data_enable) . ':';
		$::Scratch->{mv_data_enable_key} = $opt->{item_id};
	}
	if(@ext_enable) {
		$::Scratch->{mv_data_enable} .= " " . join(" ", @ext_enable) . " ";
	}
#Debug("setting mv_data_enable to $::Scratch->{mv_data_enable}");
	my @serial = keys %serialize;
	my @serial_fields;
	my @o;
	for (@serial) {
#Debug("$_ serial_data=$serial_data{$_}");
		$serial_data{$_} = uneval($serial_data{$_})
			if is_hash($serial_data{$_});
		$serial_data{$_} =~ s/\&/&amp;/g;
		$serial_data{$_} =~ s/"/&quot;/g;
		push @o, qq{<INPUT TYPE=hidden NAME="$_" VALUE="$serial_data{$_}">}; # unless $wo;
		push @serial_fields, @{$serialize{$_}};
	}

	if(! $wo and @serial_fields) {
		push @o, qq{<INPUT TYPE=hidden NAME="ui_serial_fields" VALUE="};
		push @o, join " ", @serial_fields;
		push @o, qq{">};
		chunk 'SERIAL_FIELDS', join("", @o);
	}

	###
	### Here the user can include some extra stuff in the form....
	###
	if($opt->{include_form}) {
		col_chunk '_INCLUDE_FORM',
					{
						ROW => $opt->{include_form},
						TEMPLATE => $opt->{whole_template} || '<tr>{ROW}</tr>',
					};
	}
	### END USER INCLUDE

	unless ($opt->{mailto} and $opt->{mv_blob_only}) {
		@cols = grep ! $display_only{$_}, @cols;
	}
	$passed_fields = join " ", @cols;


	chunk ttag(), <<EOF;
<tr class=rspacer>
<td colspan=$span>
EOF
	chunk 'HIDDEN_EXTRA', <<EOF; # unless $wo;
<INPUT TYPE=hidden NAME=mv_data_fields VALUE="$passed_fields">@extra_hidden
EOF
	chunk ttag(), <<EOF;
<img src="$opt->{clear_image}" height=3 alt=x></td>
</tr>
EOF

  SAVEWIDGETS: {
  	last SAVEWIDGETS if $wo || $opt->{nosave}; 
#::logDebug("in SAVEWIDGETS");
		chunk ttag(), <<EOF;
<TR class=rnorm>
<td>&nbsp;</td>
<td align=left colspan=$oddspan class=cdata>
EOF


	  	if($opt->{back_text}) {

			chunk 'COMBINED_BUTTONS_BOTTOM', <<EOF;
<INPUT TYPE=submit NAME=mv_click VALUE="$opt->{back_text}">&nbsp;<INPUT TYPE=submit NAME=mv_click VALUE="$opt->{cancel_text}">&nbsp;<B><INPUT TYPE=submit NAME=mv_click VALUE="$opt->{next_text}"></B>
EOF
		}
		elsif($opt->{wizard}) {
			chunk 'WIZARD_BUTTONS_BOTTOM', <<EOF;
<TR class=rnorm>
<td>&nbsp;</td>
<td align=left colspan=$oddspan class=cdata>
<INPUT TYPE=submit NAME=mv_click VALUE="$opt->{cancel_text}">&nbsp;<B><INPUT TYPE=submit NAME=mv_click VALUE="$opt->{next_text}"></B>
EOF
		}
		else {
			chunk 'OK_BOTTOM', <<EOF;
<INPUT TYPE=submit NAME=mv_click VALUE="$opt->{next_text}" style="$opt->{ok_button_style}">
EOF

			chunk 'CANCEL_BOTTOM', 'NOCANCEL', <<EOF;
&nbsp;<INPUT TYPE=submit NAME=mv_click VALUE="$opt->{cancel_text}" style="$opt->{cancel_button_style}">
EOF

			chunk 'RESET_BOTTOM', qq{&nbsp;<INPUT TYPE=reset>}
				if $opt->{show_reset};
		}

	if(! $opt->{notable} and $Tag->if_mm('tables', "$table=x") and ! $db->config('LARGE') ) {
		my $checked = ' CHECKED';
		$checked = ''
			if defined $opt->{mv_auto_export} and ! $opt->{mv_auto_export};
		my $autoexpstr = errmsg('Auto-export');		
		chunk 'AUTO_EXPORT', 'NOEXPORT NOSAVE', <<EOF; # unless $opt->{noexport} or $opt->{nosave};
<small>
&nbsp;
&nbsp;
&nbsp;
&nbsp;
&nbsp;
	<INPUT TYPE=checkbox NAME=mv_auto_export VALUE="$table"$checked>&nbsp;$autoexpstr
EOF

	}

	if($exists and ! $opt->{nodelete} and $Tag->if_mm('tables', "$table=d")) {
		my $extra = $Tag->return_to( { type => 'click', tablehack => 1 });
		my $page = $CGI->{ui_return_to};
		$page =~ s/\0.*//s;
		my $url = $Tag->area( {
					href => $page,
					form => qq!
						deleterecords=1
						ui_delete_id=$key
						mv_data_table=$table
						mv_click=db_maintenance
						mv_action=back
						$extra
					!,
					});
		my $delstr = errmsg('Delete');
		my $delmsg = errmsg('Are you sure you want to delete %s?',$key);
		chunk 'DELETE_BUTTON', 'NOSAVE', <<EOF; # if ! $opt->{nosave};
<BR><BR><A
onClick="return confirm('$delmsg')"
HREF="$url"><IMG SRC="delete.gif" ALT="Delete $key" BORDER=0></A> $delstr
EOF

	}
	chunk_alias 'HIDDEN_FIELDS', qw/
										HIDDEN_ALWAYS
										HIDDEN_OPT
										HIDDEN_CGI
										HIDDEN_USER
										HIDDEN_EXTRA
										/;
	chunk_alias 'BOTTOM_BUTTONS', qw/
										WIZARD_BUTTONS_BOTTOM
										COMBINED_BUTTONS_BOTTOM
										OK_BOTTOM
										CANCEL_BOTTOM
										RESET_BOTTOM
										AUTO_EXPORT
										DELETE_BUTTON/;
	chunk ttag(), <<EOF;
</small>
</td>
</tr>
EOF
  } # end SAVEWIDGETS

	my $message = '';

	if(@errors) {
		$message .= '<P>Errors:';
		$message .= qq{<FONT COLOR="$opt->{color_fail}">};
		$message .= '<BLOCKQUOTE>';
		$message .= join "<BR>", @errors;
		$message .= '</BLOCKQUOTE></FONT>';
	}
	if(@messages) {
		$message .= '<P>Messages:';
		$message .= qq{<FONT COLOR="$opt->{color_success}">};
		$message .= '<BLOCKQUOTE>';
		$message .= join "<BR>", @messages;
		$message .= '</BLOCKQUOTE></FONT>';
	}
	$Tag->error( { all => 1 } );

	chunk ttag(), 'NO_BOTTOM _MESSAGE', <<EOF;
<tr class=rtitle>
	<td colspan=$span>
EOF

	chunk 'MESSAGE_TEXT', 'NO_BOTTOM', $message; # unless $wo or ($opt->{no_bottom} and ! $message);

	chunk ttag(), 'NO_BOTTOM _MESSAGE', <<EOF;
	</td>
</tr>
EOF

#::logDebug("tcount=$tcount_all, prior to closing table");
	chunk ttag(), <<EOF; # unless $wo;
</table>
</td></tr></table>
EOF

	chunk 'FORM_END', '', 'BOTTOM_OF_FORM', <<EOF;
</form>$restrict_end
EOF

	my %ehash = (
	);
	for(qw/
		BOTTOM_BUTTONS
		NOCANCEL
		NOEXPORT
		NOSAVE
		NO_BOTTOM
		NO_TOP
		SHOW_RESET
		/)
	{
		$ehash{$_} = $opt->{lc $_} ? 1 : 0;
	}

	$ehash{MESSAGE} = length($message) ? 1 : 0;

#::logDebug("exclude is " . uneval(\%exclude));
	resolve_exclude(\%ehash);

	if($wo) {
		return (map { @$_ } @controls) if wantarray;
		return join "", map { @$_ } @controls;
	}
show_times("end table editor call item_id=$key") if $Global::ShowTimes;

	my @put;
	if($overall_template) {
		my $death = sub {
			my $item = shift;
			logDebug("must have chunk {$item} defined in overall template.");
			logError("must have chunk {%s} defined in overall template.", $item);
			return undef;
		};
		$overall_template =~ /{TOP_OF_FORM}/
			or return $death->('TOP_OF_FORM');
		$overall_template =~ /{HIDDEN_FIELDS}/
			or return $death->('HIDDEN_FIELDS');
		$overall_template =~ /{BOTTOM_OF_FORM}/
			or return $death->('BOTTOM_OF_FORM');
		while($overall_template =~ m/\{((?:_INCLUDE_|COLUMN_|_SPREAD_).*?)\}/g) {
			my $name = $1;
			my $orig = $name;
			my $thing = delete $outhash{$name};
#::logDebug("Got to column replace $name, thing=$thing");
			if($name =~ /^_/) {
				$overall_template =~ s/\{$name\}/$thing->{ROW}/;
			}
			elsif($name =~ s/__WIDGET$//) {
				$thing = delete $outhash{$name};
#::logDebug("Got to widget replace $name, thing=$thing");
				$overall_template =~ s/\{$orig\}/$thing->{WIDGET}/;
			}
			elsif($thing) {
				$overall_template =~ s!\{$name\}!
										tag_attr_list($thing->{TEMPLATE}, $thing)
										!e;
			}
		}
		while($overall_template =~ m/\{([A-Z_]+)\}/g) {
			my $name = $1;
			my $thing = delete $outhash{$name};
#::logDebug("Got to random replace $name, thing=$thing");
			next if ! $thing and $alias{$name};
			$overall_template =~ s/\{$name\}/$thing/;
		}
		while($overall_template =~ m/\{([A-Z_]+)\}/g) {
			my $name = $1;
			my $thing = delete $alias{$name};
#::logDebug("Got to alias replace $name, thing=$thing");
			$overall_template =~ s/\{$name\}/join "", @outhash{@$thing}/e;
		}
		my @put;
		if($opt->{tabbed}) {
			my @tabcont;
			for(@controls) {
				push @tabcont, create_rows($opt, $_);
			}
			$opt->{panel_prepend} ||= '<table>';
			$opt->{panel_append} ||= '</table>';
			push @put, tabbed_display(\@titles,\@tabcont,$opt);
		}
		else {
			for(my $i = 0; $i < @controls; $i++) {
				push @put, tag_attr_list($opt->{break_template}, { ROW => $titles[$i] })
					if $titles[$i];
				push @put, create_rows($opt, $controls[$i]);
			}
		}
		$overall_template =~ s/{:REST}/join "\n", @put/e;
		return $overall_template;
	}

	for(my $i = 0; $i < $firstout; $i++) {
#::logDebug("$out[$i] content length=" . length($outhash{$out[$i]} ));
		push @put, $outhash{$out[$i]};
	}

	if($opt->{tabbed}) {
#::logDebug("In tabbed display...controls=" . scalar(@controls) . ", titles=" . scalar(@titles));
		my @tabcont;
		for(@controls) {
			push @tabcont, create_rows($opt, $_);
		}
		$opt->{panel_prepend} ||= '<table>';
		$opt->{panel_append} ||= '</table>';
		push @put, tabbed_display(\@titles,\@tabcont,$opt);
	}
	else {
#::logDebug("titles=" . uneval(\@titles) . "\ncontrols=" . uneval(\@controls));
		for(my $i = 0; $i < @controls; $i++) {
			push @put, tag_attr_list($opt->{break_template}, { ROW => $titles[$i] })
				if $titles[$i];
			push @put, create_rows($opt, $controls[$i]);
		}
	}

	for(my $i = $firstout; $i < @out; $i++) {
#::logDebug("$out[$i] content length=" . length($outhash{$out[$i]} ));
		push @put, @outhash{$out[$i]};
	}
	return join "", @put;
}

sub convert_old_template {
	my $string = shift;
	$string =~ s/\$WIDGET\$/{WIDGET}/g
		or return $string;
	$string =~ s!\{HELP_URL\}(.*)\{/HELP_URL\}!{HELP_URL?}$1\{/HELP_URL?}!gs;
	$string =~ s/\$HELP\$/{HELP}/g;
	$string =~ s/\$HELP_URL\$/{HELP_URL}/g;
	$string =~ s/\~META\~/{META_STRING}/g;
	$string =~ s/\$LABEL\$/{LABEL}/g;
	$string =~ s/\~ERROR\~/{LABEL}/g;
	$string =~ s/\~TKEY\~/{TKEY}/g;
	$string =~ s/\~BLABEL\~/{BLABEL}/g;
	$string =~ s/\~ELABEL\~/{ELABEL}/g;
	return $string;
}

sub create_rows {
	my ($opt, $columns) = @_;
	$columns ||= [];

	my $rowdiv			= $opt->{across}    || 1;
	my $cells_per_span	= $opt->{cell_span} || 2;
	my $rowcount		= 0;
	my $span			= $rowdiv * $cells_per_span;
	my $oddspan			= $span - 1;

	my @out;

	for(@$columns) {
		# If doesn't exist, was brought in before.
		my $ref = delete $outhash{$_}
			or next;
		if($ref->{ROW}) {
#::logDebug("outputting ROW $_=$ref->{ROW}");
			my $tpl = $ref->{TEMPLATE} || $opt->{combo_template};
			push @out, tag_attr_list($tpl, $ref);
			$rowcount = 0;
			next;
		}
		my $w = '';
		$w .= "<tr$opt->{data_row_extra}>\n" unless $rowcount++ % $rowdiv;
		$w .= tag_attr_list($ref->{TEMPLATE}, $ref);
		$w .= "</tr>" unless $rowcount % $rowdiv;
		push @out, $w;
	}	

	if($rowcount % $rowdiv) {
		my $w = '';
		while($rowcount % $rowdiv) {
			$w .= '<TD colspan=$cells_per_span>&nbsp;</td>';
			$rowcount++;
		}
		$w .= "</tr>";
		push @out, $w;
	}
	return join "\n", @out;
}

#			push @out, <<EOF if $break;
#<tr$opt->{break_row_extra}>
#	<td COLSPAN=$span$opt->{td_extra}{break}>$break_label{$namecol}</td>
#</tr>
#EOF

1;
