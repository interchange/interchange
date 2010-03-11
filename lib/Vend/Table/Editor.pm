# Vend::Table::Editor - Swiss-army-knife table editor for Interchange
#
# $Id: Editor.pm,v 1.93 2009-03-20 18:59:35 mheins Exp $
#
# Copyright (C) 2002-2008 Interchange Development Group
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
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA  02110-1301  USA.

package Vend::Table::Editor;

use vars qw($VERSION);
$VERSION = substr(q$Revision: 1.93 $, 10);

use Vend::Util;
use Vend::Interpolate;
use Vend::Data;
use Exporter;
@EXPORT_OK = qw/meta_record expand_values tabbed_display display/;
use strict;
no warnings qw(uninitialized numeric);

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

my $Trailer;

use vars qw/%Display_type %Display_options %Style_sheet/;

%Display_options = (
	three_column => sub {
		my $opt = shift;
		$opt->{cell_span} = 3;
		return;
	},
	nospace => sub {
		my $opt = shift;
		$opt->{break_cell_first_style} ||= 'border-top: 1px solid #999999';
		return;
	},
	adjust_width => sub {
		my $opt = shift;
		$opt->{adjust_cell_class} ||= $opt->{widget_cell_class};
		if($opt->{table_width} and $opt->{table_width} =~ /^\s*(\d+)(\w*)\s*$/) {
			my $wid = $1;
			my $type = $2 || '';
			$opt->{help_cell_style} ||= 'width: ' . int($wid * .35) . $type;
		}
		else {
			$opt->{help_cell_style} ||= 'width: 400';
		}
		return;
	},
);

%Display_type = (
	default => sub {
		my $opt = shift;
		my $thing = <<EOF;
   <td$opt->{label_cell_extra}> 
     {BLABEL}{LABEL}{ELABEL}{META_STRING}
   </td>
   <td$opt->{data_cell_extra}\{COLSPAN}>
     <table cellspacing="0" cellmargin="0" width="100%">
       <tr> 
         <td$opt->{widget_cell_extra}>
           {WIDGET}
         </td>
         <td$opt->{help_cell_extra}>{TKEY}{HELP?}<i>{HELP}</i>{/HELP?}{HELP_URL?}<br><a href="{HELP_URL}">$opt->{help_anchor}</a>{/HELP_URL?}</td>
       </tr>
     </table>
   </td>
EOF
		chomp $thing;
		return $thing;
	},
	blank => sub {
		my $opt = shift;
		my $thing = <<EOF;
EOF
		chomp $thing;
		return $thing;

	},
	nospace => sub {
		my $opt = shift;
		my $span = shift;
		$opt->{break_template} ||= <<EOF;
<tr$opt->{break_row_extra}><td colspan="$span" $opt->{break_cell_extra}\{FIRST?} style="$opt->{break_cell_first_style}"{/FIRST?}>{ROW}</td></tr>
EOF
		my $thing = <<EOF;
   <td$opt->{label_cell_extra}> 
     {BLABEL}{LABEL}{ELABEL}
   </td>
   <td$opt->{data_cell_extra}\{COLSPAN}>
     <table cellspacing="0" cellmargin="0" width="100%">
       <tr> 
         <td$opt->{widget_cell_extra}>
           {WIDGET}
         </td>
         <td$opt->{help_cell_extra}>{TKEY}{HELP?}<i>{HELP}</i>{/HELP?}{HELP_URL?}<br><a href="{HELP_URL}">$opt->{help_anchor}</a>{/HELP_URL?}</td>
         <td align="right">{META_STRING}</td>
       </tr>
     </table>
   </td>
EOF
		chomp $thing;
		return $thing;

	},
	text_js_help => sub {
		my $opt = shift;
		my $thing = <<EOF;
   <td$opt->{label_cell_extra}> 
     {BLABEL}{LABEL}{ELABEL}
   </td>
   <td$opt->{data_cell_extra}\{COLSPAN} nowrap>{WIDGET}{HELP_EITHER?}&nbsp;<a href="{HELP_URL?}{HELP_URL}{/HELP_URL?}{HELP_URL:}javascript:alert('{HELP}'); void(0){/HELP_URL:}" title="{HELP}">$opt->{help_anchor}</a>{/HELP_EITHER?}&nbsp;{META_URL?}<a href="{META_URL}">$opt->{meta_anchor}</a>{/META_URL?}
   </td>
EOF
		chomp $thing;
		return $thing;
	},
	three_column => sub {
		my $opt = shift;
		my $thing = <<EOF;
   <td$opt->{label_cell_extra}> 
     {BLABEL}{LABEL}{ELABEL}
   </td>
   <td$opt->{data_cell_extra}\{COLSPAN} nowrap>
   	{WIDGET}
   </td>
   <td>{HELP_EITHER?}&nbsp;<a href="{HELP_URL}" title="{HELP}">$opt->{help_anchor}</a>{/HELP_EITHER?}&nbsp;{META_URL?}<a href="{META_URL}">$opt->{meta_anchor}</a>{/META_URL?}
   </td>
EOF
		chomp $thing;
		return $thing;
	},
	simple_row => sub {
#::logDebug("calling simple_row display");
		my $opt = shift;
		my $thing = <<EOF;
   <td$opt->{label_cell_extra}> 
     {BLABEL}{LABEL}{ELABEL}
   </td>
   <td$opt->{data_cell_extra}\{COLSPAN} nowrap>{WIDGET}{HELP_EITHER?}&nbsp;<a href="{HELP_URL}" title="{HELP}">$opt->{help_anchor}</a>{/HELP_EITHER?}&nbsp;{META_URL?}<a href="{META_URL}">$opt->{meta_anchor}</a>{/META_URL?}
   </td>
EOF
		chomp $thing;
		return $thing;
	},
	over_under => sub {
		my $opt = shift;
		my $thing = <<EOF;
{HELP?}
	<td colspan="2"$opt->{help_cell_extra}>
		{HELP}
	</td>
</tr>
<tr>
{/HELP?}	<td colspan="2"$opt->{label_cell_extra}>
		{LABEL}
	</td>
</tr>
<tr>
	<td colspan="2"$opt->{widget_cell_extra}>
		{WIDGET}
	</td>
EOF
		chomp $thing;
		return $thing;
	},
	adjust_width => sub {
		my $opt = shift;
		my $span = shift;
		$opt->{break_template} ||= <<EOF;
$opt->{spacer_row}
<tr$opt->{break_row_extra}><td colspan="$span" $opt->{break_cell_extra}>{ROW}</td></tr>
EOF
		my $thing = <<EOF;
   <td$opt->{label_cell_extra}> 
     {BLABEL}{LABEL}{ELABEL}
   </td>
   <td$opt->{data_cell_extra}\{COLSPAN}>
     <table cellspacing="0" cellmargin="0" width="100%">
       <tr> 
         <td$opt->{widget_cell_extra}>
           {WIDGET}
         </td>
         <td$opt->{help_cell_extra}>{TKEY}{HELP?}{HELP}{/HELP?}{HELP:}&nbsp;{/HELP:}{HELP_URL?}<br><a href="{HELP_URL}">$opt->{help_anchor}</a>{/HELP_URL?}</td>
         <td align="right">{META_STRING}</td>
       </tr>
     </table>
   </td>
EOF
		chomp $thing;
		return $thing;
	},
	image_meta => sub {
		my $opt = shift;
		my $span = shift;
		$opt->{break_template} ||= <<EOF;
$opt->{spacer_row}
<tr$opt->{break_row_extra}><td colspan="$span" $opt->{break_cell_extra}>{ROW}</td></tr>
EOF
		my $thing = <<EOF;
   <td$opt->{label_cell_extra}> 
     {BLABEL}{LABEL}{ELABEL}
   </td>
   <td$opt->{data_cell_extra}\{COLSPAN}>
     <table cellspacing="0" cellmargin="0" width="100%">
       <tr> 
         <td$opt->{widget_cell_extra}>
           {WIDGET}
         </td>
         <td$opt->{help_cell_extra}>{TKEY}{HELP?}{HELP}{/HELP?}{HELP:}&nbsp;{/HELP:}{HELP_URL?}<br><a href="{HELP_URL}">$opt->{help_anchor}</a>{/HELP_URL?}</td>
         <td align="right">{META_STRING}</td>
       </tr>
     </table>
   </td>
EOF
		chomp $thing;
		return $thing;
	},
	simple_help_below => sub {
		my $opt = shift;
		my $thing = <<EOF;
   <td$opt->{label_cell_extra}> 
     {BLABEL}{LABEL}{ELABEL}
   </td>
   <td$opt->{data_cell_extra}\{COLSPAN}>
				{WIDGET}
				{HELP_EITHER?}<br$Trailer>{/HELP_EITHER?}
				{HELP}{HELP_URL?}<br$Trailer><a href="{HELP_URL}">$opt->{help_anchor}</a>{/HELP_URL?}
				{META_URL?}<a href="{META_URL}">$opt->{meta_anchor}</a>{/META_URL?}
			</td>
		</tr>
	</table>
   </td>
EOF
		chomp $thing;
		return $thing;
	},
	simple_icon_help => sub {
		my $opt = shift;
		$opt->{help_icon} ||= '/icons/small/unknown.gif';
		my $thing = <<EOF;
   <td$opt->{label_cell_extra}> 
     {BLABEL}{LABEL}{ELABEL}
   </td>
   <td$opt->{data_cell_extra}\{COLSPAN}>
   	<table width="100%">
		<tr>
			<td style="padding-left: 3px">
				{WIDGET}
			</td>
			<td align="right">
				{HELP_EITHER?}&nbsp;<a href="{HELP_URL?}{HELP_URL}{/HELP_URL?}{HELP_URL:}javascript:alert('{HELP}'); void(0){/HELP_URL:}" title="{HELP}"><img src="$opt->{help_icon}" border="0"></a>{/HELP_EITHER?}&nbsp;{META_URL?}<a href="{META_URL}">$opt->{meta_anchor}</a>{/META_URL?}
			</td>
		</tr>
	</table>
   </td>
EOF
		chomp $thing;
		return $thing;
	},
);

my %dt_map = qw/
 simple_row            1
 text_help             2
 simple_icon_help      3
 over_under            4
 simple_help_below     5
 image_meta            6
 three_column          7
 nospace               8
/;

for(keys %dt_map) {
	$Display_type{$dt_map{$_}} = $Display_type{$_}
		if $Display_type{$_};
	$Display_options{$dt_map{$_}} = $Display_options{$_}
		if $Display_options{$_};
}

