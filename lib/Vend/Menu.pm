# Vend::Menu - Interchange payment processing routines
#
# $Id: Menu.pm,v 2.2 2002-08-05 06:17:49 mheins Exp $
#
# Copyright (C) 2002 Mike Heins, <mike@perusion.net>
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

package Vend::Menu;

$VERSION = substr(q$Revision: 2.2 $, 10);

use Vend::Util;
use strict;

my %transform = (
	ui_security => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		my $status = 1;
		for(@$fields) {
			$status = $status && Vend::Tags->if_mm('advanced', $row->{$_});
		}
		return $status;
	},
	full_interpolate => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		for(@$fields) {
			next unless $row->{$_} =~ /\[|__[A-Z]\w+__/;
			$row->{$_} = Vend::Interpolate::interpolate_html($row->{$_});
		}
		return 1;
	},
	menu_group => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		my $status = 1;
		eval {
			for(@$fields) {
				my($f, $c) = split /[=~]+/, $_;
				$c ||= $f;
				$status = $status && (
								!  $row->{$f}
								or $row->{$f} =~ /$CGI::values{$c}/i
								);
			}
		};
		return $status;
	},
	superuser => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		my $status = 1;
		for(@$fields) {
			$status = $status && (! $row->{$_} or Vend::Tags->if_mm('super'));
		}
		return $status;
	},
	depends_on => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		my $status = 1;
		for(@$fields) {
			$status = $status && $CGI::values{$row->{$_}};
		}
		return $status;
	},
	exclude_on => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		my $status = 1;
		for(@$fields) {
			$status = $status && (! $CGI::values{$row->{$_}});
		}
		return $status;
	},
	indicator => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		for(@$fields) {
			my $indicator;
			next unless $indicator = $row->{$_};
			my $rev = $indicator =~ s/^!\s*// ? 1 : 0;
			my $status =  defined $CGI::values{$indicator}
						  ? $CGI::values{$indicator}
						  : $::Values->{$indicator};
			($row->{indicated} = 1, next)
				if $rev xor $status;
			$status = $Global::Variable->{MV_PAGE} eq $indicator;
			($row->{indicated} = 1, next)
				if $rev xor $status;
		}
		return 1;
	},
	expand_values => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		for(@$fields) {
			next unless $row->{$_} =~ /\[/;
			$row->{$_} =~ s/\[cgi\s+([^\[]+)\]/$CGI::values{$1}/g;
			$row->{$_} =~ s/\[var\s+([^\[]+)\]/$::Variable->{$1}/g;
			$row->{$_} =~ s/\[value\s+([^\[]+)\]/$::Values->{$1}/g;
		}
		return 1;
	},
);

sub old_tree {
	my ($name, $opt, $template) = @_;
	my @out;
	my $u;
	if(! $opt->{explode_url}) {
		$u = Vend::Tags->history_scan( { var_exclude => 'toggle,collapse,expand' });
		$opt->{explode_url} = $u;
		$opt->{explode_url} .= $u =~ /\?/ ? '&' : "?";
		$opt->{explode_url} .= 'explode=1';
	}
	if(! $opt->{collapse_url}) {
		$u ||= Vend::Tags->history_scan( { var_exclude => 'toggle,collapse,expand' });
		$opt->{collapse_url} = $u;
		$opt->{collapse_url} .= $u =~ /\?/ ? '&' : "?";
		$opt->{collapse_url} .= 'collapse=1';
	}

	$opt->{header_template} ||= <<EOF;
<P>
<a href="{EXPLODE_URL}" {LINK_STYLE?} style="{LINK_STYLE}"{/LINK_STYLE?} {LINK_CLASS?} class="{LINK_CLASS}"{/LINK_CLASS?}>Explode tree</A><br>
<a href="{COLLAPSE_URl}" {LINK_STYLE?} style="{LINK_STYLE}"{/LINK_STYLE?} {LINK_CLASS?} class="{LINK_CLASS}"{/LINK_CLASS?}">Collapse tree</A>
</P>
EOF

	push @out, Vend::Tags->uc_attr_list($opt, $opt->{header_template})
		unless $opt->{no_expand_collapse};

	my %defaults = (
				start       => $opt->{tree_selector} || 'Products',
				table       => $::Variable->{MV_TREE_TABLE} || 'tree',
				master      => 'parent_fld',
				subordinate => 'code',
				autodetect  => '1',
				sort        => 'code',
				iterator    => \&tree_link,
				spacing     => '4',
				toggle      => 'toggle',
				memo        => 'memo',
				expand      => 'expand',
				collapse    => 'collapse',
				spacer		=> '&nbsp;',
			);

	while( my ($k, $v) = each %defaults) {
		next if defined $opt->{$k};
		$opt->{$k} = $v;
	}
	push @out, Vend::Tags->tree($opt);

	push @out, Vend::Tags->uc_attr_list($opt, $opt->{footer_template})
		unless $opt->{no_expand_collapse};

	return join "\n", @out;

}

sub old_simple {
	my ($name, $opt, $template) = @_;
	my @out;
	my $u;

	push @out, Vend::Tags->uc_attr_list($opt, $opt->{header_template}, 1)
		if $opt->{header_template};

	my %defaults = (
				iterator    => \&menu_link,
				head_skip   => 1,
			);

	while( my ($k, $v) = each %defaults) {
		next if defined $opt->{$k};
		$opt->{$k} = $v;
	}
	push @out, Vend::Tags->loop(undef,$opt,$template);

	push @out, Vend::Tags->uc_attr_list($opt, $opt->{footer_template})
		if $opt->{footer_template};

	return join "\n", @out;

}

sub dhtml_simple {
	return old_simple(@_);
}

sub dhtml_tree {
	my($name, $opt, $template) = @_;
	my @out;
	# out 0

	$opt->{toggle_class} ||= '';
	$opt->{explode_url} ||= "javascript:do_explode(); void(0)";
	$opt->{collapse_url} ||= "javascript:do_collapse(); void(0)";
	$opt->{header_template} ||= <<EOF;
<P>
<a href="{EXPLODE_URL}" {LINK_STYLE?} style="{LINK_STYLE}"{/LINK_STYLE?} {LINK_CLASS?} class="{LINK_CLASS}"{/LINK_CLASS?}>Explode tree</A><br>
<a href="{COLLAPSE_URL} {LINK_STYLE?} style="{LINK_STYLE}"{/LINK_STYLE?} {LINK_CLASS?} class="{LINK_CLASS}"{/LINK_CLASS?}">Collapse tree</A>
</P>
EOF

	push @out, Vend::Tags->uc_attr_list($opt, $opt->{header_template});

	$opt->{div_style} ||= '';
	push @out, <<EOF;

<div id=treebox style="visibility: Visible">
Test.
</div>
<script language="JavaScript1.3">
var lines = new Array;
EOF

	my %o = (
			start       => $opt->{tree_selector} || 'Products',
			table       => $opt->{table} || $::Variable->{MV_TREE_TABLE} || 'tree',
			master      => 'parent_fld',
			subordinate => 'code',
			autodetect  => '1',
			sort        => $opt->{sort} || 'code',
			iterator    => \&tree_line,
			full        => '1',
			spacing     => '4',
		);
	push @out, Vend::Tags->tree(\%o);
#::logDebug("out now=" . ::uneval(\@out) );
	if(defined $CGI::values{open}) {
		 $::Scratch->{dhtml_tree_open} = $CGI::values{open};
	}
	else {
		$CGI::values{open} = $::Scratch->{dhtml_tree_open};
	}
	my $out = '  var openstatus = [';
	$out .=  join ",", split //, $CGI::values{open};
	$out .= "];\n";
	$out .= " var explode = ";
	$out .= $CGI::values{explode} ? 1 : 0;
	$out .= ";\n";
	$out .= " var collapse = ";
	$out .= $CGI::values{collapse} ? 1 : 0;
	$out .= ";\n";

	push @out, $out;

	push @out, <<EOF;
var next_level = 0;
var openstring = '';
var link_class = '$opt->{link_class}';
var link_class_open = '$opt->{link_class_open}';
var link_class_closed = '$opt->{link_class_closed}';
var link_style = '$opt->{link_style}';
var link_style_open = '$opt->{link_style_open}';
var link_style_closed = '$opt->{link_style_closed}';
var toggle_class = '$opt->{toggle_class}';
toggle_anchor_clear = '$opt->{toggle_anchor_clear}';
toggle_anchor_closed = '$opt->{toggle_anchor_closed}';
toggle_anchor_open = '$opt->{toggle_anchor_open}';
var treebox = document.getElementById('treebox');
EOF

	push @out, <<'EOF';
function tree_link (idx) {

	var out = '';

	var l = lines[idx];

	if(l == undefined) {
		alert("Bad idx=" + idx + ", no line there.");
		return;
	}

	if(l[MV_LEVEL] > next_level)
		return '';
		// return 'next_level=' + next_level + ', mv_level=' + l[MV_LEVEL] + '<br>';
// alert("line is " + l);
	var i;
	var needed = l[MV_LEVEL];
	for(i = 1; i <= needed; i++)
		out = out + '&nbsp;&nbsp;&nbsp;&nbsp;';

	var tstyle = link_style;
	var tclass = link_class;
	if(l[MV_CHILDREN] > 0) {
		if(openstatus[idx] == 1) {
			tclass = link_class_open;
			tstyle = link_style_open;
			tanchor = toggle_anchor_open;
			next_level = l[MV_LEVEL] + 1;
		}
		else {
			tclass = link_class_closed;
			tstyle = link_style_closed;
			tanchor = toggle_anchor_closed;
			next_level = l[MV_LEVEL];
		}

		out = out + '<a href="javascript:toggit(' + idx + ');void(0)"';
		if(tclass)
			out = out + ' class="' + tclass + '"';
		if(tstyle)
			out = out + ' style="' + tstyle + '"';
		out = out + '>';
		out = out + tanchor;
		out = out + '</a>';
	}
	else {
		out = out + toggle_anchor_clear;
		next_level = l[MV_LEVEL];
	}

	if(l[PAGE]) {
		out = out + '<a href="' + l[PAGE] + openstring + '"';
		if(tclass)
			out = out + ' class="' + tclass + '"';
		if(tstyle)
			out = out + ' style="' + tstyle + '"';
		if(l[DESCRIPTION])
			out = out + ' title="' + l[DESCRIPTION] + '"';
		out = out + '>';
		out = out + l[NAME] + '</a>';
	}
	else {
		out = out + l[NAME];
	}
	// out = out + ' level=' + l[MV_LEVEL] + ' children=' + l[MV_CHILDREN];
	// out = out + ' needed=' + needed + ", next_level=" + next_level;
	out = out + '<br>';

	return out;
}
function toggit (idx) {

	var l = lines[idx];
	if(l == undefined) {
		alert("bad index " + idx);
		return;
	}
	if(l[MV_CHILDREN] < 1) {
		alert("nothing to toggle at index " + idx);
		return;
	}

	openstatus[idx] = openstatus[idx] == 1 ? 0 : 1;
	openstring = openstatus.join('');
	openstring = openstring.replace(/0+$/, '');
	rewrite_tree();
}
function do_explode () {
	for(var i = 0; i < lines.length; i++)
		openstatus[i] = 1;
	rewrite_tree();
}
function do_collapse () {
	for(var i = 0; i < lines.length; i++)
		openstatus[i] = 0;
	rewrite_tree();
}
function rewrite_tree () {
	var thing = '';
	for(i = 0; i < lines.length; i++) {
		thing = thing + tree_link(i);
	}
	treebox.innerHTML = thing;
	next_level = 0;
}
if(collapse == 1 || explode == 1) {
	openstatus.length = 0;
}
for( var i = 0; i < lines.length; i++) {
	if(openstatus[i] == undefined)
		openstatus[i] = explode;
}
collapse = 0;
explode = 0;
openstring = openstatus.join('');
openstring = openstring.replace(/0+$/, '');
rewrite_tree();
</script>
EOF
	push @out, Vend::Tags->uc_attr_list($opt, $opt->{footer_template})
		if $opt->{footer_template};
	return join "\n", @out;
}

my %menu_default_img = (
		clear  => 'bg.gif',
		closed => 'fc.gif',
		open   => 'fo.gif',
);

sub dhtml_browser {
	my $regex;
	eval {
		$regex = $::Variable->{MV_DHTML_BROWSER}
			and $regex = qr/$regex/;
	};
	$regex ||= qr/MSIE [5-9].*Windows|Mozilla.*Gecko/;
	return $Vend::Session->{browser} =~ $regex;
}

## Returns a link line for a tree walk without DHTML.
sub tree_link {
	my ($template, $row, $opt) = @_;

	for(@{$opt->{_transform}}) {
		return unless $transform{$_}->($row, $opt->{$_});
	}

	$template ||= qq[
{MV_SPACER}{MV_CHILDREN?}<A href="{TOGGLE_URL}" class="{TOGGLE_CLASS}" style="{TOGGLE_STYLE}">{TOGGLE_ANCHOR}</A>{URL?}<A href="{URL}" class="{TOGGLE_CLASS}" style="{TOGGLE_STYLE}">{/URL?}{NAME}{URL?}</a>{/URL?}{/MV_CHILDREN?}{MV_CHILDREN:}{TOGGLE_ANCHOR}{URL?}<A href="{URL}" class="{LINK_CLASS}" style="{LINK_STYLE}">{/URL?}{NAME}{URL?}</a>{/URL?}{/MV_CHILDREN:}<br>
];

	if($row->{page}) {
		unless($row->{form} =~ /\r/) {
			$row->{form} = join "\n", split /\&/, $row->{form};
		}
		$row->{url} = Vend::Tags->area( { href => $row->{page}, form => $row->{form} });
	}
	$row->{name} =~ s/ /&nbsp;/g;
	$opt->{toggle_base_url} ||= Vend::Tags->history_scan(
							{ var_exclude => 'toggle,collapse,expand' }
							);
	$row->{link_class} ||= $opt->{link_class};
	$row->{link_style} ||= $opt->{link_style};
	if($row->{mv_children}) {
		my $u = $opt->{toggle_base_url};
		$u .= $u =~ /\?/ ? '&' : "?";
		$u .= "toggle=$row->{code}";
		$row->{toggle_url} = $u;
		if($row->{mv_toggled}) {
			$row->{toggle_anchor} = $opt->{toggle_anchor_open};
			$row->{toggle_class}  = $opt->{link_class_open};
			$row->{toggle_style}  = $opt->{link_style_open};
		}
		else {
			$row->{toggle_anchor} = $opt->{toggle_anchor_closed};
			$row->{toggle_class}  = $opt->{link_class_closed};
			$row->{toggle_style}  = $opt->{link_style_closed};
		}
	}
	else {
		$row->{toggle_anchor} =	$opt->{toggle_anchor_clear};
	}
	return Vend::Tags->uc_attr_list($row, $template);
}

## Returns a javascript line from a tree walk.
## Designed as a [tree ..] iterator, first iteration
## returns UPPERCASE var name index defines for the fields.
sub tree_line {
	my($template, $row, $opt) = @_;
#::logDebug("tree_line: loopname=$opt->{loopname} row=" . uneval($row));

	my @out;
	my $fields;

	if (! defined $opt->{loopinc}) {
		$opt->{loopinc} = 0;
		$opt->{loopname} ||= 'lines';
		$fields = [qw/	code
							parent_fld
							mv_level
							mv_children
							mv_increment
							page
							form
							name
							description
							img_up
							img_dn
							img_sel / ];
		if($opt->{loopfields}) {
			if(! ref($opt->{loopfields})) {
				my $fstring = $opt->{loopfields};
				$fstring =~ s/^\s+//;
				@$fields = split /[\s,\0]+/, $fstring;
			}
			else {
				$fields = $opt->{loopfields};
			}
		}

		push @$fields, 'open';
		for(my $i = 1; $i < @$fields; $i++) {
			push @out, "var \U$fields->[$i]\E = $i;";
		}
		pop @$fields;
		$opt->{loopfields} = $fields;
	}

	$fields = $opt->{loopfields};

	for(@{$opt->{_transform}}) {
		return unless $transform{$_}->($row, $opt->{$_});
	}

	if($row->{page}) {
		my $form = $row->{form};
		if($form) {
			$form =~ s/&/\n/g;
			$form .= "\nopen=";
		}
		else {
			$form = 'open=';
		}
		$row->{page} = Vend::Tags->area( { href => $row->{page}, form => $form });
	}
	$row->{description} = HTML::Entities::encode_entities($row->{description});

	my @values = @{$row}{@$fields};

	for(@values) {
		$_ = Vend::Tags->jsq($_) unless $_ eq '0' || /^[1-9](?:\d*\.)?\d*$/;
	}
	push @out, "$opt->{loopname}\[" . $opt->{loopinc}++  . "] = [" . join(", ", @values) . "];";
	return join "\n", @out, '';
}

sub menu_link {
	my ($template, $row, $opt) = @_;

	# Set to a default if not passed
	$template ||= <<EOF unless $template =~ /\S/;
{PAGE:}
	<b>{NAME}:</b>
	<br>
{/PAGE:}

{PAGE?}
&nbsp;&nbsp;&nbsp;
<a href="{HREF}"{DESCRIPTION?} title="{DESCRIPTION}"{/DESCRIPTION?}>{NAME}</a><br>
{/PAGE?}
EOF

	my %line;
	if(ref($row) eq 'ARRAY') {
		$opt->{_fa} ||= $opt->{object}{mv_field_names};
		@line{@{$opt->{_fa}}} = @$row;
		$row = \%line;
	}

	for(@{$opt->{_transform}}) {
		return unless $transform{$_}->($row, $opt->{$_});
	}

	return '<br>' unless $row->{name};
	return $row->{name} if ! $row->{page} and $row->{name} =~ /^\s*</;
	$row->{win}  = $::Scratch->{win};
	$row->{href} = Vend::Tags->area( { href => $row->{page}, form => $row->{form} });
	$row->{name} = errmsg($row->{name});
	$row->{description} =~ s/"/&quot;/g;
	return Vend::Tags->uc_attr_list($row, $template);
}

sub menu {
	my ($name, $opt, $template) = @_;
	
	$opt->{dhtml_browser} = dhtml_browser()
		unless defined $opt->{dhtml_browser};
	$opt->{menu_type} ||= 'simple';

	my $prefix = $opt->{prefix} || 'menu';
	$opt->{link_class} ||= $::Variable->{MV_DEFAULT_LINK_CLASS};

	if($template and $template =~ s:\[$prefix-header\](.*?)\[/$prefix-header\]::si) {
		$opt->{header_template} = $1;
	}
	if($template and $template =~ s:\[$prefix-footer\](.*?)\[/$prefix-footer\]::si) {
		$opt->{footer_template} = $1;
	}

	my @transform;
	for(keys %transform) {
		next unless $opt->{$_};
		my @fields = grep /\S/, split /[\s,\0]+/, $opt->{$_};
		$opt->{$_} = \@fields;
		push @transform, $_;
	}
	$opt->{_transform} = \@transform;

	if($opt->{menu_type} eq 'tree') {
		$opt->{link_class_open}   ||= $opt->{link_class};
		$opt->{link_class_closed} ||= $opt->{link_class};
		if(is_yes($opt->{no_image})) {
			$opt->{no_image} = 1;
			$opt->{toggle_anchor_clear}  ||= '&nbsp;';
			$opt->{toggle_anchor_closed} ||= '+';
			$opt->{toggle_anchor_open}   ||= '-';
		}
		else {
			$opt->{no_image} = 0;
			my $nm = "img_$_";
			$opt->{toggle_anchor_open} = Vend::Tags->image( {
							src => $opt->{img_open}  || $menu_default_img{open},
							border => 0,
							extra => $opt->{img_open_extra} || 'align=absbottom',
							});
			$opt->{toggle_anchor_closed} = Vend::Tags->image( {
							src => $opt->{img_closed} || $menu_default_img{closed},
							border => 0,
							extra => $opt->{img_closed_extra} || 'align=absbottom',
							});
			if($opt->{toggle_anchor_closed} =~ /\s+width="?(\d+)/i) {
				$opt->{img_clear_extra} ||= "height=1 width=$1";
			}
			$opt->{toggle_anchor_clear} = Vend::Tags->image( {
							src => $opt->{img_clear} || $menu_default_img{clear},
							getsize => 0,
							border => 0,
							extra => $opt->{img_clear_extra},
							});
		}

		return old_tree(@_) unless $opt->{dhtml_browser};
		return dhtml_tree(@_);
	}
	elsif($opt->{menu_type} eq 'simple') {
		if($opt->{search}) {
			## Do nothing
		}
		elsif(! $opt->{file}) {
			$opt->{file} = $::Variable->{MV_MENU_DIRECTORY} || 'include/menus';
			if(! $opt->{name}) {
				logError("No file or name specified for menu.");
			}
			$opt->{file} .= "/$opt->{name}.txt";
		}
		return old_simple(@_) unless $opt->{dhtml_browser};
		return dhtml_simple(@_);
	}
	else {
		logError("unknown menu_type %s", $opt->{menu_type});
	}
}


1;
__END__
