# UI::ContentEditor - Interchange page/component edit
# 
# $Id: ContentEditor.pm,v 2.22.2.1 2008-07-09 12:26:00 thunder Exp $
#
# Copyright (C) 2002-2007 Interchange Development Group
# Copyright (C) 1996-2002 Red Hat, Inc.
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

package UI::ContentEditor;

$VERSION = substr(q$Revision: 2.22.2.1 $, 10);
$DEBUG = 0;

use POSIX qw/strftime/;
use Exporter;
use Vend::Util;
use Vend::Interpolate;
use HTML::Entities;

use vars qw!
	@EXPORT
	@EXPORT_OK
	$VERSION
	$DEBUG
	!;

use strict;

@EXPORT = qw( ) ;

@EXPORT_OK = qw( ) ;

=head1 NAME

Vend/ContentEditor.pm -- Interchange Page/component edit

=head1 SYNOPSIS

[component-editor component=search_box ...]
[page-editor page=index ...]

=head1 DESCRIPTION

The Interchange Component and Page editor provides HTML editing support
for Interchange pages, components, and templatees.

=cut

my %New = (
		page => {
				},
		template => {
		},
		component => {
		},
		);
my %Extra_options = (
		standard => {
				name => 'standard_page_editor',
				control_fields
					=> [ qw/page_title page_banner display_class members_only /],
				control_fields_meta => {
					page_title => {
						width => 30,
						label => errmsg('Page Title'),
					},
					page_banner => {
						width => 30,
						label => errmsg('Page Banner'),
					},
					display_class => {
						label => errmsg('Display class'),
						help => errmsg('This overrides the template type with a different display'),
					},
					members_only => {
						label => errmsg('Members only'),
						help => errmsg('Allows only logged-in users to display the page'),
						type => 'yesno',
					},
				},
				component_fields => [qw/ output /],
				component_fields_meta => {
					output => {
						label => errmsg('Output location'),
						help => errmsg('Which section of the page the component should go to'),
						type => 'select',
						passed => qq[
							=default,
							left=Left,
							right=Right,
							top=Top,
							Bottom=Bottom
						],
					},
				},
		},
	);
my %Template;  # Initialized at bottom of file
my @All_templates;
my @All_components;
my @All_pages;

my %CompCache;

sub death {
	my $name = shift;
#::logDebug("called death for $name: " . errmsg(@_));
	Vend::Tags->error( { set => errmsg(@_), name => $name } );
	return undef;
}

sub pain {
	my ($tag, $msg, @args) = @_;
#::logDebug("called pain for $tag: " . errmsg($msg,@args));
	$msg = "$tag: $msg";
	Vend::Tags->warnings(errmsg($msg,@args));
	return;
}

sub assert {
	my ($name, $thing, $type) = @_;
	my $status;
	$status = ref($thing) eq $type
		and return $status;
	my $caller = caller;
	death($caller, "%s (%s) not a(n) %s", $name, $thing, $type);
	return undef;
}

sub delete_store {
	my $type = shift;
	my $name = shift;
	die("Must have type and name for delete_store, args were: " . join(" ", @_))
		unless $type and $name;
	my $store = $Vend::Session->{content_edit} ||= {};
	$store->{$type} ||= {};
	delete $store->{$type}{$name};
}

sub save_store {
	my $type = shift;
	my $name = shift;
	my $value = shift;
	die("Must have type and name for save_store, args were: " . join(" ", @_))
		unless $type and $name;
	my $store = $Vend::Session->{content_edit} ||= {};
	$store->{$type} ||= {};
	$store->{$type}{$name} = $value;
}

sub get_store {
	my $type = shift;
	my $name = shift;
	my $store = $Vend::Session->{content_edit} ||= {};
	return $store unless $type;
	$store->{$type} ||= {};
	return $store->{$type} unless $name;
	return $store->{$type}{$name};
}

sub get_cdb {
	my $opt = shift;
	return $opt->{component_db} if defined $opt->{component_db};
	my $tab = $opt->{component_table};
	$tab  ||= $::Variable->{UI_COMPONENT_TABLE};
	$tab  ||= 'component';
	$opt->{component_db} = ::database_exists_ref($tab) || '';
}

sub get_tdb {
	my $opt = shift;
	return $opt->{template_db} if defined $opt->{template_db};
	my $tab = $opt->{template_table};
	$tab  ||= $::Variable->{UI_TEMPLATE_TABLE};
	$tab  ||= 'template';
	$opt->{template_db} = ::database_exists_ref($tab) || '';
}

sub get_pdb {
	my $opt = shift;
	return $opt->{page_db} if defined $opt->{page_db};
	my $tab = $opt->{page_table};
	$tab  ||= $::Variable->{UI_PAGE_TABLE};
	$tab  ||= 'page';
	$opt->{page_db} = ::database_exists_ref($tab) || '';
}

sub _setref {
	my ($ref, $key, $val) = @_;
	$key = lc $key;
	$key =~ tr/-/_/;
	$ref->{$key} = $val;
}

## This must be non-destructive of $opt, may add keys with component_
sub parse_components {
	my ($wanted, $opt, $components) = @_;
}

sub extract_template {
	my $sref = shift;
	my $opt = shift || {};
	my $tname;

	if ($sref =~ /\nui_(page_template|template_name):\s*(\w+)/) {
		$tname = $2;
	} elsif ($sref =~ /\@_(\w+)_TOP_\@/) {
		$tname = lc $1;
	} else {
		$tname = $opt->{ui_page_template};
	}

#::logDebug("extract_template read template name='$tname'");
	my $tdef;
	my $tref;

	my $allt = $opt->{_templates} ||= available_templates($opt);
#::logDebug("extract_template got all_templates=" . uneval($allt));

	for my $ref (@$allt) {
		if($tname and $tname eq $ref->[0]) {
			$tref = $ref; 
			last;
		}
		next unless is_yes($ref->[3]);
		$tdef = $ref; 
		last;
	}

	$tref ||= $tdef || $allt->[0];
#::logDebug("extract_template derived template name=$tref->[0]");
	my $o = {%$opt};
	$o->{type} = 'template';
	return read_template($tref->[0], $o);
}