%Style_sheet = (
	default => <<EOF,
<style type="text/css">
.rborder {
	background-color: #CCCCCC;
	margin: 0;;
	padding: 2
}

.rhead {
	background-color: #E6E6E6;;
	color: #000000;
	font-family: Arial, Helvetica, sans-serif;
	font-size: 12px
}

A.rhead:active,A.rhead:hover {
	color: #000000;
	font-size: 12px;
	text-decoration: underline;
}

A.rhead:link,A.rhead:visited {
	color: #000000;
	font-size: 12px;
	text-decoration:none;
}

.rheadBold {
	background-color: #E6E6E6;
	color: #000000;
	font-family: Arial, Helvetica, sans-serif;
	font-size: 12px;
	font-weight: bold;;
	padding: 4px
}

.rheader {
	background-color: #999999;
	color: #663333;
}

.rmarq {
	background-color: #999999;;
	color: #FFFFFF;
	font-size: 12px;
	font-weight: bold
}

A.rmarq:active,A.rmarq:link,A.rmarq:visited {
	color: #FFFFCC;
	font-size: 12px;
	font-weight: bold;
	text-decoration:none;
}

A.rmarq:hover {
	color: #FFFF99;
	font-size: 12px;
	font-weight: bold;
	text-decoration: underline;
}

.rnobg {
	color: #000000;
	font-family: Arial, Helvetica, sans-serif;
	font-size: 12px;
	padding: 4px;
}

.rnorm {
	background-color: #FFFFFF;
	border: 1px solid #CCCCCC;
}

.rowalt {
	background-color: #EAF1FB;
	color: #000000;
	font-family: Arial, Helvetica, sans-serif;
	font-size: 12px;
	padding: 4px;
}

A.rowalt:hover,A.rowalt:hover,A.rownorm:active,A.rownorm:hover {
	color: #333333;
	font-family: Arial, Helvetica, sans-serif;
	font-size: 12px;
	text-decoration: underline;
}

A.rowalt:link,A.rowalt:visited,A.rownorm:link,A.rownorm:visited {
	color: #333333;
	font-family: Arial, Helvetica, sans-serif;
	font-size: 12px;
	text-decoration:none;
}

.rownorm {
	background-color: #FFFFFF;
	color: #000000;
	font-family: Arial, Helvetica, sans-serif;
	font-size: 12px;
	padding: 4px;
}

.rownormbold {
	background-color: #FFFFFF;
	color: #000000;
	font-family: Arial, Helvetica, sans-serif;
	font-size: 12px;
	font-weight: bold;;
	padding: 4px
}

.rseparator {
	background-color: #CCCCCC;
}

.rshade {
	background-color: #E6E6E6;
	color: #000000;
	font-family: Arial, Helvetica, sans-serif;
	font-size: 12px;
	padding: 4px;
}

.rspacer {
	background-color: #999999;
	margin: 0;;
	padding: 0
}

.rsubbold {
	background-color: #FFFFFF;
	color: #808080;
	font-family: Arial, Helvetica, sans-serif;
	font-size: 12px;
	font-weight: bold;;
	padding: 4px
}

.rtitle {
	background-color: #808080;;
	color: #FFFFFF;
	font-family: Verdana, Arial, Helvetica, sans-serif;
	font-size: 12px;
	font-weight: bold
}

A.rtitle:active,A.rtitle:link,A.rtitle:visited {
	color: #FFFFCC;
	font-size: 12px;
	font-weight: bold;
	text-decoration:none;
}


.s1,.s2 {
	color: #666666;;
	font-family: Verdana, Arial, Helvetica, sans-serif;
	font-size: 10px
}

.s3 {
	color: #333333;;
	font-family: Verdana, Arial, Helvetica, sans-serif;
	font-size: 10px
}

.s4 {
	color: #666666;
	font-family: Verdana, Arial, Helvetica, sans-serif;
	font-size: 10px;
	width: 100%;
}


.rbreak {
	background-color: #FFFFFF;
}


.cborder {
	background-color: #999999;
	padding: 0;
}

.cbreak {
	background-color: #EEEEEE;
	border-left: 1px solid #999999;
	font-size: 11px;;
	font-weight: bold
}

.cdata {
	border-bottom: 1px solid #CCCCCC;
	border-right: 1px solid #CCCCCC;
	border-top: 1px solid #CCCCCC;
	font-size: 11px;;
	margin-right: 4px;
	padding-right: 2px;
	vertical-align: top
}

.cerror {
	color: red;
	font-size: 11px;
}

.cheader {
	color: #663333;
	font-size: 11px;;
	font-weight: bold
}

.chelp,.rhint {
	color: #AFABA5;
	font-family: Arial, Helvetica, sans-serif;
	font-size: 12px;
	padding: 4px;
}

.clabel {
	border-bottom: 1px solid #CCCCCC;
	border-left: 1px solid #CCCCCC;
	border-top: 1px solid #CCCCCC;
	font-size: 11px;
	vertical-align: top;
	font-weight: medium;
	padding-left: 5px;;
	text-align: left
}

.cmiddle {
	border-bottom: 1px solid #CCCCCC;
	border-top: 1px solid #CCCCCC;
	font-size: 11px;
	font-weight: medium;
	padding-left: 5px;;
	text-align: middle
}

.cmessage {
	color: green;
	font-size: 11px;
}

A:link.ctitle,A:visited.ctitle {
	color: white;
	font-size: 11px;;
	font-weight: bold;
	text-decoration: none
}

A:hover.ctitle,A:active.ctitle {
	color: yellow;
	font-size: 11px;;
	font-weight: bold;
	text-decoration: underline
}

.ctitle {
	font-size: 11px;;
	font-weight: bold
}

.cwidget {
	font-size: 11px;;
	vertical-align: center
}

</style>
EOF
);

sub expand_values {
	my $val = shift;
	return $val unless $val =~ /\[/;
	$val =~ s/\[cgi\s+([^\[]+)\]/$CGI::values{$1}/ig;
	$val =~ s/\[var\s+([^\[]+)\]/$::Variable->{$1}/ig;
	$val =~ s/\[value\s+([^\[]+)\]/$::Values->{$1}/ig;
	return $val;
}

sub widget_meta {
	my ($type,$opt) = @_;
	my $meta = meta_record("_widget::$type", $opt->{view}, $opt->{meta_table}, 1);
	return $meta if $meta;
	my $w = $Vend::Cfg->{CodeDef}{Widget};
	if($w and $w->{Widget}{$type}) {
		my $string;
		return undef unless $string = $w->{ExtraMeta}{$type};
		return get_option_hash($string);
	}

	$w = $Global::CodeDef->{Widget};
	if($w and $w->{Widget}{$type}) {
		my $string;
		return undef unless $string = $w->{ExtraMeta}{$type};
		return get_option_hash($string);
	}

	return $Vend::Form::ExtraMeta{$type};
}

sub meta_record {
	my ($item, $view, $mdb, $extended_only, $overlay) = @_;

#::logDebug("meta_record: item=$item view=$view mdb=$mdb");
	return undef unless $item;

	my $mtable;
	if(! ref ($mdb)) {
		$mtable = $mdb || $::Variable->{UI_META_TABLE} || 'mv_metadata';
#::logDebug("meta_record mtable=$mtable");
		$mdb = database_exists_ref($mtable)
			or return undef;
	}
#::logDebug("meta_record has an item=$item and mdb=$mdb");

	my $record;

	my $mkey = $view ? "${view}::$item" : $item;

	if( ref ($mdb) eq 'HASH') {
		$record = $mdb;
	}
	else {
		$record = $mdb->row_hash($mkey);
#::logDebug("used mkey=$mkey to select record=$record");
	}

	$record ||= $mdb->row_hash($item) if $view and $mdb;
#::logDebug("meta_record  record=$record");

	return undef if ! $record;

	# Get additional settings from extended field, which is a serialized
	# hash
	my $hash;
	if(! $record->{extended}) {
			return undef if $extended_only;
	}
	else {
		## From Vend::Util
		$hash = get_option_hash($record->{extended});
		$record = {} if $extended_only;
		if(ref $hash eq 'HASH') {
			@$record{keys %$hash} = values %$hash;
		}
		else {
			undef $hash;
			return undef if $extended_only;
		}
	}

	# Allow view settings to be placed in the extended area
	if($view and $hash and $hash->{view}) {
		my $view_hash = $record->{view}{$view};
		ref $view_hash
			and @$record{keys %$view_hash} = values %$view_hash;
	}

	# Allow overlay of certain settings
	if($overlay and $record->{overlay}) {
		my $ol_hash = $record->{overlay}{$overlay};
		Vend::Util::copyref($ol_hash, $record) if $ol_hash;
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
		$opt->{already_got_data} = 1;
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
		if($table eq $mtab and $column eq $meta->config('KEY')) {
			if($view and $opt->{value} !~ /::.+::/) {
				$base_entry_value = ($opt->{value} =~ /^([^:]+)::(\w+)$/)
									? $1
									: $opt->{value};
			}
			else {
				$base_entry_value = $opt->{value} =~ /(\w+)::/
									? $1
									: $opt->{value};
			}
		}

		my (@tries) = "${table}::$column";
		unshift @tries, "${table}::${column}::$key"
			if length($key) and $opt->{specific};

		my $sess = $Vend::Session->{mv_metadata} || {};

		push @tries, { type => $opt->{type} }
			if $opt->{type} || $opt->{label};

		for my $metakey (@tries) {
			## In case we were passed a meta record
			last if $record = $sess->{$metakey} and ref $record;
			$record = meta_record($metakey, $view, $meta)
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
								callback_prescript
								callback_postscript
								class
								default
								extra
								disabled
								field
								form
								form_name
								filter
								height
								help
								help_url
								id
								label
								js_check
								lookup
								lookup_exclude
								lookup_query
								maxlength
								name
								options
								outboard
								passed
								pre_filter
								prepend
								table
								type
								type_empty
								width
								/;
			for(@override) {
				delete $record->{$_} if ! length($record->{$_});
				next unless defined $opt->{$_};
				$record->{$_} = $opt->{$_};
			}
		}

		if($record->{type_empty} and length($opt->{value}) == 0) {
			$record->{type} = $record->{type_empty};
		}
		else {
			$record->{type} ||= $opt->{default_widget};
		}

		$record->{name} ||= $column;
#::logDebug("record now=" . ::uneval($record));

		if($record->{options} and $record->{options} =~ /^[\w:,]+$/) {
#::logDebug("checking options");
			PASS: {
				my $passed = $record->{options};

				if($passed eq 'tables') {
					my @tables = $Tag->list_databases();
					$record->{passed} = join (',', "=--none--", @tables);
				}
				elsif($passed =~ /^(?:filters|\s*codedef:+(\w+)(:+(\w+))?\s*)$/i) {
					my $tag = $1 || 'filters';
					my $mod = $3;
					$record->{passed} = Vend::Util::codedef_options($tag, $mod);
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

		$opt->{restrict_allow} ||= $record->{restrict_allow};
#::logDebug("formatting prepend/append/lookup_query name=$opt->{name} restrict_allow=$opt->{restrict_allow}");
		for(qw/append prepend lookup_query/) {
			next unless $record->{$_};
			if($opt->{restrict_allow}) {
				$record->{$_} = $Tag->restrict({
									log => 'none',
									enable => $opt->{restrict_allow},
									disable => $opt->{restrict_deny},
									body => $record->{$_},
								});
			}
			else {
				$record->{$_} = expand_values($record->{$_});
			}
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

		if($opt->{opts}) {
			my $r = get_option_hash(delete $opt->{opts});
			for my $k (keys %$r) {
				$record->{$k} = $r->{$k};
			}
		}


#::logDebug("overriding defaults");
#::logDebug("passed=$record->{passed}") if $record->{debug};
		my %things = (
			attribute	=> $column,
			cols	 	=> $opt->{cols}   || $record->{width},
			passed	 	=> $record->{options},
			rows 		=> $opt->{rows}	|| $record->{height},
			value		=> $opt->{value},
			applylocale => $opt->{applylocale},
		);

		while( my ($k, $v) = each %things) {
			next if length $record->{$k};
			next unless defined $v;
			$record->{$k} = $v;
		}

#::logDebug("calling Vend::Form with record=" . ::uneval($record));
		if($record->{save_defaults}) {
			my $sd = $Vend::Session->{meta_defaults} ||= {};
			$sd = $sd->{"${table}::$column"} ||= {}; 
			while (my ($k,$v) = each %$record) {
				next if ref($v) eq 'CODE';
				$sd->{$k} = $v;
			}
		}

		$w = Vend::Form::display($record);
		if($record->{filter}) {
			$w .= qq{<input type="hidden" name="ui_filter:$record->{name}" value="};
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
	<textarea name="$iname" cols="60" rows="$count">$text</textarea>
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
	<input name="$iname" size="$size" value="$text">
EOF
	}

	my $array_return = wantarray;

#::logDebug("widget=$w");

	# don't output label if widget is hidden form variable only
	# and not an array type
	undef $template if $w =~ /^\s*<input\s[^>]*type\s*=\W*hidden\b[^>]*>\s*$/i;

	return $w unless $template || $opt->{return_hash} || $array_return;

	if($template and $template !~ /\s/) {
		$template = <<EOF;
<tr>
<td>
	<b>\$LABEL\$</b>
</td>
<td valign="top">
	<table cellspacing="0" cellmargin="0"><tr><td>\$WIDGET\$</td><td>\$HELP\${HELP_URL}<br$Vend::Xtrailer><a href="\$HELP_URL\$">help</a>{/HELP_URL}</td></tr></table>
</td>
</tr>
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

	my @colors;
	$opt->{tab_bgcolor_template} ||= '#xxxxxx';
	$opt->{tab_height} ||= '20'; $opt->{tab_width} ||= '120';
	$opt->{panel_id} ||= 'mvpan';
	$opt->{tab_horiz_offset} ||= '10';
	$opt->{tab_vert_offset} ||= '8';
	my $width_height;
	$opt->{tab_style} ||= q{
								text-align:center;
								font-family: sans-serif;
								line-height:150%;
								font-size: smaller;
								border:2px;
								border-color:#999999;
								border-style:outset;
								border-bottom-style:none;
							};
	if($opt->{ui_style}) {
		$opt->{panel_style} ||= q{ 
									padding: 0;
								};
		$width_height = '';
	}
	else {
		$opt->{panel_style} ||= q{ 
									font-family: sans-serif;
									font-size: smaller;
									padding: 0;
									border: 2px;
									border-color:#999999;
									border-style:outset;
								};
		$opt->{panel_height} ||= '600';
		$opt->{panel_width} ||= '800';
		$width_height = <<EOF;
   width: $opt->{panel_width}px;
   height: $opt->{panel_height}px;
EOF
	}

	$opt->{panel_shade} ||= 'e';

	my @chars = reverse(0 .. 9, 'a' .. $opt->{panel_shade});
	my $id = $opt->{panel_id};
	my $vpf = $id . '_';
	my $num_panels = scalar(@$cont);
	my $tabs_per_row = int( $opt->{panel_width} / $opt->{tab_width}) || 1;
    my $num_rows = POSIX::ceil( $num_panels / $tabs_per_row);
	my $width = $opt->{panel_width};
	my $height = $opt->{tab_height} * $num_rows + $opt->{panel_height};
	my $panel_y;
	my $int1;
	my $int2;
	if($opt->{ui_style}) {
		$panel_y = 2;
		$int1 = $int2 = 0;
	}
	else {
	  $panel_y =
		$num_rows
		* ($opt->{tab_height} - $opt->{tab_vert_offset})
		+ $opt->{tab_vert_offset};
		$int1 = $panel_y - 2;
		$int2 = $opt->{tab_height} * $num_rows;
	}
	for(my $i = 0; $i < $num_panels; $i++) {
		my $c = $opt->{tab_bgcolor_template} || '#xxxxxx';
		$c =~ s/x/$chars[$i] || $opt->{panel_shade}/eg;
		$colors[$i] = $c;
	}
	my $cArray = qq{var ${vpf}colors = ['} . join("','", @colors) . qq{'];};
#::logDebug("num rows=$num_rows");
	my $out = <<EOF;
<script language="JavaScript">
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

var ${vpf}uptabs = new Array;
var ${vpf}dntabs = new Array;
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

function ${vpf}tripTab(n) {
	// n is the ID of the division that was clicked
	// firstTab is the location of the first tab in the selected row
	var el;
	for(var i = 0; i < ${vpf}dntabs.length; i++) {
		el = document.getElementById('${vpf}td' + i);
		if(el != undefined) {
			el.innerHTML = ${vpf}dntabs[ i ];
			el.style.backgroundColor = '#B4B0AA';
		}
	}
	el = document.getElementById('${vpf}td' + n);
	el.innerHTML = ${vpf}uptabs[ n ];
	el.style.backgroundColor = '#D4D0C8';
	// Set tab positions & zIndex
	// Update location
	var j = 1;
	for(var i=0; i<${vpf}numDiv; ++i) {
		var loc = ${vpf}newLocation[i]
		var div = ${vpf}getDiv("panel",i)
		if(i == n) {
			${vpf}setZIndex(div, ${vpf}numLocations +1);
			div.style.display = 'block';
			div.style.backgroundColor = ${vpf}colors[0];
		}
		else {
			${vpf}setZIndex(div, ${vpf}numLocations - loc)
			div.style.display = 'none';
			div.style.backgroundColor = ${vpf}colors[j++];
		}
		${vpf}divLocation[i] = loc
	}
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
		else if(loc < ${vpf}tabsPerRow) ${vpf}newLocation[i] = firstTab+(loc % ${vpf}tabsPerRow)
		else ${vpf}newLocation[i] = loc
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

//-->
</script>
<style type="text/css">
<!--
.${id}tab {
	font-weight: bold;
	width:$opt->{tab_width}px;
	margin:0px;
	height: ${int2}px;
	position:relative;
	$opt->{tab_style}
	}

.${id}panel {
	position:relative;
	width: $opt->{panel_width}px;
	height: $opt->{panel_height}px;
	left:0px;
	top:${int1}px;
	margin:0px;
	$opt->{panel_style}
	}
-->
</style>
EOF
	my $s1 = '';
	my $s2 = '';
	my $ibase = $Tag->image({
							ui			=> $Vend::admin,
							dir_only	=> 1,
							secure		=> $Vend::admin && $::Variable->{UI_SECURE},
						});
	$opt->{clear_image} ||= 'bg.gif';
	my $clear = "$ibase/$opt->{clear_image}";
	my @dntabs;
	my @uptabs;
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
<div id="${id}panel$i"
		class="${id}panel"
		style="
			background-color: $colors[$i]; 
			z-index:$zi
		">
$opt->{panel_prepend}
$cont->[$i]
$opt->{panel_append}
</div>
EOF
		if($opt->{ui_style}) {
			$s2 .= <<EOF;
<td class="subtabdown" id="${vpf}td$i"> 
EOF

			$dntabs[$i] = <<EOF;
	<table width="100%" border="0" cellspacing="0" cellpadding="0">
	  <tr> 
		 <td class="subtabdownleft"><a href="javascript:${vpf}tripTab($i,1)"><img src="$clear" width="16" height="16" border="0"></a></td>
		 <td nowrap class="subtabdownfill"><a href="javascript:${vpf}tripTab($i,1)" class="subtablink">$tit->[$i]</a></td>
		 <td class="subtabdownright"><a href="javascript:${vpf}tripTab($i,1)"><img src="$clear" width="16" height="16" border="0"></a></td>
	  </tr>
	  <tr> 
		 <td colspan="3" class="darkshade"><img src="$clear" height="1"></td>
	  </tr>
	  <tr> 
		 <td colspan="3" class="lightshade"><img src="$clear" height="1"></td>
	  </tr>
   </table>
EOF

			$s2 .= $dntabs[$i];

			$uptabs[$i] = <<EOF;
	<table width="100%" border="0" cellspacing="0" cellpadding="0">
	  <tr> 
		 <td class="subtableft"><a href="javascript:${vpf}tripTab($i,1)"><img src="$clear" width="16" height="16" border="0"></a></td>
		 <td nowrap class="subtabfill"><a href="javascript:${vpf}tripTab($i,1)" class="subtablink">$tit->[$i]</a></td>
		 <td class="subtabright"><a href="javascript:${vpf}tripTab($i,1)"><img src="$clear" width="16" height="16" border="0"></a></td>
	  </tr>
	  <tr> 
		 <td colspan="3" class="subtabfilllwr"><img src="$clear" height="1"></td>
	  </tr>
	</table>
EOF
			$s2 .= "</td>\n";

		}
		else {
			$s1 .= <<EOF;
<div
	onclick="${vpf}selectTab($i)"
	id="${id}tab$i"
	class="${id}tab"
	style="
		position: absolute;
		background-color: $colors[$i]; 
		cursor: pointer;
		left: ${left}px;
		top: ${top}px;
		z-index:$zi;
		clip:rect(0 auto $cliprect 0);
		">
$tit->[$i]
</div>
EOF
		}
	}

	my $start_index = $opt->{start_at_index} || 0;
	$start_index += 0;
	if($s2) {
		$Tag->output_to('third_tabs', { name => 'third_tabs' }, $s2);
	}
	$out .= <<EOF;
<div style="
		position: relative;
		left: 0; top: 0; width: 100%; height: 100%;
		z-index: 0;
	">
$s1
EOF
	if($s2) {
		$out .= <<EOF;
<script>
EOF
		for(my $i = 0; $i < @dntabs; $i++) {
			$out .= "${vpf}uptabs[ $i ] = ";
			$out .= $Tag->jsq($uptabs[$i]);
			$out .= ";\n";
			$out .= "${vpf}dntabs[ $i ] = ";
			$out .= $Tag->jsq($dntabs[$i]);
			$out .= ";\n";
		}
		$out .= <<EOF;
	${vpf}tripTab($start_index);
</script>
EOF
	}
	else {
		$out .= <<EOF;
<script>
	${vpf}selectTab($start_index);
</script>
EOF
	}

	$out .= <<EOF;
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

	if(exists $outhash{$tag}) {
		my $col = $tag;
		$col =~ s/^COLUMN_//;
		my $msg = errmsg("Column '%s' defined twice, skipping second.", $col);
		Vend::Tags->warnings($msg);
		return;
	}

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
	border_cell_class	=> 'cborder',
	widget_cell_class	=> 'cwidget',
	label_cell_class	=> 'clabel',
	data_cell_class	=> 'cdata',
	help_cell_class	=> 'chelp',
	break_cell_class_first	=> 'cbreakfirst',
	break_cell_class	=> 'cbreak',
	spacer_row_class => 'rspacer',
	break_row_class => 'rbreak',
	title_row_class => 'rmarq',
	data_row_class => 'rnorm',
	ok_button_style => 'font-weight: bold; width: 40px; text-align: center',
);

my %o_default_var = (qw/
	color_fail			UI_CONTRAST
	color_success		UI_C_SUCCESS
/);

my %o_default_defined = (
	mv_update_empty		=> 1,
	restrict_allow		=> 'page area var',
);

my %o_default = (
	action				=> 'set',
	wizard_next			=> 'return',
	help_anchor			=> 'help',
	wizard_cancel		=> 'back',
	across				=> 1,
	color_success		=> '#00FF00',
	color_fail			=> '#FF0000',
	spacer_height		=> 1,
	border_height		=> 1,
	clear_image			=> 'bg.gif',
	table_width			=> '100%',
);

# Build maps for ui_te_* option pass
my @cgi_opts = qw/

	append
	check
	database
	default
	disabled
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

my %ignore_cgi = qw/
					item_id				1
					item_id_left		1
					mv_pc				1
					mv_action           1
					mv_todo             1
					mv_ui               1
					mv_data_table       1
					mv_session_id       1
					mv_nextpage         1
					ui_sequence_edit	1
				  /;
sub save_cgi {
	my $ref = {};
	my @k; 
	if($CGI::values{save_cgi}) {
		@k = split /\0/, $CGI::values{save_cgi};
	}
	else {
		@k = grep ! $ignore_cgi{$_}, keys %CGI::values;
	}

	# Can be an array because of produce_hidden
	$ref->{save_cgi} = \@k;

	for(@k) {
		$ref->{$_} = $CGI::values{$_};
	}
	return $ref;
}

sub produce_hidden {
	my ($key, $val) = @_;
	return unless length $val;
	my @p; # pieces of var
	my @o; # output
	if(ref($val) eq 'ARRAY') {
		@p = @$val;
	}
	else {
		@p = split /\0/, $val;
	}
	for(@p) {
		s/"/&quot;/g;
		push @o, qq{<input type="hidden" name="$key" value="$_">\n};
	}
	return join "", @o;
}

sub resolve_options {
	my ($opt, $CGI, $data) = @_;

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
#::logDebug("all_opts being brought in...=" . ::uneval($opt->{all_opts}));
		if(ref($opt->{all_opts}) eq 'HASH') {
#::logDebug("all_opts being brought in...");
			my $o = $opt->{all_opts};
			for (keys %$o ) {
				$opt->{$_} = $o->{$_};
			}
		}
		else {
			my $o = meta_record($opt->{all_opts});
#::logDebug("all_opts being brought in text, o=$o");
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

	my @mapdirect = qw/
        back_button_class
        back_button_style
        border_cell_class
        border_height
        bottom_buttons
        break_cell_class
        break_cell_style
        break_row_class
        break_row_style
        button_delete
        cancel_button_class
        cancel_button_style
        clear_image
        data_cell_class
        data_cell_style
        data_row_class
        data_row_style
        default_widget
        delete_button_class
        delete_button_style
        display_type
        file_upload
        help_anchor
        help_cell_class
        help_cell_style
        image_meta
        include_before
        include_form
        include_form_expand
        include_form_interpolate
        intro_text
        label_cell_class
        label_cell_style
        left_width
        link_auto_number
        link_before
        link_blank_auto
        link_extra
        link_fields
        link_key
        link_label
        link_no_blank
        link_row_qual
        link_rows_blank
        link_sort
        link_table
        link_template
        link_view
        mv_auto_export
        mv_blob_field
        mv_blob_label
        mv_blob_nick
        mv_blob_pointer
        mv_blob_title
        mv_data_decode
        mv_data_table
        mv_update_empty
        next_button_class
        next_button_style
        no_meta
        nodelete
        ok_button_class
        ok_button_style
        output_map
        panel_class
        panel_height
        panel_id
        panel_shade
        panel_style
        panel_width
        reset_button_class
        reset_button_style
        restrict_allow
        spacer_height
        spacer_row_class
        spacer_row_style
        start_at
        tab_bgcolor_template
        tab_cellpadding
        tab_cellspacing
        tab_class
        tab_height
        tab_horiz_offset
        tab_style
        tab_vert_offset
        tab_width
        tabbed
        table_height
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
        ui_profile
        view_from
        widget_cell_class
        widget_cell_style
        widget_class
		xhtml
	/;

	if($opt->{cgi}) {
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
	}

#::logDebug("no_meta_display=$opt->{ui_no_meta_display}");
	my $tmeta;
	if($opt->{no_table_meta} || $opt->{ui_no_meta_display}) {
		$tmeta = {};
	}
	else {
		$tmeta = meta_record($table, $opt->{ui_meta_view}) || {};
	}

	$opt->{view_from} ||= $tmeta->{view_from};
	
	my $baseopt;
	if($opt->{no_base_meta} || $opt->{ui_no_meta_display}) {
		$baseopt = {};
	}
	else {
		$baseopt = meta_record('table-editor') || {};
		delete $baseopt->{extended};
	}

	if( !   $opt->{ui_meta_view}
		and $opt->{view_from}
		and $data
		and ! $opt->{ui_no_meta_display}
		and $opt->{ui_meta_view} = $data->{$opt->{view_from}}
		)
	{
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
                    disabled
					database
                    error
                    extra
                    field
                    filter
					form
                    height
                    help
                    help_url
                    label
                    lookup
                    lookup_query
					js_check
                    maxlength
                    meta
                    options
                    outboard
                    override
                    passed
                    pre_filter
                    prepend
                    template
                    wid_href
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

	for(grep length($baseopt->{$_}), @mapdirect) {
#::logDebug("checking baseopt->{$_}, baseopt=$baseopt->{$_} tmeta=$tmeta->{$_}");
		$tmeta->{$_} = $baseopt->{$_}	unless length $tmeta->{$_};
	}

	for(grep defined $tmeta->{$_}, @mapdirect) {
#::logDebug("checking tmeta->{$_}, tmeta=$tmeta->{$_} opt=$opt->{$_}");
#::logDebug("opt->{$_} is " . (defined $opt->{$_} ? 'defined' : 'undefined'));
		$opt->{$_} = $tmeta->{$_}		unless defined $opt->{$_};
	}

	if($opt->{cgi}) {
		my @extra = qw/
				item_id
				item_id_left
				ui_clone_id
				ui_clone_tables
				ui_sequence_edit
		/;
		for(@extra) {
			next if ! defined $CGI->{$_};
			$opt->{$_} = $CGI->{$_};
		}
	}

	if($opt->{wizard}) {
		$opt->{noexport} = 1;
		$opt->{next_text} = 'Next -->' unless $opt->{next_text};
		$opt->{back_text} = '<-- Back' unless $opt->{back_text};
	}
	else {
		$opt->{next_text} = "Ok" unless $opt->{next_text};
	}
	$opt->{cancel_text} = 'Cancel' unless $opt->{cancel_text};

	for(qw/ next_text cancel_text back_text/ ) {
		$opt->{$_} = errmsg($opt->{$_});
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

	if (! $opt->{inner_table_width}) {
		if ($opt->{table_width} =~ /^\d+$/) {
			$opt->{inner_table_width} = $opt->{table_width} - 2;
		}
		elsif($opt->{table_width} =~ /\%/) {
			$opt->{inner_table_width} = '100%';
		}
		else {
			$opt->{inner_table_width} = $opt->{table_width};
		}
	}

	if (! $opt->{inner_table_height}) {
		if ($opt->{table_height} =~ /^\d+$/) {
			$opt->{inner_table_height} = $opt->{table_height} - 2;
		}
		elsif($opt->{table_height} =~ /\%/) {
			$opt->{inner_table_height} = '100%';
		}
		else {
			$opt->{inner_table_height} = $opt->{table_height};
		}
	}

	if(! $opt->{left_width}) {
		if($opt->{table_width} eq '100%') {
			$opt->{left_width} = 150;
		}
		else {
			$opt->{left_width} = '30%';
		}
	}

	if(my $dt = $opt->{display_type}) {
		my $sub = $Display_options{$dt};
		$sub and ref($sub) eq 'CODE' and $sub->($opt);
	}

	# init the row styles
	foreach my $rtype (qw/data break combo spacer title/) {
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

	# Init the button styles

	for my $ctype (qw/ok next back cancel delete reset/) {
		my $mainp = $ctype . '_button_extra';
		my $thing = '';
		for my $ptype (qw/class style/) {
			my $parm = $ctype . '_button_' . $ptype;
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

	$opt->{ui_data_fields} ||= $opt->{ui_wizard_fields};

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
		while ($fstring =~ s/\n+(?:\n[ \t]*=(.*?)(\*?))?\n+[ \t]*(\w[:.\w]+)/\n$3/) {
			push @breaks, $3;
			$opt->{start_at} ||= $3 if $2;
			push @break_labels, "$3=$1" if $1;
		}
		$opt->{ui_break_before} = join(" ", @breaks)
			if ! $opt->{ui_break_before};
		$opt->{ui_break_before_label} = join(",", @break_labels)
			if ! $opt->{ui_break_before_label};
		while($fstring =~ s/\n(.*)[ \t]*\*/\n$1/) {
			$opt->{focus_at} = $1;
		}
		$opt->{ui_data_fields} = $fstring;
	}

	$opt->{ui_data_fields} ||= $opt->{mv_data_fields};
	$opt->{ui_data_fields} =~ s/^[\s,\0]+//;
	$opt->{ui_data_fields} =~ s/[\s,\0]+$//;
#::logDebug("fields now=$opt->{ui_data_fields}");

	#### This code is also in main editor routine, change there too!
	my $cells_per_span = $opt->{cell_span} || 2;
	#### 

	## Visual field layout
	if($opt->{ui_data_fields} =~ /[\w:.]+[ \t,]+\w+.*\n\w+/) {
		my $cs = $opt->{colspan} ||= {};
		my @things = split /\n/, $opt->{ui_data_fields};
		my @rows;
		my $max = 0;
		for(@things) {
			my @cols = split /[\s\0,]+/, $_;
			my $cnt = scalar(@cols);
			$max = $cnt if $cnt > $max;
			push @rows, \@cols;
		}
		$opt->{across} = $max;
		for(@rows) {
			my $cnt = scalar(@$_);
			if ($cnt < $max) {
				my $name = $_->[-1];
				$cs->{$name} = (($max - $cnt) * $cells_per_span) + 1;
			}
		}
	}

	#### This code is also in main editor routine, change there too!
	my $rowdiv         = $opt->{across}    || 1;
	my $rowcount = 0;
	my $span = $rowdiv * $cells_per_span;
	#### 

	# Make standard fixed rows
	$opt->{spacer_row} = <<EOF;
<tr$opt->{spacer_row_extra}>
<td colspan="$span" $opt->{spacer_row_extra}><img src="$opt->{clear_image}" width="1" height="$opt->{spacer_height}" alt="x"></td>
</tr>
EOF

	$opt->{mv_nextpage} = $Global::Variable->{MV_PAGE}
		if ! $opt->{mv_nextpage};

	$opt->{form_extra} =~ s/^\s*/ /
		if $opt->{form_extra};
	$opt->{form_extra} ||= '';

	$opt->{form_extra} .= qq{ name="$opt->{form_name}"}
		if $opt->{form_name};

	$opt->{form_extra} .= qq{ target="$opt->{form_target}"}
		if $opt->{form_target};

	$opt->{enctype} = $opt->{file_upload} ? ' enctype="multipart/form-data"' : '';

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

#::logDebug("overall_template=$overall_template\nin=$opt->{overall_template}");
	use vars qw/$Tag/;

	editor_init($opt);

	my @messages;
	my @errors;
	my $pass_return_to;
	my $hidden = $opt->{hidden} ||= {};

#::logDebug("key at beginning: $key");
	$opt->{mv_data_table} = $table if $table;
	$opt->{table}		  = $opt->{mv_data_table};
	$opt->{ui_meta_view}  ||= $CGI->{ui_meta_view} if $opt->{cgi};

	$key ||= $opt->{item_id};

	if($opt->{cgi}) {
		$key ||= $CGI->{item_id};
		unless($opt->{ui_multi_key} = $CGI->{ui_multi_key}) {
			$opt->{item_id_left} ||= $CGI::values{item_id_left};
			$opt->{ui_sequence_edit} ||= $CGI::values{ui_sequence_edit};
		}
	}

	if($opt->{ui_sequence_edit} and ! $opt->{ui_multi_key}) {
		delete $opt->{ui_sequence_edit};
		my $left = delete $opt->{item_id_left}; 

		if(! $key) {
#::logDebug("No key, getting from $left");
			if($left =~ s/(.*?)[\0,]// ) {
				$key = $opt->{item_id} = $1;
				$hidden->{item_id_left} = $left;
				$hidden->{ui_sequence_edit} = 1;
			}
			elsif($left) {
				$key = $opt->{item_id} = $left;
			}
#::logDebug("No key, left now $left");
		}
		elsif($left) {
#::logDebug("Key, leaving left $left");
			$hidden->{item_id_left} = $left;
			$hidden->{ui_sequence_edit} = 1;
		}
	}

	$opt->{item_id} = $key;

	$pass_return_to = save_cgi() if $hidden->{ui_sequence_edit};

	my $data;
	my $exists;
	my $db;
	my $multikey;

	## Try and sneak a peek at the data so we can determine views and
	## maybe some other stuff -- we definitely need table/key or a 
	## clone id
	unless($opt->{notable}) {
		# From Vend::Data
		my $tab = $table || $opt->{mv_data_table} || $CGI->{mv_data_table};
		my $key = $opt->{item_id} || $CGI->{item_id};
		$db = database_exists_ref($tab);

		if($db) {
			$multikey = $db->config('COMPOSITE_KEY');
			if($multikey and $key !~ /\0/) {
				$key =~ s/-_NULL_-/\0/g;
			}
			if($opt->{ui_clone_id} and $db->record_exists($opt->{ui_clone_id})) {
				$data = $db->row_hash($opt->{ui_clone_id});
			}
			elsif ($key and $db->record_exists($key)) {
				$data = $db->row_hash($key);
				$exists = 1;
			}
			
			if(! $exists and $multikey) {
				$data = {};
				eval { 
					my @inits = split /\0/, $key;
					for(@{$db->config('_Key_columns')}) {
						$data->{$_} = shift @inits;
					}
				};
			}
		}
	}

	my $regin = $opt->{all_opts} ? 1 : 0;

	resolve_options($opt, undef, $data);

	$Trailer = $opt->{xhtml} ? '/' : '';
	if($regin) {
		## Must reset these in case they get set from all_opts.
		$hidden = $opt->{hidden};
	}
	$overall_template = $opt->{overall_template}
		if $opt->{overall_template};

	$table = $opt->{table};
	$key = $opt->{item_id};
	if($opt->{save_meta}) {
		$::Scratch->{$opt->{save_meta}} = uneval($opt);
	}
#::logDebug("key after resolve_options: $key");

#::logDebug("cell_span=$opt->{cell_span}");
	#### This code is also in resolve_options routine, change there too!
	my $rowdiv         = $opt->{across}    || 1;
	my $cells_per_span = $opt->{cell_span} || 2;
	my $rowcount = 0;
	my $span = $rowdiv * $cells_per_span;
	#### 

	my $oddspan = $span - 1;
	my $def = $opt->{default_ref} || $::Values;

	my $append       = $opt->{append};
	my $check        = $opt->{check};
	my $class        = $opt->{class} || {};
	my $database     = $opt->{database};
	my $default      = $opt->{default};
	my $disabled     = $opt->{disabled};
	my $error        = $opt->{error};
	my $extra        = $opt->{extra};
	my $field        = $opt->{field};
	my $filter       = $opt->{filter};
	my $form	     = $opt->{form};
	my $height       = $opt->{height};
	my $help         = $opt->{help};
	my $help_url     = $opt->{help_url};
	my $label        = $opt->{label};
	my $wid_href     = $opt->{wid_href};
	my $lookup       = $opt->{lookup};
	my $lookup_query = $opt->{lookup_query};
	my $meta         = $opt->{meta};
	my $js_check     = $opt->{js_check};
	my $maxlength    = $opt->{maxlength};
	my $opts         = $opt->{opts};
	my $options      = $opt->{options};
	my $outboard     = $opt->{outboard};
	my $override     = $opt->{override};
	my $passed       = $opt->{passed};
	my $pre_filter   = $opt->{pre_filter};
	my $prepend      = $opt->{prepend};
	my $template     = $opt->{template};
	my $widget       = $opt->{widget};
	my $width        = $opt->{width};
	my $colspan      = $opt->{colspan} || {};

	my $blabel = $opt->{blabel};
	my $elabel = $opt->{elabel};
	my $mlabel = '';
	my $hidden_all = $opt->{hidden_all} ||= {};
#::logDebug("hidden_all=" . ::uneval($hidden_all));
	my $ntext;
	my $btext;
	my $ctext;

	if($pass_return_to) {
		delete $::Scratch->{$opt->{next_text}};
	}
	elsif (! $opt->{wizard} and ! $opt->{nosave}) {
		$ntext = $Tag->return_to('click', 1);
		$ctext = $ntext . "\nmv_todo=back";
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
	$opt->{cancel_text} = HTML::Entities::encode($opt->{cancel_text}, $ESCAPE_CHARS::std);

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
		my $prof = $opt->{ui_profile} || "&update=yes\n";
		if ($prof =~ s/^\*//) {
			# special notation ui_profile="*whatever" means
			# use automatic checklist-related profile
			my $name = $prof;
			$prof = $::Scratch->{"profile_$name"} || "&update=yes\n";
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
				## Un-confuse vi }
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

		## Enable individual widget checks
		$::Scratch->{mv_individual_profile} = 1;

		## Call the profile in the form
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
		$mlabel = ($opt->{message_label} || '&nbsp;&nbsp;&nbsp;'
. errmsg('<b>Bold</b> fields are required'));
		$have_errors = $Tag->error( {
									all => 1,
									show_var => $error_show_var,
									show_error => 1,
									joiner => "<br$Vend::Xtrailer>",
									keep => 1}
									);
		if($opt->{all_errors} and $have_errors) {
			my $title = $opt->{all_errors_title} || errmsg('Errors');
			my $style = $opt->{all_errors_style} || "color: $opt->{color_fail}";
			my %hash = (
				title => $opt->{all_errors_title} || errmsg('Errors'),
				style => $opt->{all_errors_style} || "color: $opt->{color_fail}",
				errors => $have_errors,
			);
			my $tpl = $opt->{all_errors_template} || <<EOF;
<p>{TITLE}:
<blockquote style="{STYLE}">{ERRORS}</blockquote>
</p>
EOF
			$mlabel .= tag_attr_list($tpl, \%hash, 'uc');

		}
	}
	### end build of error checking

	my $die = sub {
		::logError(@_);
		$::Scratch->{ui_error} .= "<BR>\n" if $::Scratch->{ui_error};
		$::Scratch->{ui_error} .= ::errmsg(@_);
		return undef;
	};

	unless($opt->{notable}) {
		# From Vend::Data
		$db = database_exists_ref($table)
			or return $die->("table-editor: bad table '%s'", $table);
	}

	$opt->{ui_data_fields} =~ s/[,\0\s]+/ /g;

	if($opt->{ui_wizard_fields}) {
		$opt->{ui_display_only} = $opt->{ui_data_fields};
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
		my (@cols, %colseen);

		for (split /[,\0\s]/, $opt->{ui_data_fields}) {
			next if $colseen{$_}++;
			push (@cols, $_);
		}

		$opt->{ui_data_fields} = join " ", @cols;

		$linecount = scalar @cols;
	}

	my $url = $Tag->area('ui');

	my $key_message;
	if($opt->{ui_new_item} and ! $opt->{notable}) {
		if( ! $db->config('_Auto_number') and ! $db->config('AUTO_SEQUENCE')) {
			$db->config('AUTO_NUMBER', '000001');
			$key = $db->autonumber($key);
		}
		else {
			$key = '';
			$opt->{mv_data_auto_number} = 1;
			$key_message = errmsg('(new key will be assigned if left blank)');
		}
	}

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
			unshift @labels, '';

			my $extra = '';
			for my $k (keys %$hidden_all) {
				my $v = $hidden_all->{$k};
				if(ref($v) eq 'ARRAY') {
					for(@$v) {
						$extra .= "\n$k=$_";
					}
				}
				else {
					$extra .= "\n$k=$v";
				}
			}

			for my $key (@labels) {
				my $ref;
				my $lab;
				if($key) {
					$ref = $blob->{$key};
					$lab = $ref->{$opt->{mv_blob_label} || 'name'};
				}
				else {
					$key = '';
					$lab = '--' . errmsg('none') . '--';
					$ref = {};
				}
				if($lab) {
					$lab =~ s/,/&#44/g;
					$wid_data{$key} = "$key=$key - $lab";
					next unless $key;
					$url_data{$key} = $Tag->page( {
											href => $Global::Variable->{MV_PAGE},
											form => "
												item_id=$opt->{item_id}
												mv_blob_nick=$key$extra
											",
										});
					$url_data{$key} .= "$key - $lab</a><br$Trailer>";
				}
				else {
					$wid_data{$key} = $key;
					next unless $key;
					$url_data{$key} = $Tag->page( {
											href => $Global::Variable->{MV_PAGE},
											form => "
												item_id=$opt->{item_id}
												mv_blob_nick=$key$extra
											",
										});
					$url_data{$key} .= "$key</a>";
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
<i>($lfrom_msg)</i><br>
EOF
			if(@labels) {
				$loaded_from .= errmsg("Load from") . ":<blockquote>";
				$loaded_from .=  join (" ", @url_data{ sort keys %url_data });
				$loaded_from .= "</blockquote>";
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
				my $msg2 = errmsg('Save to book only');
				for (\$msg1, \$msg2) {
					$$_ =~ s/ /&nbsp;/g;
				}
				$blob_widget = <<EOF unless $opt->{ui_blob_hidden};
<b>$msg1:</b> $blob_widget&nbsp;
<input type="checkbox" name="mv_blob_only" class="$opt->{widget_class}" value="1"$checked>&nbsp;$msg2</small>
EOF
			}

			$blob_widget = <<EOF unless $opt->{ui_blob_hidden};
<tr$opt->{data_row_extra}>
	 <td width="$opt->{left_width}"$opt->{label_cell_extra}>
	   <small>$opt->{mv_blob_title}<br>
		$loaded_from
	 </td>
	 <td$opt->{data_cell_extra}>
	 	$blob_widget&nbsp;
	 </td>
</tr>

<tr>
<td colspan="$span"$opt->{border_cell_extra}><img src="$opt->{clear_image}" width="1" height="$opt->{border_height}" alt="x"></td>
</tr>
EOF

		if($opt->{mv_blob_nick}) {
			delete $opt->{force_defaults};
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

	if(! $opt->{href}) {
		$opt->{href} = $opt->{mv_nextpage};
		$opt->{hidden}{mv_ui} = 1
			if $Vend::admin and ! defined $opt->{hidden}{mv_ui};
		$opt->{hidden}{mv_action} = $opt->{action};
	}

	$opt->{href} = "$url_base/$opt->{href}"
		if $opt->{href} !~ m{^(https?:|)/};

	$opt->{method} = $opt->{get} ? 'GET' : 'POST';

	my $wo = $opt->{widgets_only};

	my $restrict_begin;
	my $restrict_end;

	if($opt->{reparse} and ! $opt->{promiscuous}) {
		$restrict_begin = qq{[restrict allow="$opt->{restrict_allow}"]};
		$restrict_end = '[/restrict]';
	}

	no strict 'subs';

	chunk ttag(), $restrict_begin;

	chunk 'FORM_BEGIN', 'OUTPUT_MAP', <<EOF;
<form method="$opt->{method}" action="$opt->{href}"$opt->{enctype}$opt->{form_extra}>
EOF

	my $prescript_marker = $#out;

    $hidden->{mv_click}      = $opt->{process_filter};
    $hidden->{mv_todo}       = $opt->{action};
    $hidden->{mv_nextpage}   = $opt->{mv_nextpage};
    $hidden->{mv_data_table} = $table;
    $hidden->{mv_data_key}   = $keycol;
	if($opt->{cgi}) {
		$hidden->{mv_return_table}   = $CGI->{mv_return_table} || $table;
	}
	else {
		$hidden->{mv_return_table}   = $table;
	}

	chunk 'HIDDEN_ALWAYS', 'OUTPUT_MAP', <<EOF;
<input type="hidden" name="mv_session_id" value="$Vend::Session->{id}">
<input type="hidden" name="mv_click" value="process_filter">
EOF

	my @opt_set = (qw/
						ui_meta_specific
						ui_hide_key
						ui_meta_view
						ui_new_item
						ui_data_decode
						mv_blob_field
						mv_blob_label
						mv_blob_title
						mv_blob_pointer
						mv_update_empty
						mv_data_auto_number
						mv_data_function
				/);

	for my $k (@opt_set) {
		$opt->{hidden}{$k} = $opt->{$k};
	}

	if($pass_return_to) {
		while( my($k, $v) = each %$pass_return_to) {
			next if defined $opt->{hidden}{$k};
			$opt->{hidden}{$k} = $pass_return_to->{$k};
		}
	}

	if($opt->{mailto}) {
		$opt->{mailto} =~ s/\s+/ /g;
		$::Scratch->{mv_email_enable} = $opt->{mailto};
		$opt->{hidden}{mv_data_email} = 1;
	}

	$Vend::Session->{ui_return_stack} ||= [];

	if($opt->{cgi} and ! $pass_return_to) {
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

	if(ref $opt->{hidden} or ref $opt->{hidden_all}) {
		my ($hk, $hv);
		my @o;
		while ( ($hk, $hv) = each %$hidden ) {
			push @o, produce_hidden($hk, $hv);
		}
		while ( ($hk, $hv) = each %$hidden_all ) {
			push @o, produce_hidden($hk, $hv);
		}
		chunk 'HIDDEN_USER', 'OUTPUT_MAP', join("", @o); # unless $wo;
	}

	if($opt->{tabbed}) {
		$opt->{table_width} ||= ($opt->{panel_width} || 800) + 10;
		$opt->{table_height} ||= ($opt->{panel_height} || 600) + 10;
		$opt->{inner_table_width} ||= ($opt->{panel_width} || 800);
		$opt->{inner_table_height} ||= ($opt->{panel_height} || 600);
	}
	chunk ttag(), <<EOF; # unless $wo;
<table class="touter" border="0" cellspacing="0" cellpadding="0" width="$opt->{table_width}" height="$opt->{table_height}">
<tr>
  <td valign="top">

<table class="tinner" width="$opt->{inner_table_width}" height="$opt->{inner_table_height}" cellspacing="0" cellmargin="0" cellpadding="2" align="center" border="0">
EOF
	chunk ttag(), 'NO_TOP OUTPUT_MAP', <<EOF; # unless $opt->{no_top} or $wo;
<tr> 
<td colspan="$span"$opt->{border_cell_extra}><img src="$opt->{clear_image}" width="1" height="$opt->{border_height}" alt="x"></td>
</tr>
EOF

	if ($opt->{intro_text}) {
#::logDebug("intro_text=$opt->{intro_text}");
		chunk ttag(), <<EOF;
<tr $opt->{spacer_row_extra}> 
	<td colspan="$span" $opt->{spacer_cell_extra}>$opt->{intro_text}</td>
</tr>
<tr $opt->{title_row_extra}> 
	<td colspan="$span" $opt->{title_cell_extra}>$::Scratch->{page_title}</td>
</tr>
EOF
	}

	$opt->{top_buttons_rows} = 5 unless defined $opt->{top_buttons_rows};

	#### Extra buttons
	my $extra_ok =	$blob_widget
						|| $opt->{output_map}
	  					|| $linecount >= $opt->{top_buttons_rows}
						|| defined $opt->{include_form}
						|| $mlabel;
	
	$mlabel ||= '&nbsp;';
	if ($extra_ok and ! $opt->{no_top} and ! $opt->{nosave}) {
	  	if($opt->{back_text}) {
		  chunk ttag(), 'OUTPUT_MAP', <<EOF; # unless $wo;
<tr$opt->{data_row_extra}>
<td$opt->{label_cell_extra}>&nbsp;</td>
<td align="left" colspan="$oddspan"$opt->{data_cell_extra}>
EOF
			chunk 'COMBINED_BUTTONS_TOP', 'BOTTOM_BUTTONS OUTPUT_MAP', <<EOF;
<input type="submit" name="mv_click" value="$opt->{back_text}"$opt->{back_button_extra}>&nbsp;<input type="submit" name="mv_click" value="$opt->{cancel_text}"$opt->{cancel_button_extra}>&nbsp;<b><input type="submit" name="mv_click" value="$opt->{next_text}"$opt->{next_button_extra}></b>
<br>
EOF
			chunk 'MLABEL', 'OUTPUT_MAP', 'MESSAGES', $mlabel;
			chunk ttag(), <<EOF;
	</td>
</tr>
$opt->{spacer_row}
EOF
		}
		elsif ($opt->{wizard}) {
			chunk ttag(), 'NO_TOP OUTPUT_MAP', <<EOF;
<tr$opt->{data_row_extra}>
<td$opt->{label_cell_extra}>&nbsp;</td>
<td align="left" colspan="$oddspan"$opt->{data_cell_extra}>
EOF
			chunk 'WIZARD_BUTTONS_TOP', 'BOTTOM_BUTTONS NO_TOP OUTPUT_MAP', <<EOF; 
<input type="submit" name="mv_click" value="$opt->{cancel_text}"$opt->{cancel_button_extra}>&nbsp;<b><input type="submit" name="mv_click" value="$opt->{next_text}"$opt->{next_button_extra}></b>
<br>
EOF
			chunk 'MLABEL', 'NO_TOP OUTPUT_MAP', 'MESSAGES', $mlabel;
			chunk ttag(), 'NO_TOP OUTPUT_MAP', <<EOF;
	</td>
</tr>
$opt->{spacer_row}
EOF
		}
		else {
		  chunk ttag(), 'BOTTOM_BUTTONS NO_TOP OUTPUT_MAP', <<EOF;
<tr$opt->{data_row_extra}>
<td$opt->{label_cell_extra}>&nbsp;</td>
<td align="left" colspan="$oddspan"$opt->{data_cell_extra}>
EOF

		  chunk 'OK_TOP', 'NO_TOP OUTPUT_MAP', <<EOF;
<input type="submit" name="mv_click" value="$opt->{next_text}"$opt->{ok_button_extra}>
EOF
		  chunk 'CANCEL_TOP', 'NOCANCEL BOTTOM_BUTTONS NO_TOP OUTPUT_MAP', <<EOF;
&nbsp;
<input type="submit" name="mv_click" value="$opt->{cancel_text}"$opt->{cancel_button_extra}>
EOF

		  if($opt->{show_reset}) {
			  chunk 'RESET_TOP', 'BOTTOM_BUTTONS NO_TOP OUTPUT_MAP', <<EOF;
&nbsp;
<input type="reset"$opt->{reset_button_extra}>
EOF
		  }

			chunk 'MLABEL', 'BOTTOM_BUTTONS OUTPUT_MAP', $mlabel;
			chunk ttag(), 'BOTTOM_BUTTONS NO_TOP OUTPUT_MAP', <<EOF;
	</td>
</tr>
$opt->{spacer_row}
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
		my $db = $Db{$_} || Vend::Data::database_exists_ref($_);
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
		my $db = $Db{$t} || Vend::Data::database_exists_ref($t) or next;
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
<input type="checkbox" name="ui_clone_tables" value="$_"$checked> clone to <b>$_</b><br>
EOF
		}
		for(@sets) {
			my ($t, $col) = split /:/, $_;
			my $checked = $tab_checked{$_} ? ' CHECKED' : '';
			$tabform .= <<EOF;
<input type="checkbox" name="ui_clone_tables" value="$_"$checked> clone entries of <b>$t</b> matching on <b>$col</b><br>
EOF
		}

		my $tabs = join " ", @tables;
		$set =~ s/_TABLES_/$tabs/g;
		$::Scratch->{clone_tables} = $set;
		chunk ttag(), <<EOF; # unless $wo;
<tr>
<td colspan="$span"$opt->{border_cell_extra}>
EOF
		chunk 'CLONE_TABLES', <<EOF;
$tabform<input type="hidden" name="mv_check" value="clone_tables">
<input type="hidden" name="ui_clone_id" value="$opt->{ui_clone_id}">
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
								/;

	my %break;
	my %break_label;
	if($opt->{ui_break_before}) {
		my @tmp = grep /\S/, split /[\s,\0]+/, $opt->{ui_break_before};
		@break{@tmp} = @tmp;
		if($opt->{ui_break_before_label}) {
			@tmp = grep /\S/, split /\s*[,\0]\s*/, $opt->{ui_break_before_label};
			for(@tmp) {
				my ($br, $lab) = split /\s*=\s*/, $_, 2;
				$break_label{$br} = $lab;
			}
		}
	}
	if(!$db and ! $opt->{notable}) {
		return "<tr><td>Broken table '$table'</td></tr>";
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
			$opt->{meta_prepend} = qq{<br$Trailer><font size="1">}
				unless defined $opt->{meta_prepend};

			$opt->{meta_append} = '</font>'
				unless defined $opt->{meta_append};
		}
		else {
			$opt->{meta_prepend} ||= '';
			$opt->{meta_append} ||= '';
		}
		$opt->{meta_title} ||= errmsg('Edit field meta display info, table %s, column %s');
		$opt->{meta_title_specific} ||= errmsg('Item-specific meta edit, table %s, column %s, key %s');
		$opt->{meta_image_specific} ||= errmsg('specmeta.png');
		$opt->{meta_image} ||= errmsg('meta.png');
		$opt->{meta_image_extra} ||= 'border="0"';
		$opt->{meta_anchor_specific} ||= errmsg('item-specific meta');
		$opt->{meta_anchor} ||= errmsg('meta');
		$opt->{meta_anchor_specific} ||= errmsg('item-specific meta');
		$opt->{meta_extra} = " $opt->{meta_extra}"
			if $opt->{meta_extra};
		$opt->{meta_extra} ||= "";
		$opt->{meta_extra} .= qq{ class="$opt->{meta_class}"}
			if $opt->{meta_class};
		$opt->{meta_extra} .= qq{ style="$opt->{meta_style}"}
			if $opt->{meta_style};
	}

 	my $row_template = convert_old_template($opt->{row_template});

#::logDebug("display_type='$opt->{display_type}' row_template length=" . length($row_template));

	if(! $row_template) {
		$opt->{display_type} = 'simple_row' if $opt->{simple_row};
		$opt->{display_type} ||= 'image_meta' if $opt->{image_meta};
		my $dt = $opt->{display_type} ||= 'default';

		$dt =~ s/-/_/g;
		$dt =~ s/\W+//g;
#::logDebug("display_type=$dt");
		my $sub = $Display_type{$dt};
		if(ref($sub) eq 'CODE') {
			$row_template = $sub->($opt, $span);
		}
		else {
			::logError("table-editor: display_type '%s' sub not found", $dt);
			$row_template = $Display_type{default}->($opt, $span);
		}
	}

	$row_template =~ s/~OPT:(\w+)~/$opt->{$1}/g;
	$row_template =~ s/~([A-Z]+)_EXTRA~/$opt->{"\L$1\E_extra"} || $opt->{"\L$1\E_cell_extra"}/g;

	$opt->{row_template} = $row_template;

	$opt->{combo_template} ||= <<EOF;
<tr$opt->{combo_row_extra}><td> {LABEL} </td><td>{WIDGET}</td></tr>
EOF

	$opt->{break_template} ||= <<EOF;
<tr$opt->{break_row_extra}><td colspan="$span" $opt->{break_cell_extra}\{FIRST?} style="$opt->{break_cell_first_style}"{/FIRST?}>{ROW}</td></tr>
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
		my @lnb;
		my @lrq;
		my @lra;
		my @lrb;
		my @lba;
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
			@lnb     = @{$opt->{link_no_blank}};
			@lrq     = @{$opt->{link_row_qual}};
			@lra     = @{$opt->{link_auto_number}};
			@lrb     = @{$opt->{link_rows_blank}};
			@lba     = @{$opt->{link_blank_auto}};
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
			@lnb     = $opt->{link_no_blank};
			@lrq     = $opt->{link_row_qual};
			@lra     = $opt->{link_auto_number};
			@lrb     = $opt->{link_rows_blank};
			@lba     = $opt->{link_blank_auto};
			@lbefore = $opt->{link_before};
			@lsort   = $opt->{link_sort};
		}
		while(my $lt = shift @ltable) {
			my $lf = shift @lfields;
			my $lv = shift @lview;
			my $lk = shift @lkey;
			my $ll = shift @llab;
			my $lb = shift @lbefore;
			my $lnb = shift @lnb;
			my $ls = shift @lsort;
			my $lrq = shift @lrq;
			my $lra = shift @lra;
			my $lrb = shift @lrb;
			my $lba = shift @lba;

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
			$lrq ||= $l_pkey;

			if($lba) {
				my @f = grep /\w/, split /[\s,\0]+/, $lf;
				@f = grep $_ ne $lk && $_ ne $l_pkey, @f;
				$lf = join " ", @f;
			}

			my $an_piece = '';
			if($lra) {
				$an_piece = <<EOF;
<input type="hidden" name="mv_data_auto_number__$tcount" value="$lra">
<input type="hidden" name="mv_data_function__$tcount" value="insert">
EOF
			}

			## Have to produce two field lists -- one for
			## in link_blank_auto mode (no link_key for row_edit)
			## and one with all when not in link_blank_auto

			my @cf = grep /\S/, split /[\s,\0]+/, $lf;
			@cf = grep $_ ne $l_pkey, @cf;
			$lf = join " ", @cf;

			unshift @cf, $lk if $lba;
			my $df = join " ", @cf;

			my $lextra = $opt->{link_extra} || '';
			$lextra = " $lextra" if $lextra;

			my @lout = q{<table cellspacing="0" cellpadding="1">};
			push @lout, qq{<tr><td$lextra>
<input type="hidden" name="mv_data_table__$tcount" value="$lt">
<input type="hidden" name="mv_data_fields__$tcount" value="$df">
<input type="hidden" name="mv_data_multiple__$tcount" value="1">
<input type="hidden" name="mv_data_key__$tcount" value="$l_pkey">
<input type="hidden" name="mv_data_multiple_qual__$tcount" value="$lrq">
$an_piece
$l_pkey</td>};
			push @lout, $Tag->row_edit({ table => $lt, columns => $lf });
			push @lout, '</tr>';

			my $tname = $ldb->name();
			my $k = $key;
			my $lfor = $k;
			$lfor = $ldb->quote($key, $lk);
			my $q = "SELECT $l_pkey FROM $tname WHERE $lk = $lfor";
			$q .= " ORDER BY $ls" if $ls;
			my $ary = $ldb->query($q);
			for(@$ary) {
				my $rk = $_->[0];
				my $pp = $rcount ? "${rcount}_" : '';
				my $hid = qq{<input type="hidden" name="$pp${l_pkey}__$tcount" value="};
				$hid .= HTML::Entities::encode($rk);
				$hid .= qq{">};
				push @lout, qq{<tr><td$lextra>$rk$hid</td>};
				if($lba) {
					my $hid = qq{<input type="hidden" name="$pp${lk}__$tcount" value="};
					$hid .= HTML::Entities::encode($k);
					$hid .= qq{">};
					push @lout, qq{<td$lextra>$k$hid</td>};
				}
				my %o = (
					table => $lt,
					key => $_->[0],
					extra => $opt->{link_extra},
					pointer => $rcount,
					stacker => $tcount,
					columns => $lf,
				);
				$rcount++;
				push @lout, $Tag->row_edit(\%o);
				push @lout, "</tr>";
			}

			if($lba and $lrq eq $lk || $lrq eq $l_pkey) {
				my $colcount = scalar(@cf) + 1;
				push @lout, qq{<td colspan="$colcount">Link row qualifier must be different than link_key and primary code when in auto mode.</td>};
				$lnb = 1;
			}

			unless($lnb) {
				my $start_ptr = 999000;
				$lrb ||= 1;
				for(0 .. $opt->{link_rows_blank}) {
					my %o = (
						table => $lt,
						blank => 1,
						extra => $opt->{link_extra},
						pointer => $start_ptr,
						stacker => $tcount,
						columns => $lf,
					);
					my $ktype = $lba ? 'hidden' : 'text';
					push @lout, qq{<tr><td$lextra>};
					push @lout, qq{<input size="8" type="$ktype" name="${start_ptr}_${l_pkey}__$tcount" value="">};
					push @lout, '(auto)' if $lba;
					push @lout, '</td>';
					if($lba) {
						my $hid = qq{<input type="hidden" name="${start_ptr}_${lk}__$tcount" value="};
						$hid .= HTML::Entities::encode($k);
						$hid .= qq{">};
						push @lout, qq{<td$lextra>$k$hid</td>};
					}
					push @lout, $Tag->row_edit(\%o);
					push @lout, '</tr>';
					$start_ptr++;
				}
			}
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
        my $extra = qq{ width="$pw" height="$oh" valign="top"};
        chunk ttag(), qq{<tr><td colspan="$span"$extra>\n};
    }

#::logDebug("include_before: " . uneval($opt->{include_before}));

	my @extra_hidden;
	my $icount = 0;

	my $reload;
	## Find out what our errors are
	if($CGI->{mv_form_profile} eq 'ui_profile' and $Vend::Session->{errors}) {
		for(keys %{$Vend::Session->{errors}}) {
			$error->{$_} = 1;
		}
		$reload = 1 unless $opt->{no_reload};
	}

	my @prescript;
	my @postscript;

	for(qw/callback_prescript callback_postscript/) {
		next unless $opt->{$_};
		next if ref($opt->{$_}) eq 'CODE';
		$Tag->error({
						name => errmsg('table-editor'), 
						set => errmsg('%s is not a code reference', $_), 
					});
	}

	my $callback_prescript = $opt->{callback_prescript} || sub {
		push @prescript, @_;
	};
	my $callback_postscript = $opt->{callback_postscript} || sub {
		push @postscript, @_;
	};


	if(my $sheet = $opt->{style_sheet}) {
		$sheet =~ s/^\s+//;
		$sheet =~ s/\s+$//;
		if($Style_sheet{$sheet}) {
			push @prescript, $Style_sheet{$sheet};
		}
		elsif($sheet =~ /\s/) {
			my $pre_put;
			if($sheet !~ /^<\w+/) {
				$pre_put = 1;
				push @prescript, q{<style type="text/css">}
			}
			push @prescript, $sheet;
			push @prescript, q{</style>} if $pre_put;
		}
		else {
			::logError(
				"%s: style sheet %s not found, using default",
				errmsg('table-editor'),
				$sheet,
			);
			push @prescript, $Style_sheet{default};
		}
	}

	foreach my $col (@cols) {
		my $t;
		my $c;
		my $k;
		my $tkey_message;
		if($col eq $keycol) {
			if($opt->{ui_hide_key}) {
				my $kval = $key || $override->{$col} || $default->{$col};
				push @extra_hidden,
					qq{<input type="hidden" name="$col" value="$kval">};
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
			$do = 1 if $disabled->{$c};
			push @ext_enable, ("$t:$c" . $k ? ":$k" : '')
				unless $do;
		}
		else {
			$t = $table;
			$c = $col;
			$c =~ /(.+?)\.\w.*/
				and $col = $1
					and $serialize = $c;
			$do = 1 if $disabled->{$c};
			push @data_enable, $col
				unless $do and ! $opt->{mailto};
		}

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
			$overridden = 1;
#::logDebug("hit preload for $col,currval=$currval");
		}
		else {
#::logDebug("hit data->col for $col, t=$t, c=$c, k=$k, currval=$currval");
			$currval = length($data->{$col}) ? $data->{$col} : '';
			$overridden = 1;
		}

		if($reload and defined $CGI::values{$col}) {
			$currval = $CGI::values{$col};
		}

		my $namecol;
		if($serialize) {
#::logDebug("serialize=$serialize");
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
					$sd = $data->{$col} || $default->{$col};
				}
#::logDebug("serial_data=$sd");
				$serial_data{$col} = $sd;
				$opt->{hidden}{$col} = $data->{$col};
				$serialize{$col} = [$serialize];
			}
			$c =~ /\.(.*)/;
			my $hk = $1;
#::logDebug("fetching serial_data for $col hk=$hk data=$serial_data{$col}");
			$currval = dotted_hash($serial_data{$col}, $hk);
#::logDebug("fetched hk=$hk value=$currval");
			$overridden = 1;
			$namecol = $c = $serialize;

			if($reload and defined $CGI::values{$namecol}) {
				$currval = $CGI::values{$namecol};
			}
		}

		$namecol = $col unless $namecol;

#::logDebug("display_only=$do col=$c");
		$widget->{$c} = 'value'
			if $do and ! ($disabled->{$c} || $opt->{wizard} || $opt->{mailto});

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
				$parm->{text} = $opt->{error_template} || <<EOF;
<font color="$opt->{color_fail}">\$LABEL\$ (%s)</font>
[else]{REQUIRED <b>}{LABEL}{REQUIRED </b>}[/else]
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
<br$Trailer><a href="$meta_url_specific"$opt->{meta_extra} tabindex="9999">$opt->{meta_anchor_specific}</a>
EOF
			}
								
			$opt->{meta_append} = '</font>'
				unless defined $opt->{meta_append};
			if($opt->{image_meta}) {
#::logDebug("meta-title=$opt->{meta_title}");
				my $title = errmsg($opt->{meta_title}, $t, $c);
				$meta_string = <<EOF;
<a href="$meta_url"$opt->{meta_extra} tabindex="9999"><img src="$opt->{meta_image}" title="$title" $opt->{meta_image_extra}></a>
EOF
				if($meta_specific) {
					$title = errmsg($opt->{meta_title_specific}, $t, $c, $key);
					$meta_string .= <<EOF;
<a href="$meta_url_specific"$opt->{meta_extra} tabindex="9999"><img src="$opt->{meta_image_specific}" title="$title" $opt->{meta_image_extra}></a>
EOF
				}
			}
			else {
				$meta_string = <<EOF;
$opt->{meta_prepend}<a href="$meta_url"$opt->{meta_extra} tabindex="9999">$opt->{meta_anchor}</a>
$meta_specific$opt->{meta_append}
EOF
			}
		}

		$class->{$c} ||= $opt->{widget_class};

#::logDebug("col=$c currval=$currval widget=$widget->{$c} label=$label->{$c}");
		my $display = display($t, $c, $key, {
							append				=> $append->{$c},
							applylocale			=> 1,
							arbitrary			=> $opt->{ui_meta_view},
							callback_prescript  => $callback_prescript,
							callback_postscript  => $callback_postscript,
							class				=> $class->{$c},
							column				=> $c,
							db					=> $database->{$c},
							default				=> $currval,
							default_widget		=> $opt->{default_widget},
							disabled			=> $disabled->{$c},
							extra				=> $extra->{$c},
							fallback			=> 1,
							field				=> $field->{$c},
							filter				=> $filter->{$c},
							form				=> $form->{$c},
							form_name			=> $opt->{form_name},
							height				=> $height->{$c},
							help				=> $help->{$c},
							help_url			=> $help_url->{$c},
							href				=> $wid_href->{$c},
							js_check			=> $js_check->{$c},
							key					=> $key,
							label				=> $label->{$c},
							lookup				=> $lookup->{$c},
							lookup_query		=> $lookup_query->{$c},
							maxlength			=> $maxlength->{$c},
							meta				=> $meta->{$c},
							meta_url			=> $meta_url,
							meta_url_specific	=> $meta_url_specific,
							name				=> $namecol,
							options				=> $options->{$c},
							outboard			=> $outboard->{$c},
							override			=> $overridden,
							opts				=> $opts->{$c},
							passed				=> $passed->{$c},
							pre_filter			=> $pre_filter->{$c},
							prepend				=> $prepend->{$c},
							return_hash			=> 1,
							restrict_allow      => $opt->{restrict_allow},
							specific			=> $opt->{ui_meta_specific},
							table				=> $t,
							type				=> $widget->{$c},
							ui_no_meta_display	=> $opt->{ui_no_meta_display},
							width				=> $width->{$c},
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
		$display->{COLSPAN} = qq{ colspan="$colspan->{$namecol}"}
			if $colspan->{$namecol};
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
			my $chunk = delete $opt->{include_before}{$col};
			if($opt->{include_form_interpolate}) {
				$Vend::Interpolate::Tmp->{table_editor_data} = $data;
#::logDebug("data to include=" . ::uneval($data));
				$chunk = interpolate_html($chunk);
			}
			elsif($opt->{include_form_expand}) {
				$chunk = expand_values($chunk);
#::logDebug("include_before: expanded values on $col $chunk");
			}
			my $h = { ROW => $chunk };
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
		chunk ttag(), '<td colspan="$cells_per_span">&nbsp;</td>'; # unless $wo;
		$rowcount++;
	}

	$::Scratch->{mv_data_enable} = '';
	if($opt->{auto_secure}) {
		$::Scratch->{mv_data_enable} .= "$table:" . join(",", @data_enable) . ':';
		$::Scratch->{mv_data_enable} .=  $opt->{item_id};
		$::Scratch->{mv_data_enable_key} = $opt->{item_id};
	}
	if(@ext_enable) {
		$::Scratch->{mv_data_enable} .= " " . join(" ", @ext_enable) . " ";
	}
#::logDebug("setting mv_data_enable to $::Scratch->{mv_data_enable}");
	my @serial = keys %serialize;
	my @serial_fields;
	my @o;
	for (@serial) {
#::logDebug("$_ serial_data=$serial_data{$_}");
		$serial_data{$_} = uneval($serial_data{$_})
			if is_hash($serial_data{$_});
		$serial_data{$_} =~ s/\&/&amp;/g;
		$serial_data{$_} =~ s/"/&quot;/g;
		push @o, qq{<input type="hidden" name="$_" value="$serial_data{$_}">}; # unless $wo;
		push @serial_fields, @{$serialize{$_}};
	}

	if(! $wo and @serial_fields) {
		push @o, qq{<input type="hidden" name="ui_serial_fields" value="};
		push @o, join " ", @serial_fields;
		push @o, qq{">};
		chunk 'HIDDEN_SERIAL', 'OUTPUT_MAP', join("", @o);
	}

	###
	### Here the user can include some extra stuff in the form....
	###
	if($opt->{include_form}) {
		my $chunk = delete $opt->{include_form};
		if($opt->{include_form_interpolate}) {
			$chunk = interpolate_html($chunk);
		}
		elsif($opt->{include_form_expand}) {
			$chunk = expand_values($chunk);
		}
		col_chunk '_INCLUDE_FORM',
					{
						ROW => $chunk,
						TEMPLATE => $opt->{whole_template} || '<tr>{ROW}</tr>',
					};
	}
	### END USER INCLUDE

	unless ($opt->{mailto} and $opt->{mv_blob_only}) {
		@cols = grep ! $display_only{$_} && ! $disabled->{$_}, @cols;
	}
	$passed_fields = join " ", @cols;

	my ($beghid, $endhid) = split m{</td>}i, $opt->{spacer_row}, 2;
	$endhid = "</td>$endhid" if $endhid;
	chunk ttag(), 'OUTPUT_MAP', $beghid;
	chunk 'HIDDEN_EXTRA', 'OUTPUT_MAP', qq{<input type="hidden" name="mv_data_fields" value="$passed_fields">@extra_hidden};
	chunk ttag(), 'OUTPUT_MAP', $endhid;

  SAVEWIDGETS: {
  	last SAVEWIDGETS if $wo || $opt->{nosave}; 
#::logDebug("in SAVEWIDGETS");
		chunk ttag(), 'OUTPUT_MAP', <<EOF;
<tr$opt->{data_row_extra}>
<td$opt->{label_cell_extra}>&nbsp;</td>
<td align="left" colspan="$oddspan"$opt->{data_cell_extra}>
EOF

	  	if($opt->{back_text}) {

			chunk 'COMBINED_BUTTONS_BOTTOM', 'OUTPUT_MAP', <<EOF;
<input type="submit" name="mv_click" value="$opt->{back_text}"$opt->{back_button_extra}>&nbsp;<input type="submit" name="mv_click" value="$opt->{cancel_text}"$opt->{cancel_button_extra}>&nbsp;<b><input type="submit" name="mv_click" value="$opt->{next_text}"$opt->{next_button_extra}></b>
EOF
		}
		elsif($opt->{wizard}) {
			chunk 'WIZARD_BUTTONS_BOTTOM', 'OUTPUT_MAP', <<EOF;
<input type="submit" name="mv_click" value="$opt->{cancel_text}"$opt->{cancel_button_extra}>&nbsp;<b><input type="submit" name="mv_click" value="$opt->{next_text}"$opt->{next_button_extra}></b>
EOF
		}
		else {
			chunk 'OK_BOTTOM', 'OUTPUT_MAP', <<EOF;
<input type="submit" name="mv_click" value="$opt->{next_text}"$opt->{ok_button_extra}>
EOF

			chunk 'CANCEL_BOTTOM', 'NOCANCEL OUTPUT_MAP', <<EOF;
&nbsp;<input type="submit" name="mv_click" value="$opt->{cancel_text}"$opt->{cancel_button_extra}>
EOF

			chunk 'RESET_BOTTOM', 'OUTPUT_MAP', qq{&nbsp;<input type="reset"$opt->{reset_button_extra}>}
				if $opt->{show_reset};
		}


	if($exists and ! $opt->{nodelete} and $Tag->if_mm('tables', "$table=d")) {
		my $key_display = join '/', split /\0/, $key;
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
		my $delmsg = errmsg('Are you sure you want to delete %s?', $key_display);
		if($opt->{output_map} or $opt->{button_delete}) {
			chunk 'DELETE_BUTTON', 'NOSAVE OUTPUT_MAP', <<EOF;
&nbsp;
	<input
		type=button
		onClick="if(confirm('$delmsg')) { location='$url' }"
		title="Delete $key_display"
		value="$delstr"$opt->{delete_button_extra}>
EOF
		}
		else {
			chunk 'DELETE_BUTTON', 'NOSAVE OUTPUT_MAP', <<EOF; # if ! $opt->{nosave};
<br><br><a onClick="return confirm('$delmsg')" href="$url"><img src="delete.gif" alt="Delete $key_display" border="0"></a> $delstr
EOF
		}

	}

	if(! $opt->{notable} and $Tag->if_mm('tables', "$table=x") and ! $db->config('LARGE') ) {
		my $checked = ' CHECKED';
		my $msg = errmsg("Automatically export to text file");
		$checked = ''
			if defined $opt->{mv_auto_export} and ! $opt->{mv_auto_export};
		my $autoexpstr = errmsg('Auto-export');		
		chunk 'AUTO_EXPORT', 'NOEXPORT NOSAVE OUTPUT_MAP', <<EOF;
<small>
&nbsp;
&nbsp;
	<input type="checkbox" class="$opt->{widget_class}" title="$msg" name="mv_auto_export" value="$table"$checked><span class="$opt->{widget_class}" title="$msg">&nbsp;$autoexpstr</span>
EOF

	}

	chunk_alias 'HIDDEN_FIELDS', qw/
										HIDDEN_ALWAYS
										HIDDEN_EXTRA
										HIDDEN_SERIAL
										HIDDEN_USER
										/;
	chunk_alias 'BOTTOM_BUTTONS', qw/
										WIZARD_BUTTONS_BOTTOM
										COMBINED_BUTTONS_BOTTOM
										OK_BOTTOM
										CANCEL_BOTTOM
										RESET_BOTTOM
										/;
	chunk_alias 'EXTRA_BUTTONS', qw/
										AUTO_EXPORT
										DELETE_BUTTON
										/;
	chunk ttag(), 'OUTPUT_MAP', <<EOF;
</small>
</td>
</tr>
EOF
  } # end SAVEWIDGETS

	my $message = '';

	if(@errors) {
		$message .= '<p>Errors:';
		$message .= qq{<font color="$opt->{color_fail}">};
		$message .= '<blockquote>';
		$message .= join "<br>", @errors;
		$message .= '</blockquote></font>';
	}
	if(@messages) {
		$message .= '<p>Messages:';
		$message .= qq{<font color="$opt->{color_success}">};
		$message .= '<blockquote>';
		$message .= join "<br>", @messages;
		$message .= '</blockquote></font>';
	}
	$Tag->error( { all => 1 } );

	chunk ttag(), 'NO_BOTTOM _MESSAGE', <<EOF;
<tr>
	<td colspan=$span$opt->{border_cell_extra}>
EOF

	chunk 'MESSAGE_TEXT', 'NO_BOTTOM', $message; # unless $wo or ($opt->{no_bottom} and ! $message);

	chunk ttag(), 'NO_BOTTOM _MESSAGE', <<EOF;
	</td>
</tr>
EOF

#::logDebug("tcount=$tcount_all, prior to closing table");
	chunk ttag(), <<EOF; # unless $wo;
<tr> 
<td colspan="$span"$opt->{border_cell_extra}><img src="$opt->{clear_image}" width="1" height="$opt->{border_height}" alt="x"></td>
</tr>
</table>
</td></tr></table>
EOF

	my $end_script = '';
	if( $opt->{start_at} || $opt->{focus_at}
			and
		$opt->{form_name}
			and
		$widget->{$opt->{start_at}} !~ /radio|check/i
		)
	{
		my $foc = $opt->{focus_at} || $opt->{start_at};
		$end_script = <<EOF;
<script>
	document.$opt->{form_name}.$foc.focus();
</script>
EOF
	}

	if($opt->{adjust_cell_class}) {
		$end_script .= <<EOF;
<script>
	var mytags=document.getElementsByTagName("td");

	var max = 0;
	var nextmax = 0;
	var type = '$opt->{adjust_cell_class}';
	for(var i = 0; i < mytags.length; i++) {
		if(mytags[i].getAttribute('class') != type)
			continue;
		var wid = mytags[i].offsetWidth;
		var span = mytags[i].getAttribute('colspan');
		if(span < 2 && mytags[i].getAttribute('class') == type && wid >= max) {
			nextmax = max;
			max = wid;
	}
	}
	if(max > 500 && (max / 2) > nextmax) 
		max = nextmax;
	for(var i = 0; i < mytags.length; i++) {
		if(mytags[i].getAttribute('class') != type)
			continue;
		if(mytags[i].getAttribute('colspan') > 1)
			continue;
		mytags[i].setAttribute('width', max);
	}
</script>
EOF
	}

	if(@prescript) {
		my $end = $outhash{FORM_BEGIN};
		$outhash{FORM_BEGIN} = join "\n", $end, @prescript;
	}

	unshift @postscript, qq{</form>$end_script};

	chunk 'FORM_END', 'OUTPUT_MAP', join("\n", @postscript);

	chunk ttag(), $restrict_end;

	chunk_alias 'BOTTOM_OF_FORM', qw/ FORM_END /;

	my %ehash = (
	);
	for(qw/
		BOTTOM_BUTTONS
		NOCANCEL
		NOEXPORT
		NOSAVE
		NO_BOTTOM
		OUTPUT_MAP
		NO_TOP
		SHOW_RESET
		/)
	{
		$ehash{$_} = $opt->{lc $_} ? 1 : 0;
	}

	$ehash{MESSAGE} = length($message) ? 1 : 0;

#::logDebug("exclude is " . uneval(\%exclude));

	if($opt->{output_map}) {
		$opt->{output_map} =~ s/^\s+//;
		$opt->{output_map} =~ s/\s+$//;
		my %map;
		my @map = split /[\s,=\0]+/, $opt->{output_map};
		if(@map > 1) {
			for(my $i = 0; $i <= @map; $i += 2) {
				$map{ uc $map[$i] } = lc $map[$i + 1];
			}
		}
		else {
			%map = qw/
				TOP_OF_FORM			top_of_form
				BOTTOM_OF_FORM		bottom_of_form
				HIDDEN_FIELDS  	    hidden_fields
				TOP_BUTTONS    	    top_buttons
				BOTTOM_BUTTONS    	bottom_buttons
				EXTRA_BUTTONS    	extra_buttons
			/;
		}

		while(my($al, $to) = each %map) {
#::logDebug("outputting alias $al to output $to");
			my $ary = $alias{$al} || [];
#::logDebug("alias $al means " . join(" ", @$ary));
			my $string = join("", @outhash{@$ary});
#::logDebug("alias $al string is $string");
			$Tag->output_to($to, { name => $to}, $string );
		}
	}

	resolve_exclude(\%ehash);

	if($wo) {
		return (map { @$_ } @controls) if wantarray;
		return join "", map { @$_ } @controls;
	}
show_times("end table editor call item_id=$key") if $Global::ShowTimes;

	my @put;
	if($overall_template =~ /\S/) {
		my $death = sub {
			my $item = shift;
			logDebug("must have chunk {$item} defined in overall template.");
			logError("must have chunk {%s} defined in overall template.", $item);
			return undef;
		};

		if($opt->{fields_template_only}) {
			my $tstart = '<table';
			for my $p (qw/height width cellspacing cellmargin cellpadding class style/) {
				my $tag = "table_$p";
				next unless length $opt->{$tag} and $opt->{$tag} =~ /\S/;
				my $val = HTML::Entities::encode($opt->{$tag});
				$tstart .= qq{ $p="$val"};
			}
			$tstart .= ">";
			$overall_template = qq({TOP_OF_FORM}
{HIDDEN_FIELDS}
$tstart
<tr><td colspan="$span">{TOP_BUTTONS}</td></tr>
<tr><td colspan="$span">$overall_template</td></tr>
<tr><td colspan="$span">{BOTTOM_BUTTONS}</td></tr>
</table>
{BOTTOM_OF_FORM}
);
		}

		unless($opt->{incomplete_form_ok}) {
			$overall_template =~ /{TOP_OF_FORM}/
				or return $death->('TOP_OF_FORM');
			$overall_template =~ /{HIDDEN_FIELDS}/
				or return $death->('HIDDEN_FIELDS');
			$overall_template =~ /{BOTTOM_OF_FORM}/
				or return $death->('BOTTOM_OF_FORM');
		}

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
				my $lab  = "${name}__LABEL";
				my $help = "${name}__HELP";
#::logDebug("Got to widget replace $name, thing=$thing");
				$overall_template =~ s/\{$lab\}/$thing->{LABEL}/;
				$overall_template =~ s/\{$help\}/$thing->{HELP}/;
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
			$opt->{panel_table_extra} ||= 'width="100%" cellpadding="3" cellspacing="1"';
			$opt->{panel_table_extra} =~ s/^/ /;
			$opt->{panel_prepend} ||= "<table$opt->{panel_table_extra}>";
			$opt->{panel_append} ||= '</table>';
			push @put, tabbed_display(\@titles,\@tabcont,$opt);
		}
		else {
			my $first = 0;
			for(my $i = 0; $i < @controls; $i++) {
				push @put, tag_attr_list(
								$opt->{break_template},
								{ FIRST => ! $first++, ROW => $titles[$i] },
							)
					if $titles[$i];
				push @put, create_rows($opt, $controls[$i]);
			}
		}
		$overall_template =~ s/{:REST}/join "\n", @put/e;
#::logDebug("overall_template:\n$overall_template");
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
		$opt->{panel_table_extra} ||= 'width="100%" cellpadding="3" cellspacing="1"';
		$opt->{panel_table_extra} =~ s/^/ /;
		$opt->{panel_prepend} ||= "<table$opt->{panel_table_extra}>";
		$opt->{panel_append} ||= '</table>';
		push @put, tabbed_display(\@titles,\@tabcont,$opt);
	}
	else {
#::logDebug("titles=" . uneval(\@titles) . "\ncontrols=" . uneval(\@controls));
		my $first = 0;
		for(my $i = 0; $i < @controls; $i++) {
				push @put, tag_attr_list(
								$opt->{break_template},
								{ FIRST => ! $first++, ROW => $titles[$i] },
							)
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
	my $colspan = $opt->{colspan};
#::logDebug("colspan=" . ::uneval($colspan));

	my @out;

	for my $c (@$columns) {
		my $colname = $c;
		$colname =~ s/^COLUMN_//;
#::logDebug("doing column $c name=$colname");
		# If doesn't exist, was brought in before.
		my $ref = delete $outhash{$c}
			or next;
		if($ref->{ROW}) {
#::logDebug("outputting ROW $c=$ref->{ROW}");
			my $tpl = $ref->{TEMPLATE} || $opt->{combo_template};
			push @out, tag_attr_list($tpl, $ref);
			$rowcount = 0;
			next;
		}
		my $w = '';
		$w .= "<tr$opt->{data_row_extra}>\n" unless $rowcount++ % $rowdiv;
		if(my $s = $colspan->{$colname}) {
#::logDebug("found colspan=$s (ref=$ref->{COLSPAN}) for $colname");
			my $extra =  ($s - 1) / $cells_per_span;
			$rowcount += $extra;
		}
		$w .= tag_attr_list($ref->{TEMPLATE}, $ref);
		$w .= "</tr>" unless $rowcount % $rowdiv;
		push @out, $w;
	}	

	if($rowcount % $rowdiv) {
		my $w = '';
		while($rowcount % $rowdiv) {
			$w .= '<td colspan="$cells_per_span">&nbsp;</td>';
			$rowcount++;
		}
		$w .= "</tr>";
		push @out, $w;
	}
	return join "\n", @out;
}

1;