## This must be non-destructive of $opt, may add keys with component_
sub parse_template {
	my ($tref, $opt) = @_;
	$opt ||= {};

	
	my $type = $tref->{ui_type};

	my $tdb = get_tdb();

	my $things;
	my @int;
	my @out;
	my @comp;

#::logDebug("ui_template_layout=$tref->{ui_template_layout}");
	if(! ref $tref->{ui_template_layout}) {
		$tref->{ui_template_layout} = [split /\s*,\s*/, $tref->{ui_template_layout}];
	}
#::logDebug("ui_template_layout=$tref->{ui_template_layout}");
	$things = $tref->{ui_template_layout} || [];

	for(@$things) {
#::logDebug("looking at thing=$_");
		if($tref->{$_}) {
			push @int, $tref->{$_};
		}
		elsif($_ eq 'UI_CONTENT') {
#::logDebug("thing=$_ is UI_CONTENT");
			push @int, '';
		}
		elsif(defined $::Variable->{$_}) {
#::logDebug("thing=$_ is Variable");
			push @int, Vend::Tags->var($_);
		}
		elsif($tdb and my $row = $tdb->row_hash($_)) {
#::logDebug("thing=$_ is Data");
			push @int, $row->{comp_text};
		}
		elsif(/^[A-Z][A-Z_0-9]+$/) {
#::logDebug("parse_template: thing=$_ is unknown, creating new thing");
			push @int, qq{<!-- BEGIN $_ -->\n<!-- END $_ -->};
		}
	}

	my %allow = (qw/
					PAGE_PICTURE ui_page_picture
				/);

	while ( $tref->{ui_body} =~ s{
			(<!--+\s+BEGIN\s+(\w+)\s+--+>
				(.*)
			<!--+\s+END\s+\2\s+--+>)
				}
			{ $allow{uc $2} ? '' : $1 }eixs
		)
	{
		my $name = uc $2;
		my $value = $3;
		next unless $allow{$name};
		$tref->{$allow{$name}} = $value;
	}

	my $i = -1;
	for(@int) {
		$i++;
		next unless defined $_;
		push (@out, {}), next unless $_;
		$tref->{$things->[$i]} = $_;
		my $done_one;
		while( m{
				 [ \t]* 
				 (?:
				 	<!--+ \s+ begin \s+ component \s+ (\w+) \s+ (\w*) \s* --+>
				 	(.*?)
					<!--+ \s+ end \s+ component \s+ \1 \s+ --+> 
				 | 
				 	\[ include \s+ (.*?) file \s*=\s*["'][^"]*/
						(?:\[control \s+ component \s* )?
							(\w*)
						\]? ['"]
				 	(.*?)
					\]  \s*  \[control\]
				 |
				 	\[ component
					(
					  (?:
						\s+
						\w[-\w]+\w
						
							\s*=\s*

						(["'\|]?)
							\[?
								[^\n]*?
							\]?
						\8
					   )+
					)?
					\s*
					\]
				 )
			}gsix)
		{
			my $compname = $1 || $5;
			my $comptype = $2;
			my $all = $7;
#::logDebug("all=$all");
			if($all) {
				if($all =~ m{(?:comp[-_]name|default|component)\s*=\s*(['"|])(.*?)\1}is) {
					$compname = $2;
					$compname =~ s/^\s*\[control\s+component\s+//i;
					$compname =~ s/\]\s*$//;
				}
				if($all =~ m{\bgroup\s*=\s*['"\|]?([-\w]+)}) {
					$comptype = $1;
				}
				$compname ||= '';
				$comptype ||= '';
			}
			elsif(! $comptype) {
				my @stuff = ($4, $6, $7, $9);
#::logDebug("no comptype, stuff is: " . uneval(\@stuff));
				@stuff = grep $_, @stuff;
				my $stuff = join "", @stuff;
				$stuff =~ /\s+(?:class|group)\s*=[\s'"]*(\w+)/i
					and $comptype = $1;
			}
#::logDebug("comptype=$comptype");
			push @out, { code => $compname, class => $comptype, where => $things->[$i] };
			push @comp, $compname;
			$done_one = 1;
		}
	}

	$tref->{ui_slots} = \@out;
	$tref->{ui_display_order} ||= [];
#::logDebug("parsed tref=" . uneval($tref));
	return $tref;
}

sub match_slots {
	my ($pref, $tref) = @_;

	my $p = $pref->{ui_slots} || [];
	my $t = $tref->{ui_slots} || [];

#::logDebug("page slots in=" . uneval($p));
#::logDebug("tpl  slots in=" . uneval($t));
	$p ||= [];
	$t ||= [];
	#### Temporarily remove content slot
	my $content;
	my $idx;

	unless (@$p) {
		@$p = @$t;
	}

	for($idx = 0; $idx <= $#$p; $idx++) {
		next if defined $p and $p->[$idx] and $p->[$idx]{where};
		last;
	}

	if($idx > $#$p and $#$p > 0) {
		pain (	'parse_page',
				"No content slot found in page %s",
				$pref->{ui_page_template},
			);
	}
	else {
		$content = splice @$p, $idx, 1;
	}

	#### Find content slot in template
	for($idx = 0; $idx <= $#$t; $idx++) {
		next if defined $t and $t->[$idx] and $t->[$idx]{where};
		last;
	}

	while ($#$p > $#$t) {
		pop @$p;
	}

#::logDebug("splice index=$idx");
	splice @$p, $idx, 0, $content;
#::logDebug("page slots now=" . uneval($p));

	if($idx > $#$t and $#$t > 0) {
		pain (	'parse_page',
				"No content slot found in template %s",
				$pref->{ui_page_template},
			);
	}

	for(my $i = 0; $i < @$t; $i++) {
#::logDebug("Matching slot $i");
		if (! defined $p->[$i]) {
#::logDebug("slot $i not defined?");
			$p->[$i] = { %{$t->[$i]} };
		}
		elsif ($p->[$i]) {
			if($p->[$i]{class} ne $t->[$i]{class}) {
				$p->[$i] =  { %{$t->[$i]} };
			}
			else {
				$p->[$i]{where} = $t->[$i]{where};
			}
		}
	}

	$#$p = $#$t;
#::logDebug("page slots out=" . uneval($p));
#::logDebug("tpl  slots out=" . uneval($t));

}

sub parse_page {
	my ($pref, $opt) = @_;
	$opt ||= {};

#::logDebug("pref ui_body=" . uneval($pref->{ui_body}));
	my $tmpref = { %$pref };
	$tmpref->{ui_body} = substr($tmpref->{ui_body},0,50);
#::logDebug("begin page ref=" . uneval($tmpref));

	if(my $otname = $pref->{ui_template_name}) {
		$pref->{ui_page_template} ||= $otname;
	}
	my $tpl   = $pref->{ui_page_template} || 'none';
#::logDebug("parse page $pref->{ui_name}, template=$tpl");

	## Get template info
	my $tref = get_store('template', $tpl);

	if(! $tref) {
#::logDebug("no tref first try...");
		my $topt = { %$opt };
		undef $topt->{dir};
		undef $topt->{new};
		$topt->{type} = 'template';
		$tref = read_template($tpl, $topt);
	}

#::logDebug("parse page looking for template, got " . uneval($tref));

	assert('template_reference', $tref, 'HASH')
		or undef $tref;

	if (! $tref) {
#::logDebug("no tref second try...");
		pain('read_template', '%s %s not found', 'template', $tpl);
		$tref = read_template('', { new => 1, type => 'template'});
	}
#::logDebug("tref ready to parse: " . uneval($tref));
	parse_template($tref, $opt);
	## Xfer needed template info
	my $order = $pref->{ui_display_order}   = [ @{ $tref->{ui_display_order} } ];
#::logDebug("tref order was: " . uneval($order));

	$pref->{ui_template_layout} = [ @{ $tref->{ui_template_layout} } ];
	$pref->{ui_page_picture}    = $tref->{ui_page_picture};
	for(@$order) {
		$pref->{$_} = { %{$tref->{$_}} };
	}

	my $body = delete $pref->{ui_body};

#::logDebug("page body=" . uneval($body));
	unless(defined $body) {
		### Already parsed, match slots and leave if not new page
		match_slots($pref, $tref);
#::logDebug("pref now=" . uneval($pref));
		return unless $opt->{new};
	}

	my @slots = @{ $pref->{ui_slots} || $tref->{ui_slots} || [] };

	#$body =~ s/\r\n/\n/g;

	my %allow = (qw/
					CONTROLS 1
					PREAMBLE 1
					CONTENT 1
					POSTAMBLE 1
				/);
	my $found;
	while ( $body =~ s{
			(<!--+\s+BEGIN\s+(\w+)\s+(?:(\w+)\s+)?--+>
				(.*)
			<!--+\s+END\s+\2\s+.*?--+>)
				}
			{ $allow{uc $2} ? '' : $1 }eixs
		)
	{
		my $name = uc $2;
		my $index = $3;
		my $value = $4;
		next unless $allow{$name};
		$found++;
#::logDebug("matched name=$name index=$index");
		if(! $index) {
			$pref->{$name} = $value;
		}
		elsif($index =~ /\D/) {
			if(! $pref->{$name}) {
				$pref->{$name} = { $index => $value };
			}
			elsif (! ref $pref->{$name}) {
				my $tmp = $pref->{$name};
				$pref->{$name} = {
					'' => $tmp,
					$index => $value,
				};
			}
			elsif (ref ($pref->{$name}) eq 'HASH') {
				$pref->{$name}{$index} = $value;
			}
			else {
				die errmsg(
					"bad content pointer reference %s %s %s",
					'BEGIN/END',
					$name,
					$index,
				);
			}
		}
		elsif ($index) {
			if(! $pref->{$name}) {
				$pref->{$name} = [];
				$pref->{$name}[$index] = $value;
			}
			elsif (! ref $pref->{$name}) {
				my $tmp = $pref->{$name};
				$pref->{$name} = [];
				$pref->{$name}[0] = $tmp;
				$pref->{$name}[$index] = $value;
			}
			elsif (ref ($pref->{$name}) eq 'ARRAY') {
				$pref->{$name}[$index] = $value;
			}
			else {
				die errmsg(
					"bad content pointer reference %s %s %s",
					'BEGIN/END',
					$name,
					$index,
				);
			}
		}
	}

	$pref->{CONTENT} = $body unless $found;

	my $controls;
	if($pref->{CONTROLS}) {
		$controls = $pref->{CONTROLS};
		$pref->{COMMENTS} = $body; 
		undef $body;
	}
	else {
		$controls = $body;
	}

#::logDebug("controls is $controls");
	## All that should be left now is [control] and [set]

	my @comp;
	my @compnames;
	my $comphash = {};
	while($controls =~ s{\[control-set\](.*?)\[/control-set\]}{}is ) {
            my $sets = $1;
            my $r = {};
            $sets =~ s{\[([-\w]+)\](.*?)\[/\1\]}{ _setref($r, $1, $2) }eisg;
            push @comp, $r;
            push @compnames, $r->{component};
	}

	my $vals		= {};
	my $scratches	= {};

#::logDebug("controls is $controls");
    while($controls =~ s{
						(?:
							\[
								(seti?|tmpn?)
							\s+
								([^\]]+)
							\]
								(.*?)
							\[/\1\])}{}isx
			)
	{
        $scratches->{$2} = $1;
        $vals->{$2}      = $3;
    }

	if($scratches->{not_editable} and $vals->{not_editable}) {
		return death('controls', "Not editable page");
	}

	my $idx;
	for($idx = 0; $idx <= $#slots; $idx++) {
		next if $slots[$idx] and $slots[$idx]{where};
		last;
	}

	if($idx > $#slots) {
		pain (	'parse_page',
				"No content slot found in template %s",
				$pref->{ui_page_template},
			);
	}
	else {
		splice @comp, $idx, 0, '';
	}

#::logDebug("#slots=" . scalar(@slots) . "#comp=" . scalar(@comp));
	for( my $i = 0; $i < @comp; $i++) {
		my $r =  $comp[$i]
			or next;
		my $s = $slots[$i]
			or pain('parse_page', "no slot number %s", $i), next;
		$s->{code} = $r->{component};
		while( my ($k, $v) = each %$r) {
			$s->{$k} = $v;
		}
	}

	$pref->{ui_slots}		= \@slots;
	$pref->{ui_values}		= $vals;
	$pref->{ui_scratchtype} = $scratches;

	$tmpref = { %$pref };
	$tmpref->{CONTENT} = substr($tmpref->{CONTENT},0,50);
#::logDebug("Parsed pref=" . ::uneval($tmpref));
	return @compnames;

}

my %leg_remap = qw/
	ui_component              ui_name
	ui_component_type         ui_class
	ui_template_name          ui_name
	ui_template_description   ui_label
	ui_component_group        ui_group
	ui_component_help         ui_help
	ui_component_label        ui_label
/;

sub legacy_components {
	my ($ref, $type) = @_;

	return if $ref->{ui_name} and $ref->{ui_type} and $ref->{ui_label};
	while( my($old, $new) = each %leg_remap) {
		my $tmp = delete $ref->{$old};
		next if defined $ref->{$new} and length($ref->{$new});
		$ref->{$new} = $tmp;
	}
	$ref->{ui_type} = $type;
	delete $ref->{ui_template};
	return;
}

sub read_template {
	my ($spec, $opt) = @_;

	## For syntax check
	#use vars qw/%CompCache/;

	$opt ||= {};

	my $o = { %$opt };

	my $type = $o->{type} = 'template';

	my $class = $opt->{class};

	my $db;
	$db = database_exists_ref($opt->{table}) if $opt->{table};

	my @data;

	if($spec eq 'none') {
		return {
            ui_name				=> 'none',
            ui_type				=> 'template',
            ui_label			=> 'No template',
            ui_template_version	=> $::VERSION,
            ui_template_layout  => 'UI_CONTENT',
		};
	}

	if($opt->{new}) {
		# do nothing
	}
	elsif($spec) {
		if(! $db) {
			@data = get_content_data($spec,$o);
		}
		else {
			my @atoms;
			my $tname = $db->name();
			push @atoms, "select * from $tname";
			push @atoms, "where code = '$spec'";
			my $q = join " ", @atoms;
			my $ary = $db->query({ sql => $q, hashref => 1 });
			for(@$ary) {
				push @data, [ $_->{comp_text}, "$table::$spec" ];
			}
		}
	}

	if(@data > 1) {
		logError(
			"ambiguous %s spec, %s selected. Remaining:\n%s",
			errmsg($type),
			$data[0][1],
			join(",", map { $_->[1] } @data[1 .. $#data]),
			);
	}

	my $ref;
	my $dref;

	if(not $dref = $data[0]) {
#::logDebug("no data, and new");
		$opt->{type} ||= 'page';
		my $prefix = "ui_$type";
		$ref = {
            ui_name				=> $spec,
            ui_type				=> $type,
            ui_source			=> '',
            ui_label			=> '',
            "${prefix}_version"	=> Vend::Tags->version(),
		};
		my $name = uc $spec;
		$name =~ s/\W/_/g;
		$name =~ s/__+/_/g;
		$ref->{ui_template_layout} = "${name}_TOP, UI_CONTENT, ${name}_BOTTOM";
	}
	else {
	  READCOMP: {
		assert("$type reference", $dref, 'ARRAY')
			or return death("read_$type", "Component read error for %s", $spec);
		my ($data, $source) = @$dref;
#::logDebug("template data is $data");
		$ref = {};

		unless (length($data)) {
			return death("read_$type", "empty %s: %s", errmsg($type), $source);
		}

		if($data =~ m{^\s*<\?xml version=.*?>}) {
			$ref = read_xml_component($data, $source);
#::logDebug("Got this from read_xml_component: " . ::uneval($ref));
			last READCOMP;
		}

		$ref = {};

		$data =~ m{\[comment\]\s*(ui_.*?)\[/comment\]\s*(.*)}s;
		my $structure = $1 || '';
		$ref->{ui_body} = $2;
		unless ($structure) {
			return death("read_$type", "bad %s: %s", errmsg($type), $source);
		}

		my @lines = get_lines($structure);
#::logDebug("Got lines from get_lines: " . ::uneval(\@lines));
		
		parse_line($_, $ref) for @lines;
#::logDebug("Parsed lines: " . ::uneval(\@lines));

		delete $ref->{_current};

		if(my $order = $ref->{ui_display_order}) {
			for (@$order) {
				remap_opts($ref->{$_});
			}
		}

		$ref->{ui_type}   = $type;
		$ref->{ui_source} = $source;

#::logDebug("read tref=" . uneval($ref));
		legacy_components($ref, $type);
#::logDebug("tref after legacy remap=" . uneval($ref));

		if(! $ref->{ui_name}) {
			# Compatibility with old templates
			unless ($ref->{ui_name} = delete $ref->{"ui_${type}_name"}) {
				return death("read_$type", "%s (%s) must have a name", $type, $source);
			}
		}
		if($ref->{"ui_$type"} eq 'Yes') {
			delete $ref->{"ui_$type"};
		}
	  }
	}

	return $ref;

}


sub read_component {

	my ($spec, $opt) = @_;
	$opt ||= {};
	
	my $o = { %$opt };
	my $type = $o->{type} = 'component';

	my $class = $opt->{class};

	my $db;
	$db = database_exists_ref($opt->{table}) if $opt->{table};

	my @data;

	if($opt->{new}) {
		# do nothing
	}
	elsif($spec) {
		if(! $db) {
			@data = get_content_data($spec, $o);
		}
		else {
			my $tname = $db->name();
			my @atoms;
			push @atoms, "select * from $tname";
			push @atoms, "where code = '$spec'";
			my $q = join " ", @atoms;
			my $ary = $db->query({ sql => $q, hashref => 1 });
			for(@$ary) {
				push @data, [ $_->{comp_text}, "$table::$spec" ];
			}
		}
	}
	else {
		$opt->{new} = 1;
	}

	if(@data > 1) {
		logError(
			"ambiguous %s spec, %s selected. Remaining:\n%s",
			errmsg('component'),
			$data[0][1],
			join(",", map { $_->[1] } @data[1 .. $#data]),
			);
	}

	my $ref;
	my $dref;

	if(not $dref = $data[0]) {
#::logDebug("no data, and new");
		$opt->{type} ||= 'page';
		my $prefix = "ui_$opt->{type}";
		$ref = {
            ui_name               => $spec,
            ui_label              => '',
            ui_class              => '',
            ui_group              => '',
            ui_type               => $opt->{type},
            ui_source             => '',
            "${prefix}_version"   => Vend::Tags->version(),
		};
		if($opt->{type} eq 'page') {
			$ref->{ui_page_template} = $opt->{template};
		}
		elsif($opt->{type} eq 'template') {
			my $name = uc $spec;
			$name =~ s/\W/_/g;
			$name =~ s/__+/_/g;
			$ref->{ui_template_layout} = "${name}_TOP, UI_CONTENT, ${name}_BOTTOM";
		}
	}
	else {
	  READCOMP: {
		assert("$type reference", $dref, 'ARRAY')
			or return death("read_$type", "Component read error for %s", $spec);
		my ($data, $source) = @$dref;
#::logDebug("component data is $data");
		$ref = {};

		unless (length($data)) {
			return death("read_$type", "empty %s: %s", errmsg($type), $source);
		}

		if($data =~ m{^\s*<\?xml version=.*?>}) {
			$ref = read_xml_component($data, $source);
#::logDebug("Got this from read_xml_component: " . ::uneval($ref));
			last READCOMP;
		}

		$ref = {};

		$data =~ m{\[comment\]\s*(ui_.*?)\[/comment\]\s*(.*)}s;
		my $structure = $1 || '';
		$ref->{ui_body} = $2;
		unless ($structure) {
			return death("read_$type", "bad %s: %s", errmsg($type), $source);
		}

		my @lines = get_lines($structure);
		
		parse_line($_, $ref) for @lines;

		delete $ref->{_current};

		if(my $order = $ref->{ui_display_order}) {
			for (@$order) {
				remap_opts($ref->{$_});
			}
		}
		
		$ref->{ui_type}   = $type;
		$ref->{ui_source} = $source;

#::logDebug("read cref=" . uneval($ref));
		legacy_components($ref, $type);
#::logDebug("cref after legacy remap=" . uneval($ref));

		if(! $ref->{ui_name}) {
			return death(	
						"read_$type",
						"%s (%s) must have a name",
						errmsg($type),
						$source,
					);
		}
	  }
	}

	return $ref;

}

sub get_content_dirs {
	my $opt = shift;
	$opt ||= {};
	my $dir;
	
	if($dir = $opt->{dir}) {
		# look no farther
	}
	elsif($opt->{type} eq 'page') {
		$dir = $Vend::Cfg->{PageDir};
	}
	else {
		my $tdir	=  $opt->{template_dir}
					|| $::Variable->{UI_TEMPLATE_DIR} || 'templates';
		if($opt->{type} eq 'component') {
			$dir = $opt->{component_dir}
				 || $::Variable->{UI_COMPONENT_DIR} || "$tdir/components";
		}
		else {
			$dir = $tdir;
		}
	}
	my $tmpdir  = $Vend::Cfg->{ScratchDir} || 'tmp';
	for(\$tmpdir, \$dir) {
		$$_ =~ s!^$Vend::Cfg->{VendRoot}/!!;
	}
	$tmpdir .= "/components/$Vend::Session->{id}";
	return($dir, $tmpdir) if wantarray;
	return $dir;
}

sub get_content_filenames {
	my $spec = shift;
	my $opt = shift;

	$spec ||= '*';
	my $dir = get_content_dirs($opt);
#::logDebug("got a dir=$dir for $opt->{type}");
	return grep -f $_, glob("$dir/$spec");
}

sub get_content_data {
	my $spec = shift;
	my $opt = shift;

	my @data;
	for(get_content_filenames($spec, $opt)) {
#::logDebug("Looking at filename $_");
		push @data, [ Vend::Util::readfile($_, undef, 0), $_ ];
	}
	
	return @data if wantarray;
	return \@data;
}

sub content_info {
	my ($dir, $opt) = @_;

	$opt ||= {};

	$opt->{dir} = $dir if $dir;

	my $delim = $opt->{delimiter} || ',';
	my $type;
	if( $opt->{templates} ) {
		$type = 'templates';
	}
	else {
		$type = 'components';
	}

	my $tpls;
	my $comps;
	my $things;
	my $labels;
	my $classes;

	my $o = { %$opt };

	if($Vend::caCompCache{$type}) {
		$things = $Vend::caCompCache{$type};
		$labels = $Vend::clCompCache{$type};
		$classes = $Vend::ccCompCache{$type};
	}
	else {
		if($opt->{templates}) {
			$things = available_templates($o);
		}
		else {
			$things = available_components($o);
		}
		$Vend::caCompCache{$type} = $things;
		$labels = $Vend::clCompCache{$type} = {};
		$classes = $Vend::ccCompCache{$type} = {};
		for(@$things) {
			$Vend::clCompCache->{$_->[0]} = $_->[1];
			$Vend::ccCompCache->{$_->[0]} = $_->[2];
		}
	}

	if($opt->{label}) {
		return $Vend::clCompCache->{$opt->{code}};
	}

	if($opt->{structure}) {
		$opt->{type} = $opt->{ui_type} = 'component';
		return read_component($opt->{code}, $opt);
	}

	if ($opt->{show_class}) {
		return $Vend::ccCompCache->{$opt->{code}};
	}

	## Default is to return options

	my @out;
	if(my $class = $opt->{class}) {
		my $re = qr{\b(?:$class|ALL)\b};
		my @comps = grep $_->[2] =~ $re, @$things;
		$things = \@comps;
	}

	unless ($opt->{no_sort}) {
		@$things = sort { $a->[1] cmp $b->[1] } @$things;
	}

	for(@$things) {
		$_->[1] =~ s/($delim)/'&#' . ord($1) . ';'/ge;
		my $def = is_yes($_->[3]) ? '*' : '';
		push @out, join "=", $_->[0], "$_->[1]$def";
	}
	unshift @out, ($opt->{templates} ? "none=No template" : "=No component")
		unless $opt->{no_none};
	return join $delim, @out;
}

sub available_components {
	my ($opt) = @_;
	$opt ||= {};
	my $db;
	my $o = { %$opt };
	$o->{type} = 'component';
	$db = ::database_exists_ref($opt->{table}) if $opt->{table};
	
	my @data;
	if(! $db) {
		@data = get_content_data(undef,$o);
#::logDebug(sprintf("got %d items from get_content_data", scalar(@data)));
	}
	else {
		my @atoms;
		my $tname = $db->name();
		push @atoms, "select code,comp_text from $tname";
		push @atoms, "where comp_type = '$opt->{type}'" if $opt->{type};
		push @atoms, "where comp_class = '$opt->{class}'" if $opt->{class};
		my $q = join " ", @atoms;
		my $ary = $db->query({ sql => $q, hashref => 1 });
		for(@$ary) {
			push @data, [ $_->{comp_text}, "$table::$_->{code}" ];
		}
	}
	my @out;
			
	for my $dref (@data) {
		my $data = \$dref->[0];
		my ($name, $label, $class);
		(
		$$data =~ /\nui_name:\s*(.+)/
			or $$data =~ /\nui_component_name:\s*(.+)/
			or $$data =~ /\nui_component:\s*(.+)/
			or logDebug("name not found in data: $$data")
		)
		and $name = $1;
		(
		$$data =~ /\nui_label:\s*(.+)/
			or $$data =~ /\nui_component_label:\s*(.+)/
			or $$data =~ /\nui_component_description:\s*(.+)/
		)
		and $label = $1;
		(
		$$data =~ /\nui_class:\s*(.+)/
			or $$data =~ /\nui_component_type:\s*(.+)/
			or $$data =~ /\nui_component_group:\s*(.+)/
		)
		and $class = $1;
		push @out, [$name, $label, $class];
	}

	return @out if wantarray;
	return \@out;
}

sub available_templates {
	my ($opt) = @_;
	$opt ||= {};
	my $db;
	my $o = { %$opt };
	$o->{type} = 'template';
	$db = ::database_exists_ref($opt->{table}) if $opt->{table};

	my @data;
	if(! $db) {
		@data = get_content_data(undef,$o);
	}
	else {
		my @atoms;
		my $tname = $db->name();
		push @atoms, "select code,comp_text from $tname";
		push @atoms, "where comp_type = '$opt->{type}'" if $opt->{type};
		push @atoms, "where comp_class = '$opt->{class}'" if $opt->{class};
		my $q = join " ", @atoms;
		my $ary = $db->query({ sql => $q, hashref => 1 });
		for(@$ary) {
			push @data, [ $_->{comp_text}, "$table::$_->{code}" ];
		}
	}
	my @out;
			
	for my $dref (@data) {
		my $data = \$dref->[0];
		my ($name, $label, $class, $default);
		(
		$$data =~ /\nui_name:\s*(.+)/
			or $$data =~ /\nui_template_name:\s*(.+)/
			or $$data =~ /\nui_template:\s*(.+)/
			or logDebug("name not found in data: $$data")
		)
		and $name = $1;
		(
		$$data =~ /\nui_label:\s*(.+)/
			or $$data =~ /\nui_template_label:\s*(.+)/
			or $$data =~ /\nui_template_description:\s*(.+)/
		)
		and $label = $1;
		(
		$$data =~ /\nui_class:\s*(.+)/
			or $$data =~ /\nui_template_type:\s*(.+)/
			or $$data =~ /\nui_template_group:\s*(.+)/
		)
		and $class = $1;
		(
		$$data =~ /\nui_default:\s*(.+)/
			or $$data =~ /\nui_template_default:\s*(.+)/
		)
		and $default = $1;
		push @out, [$name, $label, $class, $default];
	}
	return @out if wantarray;
	return \@out;
}

sub get_lines {
	my ($structure, $opt) = @_;
	$opt ||= $_;
	$structure =~ s/\s+$//;
	my @lines = split /\r?\n/, $structure;
	my $found;
	for(;;) {
		my $i = -1;
		for(@lines) {
			$i++;
			next unless s/\\$//;
			$found = $i;
			last;
		}
		last unless defined $found;
		if (defined $found) {
			my $add = splice @lines, $found + 1, 1;
#::logDebug("Add is '$add', found index=$found");
			$lines[$found] .= "\n$add";
#::logDebug("Complete line now is '$lines[$found]'");
			undef $found;
		}
	}
	return @lines;
}

sub parse_line {
	my ($line, $ref) = @_;
	$line =~ s/\s+$//;
	my $type;
	if($line =~ /^\s*ui_/) {
		my ($el, $el_item, $el_data);
		if($line =~ /\n/) {
			($el, $el_item) = split /\s*:\s*/, $_, 2;
		}
		else {
			($el, $el_item, $el_data) = split /\s*:\s*/, $_, 3;
		}
#::logDebug("found el=$el el_item=$el_item el_data=$el_data");
		if(! defined $el_data) {
			$ref->{$el} = $el_item;
		}
		else {
			if($el_item eq 'ARRAY') {
				$ref->{$el} ||= [];
				assert($el, $ref->{$el}, 'ARRAY')
					or return undef;
				push @{$ref->{$el}}, [ split /[\s,\0]+/, $el_data ];
			}
			if($el_item eq 'HASH') {
				$ref->{$el} ||= {};
				assert($el, $ref->{$el}, 'HASH')
					or return undef;
				my %hash = get_option_hash($el_data);
				@{$ref->{$el}}{keys %hash} = values %hash;
			}
		}
	}
	elsif ( $line =~ /^(\w+)\s*:\s*(.*)/) {
		$ref->{_current} = $1;
		my $lab = $2;
		$ref->{ui_display_order} ||= [];
		push @{$ref->{ui_display_order}}, $ref->{_current};
	}
	elsif( $line =~ /^\s+(\w+)\s*:\s*(.*)/s ) {
		my ($fn, $fv) = ( lc($1), $2 );
		$ref->{$ref->{_current}}{$fn} = $fv;
	}
	return;
}

sub read_page {
	my ($spec, $opt) = @_;

	my $db;
	$db = database_exists_ref($opt->{table}) if $opt->{table};

	my @data;
	my $type = 'page';

	if($opt->{new}) {
		# do nothing
	}
	elsif($spec and ! $db) {
		@data = get_content_data($spec, $opt);
	}
	elsif($spec) {
		my $tname = $db->name();
		my @atoms;
		push @atoms, "select * from $tname";
		push @atoms, "where code = '$spec'";
		my $q = join " ", @atoms;
		my $ary = $db->query({ sql => $q, hashref => 1 });
		for(@$ary) {
			push @data, [ $_->{comp_text}, "$table::$spec" ];
		}
	}
	else {
		$opt->{new} = 1;
	}

	if(@data > 1) {
		logError(
			"ambiguous page spec, %s selected. Remaining:\n%s",
			$data[0][1],
			join(",", map { $_->[1] } @data[1 .. $#data]),
			);
	}

	my $dref = $data[0];

	my $ref;

	if(! $dref) {
#::logDebug("no data");
		my $prefix = "ui_$type";
		$ref = {
            ui_name               => $spec,
            ui_type               => $opt->{type},
            ui_source             => '',
			ui_body				  => '',
            "${prefix}_version"   => Vend::Tags->version(),
		};

		my $tref = extract_template('', $opt);
		assert('template', $tref, 'HASH')
			or return death('Not even a default template!');
		$ref->{ui_page_template} = $tref->{ui_name};
	}
	else {
      READCOMP: {
		my ($data, $source) = @{$dref || []};
#::logDebug("read page from source=$source");

		$ref = {};

		my $tref = extract_template($data, $opt);
		assert('read_page', $tref, 'HASH')
		  or return death('read_page', "%s has no %s", $source, errmsg('template'));
		$ref->{ui_page_template} = $tref->{ui_name};
#::logDebug("page=$spec template=$ref->{ui_page_template}");

		if($data =~ m{^\s*<\?xml version=.*?>}) {
			$ref = read_xml_component($data, $source);
#::logDebug("Got this from read_xml_component: " . ::uneval($ref));
			last READCOMP;
		}

		$data =~ m{\[comment\]\s*(ui_.*?)\[/comment\]\s*(.*)}s;
		my $structure = $1 || '';
		$ref->{ui_body} = $2;
		if(! $structure) {
			$structure = <<EOF;
ui_name: $spec
ui_type: page
ui_page_template: none
EOF
			$ref->{ui_body} = $data;
		}

		my @lines = get_lines($structure);
		parse_line($_, $ref) for @lines;

#::logDebug("page=$spec ui_name=$ref->{ui_name} after structure parse");

		delete $ref->{_current};

		if(my $order = $ref->{ui_display_order}) {
			for (@$order) {
				remap_opts($ref->{$_});
			}
		}

#::logDebug("page=$spec ui_name=$ref->{ui_name} after remap_opts");

		$ref->{ui_name}   ||= $spec;
		$ref->{ui_type}   = $type;
		$ref->{ui_source} = $source;

	  }
	}
#::logDebug("page=$spec ui_name=$ref->{ui_name}");
#::logDebug("page read returning: " . uneval($ref));
	return $ref;
}

sub page_component_editor {
	my ($name, $pos, $comp, $pref, $opt) = @_;

	assert('page reference', $pref, 'HASH')
		or return undef;

	assert('component reference', $comp, 'HASH')
		or return undef;

	$name ||= $comp->{code};

#::logDebug("called page_component_editor, name=$name comp=" . ::uneval($comp));
	my $hidden = { 
			ui_name   => $pref->{ui_name},
			ui_source => $pref->{ui_source},
			ui_page_template => $pref->{ui_page_template},
			ui_type   => $pref->{ui_type},
			ui_content_op => 'modify_component',
			ui_content_pos => $pos,
	};

	my @fields = 'code';

	my $topt = { %$opt };
	delete $topt->{dir};
	delete $topt->{new};
	$topt->{type} = 'component';
	my $cref = get_store('component', $name) || read_component($name, $topt);

	ref($cref) eq 'HASH'
		or $cref = {};

	my $action = Vend::Tags->area($Global::Variable->{MV_PAGE});
	$action =~ s/\?.*//;
	my $extra = qq{ onChange="
					if(check_change() == true) {
						this.form.action='$action';
						this.form.submit();
					}"
				};
	$extra =~ s/\s+/ /g;
	my $meta = {
		code => {
			type => 'select',
			passed => Vend::Tags->content_info(),
			label => 'Component',
		},
	};
	my $label = "$name - " . Vend::Tags->content_info( { code => $name, label => 1});
	$label = "<H3 align=center>$label</h3>";
	my $value = { code => $name };

	my $js = {
					code => $extra,
			};

	my $order = $cref->{ui_display_order} || [];
	#return undef unless @$order;

	if( my $extra_opt = $Extra_options{$opt->{editor_style}} ) {
		my $name = $extra_opt->{name} || 'page_editor';
		my $dbopt = $Tag->meta_record('ui_component', $name);
		my $ef = $dbopt->{component_fields} || $extra_opt->{component_fields};
		unless (ref $ef eq 'ARRAY') {
			my @f = grep /\w/, split /[\s,\0]+/, $ef;
			$ef = \@f;
		}
		if($ef) {
			my $eo = $extra_opt->{component_fields_meta} || {};
			my %seen;
			for(@$order) {
				$seen{$_} = 1;
			}
			for(@$ef) {
				next if $seen{$_};
				push @$order, $_;
				$cref->{$_} = $Tag->meta_record("ui_component::$_",  $name)
					or
				$cref->{$_} = $eo->{$_} ? { %{ $eo->{$_} } } : {};
			}
			if($Tag->if_mm('super')) {
				for(@$order) {
					my $url = $Tag->area({
						href => 'admin/meta_editor',
						form => qq{
							item_id=${name}::ui_component::$_
							ui_return_to=$Global::Variable->{MV_PAGE}
							ui_return_to=ui_name=$cref->{ui_name}
						},
					});
					my $anchor = errmsg('meta');
					my $title = errmsg('Edit meta');
					$cref->{$_}{label} ||= $_;
					$cref->{$_}{label} = qq{<a href="$url" title="$title" style="float: right">$anchor</a>$cref->{$_}{label}};
				}
			}
		}
	}

	for my $f (@$order) {
#::logDebug("building field $f");
		$meta->{$f} = { %{ $cref->{$f} || {} } };
		my $lab = $meta->{$f}{label} || $f;
		push @fields, "";
		push @fields, "=$lab";
		push @fields, "";
		push @fields, $f;
		$meta->{$f}{label} = 'value';
		$value->{$f} = defined $comp->{$f} ? $comp->{$f} : $meta->{$f}{default};

		next if $meta->{$f}{type} and $meta->{$f}{type} !~ /text/i;
		my $st = "_scratchtype_$f";
		push @fields, $st;
		$meta->{$st} = {
			label => 'how to set',
			type => 'select',
			passed => qq{tmpn=Unparsed and temporary,
					set=Unparsed and persistent,
					tmp=Parsed and temporary,
					seti=Parsed and persistent},
		};
		$value->{$st} = $comp->{$st};
	}

	my $fields = join "\n", @fields;

	my $tw = $opt->{table_width} || '100%';
	# Have to increment position by one to get the slot number
	my $p = $pos;
	$p++;
	my %options = (
		action => 'return',
		defaults => 1,
		extra => $js,
		force_defaults => 1,
		form_extra => qq{onSubmit="submitted('slot$p'); silent_submit(this.form)" onReset="submitted('slot$p')"},
		hidden => $hidden,
		href   => 'silent/ce_modify',
		js_changed => qq{ onChange="changed('slot$p')"},
		meta   => $meta,
		next_text => 'Save',
		no_meta => 1,
		nocancel => 1,
		noexport => 1,
		notable => 1,
		show_reset => 1,
		table_width => $tw,
		ui_data_fields => $fields,
		view => 'ui_component',
	);
	$options{default_ref} = $value;
	$options{item_id} = $name;
	return Vend::Tags->table_editor( \%options );
}

sub page_control_editor {
	my ($pref, $opt) = @_;
#::logDebug("called page_control_editor");
	assert('page reference', $pref, 'HASH')
		or return undef;

	my $hidden = { 
			ui_name   => $pref->{ui_name},
			ui_source => $pref->{ui_source},
			ui_type   => $pref->{ui_type},
			ui_content_op => 'modify_control',
	};

	my $order;
	assert('page display order', $order = $pref->{ui_display_order}, 'ARRAY')
		or return undef;

	my $meta = { };
	my @fields = 'code';

	if( my $extra_opt = $Extra_options{$opt->{editor_style}} ) {
		my $name = $extra_opt->{name} || 'page_editor';
		my $dbopt = $Tag->meta_record('ui_control', $name);
		my $ef = $dbopt->{control_fields} || $extra_opt->{control_fields};
		unless (ref $ef eq 'ARRAY') {
			my @f = grep /\w/, split /[\s,\0]+/, $ef;
			$ef = \@f;
		}
		if($ef) {
			my $eo = $extra_opt->{control_fields_meta} || {};
			my %seen;
			for(@$order) {
				$seen{$_} = 1;
			}
			for(@$ef) {
				next if $seen{$_};
				push @$order, $_;
				$pref->{$_} = $Tag->meta_record("ui_control::$_",  $name)
					or
				$pref->{$_} = $eo->{$_} ? { %{ $eo->{$_} } } : {};
			}
			if($Tag->if_mm('super')) {
				for(@$order) {
					my $url = $Tag->area({
						href => 'admin/meta_editor',
						form => qq{
							item_id=${name}::ui_control::$_
							ui_return_to=$Global::Variable->{MV_PAGE}
							ui_return_to=ui_name=$pref->{ui_name}
						},
					});
					my $anchor = errmsg('meta');
					my $title = errmsg('Edit meta');
					$pref->{$_}{label} ||= $_;
					$pref->{$_}{label} = qq{<a href="$url" title="$title" style="float: right">$anchor</a>$pref->{$_}{label}};
				}
			}
		}
	}

	for my $f (@$order) {
		$meta->{$f} = { %{ $pref->{$f} } };
		my $lab = $meta->{$f}{label} || $f;
		push @fields, "";
		push @fields, "=$lab";
		push @fields, "";
		push @fields, $f;
		$meta->{$f}{label} = 'value';

		next if $meta->{$f}{type} and $meta->{$f}{type} !~ /text/i;
		my $st = "_scratchtype_$f";
		push @fields, $st;
		$meta->{$st} = {
			label => 'how to set',
			type => 'select',
			passed => qq{tmpn=Unparsed and temporary,
					set=Unparsed and persistent,
					tmp=Parsed and temporary,
					seti=Parsed and persistent,
			},
			value => $pref->{ui_scratchtype}{$f},
		};
	}

	my $fields = join "\n", @fields;

	my $tw = $opt->{table_width} || '100%';
	my $p = $pref->{ui_name};
	my %options = (
		action => 'return',
		defaults => 1,
		force_defaults => 1,
		form_extra => qq{onSubmit="submitted('$p'); silent_submit(this.form)" onReset="submitted('$p')" height="100%"},
		hidden => $hidden,
		href   => 'silent/ce_modify',
		js_changed => qq{onChange="changed('$p')"},
		meta   => $meta,
		next_text => 'Save',
		no_meta => 1,
		nocancel => 1,
		noexport => 1,
		notable => 1,
		show_reset => 1,
		table_width => $tw,
		ui_data_fields => $fields,
		ui_hide_key => 1,
		view => 'ui_component',
	);
	$options{default_ref} = $pref->{ui_values};
	$options{item_id} = $p;
	return Vend::Tags->table_editor( \%options );
}

sub make_control_editor {
	my ($w, $r, $overall) = @_;
	$overall ||= {};
	my $type = $overall->{ui_type} || 'component';

	my $widopt;
	my $hidden = { 
			ui_name   => $overall->{ui_name},
			ui_source => $overall->{ui_source},
			ui_type   => $overall->{ui_type},
	};

	my $extra;
	my $href;
	if($w) {
		$widopt = {code =>'hiddentext'};
		$href   = 'silent/ce_modify';
		$extra  = qq{onSubmit="submitted('$w'); silent_submit(this.form)" onReset="submitted('$w')"};
		$hidden->{ui_content_op} = 'modify';
	}
	else {
		$href   = $Global::Variable->{MV_PAGE};
		$hidden->{ui_content_op} = 'add';
	}

	my %options = (
		action => 'return',
		defaults => 1,
		force_defaults => 1,
		form_extra => $extra,
		href   => $href,
		js_changed => 'changed',
		nocancel => 1,
		noexport => 1,
		no_meta => 1,
		show_reset => 1,
		table => $::Variable->{UI_META_TABLE} || 'mv_metadata',
		view => 'ui_component',
		widget => $widopt,
		hidden => $hidden,
	);

	$options{default_ref} = $r;
	$options{item_id} = $w;
	return Vend::Tags->table_editor( \%options );
}

sub page_region {
	my($pref, $opt) = @_;

	my @keys = keys %$pref;
	my @ui_keys = grep /^ui_/, @keys;

	my %ignore;
	my %done;

	my $comp = $pref->{ui_slots};

	$ignore{ui_slots} = 1;
	$ignore{ui_display_order} = 1;
	$ignore{ui_values} = 1;
	$ignore{ui_scratchtype} = 1;

	my $overall = {};
	$overall->{safe_data} = 1;  # Allow ITL introduction
	for(qw/ PREAMBLE CONTENT POSTAMBLE /) {
		$overall->{$_} = $pref->{$_};
	}

	for(@ui_keys) {
		next if $ignore{$_};
		$ignore{$_} = 1;
		$overall->{$_} = $pref->{$_};
	}

	if($pref->{ui_display_order}) {
		$overall->{ui_display_order} = join " ", @{$pref->{ui_display_order}};
	}

	my $vals      = $pref->{ui_values} || {};
	my $scratches = $pref->{ui_scratches};
	while ( my($k,$v) = each %$vals) {
		$overall->{$k} = $v;
		$overall->{"_scratchtype_$k"} = $scratches->{$k};
	}

	$overall->{_editor_table} = page_control_editor($pref, $opt);
	my @tables;

	# This is destructive, but slots are rebuilt every time
	my $slots = $pref->{ui_slots} || [];

	# Need position in case two components are the same
	my $pos = -1;
	for my $c (@$slots) {
		$pos++;
		my $r = { %$c };
		$r->{component} ||= $r->{code};
#::logDebug("slot pos=$pos, slot=" . ::uneval($c));
		delete $r->{_editor_table};
		if($r->{where}) {
			my $cname = $r->{component} || '';
			remap_opts($r);
			if($opt->{page_edit}) {
				$r->{_editor_table} = page_component_editor(
										$cname,
										$pos,
										$c,
										$pref,
										$opt,
									 );
			}
		}
		push @tables, $r;
	}

	## Allow add of new component
	if ($opt->{template_edit}) {
		push @tables, { _editor_table => make_control_editor('', {}, $overall) };
	}
#::logDebug("returning overall=" . uneval($overall));
	return ($overall, \@tables);
}

sub template_region {
	my($tref, $opt) = @_;

	my @keys = keys %$tref;
	my @ui_keys = grep /^ui_/, @keys;

	my %ignore;
	my %done;

	my $comp = $tref->{ui_slots};
	$ignore{ui_slots} = 1;
	
	my @regions;
	my $snum = 1;
	for my $reg ( @{$tref->{ui_template_layout}} ) {
		my $r = { name => $reg, code => $reg };
		if($reg eq 'UI_CONTENT') {
			$r->{contents} = "Slot $snum: Page content";
			$snum++;
		}
		else {
			my @things;
			$r->{where} = $reg;
			for(@$comp) {
				next unless $_->{where} eq $reg;
				my $code = $_->{code};
				my $lab = '';
				if($code) {
					$lab = content_info(undef, { label => 1, code => $code} );
					$lab = " default=$lab ($code)";
				}
				push @things, "Slot $snum: class=$_->{class}$lab";
				$snum++;
			}
			$r->{contents} = join "<br>", @things;
			$r->{slots} = \@things;
		}
		push @regions, $r;
	}

	$ignore{ui_display_order} = 1;

	my $overall = {%{$opt}};
	$overall->{safe_data} = 1;  # Allow ITL introduction

	for(@ui_keys) {
		next if $ignore{$_};
		$ignore{$_} = 1;
		$overall->{$_} = $tref->{$_};
	}

	my %wattr;
	
	for my $w (@keys) {
		my $ref = $tref->{$w} or next;
		next if $ignore{$w};
		if( ref($ref) eq 'HASH' ) {
			for(keys %$ref) {
				$wattr{$w} ||= {};
				$wattr{$w}{$_} = $ref->{$_};
			}
		}
		else {
			$overall->{$w} = $ref;
		}
	}

	my $order = $tref->{ui_display_order} || [];
	my @tables;

	for my $w (@$order) {
		my $r = $wattr{$w};
		$r->{code} = $w;
		remap_opts($r);
		if($opt->{template_edit}) {
			$r->{_editor_table} = make_control_editor($w, $r, $overall);
		}
		push @tables, $r;
	}

	$::Scratch->{ce_modify} = '[content-modify]';
	## Allow add of new component
	if ($opt->{template_edit}) {
		push @tables, { _editor_table => make_control_editor('', {}, $overall) };
	}
	return ($overall, \@regions, $comp, \@tables);
}

sub component_region {
	my ($cref, $opt) = @_;

	my @keys = keys %$cref;
	my @ui_keys = grep /^ui_/, @keys;

	my %ignore;
	my %done;

	my $overall = {%{$opt}};
	$overall->{safe_data} = 1;  # Allow ITL introduction
	$overall->{ui_body} = $cref->{ui_body};
	for(@ui_keys) {
		$ignore{$_} = 1;
		$overall->{$_} = $cref->{$_};
	}

	my %wattr;
	
	for my $w (@keys) {
		my $ref = $cref->{$w} or next;
		next if $ignore{$w};
		if( ref($ref) eq 'HASH' ) {
			for(keys %$ref) {
				$wattr{$w} ||= {};
				$wattr{$w}{$_} = $ref->{$_};
			}
		}
		else {
			# Is it ever right to have a scalar or array? I don't think so.
			next;
		}
	}

	my $count = 0;

	my $order = $cref->{ui_display_order} || [];
	my @tables;

	for my $w (@$order) {
		my $r = $wattr{$w};
		$r->{code} = $w;
		remap_opts($r);
#::logDebug("table-editor options: " . uneval(\%options));
		if($opt->{component_edit}) {
			$r->{_editor_table} = make_control_editor($w, $r, $overall);
		}
		push @tables, $r;
	}

	$::Scratch->{ce_modify} = '[content-modify]';
	## Allow add of new component
	if ($opt->{component_edit}) {
		push @tables, { _editor_table => make_control_editor('', {}, $overall) };
	}

	return($overall, \@tables);
}

my @valid_attr = qw/
	code
	type
	width
	height
	field
	db
	name
	outboard
	options
	attribute
	label
	help
	lookup
	filter
	help_url
	pre_filter
	lookup_exclude
	prepend
	append
	display_filter
	extended
/;

my %valid_attr;
@valid_attr{@valid_attr} = @valid_attr;

sub _trim {
	my $v = shift;
	$v =~ s/^\s+$//;
	$v =~ s/\s+$//;
	$v =~ s/\r\n/\n/g;
	$v =~ s/\r/\n/g;
	return $v;
}

sub trim_format {
	my $v = _trim(shift);
	$v =~ s/\n/\\\n/g;
	$v =~ s/\\$//;
	return $v;
}

sub format_page {
	my ($ref, $opt) = @_;
	$opt ||= {};
	my $type = 'page';
	$ref->{ui_type} eq $type
		or death("publish_$type", "Type must be %s to publish %s", $type, $type);
	my $name = $ref->{ui_name}
		or death("publish_$type", "Must have name to publish %s", $type);

	my $found_something = 0;

	my @sets;
	if($ref->{PREAMBLE} =~ /\S/) {
		push @sets, "<!-- BEGIN PREAMBLE -->";
		$ref->{PREAMBLE} =~ s/^\s*\n//;
		$ref->{PREAMBLE} =~ s/\n\s*$//;
		$ref->{PREAMBLE} =~ s/\r\n|\r/\n/g;
		push @sets, $ref->{PREAMBLE};
		push @sets, "<!-- END PREAMBLE -->";
	}
	delete $ref->{PREAMBLE};

	my $vals      = delete $ref->{ui_values};
	my $scratches = delete $ref->{ui_scratchtype};
	my $order = delete $ref->{ui_display_order} || [];

	# Do this first to get these things out of reference
	# n=name k=key v=value
	for my $n (@$order) {
		my $r;
		my $stype = $scratches->{$n} || 'tmpn'; 
		my $val = $vals->{$n};
		if($opt->{preview} and $n eq $opt->{preview}) {
			$val = ($opt->{preview_tag} || '**** PREVIEW ****') . " $val";
		}
		push @sets, "[$stype $n]" . $val . "[/$stype]";
	}
	
	$found_something += scalar(@sets);

#::logDebug("publish_page ref=" . ::uneval($ref));

	# Things we want every time
	my $layout = delete $ref->{ui_template_layout} || [];

#::logDebug("layout=" . ::uneval($layout));
	my @header;

	my $slots = delete $ref->{ui_slots} || [];
	push @header, "ui_$type: $name";
	push @header, "ui_type: $type";
	push @header, "ui_name: $name";
	push @header, "ui_page_template: $ref->{ui_page_template}";
	push @header, "ui_version: " . Vend::Tags->version();
	delete $ref->{ui_name};
	delete $ref->{ui_type};
	delete $ref->{"ui_$type"};
	delete $ref->{ui_slots};
	delete $ref->{ui_version};
	delete $ref->{ui_page_template};
	delete $ref->{ui_page_picture};
	my $body = delete $ref->{CONTENT};
	$body =~ s/\r\n/\n/g;
	$body =~ s/\r/\n/g;

	my @controls = '[control reset=1]';

	for my $r (@$slots) {
		next unless $r->{where};
		$found_something++;
		push @controls, '[control-set]';
		my @order = 'component';
		my %seen = qw/ code 1 mv_ip 1 where 1 class 1 component 1 /;
		push @order, grep !$seen{$_}++, sort keys %$r;
		for(@order) {
			next if /^_/;
			push @controls, "\t[" . "$_]$r->{$_}" . "[/$_]";
		}
		push @controls, '[/control-set]';
	}
	push @controls, '[control reset=1]';

	my @bods;
	for my $var (@$layout) {
		if ($var eq 'UI_CONTENT') {
			push @bods, "<!-- BEGIN CONTENT -->";
			$body =~ s/^\s*\n//;
			$body =~ s/\n\s*$//;
			push @bods, $body;
			push @bods, "<!-- END CONTENT -->";
		}
		elsif ($var =~ /^[A-Z]/) {
			$found_something++;
			push @bods, '@_' . $var . '_@';
		}
		else {
#::logDebug("bad bod: $var");
		}
	}

	if($ref->{POSTAMBLE} =~ /\S/) {
		$found_something++;
		push @bods, "<!-- BEGIN POSTAMBLE -->";
		$ref->{POSTAMBLE} =~ s/^\s*\n//;
		$ref->{POSTAMBLE} =~ s/\n\s*$//;
		$ref->{POSTAMBLE} =~ s/\r\n|\r/\n/g;
		push @bods, $ref->{POSTAMBLE};
		push @bods, "<!-- END POSTAMBLE -->";
	}
	delete $ref->{POSTAMBLE};

	return $body unless $found_something;

	for(sort keys %$ref) {
		next unless /^ui_/;
		my $val = delete $ref->{$_};
		next unless length($val);
		push @header, "$_: " . trim_format($val);
	}
	
	# Anything left?
	for(sort keys %$ref) {
		# We don't do anything here, don't want junk
		delete $ref->{$_};
	}

	my $out = "[comment]\n";
	$out .= join "\n", @header;
	$out .= "\n[/comment]\n";
	$out .= "\n";
	$out .= join "\n", @sets;
	$out .= "\n\n";
	$out .= join "\n", @controls;
	$out .= "\n\n";
	$out .= join "\n", @bods;
	$out .= "\n";
}

sub format_template {
	my ($ref) = @_;
	my $type = 'template';
#::logDebug("called format_template name=$ref->{ui_name} type=$ref->{ui_type}");
	$ref->{ui_type} eq $type
		or death("publish_$type", "Type must be %s to publish %s", $type, $type);
	my $name = $ref->{ui_name}
		or death("publish_$type", "Must have name to publish %s", $type);

	my @header;
	my @controls;
	my @sets;
	my $order = delete $ref->{ui_display_order} || [];

	# Do this first to get these things out of reference
	# n=name k=key v=value
	for my $n (@$order) {
		my $r = delete $ref->{$n};
		next unless $r;
		my $default = defined $r->{default} ? $r->{default} : '';
		my $out = "$n:\n";
		for my $k (sort keys %$r) {
			my $v = trim_format($r->{$k});
			$out .= "\t$k: $v\n";
		}
		push @controls, $out;
		push @sets, "[set $n]" . $default . '[/set]';

	}
	
	# Things we want every time

	push @header, "ui_$type: $name";
	push @header, "ui_type: $type";
	push @header, "ui_name: $name";
	push @header, "ui_version: " . Vend::Tags->version();
	delete $ref->{ui_name};
	delete $ref->{ui_type};
	delete $ref->{"ui_$type"};
	delete $ref->{ui_slots};
	delete $ref->{ui_version};
	my $body = delete $ref->{ui_body};
	$body =~ s/\r\n/\n/g;
	$body =~ s/\r/\n/g;

	my $dir = $::Variable->{UI_REGION_DIR} || 'templates/regions';

	my $layout = delete $ref->{ui_template_layout} || [];
	my $regdir;
	for my $var (@$layout) {
		next if $var eq 'UI_CONTENT';
		my $thing = delete($ref->{$var});
		my $r;
		my $v;
		$r = $Vend::Cfg->{DirConfig}
			and $r = $r->{Variable}
				and $v = $r->{$var}
					and Vend::Tags->write_relative_file($v, $thing)
						and next;
		if(! $regdir and ref($r) eq 'HASH') {
			my ($k, $v);
			while( ($k, $v) = each %$r) {
				last if $k =~ /_(TOP|BOTTOM)$/;
			}
			$regdir = $v;
			$regdir =~ s:/[^/]+$::;
		}
		if(! $regdir) {
			pain('format_template',
				 "unable to write dynamic variable, saving %s to $dir",
				 $var);
			$regdir = $dir;
		}
		Vend::Tags->write_relative_file("$regdir/$var", $thing)
			or
			death('format_template', "unable to write any dynamic variable, help!");
		pain('publish_template', "Must apply changes for access to this template.");
	}

	$ref->{ui_template_layout} = join ", ", @$layout;

	if(my $pp = delete $ref->{ui_page_picture}) {
		$pp =~ s/^\s+//;
		$pp =~ s/\s+$//;
		$pp =~ s{^\s*<!--+\s*BEGIN PAGE_PICTURE\s*--+>\s*}{};
		$pp =~ s{\s*<!--+\s*END PAGE_PICTURE\s*--+>\s*$}{};
		$pp = qq{<!-- BEGIN PAGE_PICTURE -->\n$pp\n<!-- END PAGE_PICTURE -->\n};
		push @sets, $pp;
	}

	for(sort keys %$ref) {
		next unless /^ui_/;
		my $val = delete $ref->{$_};
		next unless length($val);
		push @header, "$_: " . trim_format($val);
	}
	
	# Anything left?
	for(sort keys %$ref) {
		# We don't do anything here, don't want junk
		delete $ref->{$_};
	}

	my $out = "[comment]\n";
	$out .= join "\n", @header;
	$out .= "\n\n";
	$out .= join "\n", @controls;
	$out .= "\n[/comment]\n";
	$out .= join "\n", @sets;
	$out .= "\n";
}

sub format_component {
	my ($ref) = @_;
	my $type = 'component';
#::logDebug("format component=" . ::uneval($ref));
	$ref->{ui_type} eq $type
		or death("publish_$type", "Type must be %s to publish %s", $type, $type);
	my $name = $ref->{ui_name}
		or death("publish_$type", "Must have name to publish %s", $type);

	my @header;
	my @controls;
	my $order = delete $ref->{ui_display_order} || [];

	# Do this first to get these things out of reference
	# n=name k=key v=value
	for my $n (@$order) {
		my $r;
		next unless $r = delete $ref->{$n};
		my $out = "$n:\n";
		for my $k (sort keys %$r) {
			my $v = trim_format($r->{$k});
			$out .= "\t$k: $v\n";
		}
		push @controls, $out;
	}
	
	# Things we want every time

	push @header, "ui_$type: $name";
	push @header, "ui_type: $type";
	push @header, "ui_name: $name";
	delete $ref->{ui_name};
	delete $ref->{ui_type};
	delete $ref->{"ui_$type"};
	my $body = delete $ref->{ui_body};
	$body =~ s/\r\n/\n/g;
	$body =~ s/\r/\n/g;

	for(sort keys %$ref) {
		next unless /^ui_/;
		my $val = delete $ref->{$_};
		next unless length($val);
		push @header, "$_: " . trim_format($val);
	}
	
	# Anything left?
	for(sort keys %$ref) {
		push @header, "$_: " . trim_format(delete $ref->{$_});
	}
	my $out = "[comment]\n";
	$out .= join "\n", @header;
	$out .= "\n\n";
	$out .= join "\n", @controls;
	$out .= "\n[/comment]\n";
	$out .= $body;
}

sub write_page {
	my ($record, $dest) = @_;
	my $dir = $::Variable->{UI_PAGE_DIR} || 'pages';
	$dest ||= "$dir/$record->{code}";
	Vend::Tags->write_relative_file($dest, $record->{page_text});
}

sub write_template {
	my ($record, $dest) = @_;
	my $dir = $::Variable->{UI_TEMPLATE_DIR} || 'templates';
	$dest ||= "$dir/$record->{code}";
	Vend::Tags->write_relative_file($dest, $record->{temp_text});
}

sub write_component {
	my ($record, $dest) = @_;
	my $dir = $::Variable->{UI_COMPONENT_DIR} || 'templates/components';
	$dest ||= "$dir/$record->{code}";
	Vend::Tags->write_relative_file($dest, $record->{comp_text});
}

sub ref_page {
	my ($ref, $opt) = @_;
	my $vref = $opt->{values_ref} || \%CGI::values;
	my $curtime = strftime("%Y%m%d%H%M%S", gmtime() );
	my $showdate = Vend::Tags->filter('date_change', $vref->{ui_show_date});
	my $expdate  = Vend::Tags->filter('date_change', $vref->{ui_expiration_date});
	my $r = {
		content_class => $ref->{ui_class},
		mod_time => strftime("%Y%m%d%H%M%S", gmtime()),
		expiration_date => $expdate,
		show_date => $showdate,
		came_from => $ref->{ui_source},
		base_code => $ref->{ui_name},
		### comp_settings => uneval_it($ref),
		hostname => $Vend::remote_addr,
		mod_user => $Vend::username,
	};
	if($curtime lt $showdate or $expdate && $curtime gt $expdate) {
		$r->{code} = $r->{base_code} . ".$curtime";
	}
	else {
		$r->{code} = $r->{base_code};
	}
	return $r;
}

sub ref_content {
	my ($ref, $opt) = @_;
	my $vref = $opt->{values_ref} || \%CGI::values;
	my $curtime = strftime("%Y%m%d%H%M%S", gmtime() );
	my $showdate = Vend::Tags->filter('date_change', $vref->{ui_show_date});
	my $expdate  = Vend::Tags->filter('date_change', $vref->{ui_expiration_date});
	my $r = {
		reftype => $ref->{ui_type},
		content_class => $ref->{ui_class},
		mod_time => strftime("%Y%m%d%H%M%S", gmtime()),
		expiration_date => $expdate,
		show_date => $showdate,
		came_from => $ref->{ui_source},
		base_code => $ref->{ui_name},
		### comp_settings => uneval_it($ref),
		hostname => $Vend::remote_addr,
		mod_user => $Vend::username,
	};
	if($curtime lt $showdate or $expdate && $curtime gt $expdate) {
		$r->{code} = $r->{base_code} . ".$curtime";
	}
	else {
		$r->{code} = $r->{base_code};
	}
	return $r;
}

sub preview_dir {
	my $dir = $Vend::Cfg->{ScratchDir};
	$dir =~ s,^$Vend::Cfg->{VendRoot}/,,;
	$dir .= "/previews/$Vend::Session->{id}";
	return $dir;
}

sub preview_page {
	my ($ref, $opt) = @_;
	my $dest = preview_dir();
	$dest .= "/$ref->{ui_name}";
	$::Scratch->{tmp_tmpfile} = $dest;
	my $tmp = { %$ref };
	my $record = ref_content($tmp)
		or return death("preview_template", "bad news");
	my $text = format_page(
					$tmp,
					{
						preview => $::Variable->{PAGE_TITLE_NAME} || 'page_title',
						preview_tag => errmsg('****PREVIEW****'),
					},
				);
	$record->{page_text} = $text;
#::logDebug("header record: " . uneval($record));
	write_page($record, $dest);
}

sub publish_page {
	my ($ref, $opt) = @_;
	my $vref = $opt->{values_ref} || \%CGI::values;
	my $dest = $vref->{ui_destination};
	$dest =~ s/\s+$//;
	$dest =~ s/^\s+$//;
	my $record = ref_content($ref, $opt)
		or return death("publish_page", "bad news");
	delete_preview_page($ref, $opt);
	my $text = format_page($ref);
	$record->{page_text} = $text;
	write_page($record);
}

sub publish_template {
	my ($ref, $opt) = @_;
	my $vref = $opt->{values_ref} || \%CGI::values;
	my $dest = $vref->{ui_destination};
	$dest =~ s/\s+$//;
	$dest =~ s/^\s+$//;
	my $record = ref_content($ref)
		or return death("publish_template", "bad news");
#::logDebug("Got publish_template ref=" . uneval($ref));
	my $text = format_template($ref);
	$record->{temp_text} = $text;
#::logDebug("header record: " . uneval($record));
	delete_store('template', $record->{code});
	write_template($record);
}

sub publish_component {
	my ($ref, $opt) = @_;
	my $vref = $opt->{values_ref} || \%CGI::values;
	my $dest = $vref->{ui_destination};
	$dest =~ s/\s+$//;
	$dest =~ s/^\s+$//;
	my $record = ref_content($ref)
		or return death("publish_component", "bad news");
	my $text = format_component($ref);
	$record->{comp_text} = $text;
#::logDebug("publish_component header record: " . uneval($record));
	write_component($record);
}

sub delete_preview_page {
	my ($ref, $opt) = @_;
	my $dir = preview_dir();
	if($ref->{ui_name} and -f "$dir/$ref->{ui_name}") {
		unlink "$dir/$ref->{ui_name}";
	}
}

sub cancel_edit {
	my ($ref, $opt) = @_;
	delete_preview_page($ref, $opt);
	my $store = $Vend::Session->{content_edit}
		or return death('cancel', 'content store not found');
	$store = $store->{$ref->{ui_type}}
		or return death('cancel', 'content store not found');
	delete $store->{$ref->{ui_name}};
}

my %illegal = (
	code  => 1,
	where => 1,
	class => 1,
);

sub add_attribute {
	my ($ref, $opt) = @_;
	my $vref = $opt->{values_ref} || \%CGI::values;

	my $name = $vref->{code}
		or return death('code', 'BLANK');

	if($illegal{$name}) {
		return death('code', 'reserved attribute name: %s', $name);
	}

	my @found = grep length($vref->{$_}), @valid_attr;
	my %hash = map { $_ => $vref->{$_} } @found;
#::logDebug("add attribute hash: " . uneval(\%hash));
	push @{$ref->{ui_display_order} ||= []}, $name;
	$ref->{$name} = \%hash;
}

sub modify_slots {
	my ($ref, $opt) = @_;
	my $vref = $opt->{values_ref} || \%CGI::values;

	my $slots = $ref->{ui_slots};
	assert('ui_slots', $slots, 'ARRAY')
		or return undef;

	my $slots_in = {};
	for(grep /^slot\d+$/, keys %$vref) {
		/(\d+)/;
		my $snum = $1;
		$snum--;
		$slots_in->{$snum} = $vref->{$_};
	}

#::logDebug("slots in=" . ::uneval($slots_in));

	for(my $i = 0; $i < @$slots; $i++) {
		my $s = $slots->[$i];
#::logDebug("looking at slot $i, slot_in=$slots_in->{$i}, slot code=$s->{component}, slot=" . ::uneval($slots->[$i]) );
		next if $s->{component} eq $slots_in->{$i};
#::logDebug("SLOTS ARE DIFFERENT, $s->{code} ne $slots_in->{$i}");
		my $new = {
			code      => $slots_in->{$i},
			component => $slots_in->{$i},
			class     => $s->{class},
			where     => $s->{where},
		};
		$slots->[$i] = $new;
	}

	return 1;
}

sub modify_component {
	my ($ref, $opt) = @_;
	my $vref = $opt->{values_ref} || \%CGI::values;

	my $pos = $vref->{ui_content_pos};
	defined $pos
		or return death('ui_content_pos', '%s is BLANK', 'position');

	assert('ui_slots', $ref->{ui_slots}, 'ARRAY')
		or return undef;
	my $comp = $ref->{ui_slots}[$pos]
		or return death("Component change", "No component at position %s", $pos);
#::logDebug("changing slot position $pos, comp=" . ::uneval($comp));

	my $name           = $comp->{component};
	my $submitted_name = $vref->{code};

	if($name ne $submitted_name) {
		my $class = $comp->{class};
		my $where = $comp->{where};
		$comp = {
			code      => $submitted_name,
			component => $submitted_name,
			class     => $class,
			where     => $where,
		};
		my $cref = read_component($submitted_name,
									{
										type => 'component', 
										component_dir => $opt->{component_dir}, 
										single => 1,
									});
		assert("component $submitted_name", $cref, 'HASH')
			or return undef;
#::logDebug("cref=" . uneval($cref));
		my $order = $cref->{ui_display_order} || [];
		for(@$order) {
			$comp->{$_} = $cref->{$_}{default}
							if defined $cref->{$_}{default};
							
		}
		$ref->{ui_slots}[$pos] = $comp;
		return 1;
	}

	my @fields = split /[\0,\s]+/, $vref->{mv_data_fields};
	my @found = grep defined($vref->{$_}), @fields;

	for(@found) {
		next if $illegal{$_};
		next if /^_/;
		$comp->{$_} = $vref->{$_};
	}
#::logDebug("changing slot position $pos, comp now=" . ::uneval($comp));

	return 1;
}

sub modify_page_control {
	my ($ref, $opt) = @_;
	my $vref = $opt->{values_ref} || \%CGI::values;

	my $name = $vref->{code}
		or return death('code', 'BLANK');

	my @fields = split /[\0,\s]+/, $vref->{mv_data_fields};
	my @found = grep defined($vref->{$_}), @fields;
	my $vals      = $ref->{ui_values};
	my $scratches = $ref->{ui_scratchtype};

	assert('page values', $vals, 'HASH')
		or return undef;

	assert('scratchtypes', $scratches, 'HASH')
		or return undef;

	for(@found) {
		next if $illegal{$_};
		my $f = $_;
		if(s/^_scratchtype_//) {
			$scratches->{$_} = $vref->{$f};
		}
		else {
			$vals->{$_} = $vref->{$_};
		}
	}
	return 1;
}

sub modify_attribute {
	my ($ref, $opt) = @_;
	my $vref = $opt->{values_ref} || \%CGI::values;

	my $name = $vref->{code}
		or return death('code', 'BLANK');

	if($illegal{$name}) {
		return death('code', 'reserved attribute name: %s', $name);
	}

	my @found = grep length($vref->{$_}), @valid_attr;

	my $r = $ref->{$name}
		or return death($name, 'Attribute %s not found', $name);

	for(@found) {
		$r->{$_} = $vref->{$_};
	}
	return 1;
}

my %illegal_top = (
	default => {
		ui_content_op   => 1,
		ui_name         => 1,
		ui_type         => 1,
		ui_source       => 1,
		ui_destination	=> 1,
	},
);

my %always_top = (
	default => {
		ui_label   => 1,
	},
);

sub modify_top_attribute {
	my ($ref, $opt) = @_;
	my $vref = $opt->{values_ref} || \%CGI::values;

	my $illegal = $illegal_top{$ref->{ui_type}} || $illegal_top{default};
	my $always = $always_top{$ref->{ui_type}} || $always_top{default};

	my @found;
	for(keys %$vref) {
#::logDebug("checking $_ ($ref->{$_} -> $vref->{$_}) for legality");
		next if $illegal->{$_};
		next unless defined $ref->{$_} or $always->{$_};
#::logDebug("$_ is legal and defined in ref (or is always allowed)");
		push @found, $_;
	}

	for(@found) {
#::logDebug("modifying $_, $ref->{$_} to $vref->{$_}");
		$ref->{$_} = $vref->{$_};
	}
	return 1;
}

sub modify_body {
	my ($ref, $opt) = @_;
	my $vref = $opt->{values_ref} || \%CGI::values;
	my $code = $vref->{code} || 'ui_body';
#::logDebug("modify body, code=$code");
	defined $vref->{ui_body_text}
		or return death(
					$ref->{ui_name},
					'Body content not found for %s %s',
					$ref->{ui_type},
					$ref->{ui_name},
					);
	length $vref->{ui_body_text}
		or pain(
				$ref->{ui_name},
				'Body content for %s defined but had zero length.',
				$ref->{ui_name},
				);
#::logDebug("modified ui_body, length=" . length($vref->{ui_body_text}));
	$ref->{$code} = $vref->{ui_body_text};
	return 1;
}

sub delete_attribute {
	my ($ref, $opt) = @_;
	my $vref = $opt->{values_ref} || \%CGI::values;

	my $name = $vref->{code}
		or return death('code', 'BLANK');

	my $ary = $ref->{ui_display_order} ||= [];

	my $i = 0;
	my $found;
	for(@$ary) {
		$found = 1, last if $_ eq $name;
		$i++;
	}

	return death('code', 'attribute %s not found', $name)
		unless $found;

	splice @$ary, $i, 1;
	delete $ref->{$name};
}

sub reorder_attribute {
	my ($ref, $opt) = @_;
	my $vref = $opt->{values_ref} || \%CGI::values;

	my $name = $vref->{code}
		or return death('code', 'BLANK');

	my $direc = $vref->{ce_motion}
		or pain('ce_motion', 'No direction specified, defaulting to %s', 'up');
	if($direc eq 'down') {
		$direc = 1;
	}
	else {
		$direc = -1;
	}

	my $ary = $ref->{ui_display_order} ||= [];

	my $idx = 0;
	my $found;
	for(@$ary) {
		$found = 1, last if $_ eq $name;
		$idx++;
	}

	return death('code', 'attribute %s not found', $name)
		unless $found;

	my $new = $idx + $direc;
	if($new < 0) {
		return death('ce_motion', 'cannot move %s from %s', 'up', 'first');
	}
	elsif($new >= @$ary) {
		return death('ce_motion', 'cannot move %s from %s', 'down', 'last');
	}
	my $src  = $ary->[$idx];
	$ary->[$idx] = $ary->[$new];
	$ary->[$new] = $src;
	@$ary = grep defined $_, @$ary;
	
	return $direc;
}

my %immediate_action = (
	purge       => sub {
						delete $Vend::Session->{content_edit};
						File::Path::rmtree(preview_dir());
					},
);

my %common_action = (
		cancel              => \&cancel_edit,
		motion              => \&reorder_attribute,
		modify_top			=> \&modify_top_attribute,
		modify              => \&modify_attribute,
		modify_body         => \&modify_body,
		delete              => \&delete_attribute,
		add                 => \&add_attribute,
);

my %specific_action = (
	page => {
		preview				=> \&preview_page,
		publish				=> \&publish_page,
		modify				=> \&modify_top_attribute,
		modify_control		=> \&modify_page_control,
		modify_component	=> \&modify_component,
		modify_slots		=> \&modify_slots,
	},
	template => {
		publish				=> \&publish_template,
	},
	component => {
		publish				=> \&publish_component,
	},
);

sub content_modify {
	my($ops, $name, $type, $opt) = @_;

	$opt ||= {};
	my $vref = $opt->{values_ref} || \%CGI::values;
	$ops ||= $vref->{ui_content_op};

	my $sub;
	if($sub = $immediate_action{$ops}) {
#::logDebug("content modify immediate action");
		return $sub->(undef, $opt);
	}
#::logDebug("content_modify: called, name=$name type=$type ops=$ops");

	$type ||= $vref->{ui_type}
		or return death('ui_type', "Must specify a type");

	$name ||= $vref->{ui_name}
		or return death('ui_name', "Must specify a name for %s", $type);
#::logDebug("content_modify: called, name=$name type=$type");

	my(@ops) = split /[\s,\0]+/, $ops;
#::logDebug("content_modify: ops=" . join(",", @ops) . " vref=$vref");

	my $ref = get_store($type,$name)
		or return death('content_modify', "%s %s not found", $type, $name);

       #in case of an alternative component name
       if ($vref->{ui_destination} ne "") {
           $name = $ref->{ui_name} = $vref->{ui_destination};
       }


	foreach my $op (@ops) {
#::logDebug("content_modify: doing name=$name type=$type op=$op");
#::logDebug("content_modify: doing name=$name type=$type op=$op ref=" . uneval($ref));

		$sub = $specific_action{$type}{$op} || $common_action{$op};
		
		if(! $sub) {
			return death('ui_content_op', "%s %s not found", 'operation', $op );
		}

#::logDebug("ref before modify, code=$vref->{code}=" . uneval($ref));
		if(! $sub->($ref, $opt) ) {
			pain('content_modify', "op %s failed for %s %s.", $op, $type, $name);
		}
#::logDebug("ref AFTER modify=, code=$vref->{code}" . uneval($ref));

	}
	return 1;
}
 
sub page_editor {
	my($name, $opt, $form_template) = @_;
	
	my $source;

	$opt->{page_edit} = 1;

#::logDebug("in page_editor, name=$name");
	my $pref = read_page($name, $opt);

	if(ref($pref) ne 'HASH') {
		return death('page_editor', "Invalid page: %s", uneval($pref));
	}
	else {
		$pref = get_store('page', $name) || $pref;
	}

	save_store('page', $name, $pref);

	parse_page($pref, $opt);

	publish_page($pref, $opt) if $opt->{new};

#::logDebug("found a template name=$pref->{ui_name} store=$name: " . uneval($pref));

	my ($overall, $comp) = page_region($pref, $opt);

	my $to_run = [
					$opt->{list_prefix}	|| 'pages',
					$opt->{prefix}		|| 'page',
					[$overall],
					$opt->{comp_list_prefix} || 'components',
					$opt->{comp_prefix}	  || 'comp',
					$comp,
				];
	
	my $bref = $form_template ? \$form_template : \$Template{page_standard} ;
#::logDebug("table-editor records: " . uneval($pref));
#::logDebug("table-editor overall: " . uneval($overall));
	return run_templates($overall, $to_run, $bref);
}

sub template_editor {
	my($name, $opt, $form_template) = @_;
#::logDebug("template editor called, name=$name, opt=" . uneval($opt));
	my $source;

	$opt->{template_edit} = 1;

	my $tref = get_store('template', $name) || read_template($name, $opt);
	save_store('template', $name, $tref);

	parse_template($tref, $opt);

	my ($overall, $reg, $comp, $cont) = template_region($tref, $opt);
	my $to_run = [
					$opt->{list_prefix}	|| 'templates',
					$opt->{prefix}		|| 'tem',
					[$tref],
					$opt->{region_list_prefix} || 'regions',
					$opt->{region_prefix}	  || 'reg',
					$reg,
					$opt->{comp_list_prefix} || 'components',
					$opt->{comp_prefix}	  || 'comp',
					$comp,
					$opt->{cont_list_prefix} || 'controls',
					$opt->{cont_prefix}	  || 'cont',
					$cont,
				];
	
	my $bref = $form_template ? \$form_template : \$Template{template_standard} ;
#::logDebug("table-editor records: " . uneval($tref));
#::logDebug("table-editor overall: " . uneval($overall));
	return run_templates($overall, $to_run, $bref);
}

sub component_editor {
	my($name, $opt, $form_template) = @_;
#::logDebug("component editor called, cref=$cref opt=" . uneval($opt));

	$opt->{component_edit} = 1;

	my $cref = read_component($name, $opt);
	if(! ref($cref) eq 'HASH') {
		return death('component_editor', "Invalid component: %s", uneval($cref));
	}

	$cref = get_store('component', $name) || $cref;

	save_store('component', $name,$cref);

	my ($overall, $tref) = component_region($cref, $opt);
	my $to_run = ['components', 'comp', $tref];
	
	my $bref = $form_template ? \$form_template : \$Template{component_standard} ;
#::logDebug("table-editor records: " . uneval($tref));
#::logDebug("table-editor overall: " . uneval($overall));
	return run_templates($overall, $to_run, $bref);
}

my %display_remap = qw/
	type	widget
	label	description
/;

sub remap_opts {
	my $opt = shift;
	my $name;
	$name = shift and $opt->{name} = $name;
	while( my($k,$v) = each %display_remap ) {
		delete $opt->{$v}, next if defined $opt->{$k};
		next unless defined $opt->{$v};
		$opt->{$k} = delete $opt->{$v};
	}
	return $opt;
}

sub run_templates {
	my ($opt, $to_run, $bref) = @_;
#::logDebug("event_array=" . ::uneval($to_run));

	my %todo = qw/
		components	1
		regions		1
		pages		1
		templates	1
	/;
	my $region;
	my $prefix;
	my $ary;
	my @things = @$to_run;
	while( $region = shift  @things ) {
		$prefix = shift @things;
		$ary    = shift @things;

		delete $todo{$region};
#::logDebug("run_template region=$region prefix=$prefix ary=$ary from=$opt->{from_session}");
		$region =~ s/[-_]/[-_]/g;

		next unless $$bref =~ m{\[$region\](.*?)\[/$region\]}is;
		my $run = $1;
		
		if( $run !~ /\S/ or (! $ary and $run !~ /no[-_]match\]/i) ) {
			$$bref =~ s{\[$region\](.*?)\[/$region\]}{}sgi;
			next;
		}
		$opt->{prefix} = $prefix;
		$opt->{object} = {
							mv_results => $ary,
							matches => scalar(@$ary),
							mv_matchlimit => $opt->{ml} || 100,
						};
		$$bref =~ s{\[$region\](.*?)\[/$region\]}
				   {Vend::Interpolate::region($opt, $1)}eisg;
	}
	for(keys %todo) {
		$$bref =~ s,\[$region\](.*?)\[/$region\],,igs;
	}
	return $$bref;
}

sub editor {
	my ($item, $opt, $form_template) = @_;

	$::Scratch->{ce_modify} = '[content-modify]';
	if($opt->{type} eq 'page') {
		return page_editor($opt->{name}, $opt, $form_template);
	}
	elsif ($opt->{type} eq 'template') {
		return template_editor($opt->{name}, $opt, $form_template);
	}
	elsif ($opt->{type} eq 'component') {
		return component_editor($opt->{name}, $opt, $form_template);
	}
	else {
		return errmsg("Don't know how to edit type '%s'.\n", $opt->{type});
	}
}

$Template{component_standard} = <<'EOF';
EOF

$Template{page_standard} = <<EOF;
<script language=JavaScript>
function visible (index) {
	var vis = new Array;
	var xi;
	var dosel;
	var selnam = 'dynform' + index;

	for( xi = 1; ; xi++) {
		nam = 'dynform' + xi;
		var el = document.getElementById(nam);
		if(el == undefined) break;

		el.style.visibility = 'Hidden';

	}
	var element = document.getElementById(selnam);
	element.style.visibility = 'Visible';
	return;
}
</script>

<FORM METHOD=POST ACTION="[editor-param url]" ENCTYPE="[editor-param enctype]">
<table width="[editor-param table_width]" [editor-param table_extra]>
<tr>
	<td width="[editor-param left_width]" [editor-param left_extra]>
[component-links]
	<ul>
	[list]
	<li> <A HREF="javascript:void(0)"
			onClick="visible([clink-increment])"
		>[clink-param label]</A></li>
	[/list]
[/component-links]
	</td>
[component-menus]
	<td>
<div
	style="
			Position:Relative;
			Left:0; Top:0; Height:504; Width:404;
			Visibility:Visible;
			z-index:0;
		"
>
[cmenu-on-match]
<div
	style="
			Position:Absolute;
			Left:0; Top:0; Height:504; Width:404;
			Visibility:Visible;
			z-index:0;
			background-color: [cmenu-param bordercolor]
		"
>&nbsp;</div>
<div
	style="
			Position:Absolute;
			Left:2; Top:2; Height:500; Width:400;
			Visibility:Visible;
			z-index:1;
			background-color: [cmenu-param bgcolor]
		"
>&nbsp;</div>
[/cmenu-on-match]
[cmenu-list]
<div
	id=dynform[loop-code]
	style="
			Position:Absolute;
			Left:2; Top:2; Width:300; Height: 300;
			Visibility:[loop-change 1][condition]1[/condition]Visible[else]Hidden[/else][/loop-change 1];
			z-index:2;
		"
>Element [loop-code] <select name=dynform[loop-code]widget>
<OPTION>A
<OPTION [selected cgi=1 name=dynform[loop-code]widget value=B]>B
<OPTION [selected cgi=1 name=dynform[loop-code]widget value=C]>C
</select>
</div>
[/cmenu-list]
</div>
[/component-menus]
	</td>

</tr>

<tr>
  <td width="[editor-param left_width]" [editor-param left_extra]>

[content-edit]
	<h2>Content edit</h2>
	[content-list]
	[if-content-param label]<h2>[content-param label]<br>[/if-content-param]
	<textarea
		name="[content-var]"
		ROWS="[content-param vsize]" COLS="[content-param hsize]">
	[/content-list]
[/content-edit]

  </td>
  
  <td>
	Global menu
  </td>
</tr>
</table>
</form>

EOF

sub write_xml_component {
	my ($c) = @_;

	return undef unless ref($c) eq 'HASH';

	my $type;

	for(qw/component template page/) {
#::logDebug("check for component type=$_");
		if(exists $c->{"ui_$_"}) {
			$type = $_;
			last;
		}
	}
#::logDebug("component type=$type");

	if(! $type) {
		logError("unrecognized template:\n%s", uneval($c) );
	}

	my $out = qq{<?xml version="1.0"?>\n};

	my $body  = delete $c->{ui_body};
	my $order = delete $c->{ui_display_order} || [];
	delete $c->{ui_definition};

	my @keys = keys %$c;
	my @ui_keys = grep /^ui_/, @keys;

	my %ui_key;

	my %cattr;
	for(@ui_keys) {
		$ui_key{$_} = 1;
		my $val = delete $c->{$_};
		if($_ eq "ui_$type") {
			$cattr{name} ||= $c->{$_};
			next;
		}
		s/^ui_//;
		$cattr{$_} = $val;
	}

	$out .= "<$type ";

	my @ao; # attributes out
	while (my ($k, $v) = each %cattr) {
		HTML::Entities::encode($v);
		push @ao, qq{$k="$v"};
	}

	$out .= join " ", @ao;

	$out .= ">\n";

	my %wattr;
	
	
	for my $w (@keys) {
		my $ref = $c->{$w} or next;
		next unless ref($ref) eq 'HASH';
		for(keys %$ref) {
			$wattr{$w} ||= {};
			$wattr{$w}{$_} = $ref->{$_};
		}
	}

	for my $w (@$order) {
		$out .= qq{\t<attr name="$w">\n};
		for(keys %{$wattr{$w}} ) {
			$out .= "\t\t<$_>$wattr{$w}{$_}</$_>\n";
		}
		$out .= qq{\t</attr>\n};
	}

	HTML::Entities::encode($body);
	$out .= "\t<body>$body</body>\n";
	$out .= "</$type>\n";

	return $out;
}

sub read_xml_component {
	my ($thing, $source) = @_;

	require XML::Parser;
	my $xml;
	my $body;
	$thing =~ m{\[comment\]\s*(.*?)\[/comment\](.*)}s
		and $xml = $1
			and $body = $2;

	HTML::Entities::encode($body) if $body;

	$xml ||= $thing;

	$xml =~ s:<body>ENCODED</body>:<body>$body</body>:;
	my $p = new XML::Parser Style => 'Tree';
	my $tree;

	eval {
		$tree = $p->parse($xml);
	};
	if($@) {
		die "$@\n";
	}

	my %recognized = qw/ component 1 template 1 page 1/;
	my $type = shift @$tree;

	if(! $recognized{$type}) {
		logError("unrecognized template type '%s'", $type);
		return undef;
	}
	
	my $ref = shift @$tree;
	my $comphash = shift @$ref;


	my $el = {
			"ui_$type" => $comphash->{name} || 'Yes',
			ui_display_order => [],
			"ui_${type}_source" => $source,
			};

	while (my ($k, $v) = each %$comphash ) {
		$el->{"ui_$type" . "_$k"} = $v;
	}

	my %get = ( attr => 1, body => 1 );

	while( my($t, $v) = splice(@$ref, 0, 2) ) {
#Debug("found param=$t");
		next unless $t;
		if(!  defined $get{$t} ) {
			logError('%s: unrecognized %s element %s', 'xml_component_read', $type, $t);
		}
		if($t eq 'attr') {
			my $hash = shift @$v;
			my $name = $hash->{name} || 'unknown';
			push @{$el->{ui_display_order}}, $name;

			while( my ($setting, $ary) = splice(@$v, 0, 2) ) {
				next unless $setting;
				$el->{$name}{$setting} = $ary->[2];
			}
		}
		elsif ($t eq 'body') {
			$el->{ui_body} = $v->[2];
		}
	}

  return $el;

}

1;
