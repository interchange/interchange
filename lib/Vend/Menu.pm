# Vend::Menu - Interchange menu processing routines
#
# $Id: Menu.pm,v 2.53 2009-02-24 15:29:01 jon Exp $
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
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA  02110-1301  USA.

package Vend::Menu;

$VERSION = substr(q$Revision: 2.53 $, 10);

use Vend::Util;
use strict;
no warnings qw(uninitialized numeric);

my $indicated;
my $last_line;
my $first_line;
my $logical_field;

my %transform = (
	nbsp => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		for(@$fields) {
			$row->{$_} =~ s/ /&nbsp;/g;
		}
		return 1;
	},
	entities => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		for(@$fields) {
			$row->{$_} = HTML::Entities::encode_entities($row->{$_});
		}
		return 1;
	},
	localize => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		for(@$fields) {
			$row->{$_} = errmsg($row->{$_});
		}
		return 1;
	},
	first_line => sub {
		my ($row, $fields) = @_;
		return undef if ref($fields) ne 'ARRAY';
		return 1 if $first_line;
		my $status;
		for(@$fields) {
			if(s/^!\s*//) {
				$status = $status && ! $row->{$_};
			}
			else {
				$status = $status && $row->{$_};
			}
		}
		return $first_line = $status;
	},
	last_line => sub {
		my ($row, $fields) = @_;
#::logDebug("last_line transform, last_line=$last_line");
		return 1 if ref($fields) ne 'ARRAY';
		return 0 if $last_line;
		my $status;
		for(@$fields) {
#::logDebug("last_line transform checking field $_=$row->{$_}");
			if(s/^!\s*//) {
				$status = ! $row->{$_};
			}
			else {
				$status = $row->{$_};
			}
#::logDebug("last_line transform checked field $_=$row->{$_}, status=$status");
			last if $status;
		}
#::logDebug("last_line transform returning last_line=$status");
		$last_line = $status;
#::logDebug("last_line transform returning status=" . ! $status);
		return ! $status;
	},
	first_line => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		my $status = 1;
		for(@$fields) {
			if(s/^!\s*//) {
				$status = $status && ! $row->{$_};
			}
			else {
				$status = $status && $row->{$_};
			}
		}
		return $status;
	},
	inactive => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		my $status = 1;
		for(@$fields) {
			if(s/^!\s*//) {
				$status = $status && $row->{$_};
			}
			else {
				$status = $status && ! $row->{$_};
			}
		}
		return $status;
	},
	active => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		my $status = 1;
		for(@$fields) {
			if(s/^!\s*//) {
				$status = $status && ! $row->{$_};
			}
			else {
				$status = $status && $row->{$_};
			}
		}
		return $status;
	},
	ui_security => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		my $status = 1;
		for(@$fields) {
			next if ! length($row->{$_});
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
	page_class => sub {
		my ($row, $fields) = @_;
		return 1 unless $row->{indicated};
		return 1 if $row->{mv_level};
		return 1 if ref($fields) ne 'ARRAY';
		my $status = 1;
		for(@$fields) {
			my($f, $c) = split /[=~]+/, $_;
			$c ||= $f;
#::logDebug("setting scratch $f to row=$c=$row->{$c}");
			$::Scratch->{$f} = $row->{$c};
		}
		$$indicated = 0;
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
								or $CGI::values{$c} =~ /$row->{$f}/i
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
	items	=> sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		my $status = 1;
		my $nitems = scalar(@{$Vend::Items}) ? 1 : 0;
		for(@$fields) {
			next if ! length($row->{$_});
			$status = $status && (! $nitems ^ $row->{$_});
		}
		return $status;
	},
	logged_in => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		my $status = 1;
		for(@$fields) {
			next if ! length($row->{$_});
			$status = $status && (! $::Vend::Session->{logged_in} ^ $row->{$_});
		}
		return $status;
	},
	depends_on => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		my $status = 1;
		for(@$fields) {
			next if ! $row->{$_};
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
	indicator_class => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		for(@$fields) {
			my ($indicator,$rev, $last, $status);
			my($s,$r) = split /=/, $_;
			$rev = $indicator =~ s/^\s*!\s*// ? 1 : 0;
			$last = $indicator =~ s/\s*!\s*$// ? 1 : 0;
#::logDebug("checking scratch $s=$::Scratch->{$s} eq row=$r=$row->{$r}");
			$status = $::Scratch->{$s} eq $row->{$r};
			if($rev xor $status) {
				$row->{indicated} = 1;
			}
			last if $last;
		}
		if($row->{indicated}) {
			$indicated = \$row->{indicated};
		}
		return 1;
	},
	indicator_profile => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		for(@$fields) {
			my ($indicator,$rev, $last, $status);
			next unless $indicator = $row->{$_};
			$rev = $indicator =~ s/^\s*!\s*// ? 1 : 0;
			$last = $indicator =~ s/\s*!\s*$// ? 1 : 0;
			$status = Vend::Tags->run_profile($indicator);
			if($rev xor $status) {
				$row->{indicated} = 1;
				next unless $last;
			}
			last if $last;
		}
		return 1;
	},
	indicator_page => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		for(@$fields) {
			if ($::Scratch->{mv_logical_page} eq $row->{$_}) {
				unless(
						$::Scratch->{mv_logical_page_used}
						and $::Scratch->{mv_logical_page_used}
							  ne
							$row->{$logical_field}
						)
				{
					$row->{indicated} = 1;
					$::Scratch->{mv_logical_page_used} = $row->{$logical_field};
					last;
				}
			}
			($row->{indicated} = 1, last)
				if  $Global::Variable->{MV_PAGE} eq $row->{$_}
				and ! defined $row->{indicated};
		}
		return 1;
	},
	indicator => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		for(@$fields) {
			my ($indicator,$rev, $last, $status);
			next unless $indicator = $row->{$_};
			$rev = $indicator =~ s/^\s*!\s*// ? 1 : 0;
			$last = $indicator =~ s/\s*!\s*$// ? 1 : 0;
			if($indicator =~ /^\s*([-\w.:][-\w.:]+)\s*$/) {
				$status =  $CGI::values{$1};
			}
			elsif ($indicator =~ /^\s*`(.*)`\s*$/s) {
				$status = Vend::Interpolate::tag_calc($1);
			}
			elsif ($indicator =~ /\[/s) {
				$status = Vend::Interpolate::interpolate_html($indicator);
				$status =~ s/\s+//g;
			}
			if($rev xor $status) {
				$row->{indicated} = 1;
			}
			else {
				$row->{indicated} = '';
			}
			last if $last;
		}
		return 1;
	},
	expand_values_form => sub {
		my ($row, $fields) = @_;
		return 1 if ref($fields) ne 'ARRAY';
		for(@$fields) {
			next unless $row->{$_} =~ /\%5b|\[/i;
			my @parms = split $Global::UrlSplittor, $row->{$_};
			my @out;
			for my $p (@parms) {
				my ($parm, $val) = split /=/, $p, 2;
				$val = unhexify($val);
				$val =~ s/\[cgi\s+([^\[]+)\]/$CGI::values{$1}/g;
				$val =~ s/\[var\s+([^\[]+)\]/$::Variable->{$1}/g;
				$val =~ s/\[value\s+([^\[]+)\]/$::Values->{$1}/g;
				push @out, join('=', $parm, hexify($val));
			}
			$row->{$_} = join $Global::UrlJoiner, @out;
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

sub extra_value {
	my ($extra, $row) = @_;
	if(ref($extra) ne 'HASH') {
		my ($k, $v) = split /=/, $extra, 2;
		$extra = { $k => $v };
	}

	for(keys %$extra) {
		$row->{$_} = $extra->{$_}
			if length($extra->{$_});
	}
	return;
}

sub reset_transforms {
#::logDebug("resetting transforms");
	my $opt = shift;
	if($opt) {
		$logical_field = $opt->{logical_page_field} || 'name';
	}
	undef $last_line;
	undef $first_line;
	undef $indicated;
}

sub old_tree {
	my ($name, $opt, $template) = @_;
	my @out;
	my $u;
	if(! $opt->{explode_url}) {
		$u = Vend::Tags->history_scan( { var_exclude => 'toggle,collapse,expand' });
		$opt->{explode_url} = $u;
		$opt->{explode_url} .= $u =~ /\?/ ? $Global::UrlJoiner : "?";
		$opt->{explode_url} .= 'explode=1';
	}
	if(! $opt->{collapse_url}) {
		$u ||= Vend::Tags->history_scan( { var_exclude => 'toggle,collapse,expand' });
		$opt->{collapse_url} = $u;
		$opt->{collapse_url} .= $u =~ /\?/ ? $Global::UrlJoiner : "?";
		$opt->{collapse_url} .= 'collapse=1';
	}

	my $explode_label = errmsg($opt->{explode_label} || 'Explode tree');
	my $collapse_label = errmsg($opt->{collapse_label} || 'Collapse tree');

	$opt->{header_template} ||= <<EOF;
<p>
<a href="{EXPLODE_URL}" {LINK_STYLE?} style="{LINK_STYLE}"{/LINK_STYLE?} {LINK_CLASS?} class="{LINK_CLASS}"{/LINK_CLASS?}>$explode_label</a><br$Vend::Xtrailer>
<a href="{COLLAPSE_URL}" {LINK_STYLE?} style="{LINK_STYLE}"{/LINK_STYLE?} {LINK_CLASS?} class="{LINK_CLASS}"{/LINK_CLASS?}>$collapse_label</a>
</p>
EOF

	my $header;
	$header = ::interpolate_html($opt->{header_template})
		if $opt->{header_template};
	if($header =~ /\S/) {
		$header = Vend::Tags->uc_attr_list($opt, $header);
		push @out, $header;
	}

	my %defaults = (
				start       => $opt->{tree_selector} || 'Products',
				table       => $::Variable->{MV_TREE_TABLE} || 'tree',
				master      => $opt->{tree_master} || 'parent_fld',
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

	my $footer;
	$footer = ::interpolate_html($opt->{footer_template})
		if $opt->{footer_template};
	if($footer =~ /\S/) {
		$footer = Vend::Tags->uc_attr_list($opt, $footer);
		push @out, $footer;
	}

	return join "\n", @out;

}

sub old_simple {
	my ($name, $opt, $template) = @_;
	my @out;
	my $u;

	my %defaults = (
				head_skip   => 1,
			);

	while( my ($k, $v) = each %defaults) {
		next if defined $opt->{$k};
		$opt->{$k} = $v;
	}

	my $iterator;

	my $main;
	if($opt->{iterator}) {
		$main = Vend::Tags->loop(undef,$opt,$template);
	}
	else {
		$opt->{iterator} = \&transforms_only;
		delete $opt->{_transforms};
		Vend::Tags->loop(undef,$opt,'');
		reset_transforms();
		my $list = $opt->{object}{mv_results};
		if(@$list and my $fn = $opt->{object}{mv_field_names}) {
			push @$fn, 'mv_last_row';
			$list->[-1][$#$fn] = 1;
		}
		$main = join($opt->{joiner}, map {menu_link($template, $_, $opt)} @$list);
	}

	# Prevent possibility of memory leak
	reset_transforms();

	my $header;
	$header = ::interpolate_html($opt->{header_template})
		if $opt->{header_template};
	if($header =~ /\S/) {
		push @out, Vend::Tags->uc_attr_list($opt, $header);
	}

	push @out, $main;

	my $footer;

	$footer = ::interpolate_html($opt->{footer_template})
		if $opt->{footer_template};
	if($footer =~ /\S/) {
		push @out, Vend::Tags->uc_attr_list($opt, $footer);
	}

	return join "\n", @out;

}

sub dhtml_simple {
	return old_simple(@_);
}

sub old_flyout {
	return dhtml_flyout(@_);
}

sub dhtml_flyout {
	my($name, $opt, $template) = @_;

	my @out;
	my $fdiv = $name . "_flyout";

	my $vpf = $opt->{js_prefix} ||= 'mv_';

	$template = <<EOF if $template !~ /\S/;
{MV_LEVEL:}<div>{PAGE?}{MV_SPACER}<a id="{CODE}" href="{PAGE}" onMouseOver="${vpf}mousein(this)" onMouseOut="${vpf}mouseout(this)" title="{DESCRIPTION}" class="$opt->{link_class}">{NAME}</a>{/PAGE?}{PAGE:}{MV_SPACER}{NAME}{/MV_SPACER}{/PAGE:}</div>{/MV_LEVEL:}
EOF

	$opt->{cursor_type} ||= 'hand';
	$opt->{flyout_style} ||= <<EOF;
		font-weight: bold;
		text-align: left;
		font-size: 10px;
		font-family: verdana,arial;
		cursor: hand;
		text-decoration: none;
		padding: 2px;
EOF

	$opt->{anchor_down} = is_yes($opt->{anchor_down}) || 0;
	my $top_timeout = $opt->{timeout} || 1000;

	push @out, <<EOF;
<script language="JavaScript1.3">
var ${vpf}timeoutCode = -1;
var ${vpf}mydiv = '$fdiv';
var ${vpf}lines = new Array;
EOF

	my %o = (
			start       => $opt->{tree_selector} || $opt->{name},
			file		=> $opt->{file},
			table       => $opt->{table} || $::Variable->{MV_TREE_TABLE} || 'tree',
			master      => $opt->{tree_master} || 'parent_fld',
			subordinate => 'code',
			autodetect  => '1',
			no_open		=> 1,
			js_prefix	=> $vpf,
			sort        => $opt->{sort} || 'code',
			full        => '1',
			timed		=> $opt->{timed},
			spacing     => '4',
			_transform   => $opt->{_transform},
		);

	for(@{$opt->{_transform} || []}) {
		$o{$_} = $opt->{$_};
	}

	my $main;
	my $rows;
	if($opt->{iterator}) {
		$o{iterator} = $opt->{iterator};
		$main =  Vend::Tags->tree(\%o);
		$rows = $o{object}{mv_results};
	}
	else {
		$o{iterator} = \&transforms_only;
		Vend::Tags->tree(\%o);
		reset_transforms();
		delete $o{_transform};
		my @o;
		for(@{$o{object}{mv_results}}) {
			next if $_->{deleted};
			push @o, $_ unless $_->{deleted};
			$main .= tree_line(undef, $_, \%o);
		}
		$rows = \@o;
	}

	$rows->[-1]{mv_last_row} = 1 if @$rows;

	# Prevent possibility of memory leak, reset last_line/first_line
	reset_transforms();

	push @out, $main;

	my %seen;
	my @levels = grep !$seen{$_}++, map { $_->{mv_level} } @$rows;
	@levels = sort { $a <=> $b } @levels;
	my $last = $#levels || 0;
	shift @levels;

	push @out, <<EOF;
var ${vpf}anchor_down = $opt->{anchor_down};
var ${vpf}link_prepend = '$opt->{link_prepend}';
var ${vpf}link_target = '$opt->{link_target}';
var ${vpf}last_level = $last;
var ${vpf}link_class = '$opt->{link_class}';
var ${vpf}link_class_open = '$opt->{link_class_open}';
var ${vpf}link_class_closed = '$opt->{link_class_closed}';
var ${vpf}link_style = '$opt->{link_style}';
var ${vpf}link_style_open = '$opt->{link_style_open}';
var ${vpf}link_style_closed = '$opt->{link_style_closed}';
var ${vpf}submenu_image_right = '$opt->{submenu_image_right}';
var ${vpf}submenu_image_left = '$opt->{submenu_image_left}';
EOF
	push @out, <<EOF unless $opt->{no_emit_code};

// CLIP HERE
// If you want to move these functions to the HEAD
	function ${vpf}menu_link (idx) {

		if( ${vpf}browserType() == "other" )
			return;

		var l = ${vpf}lines[ idx ];

		if(l == undefined) {
			alert("Bad idx=" + idx + ", no line there.");
			return;
		}

		var mouseo = '';

		var out = '<tr><td id="' + l[0] + 'left"';
		if(l[${vpf}MV_CHILDREN] > 0) {
			baseid = l[0];
			mouseo_beg = ' onMouseOver="${vpf}mousein(this,';
			mouseo_beg += l[${vpf}MV_LEVEL] + ',';
			mouseo_end = ')"';
			out += mouseo_beg + l[0] + mouseo_end;
		}

		out += '>';

		if(${vpf}submenu_image_left && l[${vpf}MV_CHILDREN] > 0) {
			if(${vpf}submenu_image_left.substr(0,1) == '<')
				out += ${vpf}submenu_image_left;
			else
				out += '<img src="' + ${vpf}submenu_image_left + '" border="0"$Vend::Xtrailer>';
		}
		out += '</td><td><div';
		
		if(l[${vpf}MV_CHILDREN] > 0) {
			out += ' id="' + l[0] + '"' + mouseo_beg + "''" + mouseo_end;
		}
		out += '>';
		var tstyle = ${vpf}link_style;
		var tclass = ${vpf}link_class;
		var ttarget = l[${vpf}TARGET];
		if(! ttarget)
			ttarget = ${vpf}link_target;
		var tprepend = ${vpf}link_prepend;
		if(l[${vpf}PAGE]) {
			out = out + '<a href="' + tprepend + l[ ${vpf}PAGE ] + '"';
			if(tclass)
				out = out + ' class="' + tclass + '"';
			if(tstyle)
				out = out + ' style="' + tstyle + '"';
			if(ttarget)
				out = out + ' target="' + ttarget + '"';
			if(l[${vpf}DESCRIPTION])
				out = out + ' title="' + l[ ${vpf}DESCRIPTION ] + '"';
			out = out + '>';
			out = out + l[ ${vpf}NAME ] + '</a>';
		}
		else {
			out = out + l[ ${vpf}NAME ];
		}
	// alert("build idx=" + idx + " into: " + out);

		out += '</div></td><td id="' + l[0] + 'right"';

		if(l[${vpf}MV_CHILDREN] > 0) {
			out += mouseo_beg + l[0] + mouseo_end;
		}

		out += '>';
		if(${vpf}submenu_image_right && l[${vpf}MV_CHILDREN] > 0) {
			if(${vpf}submenu_image_right.substr(0,1) == '<')
				out += ${vpf}submenu_image_right;
			else
				out += '<img src="' + ${vpf}submenu_image_right + '" border="0"$Vend::Xtrailer>';
		}
		out += '</td></tr>';

		return out;
	}

	function ${vpf}mousein (obj,level,otherid) {
		if( ${vpf}browserType() == "other" )
			return;

		if(otherid != '' && otherid != undefined)
			obj = document.getElementById(otherid);

		if(level == undefined) 
			level = 0;
		level++;

		var divname = ${vpf}mydiv + level;

		var fod = document.getElementById( divname );
		if(fod == undefined) {
			return;
		}
		fod.style.display = 'none';
		clearTimeout( ${vpf}timeoutCode );
		${vpf}timeoutCode = -1;

		var html = '<table cellpadding="0" cellspacing="0" border="0">';

		var idx = -1;
		var digid = obj.id;
		digid = digid.replace(/^$vpf/, '');
		for(var j = 0; j < ${vpf}lines.length; j++) {
			if(${vpf}lines[j][0] == digid) {
				idx = j;
				break;
			}
		}

		if(idx < 0) 
			return;
	
		var l = ${vpf}lines[idx];
		var currentlevel = l[${vpf}MV_LEVEL];
		if(currentlevel == undefined)
			currentlevel = 0;

		${vpf}menuClear(currentlevel);
		if(l[${vpf}MV_CHILDREN] < 1) 
			return;

		var x = ${vpf}getRightX( obj, currentlevel ) + 1;
		var y = ${vpf}getTopX( obj, currentlevel );
		var menu = fod.style;
		menu.left = x + "px";
		menu.top = y + "px";
		menu.display = 'block';

		var i;
		for( i = idx + 1; ; i++ )
		{
			var l = ${vpf}lines[i];
// alert("running link for level=" + l[${vpf}MV_LEVEL] + ", line=" + l);
			if(l == undefined || l[${vpf}MV_LEVEL] < level)
				break;
			if(l[${vpf}MV_LEVEL] == level)
				html += ${vpf}menu_link(i);
		}
		html += '</table>';
		fod.innerHTML = html;
	}

	function ${vpf}getRightX( obj, level )
	{
		if( ${vpf}browserType() == "other" )
			return;
		var pos = 0;
		var n = 0;
		var x = obj.offsetParent;
		if(x == undefined) 
			x = obj;
		while(x.offsetParent != undefined) {
			n += x.offsetLeft;
			x = x.offsetParent;
		}
		pos = n + obj.offsetLeft;
		if(${vpf}anchor_down != 1 || level > 0)
			pos += obj.offsetWidth;
		return pos;
	}

	function ${vpf}getTopX( obj, level )
	{
		if( ${vpf}browserType() == "other" )
			return;

		var pos = 0;
		var n = 0;
		var x = obj;
		while(x.offsetParent != undefined) {
			n += x.offsetParent.offsetTop;
			x = x.offsetParent;
		}
		pos = n + obj.offsetTop;
		if(${vpf}anchor_down && level == 0)
			pos += obj.offsetHeight;
		return pos;
	}
	
	function ${vpf}mouseout( obj, level )
	{
		if( ${vpf}browserType() == "other" )
			return;

		if(level == undefined) 
			level = 0;
		level++;
		${vpf}timeoutCode = setTimeout( "${vpf}menuClear();", $top_timeout );
	}

	function ${vpf}menuClear(level)
	{
		if( ${vpf}browserType() == "other" )
			return;

		if (level == undefined)
			level = 0;
		level++;
		for( var i = level; i <= ${vpf}last_level; i++) {
			var thisdiv = ${vpf}mydiv + i;
			var fod = document.getElementById( thisdiv );
			if(fod != undefined)
				fod.style.display = 'none';
		}
		clearTimeout( ${vpf}timeoutCode );
		${vpf}timeoutCode = -1;
	}

	function ${vpf}menuBusy()
	{
		if( ${vpf}browserType() == "other" )
			return;

		clearTimeout( ${vpf}timeoutCode );
		${vpf}timeoutCode = -1;
	}

	var ${vpf}clientType = "unknown";

	function ${vpf}browserType()
	{
		if( ${vpf}clientType != "unknown"  )
			return ${vpf}clientType;
	
		${vpf}clientType = "other";
		if (document.all) {
			if( document.getElementById )
		  		${vpf}clientType = "ie";
		}
		else if (document.layers) {
		}
		else if (document.getElementById) {
			${vpf}clientType = "ns6";
		}
		else
		{
		}

		return ${vpf}clientType;
	}

// END CLIP
EOF

	push @out, <<EOF;
</script>
EOF

	for(@levels) {
		push @out, <<EOF;
<div class="$opt->{flyout_class}" id="$fdiv$_" style="
						position:absolute;
						display:none;
						$opt->{flyout_style}
					"
		 OnMouseOver="${vpf}menuBusy();" OnMouseOut="${vpf}mouseout();"></div>
EOF
	}

	my $header;
	$header = ::interpolate_html($opt->{header_template})
		if $opt->{header_template};
	if($header =~ /\S/) {
		$header = Vend::Tags->uc_attr_list($opt, $header);
		push @out, $header;
	}

	for my $row (@$rows) {
		next if $row->{deleted};
		extra_value($opt->{extra_value}, $row)
			if $opt->{extra_value};
		push @out, Vend::Tags->uc_attr_list($row, $template);
	}

	my $footer;
	$footer = ::interpolate_html($opt->{footer_template})
		if $opt->{footer_template};
	if($footer =~ /\S/) {
		$footer = Vend::Tags->uc_attr_list($opt, $footer);
		push @out, $footer;
	}

	return join "", @out;
}

sub file_tree {
	my($name, $opt, $template) = @_;
	my @out;
	# out 0

	my $vpf = $opt->{js_prefix} ||= 'mv_';
	$opt->{toggle_class} ||= '';
	$opt->{explode_url} ||= "javascript:${vpf}do_explode(); void(0)";
	$opt->{collapse_url} ||= "javascript:${vpf}do_collapse(); void(0)";
	my $explode_label = errmsg($opt->{explode_label} || 'Explode tree');
	my $collapse_label = errmsg($opt->{collapse_label} || 'Collapse tree');
	$opt->{header_template} ||= <<EOF;
<p>
<a href="{EXPLODE_URL}" {LINK_STYLE?} style="{LINK_STYLE}"{/LINK_STYLE?} {LINK_CLASS?} class="{LINK_CLASS}"{/LINK_CLASS?}>$explode_label</a><br$Vend::Xtrailer>
<a href="{COLLAPSE_URL}" {LINK_STYLE?} style="{LINK_STYLE}"{/LINK_STYLE?} {LINK_CLASS?} class="{LINK_CLASS}"{/LINK_CLASS?}>$collapse_label</a>
</p>
EOF

	my $header;
	$header = ::interpolate_html($opt->{header_template})
		if $opt->{header_template};
	if($header =~ /\S/) {
		$header = Vend::Tags->uc_attr_list($opt, $header);
		push @out, $header;
	}

	$opt->{div_style} ||= '';
	push @out, <<EOF;

<div id="${vpf}treebox" style="visibility: Visible">
</div>
<script language="JavaScript1.3">
var ${vpf}lines = new Array;
var ${vpf}sary = new Array;
EOF

	my %o = (
			start       => $opt->{tree_selector} || 'Products',
			table       => $opt->{table} || $::Variable->{MV_TREE_TABLE} || 'tree',
			master      => $opt->{tree_master} || 'parent_fld',
			file		=> $opt->{file},
			subordinate => 'code',
			autodetect  => '1',
			open_variable => $opt->{open_variable} || 'open',
			sort        => $opt->{sort} || 'code',
			js_prefix	=> $vpf,
			full        => '1',
			timed		=> $opt->{timed},
			spacing     => '4',
			_transform   => $opt->{_transform},
		);
	
	for(@{$opt->{_transform} || []}) {
		$o{$_} = $opt->{$_};
	}

	my $main;
	my $rows;
	if($opt->{iterator}) {
		$o{iterator} = $opt->{iterator};
		$main =  Vend::Tags->tree(\%o);
		$rows = $o{object}{mv_results};
	}
	else {
		$o{iterator} = \&transforms_only;
		Vend::Tags->tree(\%o);
		reset_transforms();
		delete $o{_transform};
		my @o;
		for(@{$o{object}{mv_results}}) {
			next if $_->{deleted};
			push @o, $_ unless $_->{deleted};
			$main .= tree_line(undef, $_, \%o);
		}
		$rows = \@o;
	}

	$rows->[-1]{mv_last_row} = 1 if @$rows;

	my $openvar = $opt->{open_variable} || 'open';

	push @out, $main;
	if(defined $CGI::values{$openvar}) {
		 $::Scratch->{dhtml_tree_open} = $CGI::values{$openvar};
	}
	else {
		$CGI::values{$openvar} = $::Scratch->{dhtml_tree_open};
	}
	my $out = "  var ${vpf}openstatus = [";
	my @open =  split /,/, $CGI::values{$openvar};
	my @o;

	my %hsh = (map { ($_, 1) } @open);

	for(0 .. $open[$#open]) {
		push @o, ($hsh{$_} ? 1 : 0);
	}
	$out .= join ",", @o;
	$out .= "];\n";
	$out .= " var ${vpf}explode = ";
	$out .= $CGI::values{$opt->{explode_variable} || 'explode'} ? 1 : 0;
	$out .= ";\n";
	$out .= " var ${vpf}collapse = ";
	$out .= $CGI::values{$opt->{collapse_variable} || 'collapse'} ? 1 : 0;
	$out .= ";\n";

	push @out, $out;

	my $Tag = new Vend::Tags;

	if($opt->{specific_image_toggle}) {
		$opt->{specific_image_toggle} =~ s/\D+//;
		if(defined $opt->{specific_image_base}) {
			$opt->{specific_image_base} =~ s:/*$:/:;
		}
		else {
			$opt->{specific_image_base} = $Vend::Cfg->{ImageDir};
		}
	}

	if($opt->{specific_image_link}) {
		if(defined $opt->{specific_image_base}) {
			$opt->{specific_image_base} =~ s:/*$:/:;
		}
		else {
			$opt->{specific_image_base} = $Vend::Cfg->{ImageDir};
		}
	}

	$opt->{image_link_extra} = $Tag->jsq($opt->{image_link_extra});
	$opt->{image_link_extra} ||= qq{'border="0"'};

	$opt->{specific_image_toggle} ||= 0;

	$opt->{img_node} ||= 'node.gif';
	$opt->{img_lastnode} ||= 'lastnode.gif';
	$opt->{img_spacenode} ||= 'vertline.gif';
	my $node_extra = $opt->{img_clear_extra};
	$node_extra =~ s/\bheight\s*=\s*"?\d+"?\s*//;

	for(qw/img_node img_lastnode img_spacenode/) {
			$opt->{$_} = $Tag->image({
									src => $opt->{$_},
									border => 0,
									extra => 'align=absbottom',
								});
#::logDebug("$_=$opt->{$_}");
	}

	my $canonwidth;
	$opt->{img_node} =~ m{\bwidth\s*=\s*"?(\d+)"?} 
		and $canonwidth = $1;

	my $canonheight;
	$opt->{img_node} =~ m{\bheight\s*=\s*"?(\d+)"?} 
		and $canonheight = $1;

	if($canonwidth) {
		$opt->{toggle_anchor_clear} =~ s{\bwidth\s*=\s*"*\d+"*}{width="$canonwidth"};
	}
	if($canonheight) {
		$opt->{toggle_anchor_clear} =~ s{\bheight\s*=\s*"*\d+"*}{height="$canonheight"};
	}

	$opt->{toggle_anchor_clear} =~ s{\balign\s*=\s*"*\w+"*}{}i;
	$opt->{toggle_anchor_clear} =~ s{\s*>}{ align="absbottom">}i;

#::logDebug("toggle_anchor_clear=$opt->{toggle_anchor_clear}");

	my $width = $1;
	my $ihash;
	$opt->{icon_by_type} ||= qq{
		pdf=pdf.gif
		html=html.gif
		htm=html.gif
		xls=xls.gif
		ppt=ppt.gif
		doc=doc.gif
	};

	if($opt->{icon_by_type} and $ihash = get_option_hash($opt->{icon_by_type}) ) {
		push @out, <<EOF;
var ${vpf}icon_by_type = 1;
var ${vpf}icon = new Array;
var ${vpf}img_node = '$opt->{img_node}';
var ${vpf}img_lastnode = '$opt->{img_lastnode}';
var ${vpf}img_spacenode = '$opt->{img_spacenode}';
if(! ${vpf}img_lastnode)
	${vpf}img_lastnode = ${vpf}img_node;
EOF
		for(keys %$ihash) {
			my $img = $Tag->image({
								src => $ihash->{$_},
								src_only => 1,
							});
			push @out, qq{${vpf}icon['$_'] = '$img';\n};
		}
	}
	else {
		push @out, <<EOF;
var ${vpf}icon_by_type = 0;
EOF
	}

	$opt->{no_open} = $opt->{no_open} ? 1 : 0;

	push @out, <<EOF;
var ${vpf}next_level = 0;
var ${vpf}no_open = $opt->{no_open};
var ${vpf}no_wrap = '$opt->{no_wrap}';
var ${vpf}openstring = '';
var ${vpf}link_prepend = '$opt->{link_prepend}';
var ${vpf}link_target = '$opt->{link_target}';
var ${vpf}link_class = '$opt->{link_class}';
var ${vpf}link_class_open = '$opt->{link_class_open}';
var ${vpf}link_class_closed = '$opt->{link_class_closed}';
var ${vpf}link_style = '$opt->{link_style}';
var ${vpf}link_style_open = '$opt->{link_style_open}';
var ${vpf}link_style_closed = '$opt->{link_style_closed}';
var ${vpf}specific_image_toggle = $opt->{specific_image_toggle};
var ${vpf}specific_image_base = '$opt->{specific_image_base}';
var ${vpf}specific_image_link;
var ${vpf}image_link_extra = $opt->{image_link_extra};
var ${vpf}toggle_class = '$opt->{toggle_class}';
var ${vpf}toggle_anchor_clear = '$opt->{toggle_anchor_clear}';
var ${vpf}toggle_anchor_closed = '$opt->{toggle_anchor_closed}';
var ${vpf}toggle_anchor_open = '$opt->{toggle_anchor_open}';
var ${vpf}treebox = document.getElementById('${vpf}treebox');
if(${vpf}image_link_extra)
	${vpf}image_link_extra = ' ' + ${vpf}image_link_extra;
var alert_shown;
EOF

	push @out, "${vpf}specific_image_link = 1;"
		if $opt->{specific_image_link};

	push @out, <<EOF unless $opt->{no_emit_code};

function ${vpf}image_link (rec) {
	if(rec == undefined)
		return;
	var out;
	if(rec[ ${vpf}IMG_UP ]) {
		out = '<img src="';
		out += ${vpf}specific_image_base;
		out += rec[ ${vpf}IMG_UP ];
		out += '"';
		out += ${vpf}image_link_extra;
		out += '$Vend::Xtrailer>';
// alert('img=' + out);
	}
	else {
		out = rec[${vpf}NAME];
	}
	return out;
}

var donewarn = 0;

function ${vpf}tree_link (idx) {

	var out = '';

	if(${vpf}no_wrap) {
		out += '<div style="white-space: nowrap; margin: 0; padding: 0">';
	}

	var l = ${vpf}lines[idx];
	var nxt_l = ${vpf}lines[idx + 1];
	if(! nxt_l) 
		nxt_l = new Array;

	if(l == undefined) {
		alert("Bad idx=" + idx + ", no line there.");
		return;
	}

	if(l[${vpf}MV_LEVEL] > ${vpf}next_level)
		return '';

	var spec_toggle = 0;
	if(${vpf}specific_image_toggle > 0) {
		var toglevel = ${vpf}specific_image_toggle - 1;
// if(alert_shown == undefined) {
// alert('specific image toggle triggered, toglevel=' + toglevel + ", mv_level=" + l[${vpf}MV_LEVEL]);
// alert_shown = 1;
// }
		if(l[${vpf}MV_LEVEL] <= toglevel) {
			spec_toggle = 1;
		}
	}

	var needed = l[${vpf}MV_LEVEL];
	var spacer = '';
	var nodeimg = '';
	if(l[${vpf}MV_LEVEL] && ${vpf}icon_by_type) {
		var k;
		for(k = idx + 1; ${vpf}lines[k] && ${vpf}lines[k][${vpf}MV_LEVEL] > l[${vpf}MV_LEVEL]; k++) {
			// do nothing
		}
		if( ! ${vpf}lines[k] || ${vpf}lines[k][${vpf}MV_LEVEL] < l[${vpf}MV_LEVEL] ) {
			nodeimg = ${vpf}img_lastnode;
			${vpf}sary[needed] = ${vpf}toggle_anchor_clear;
		}
		else {
			nodeimg = ${vpf}img_node;
			${vpf}sary[needed] = ${vpf}img_spacenode;
		}
	}
	else {
		${vpf}sary[needed] = '&nbsp;&nbsp;&nbsp;&nbsp;';
	}

	var i;

	if(${vpf}icon_by_type && needed)  {
		needed -= 1;
	}

	for(i = 1; i <= needed; i++)
		out += ${vpf}sary[i];

	var tstyle = ${vpf}link_style;
	var tclass = ${vpf}link_class;
	var ttarget = l[${vpf}TARGET];
	if(! ttarget)
		ttarget = ${vpf}link_target;
	var tprepend = ${vpf}link_prepend;
	if(l[${vpf}MV_CHILDREN] > 0) {
		if(l[${vpf}MV_LEVEL] && ${vpf}icon_by_type) {
			var k;
			for(k = idx; ${vpf}lines[k][${vpf}MV_LEVEL] > l[${vpf}MV_LEVEL]; k++) {
				// do nothing
			}
			out += nodeimg;
		}
		if(${vpf}openstatus[idx] == 1) {
			tclass = ${vpf}link_class_open;
			tstyle = ${vpf}link_style_open;
			if(spec_toggle > 0) {
				tanchor = '<img border="0" align="absbottom"  src="' + ${vpf}specific_image_base + l[${vpf}IMG_DN] + '"$Vend::Xtrailer>';
			}
			else {
				tanchor = ${vpf}toggle_anchor_open;
			}
			${vpf}next_level = l[${vpf}MV_LEVEL] + 1;
		}
		else {
			tclass = ${vpf}link_class_closed;
			tstyle = ${vpf}link_style_closed;
			if(spec_toggle > 0) {
				tanchor = '<img border="0" align="absbottom"  src="' + ${vpf}specific_image_base + l[${vpf}IMG_UP] + '"$Vend::Xtrailer>';
// if(alert_shown < 2) {
// alert('tanchor=' + tanchor);
// alert_shown = 2;
// }
			}
			else {
				tanchor = ${vpf}toggle_anchor_closed;
			}
			${vpf}next_level = l[${vpf}MV_LEVEL];
		}

		out = out + '<a href="javascript:${vpf}toggit(' + idx + ');void(0)"';
		if(tclass)
			out = out + ' class="' + tclass + '"';
		if(tstyle)
			out = out + ' style="' + tstyle + '"';
		out = out + '>';
		out = out + tanchor;
		out = out + '</a>';
	}
	else {
		if(! ${vpf}icon_by_type)
			out = out + ${vpf}toggle_anchor_clear;
		next_level = l[${vpf}MV_LEVEL];
	}

	if(spec_toggle == 0) {
		if(l[${vpf}PAGE]) {
			out = out + '<a href="' + tprepend + l[${vpf}PAGE];

			if(! ${vpf}no_open) 
				out += ${vpf}openstring;

			out += '"';

			if(tclass)
				out = out + ' class="' + tclass + '"';
			if(tstyle)
				out = out + ' style="' + tstyle + '"';
			if(ttarget)
				out = out + ' target="' + ttarget + '"';
			if(l[${vpf}DESCRIPTION])
				out = out + ' title="' + l[${vpf}DESCRIPTION] + '"';
			out = out + '>';
			if(${vpf}icon_by_type) {
				var fn = l[ ${vpf}PAGE ];
				var fpos = fn.lastIndexOf('.');
				var ext = fn.substr(fpos + 1);

				if(${vpf}img_node) {
					out += nodeimg;
				}

				if(${vpf}icon[ ext ]) {
					out += '<img border="0" align="absbottom" src="';
					out += ${vpf}icon[ ext ];
					out += '"$Vend::Xtrailer>';
				}
			}
			if(${vpf}specific_image_link) 
				out += ${vpf}image_link(l);
			else
				out += l[${vpf}NAME];
			out += '</a>';
		}
		else {
			if(tstyle || tclass) {
				out += "<span";
				if(tclass) 
					out += ' class="' + tclass + '"';
				if(tstyle) 
					out += ' style="' + tstyle + '"';
				out += ">" + l[${vpf}NAME] + '</span>';
			}
			else {
				out = out + l[${vpf}NAME];
			}
		}
	}

	if(${vpf}no_wrap) {
		out += '</div>';
	}
	else {
		out += "<br$Vend::Xtrailer>";
	}

	return out;
}

function ${vpf}toggit (idx) {

	var l = ${vpf}lines[idx];
	if(l == undefined) {
		alert("bad index " + idx);
		return;
	}
	if(l[${vpf}MV_CHILDREN] < 1) {
		alert("nothing to toggle at index " + idx);
		return;
	}

	${vpf}openstatus[idx] = ${vpf}openstatus[idx] == 1 ? 0 : 1;
	${vpf}gen_openstring();
	${vpf}rewrite_tree();
}
function ${vpf}gen_openstring () {
	${vpf}openstring = '';

	for(var p = 0; p < ${vpf}openstatus.length; p++) {
		if(${vpf}openstatus[p])
			${vpf}openstring += p + ',';
	}
	${vpf}openstring = ${vpf}openstring.replace(/,+\$/, '');
	return;
}
function ${vpf}do_explode () {
	for(var i = 0; i < ${vpf}lines.length; i++)
		${vpf}openstatus[i] = 1;
	${vpf}gen_openstring();
	${vpf}rewrite_tree();
}
function ${vpf}do_collapse () {
	for(var i = 0; i < ${vpf}lines.length; i++)
		${vpf}openstatus[i] = 0;
	${vpf}gen_openstring();
	${vpf}rewrite_tree();
}
function ${vpf}rewrite_tree () {
	var thing = '';
	for(i = 0; i < ${vpf}lines.length; i++) {
		thing = thing + ${vpf}tree_link(i);
	}
	${vpf}treebox.innerHTML = thing;
	${vpf}next_level = 0;
}

// END CLIP

EOF

	push @out, <<EOF;

if(${vpf}collapse == 1 || ${vpf}explode == 1) {
	${vpf}openstatus.length = 0;
}
for( var i = 0; i < ${vpf}lines.length; i++) {
	if(${vpf}openstatus[i] == undefined)
		${vpf}openstatus[i] = ${vpf}explode;
}

${vpf}collapse = 0;
${vpf}explode = 0;
${vpf}gen_openstring();
${vpf}rewrite_tree();
</script>
EOF

	my $footer;
	$footer = ::interpolate_html($opt->{footer_template})
		if $opt->{footer_template};
	if($footer =~ /\S/) {
		$footer = Vend::Tags->uc_attr_list($opt, $footer);
		push @out, $footer;
	}

	return join "\n", @out;
}

sub dhtml_tree {
	my($name, $opt, $template) = @_;
	my @out;
	# out 0

	my $vpf = $opt->{js_prefix} ||= 'mv_';
	$opt->{toggle_class} ||= '';
	$opt->{explode_url} ||= "javascript:${vpf}do_explode(); void(0)";
	$opt->{collapse_url} ||= "javascript:${vpf}do_collapse(); void(0)";
	my $explode_label = errmsg($opt->{explode_label} || 'Explode tree');
	my $collapse_label = errmsg($opt->{collapse_label} || 'Collapse tree');
	$opt->{header_template} ||= <<EOF;
<p>
<a href="{EXPLODE_URL}" {LINK_STYLE?} style="{LINK_STYLE}"{/LINK_STYLE?} {LINK_CLASS?} class="{LINK_CLASS}"{/LINK_CLASS?}>$explode_label</a><br$Vend::Xtrailer>
<a href="{COLLAPSE_URL}" {LINK_STYLE?} style="{LINK_STYLE}"{/LINK_STYLE?} {LINK_CLASS?} class="{LINK_CLASS}"{/LINK_CLASS?}>$collapse_label</a>
</p>
EOF

	my $header;
	$header = ::interpolate_html($opt->{header_template})
		if $opt->{header_template};
	if($header =~ /\S/) {
		$header = Vend::Tags->uc_attr_list($opt, $header);
		push @out, $header;
	}

	$opt->{div_style} ||= '';
	push @out, <<EOF;

<div id="${vpf}treebox" style="visibility: Visible">
</div>
<script language="JavaScript1.3">
var ${vpf}lines = new Array;
EOF

	my %o = (
			start       => $opt->{tree_selector} || 'Products',
			table       => $opt->{table} || $::Variable->{MV_TREE_TABLE} || 'tree',
			master      => $opt->{tree_master} || 'parent_fld',
			file		=> $opt->{file},
			subordinate => 'code',
			autodetect  => '1',
			open_variable => $opt->{open_variable} || 'open',
			sort        => $opt->{sort} || 'code',
			js_prefix	=> $vpf,
			full        => '1',
			timed		=> $opt->{timed},
			spacing     => '4',
			_transform   => $opt->{_transform},
		);
	
	for(@{$opt->{_transform} || []}) {
		$o{$_} = $opt->{$_};
	}

	my $main;
	my $rows;
	if($opt->{iterator}) {
		$o{iterator} = $opt->{iterator};
		$main =  Vend::Tags->tree(\%o);
		$rows = $o{object}{mv_results};
	}
	else {
		$o{iterator} = \&transforms_only;
		Vend::Tags->tree(\%o);
		reset_transforms();
		delete $o{_transform};
		my @o;
		for(@{$o{object}{mv_results}}) {
			next if $_->{deleted};
			push @o, $_ unless $_->{deleted};
			$main .= tree_line(undef, $_, \%o);
		}
		$rows = \@o;
	}

	$rows->[-1]{mv_last_row} = 1 if @$rows;

	my $openvar = $opt->{open_variable} || 'open';

	push @out, $main;
	if(defined $CGI::values{$openvar}) {
		 $::Scratch->{dhtml_tree_open} = $CGI::values{$openvar};
	}
	else {
		$CGI::values{$openvar} = $::Scratch->{dhtml_tree_open};
	}
	my $out = "  var ${vpf}openstatus = [";
	my @open =  split /,/, $CGI::values{$openvar};
	my @o;

	my %hsh = (map { ($_, 1) } @open);

	for(0 .. $open[$#open]) {
		push @o, ($hsh{$_} ? 1 : 0);
	}
	$out .= join ",", @o;
	$out .= "];\n";
	$out .= " var ${vpf}explode = ";
	$out .= $CGI::values{$opt->{explode_variable} || 'explode'} ? 1 : 0;
	$out .= ";\n";
	$out .= " var ${vpf}collapse = ";
	$out .= $CGI::values{$opt->{collapse_variable} || 'collapse'} ? 1 : 0;
	$out .= ";\n";

	push @out, $out;

	if($opt->{specific_image_toggle}) {
		$opt->{specific_image_toggle} =~ s/\D+//;
		if(defined $opt->{specific_image_base}) {
			$opt->{specific_image_base} =~ s:/*$:/:;
		}
		else {
			$opt->{specific_image_base} = $Vend::Cfg->{ImageDir};
		}
	}

	if($opt->{specific_image_link}) {
		if(defined $opt->{specific_image_base}) {
			$opt->{specific_image_base} =~ s:/*$:/:;
		}
		else {
			$opt->{specific_image_base} = $Vend::Cfg->{ImageDir};
		}
	}

	$opt->{image_link_extra} = Vend::Tags->jsq($opt->{image_link_extra});
	$opt->{image_link_extra} ||= qq{'border="0"'};

	$opt->{specific_image_toggle} ||= 0;

	push @out, <<EOF;
var ${vpf}next_level = 0;
var ${vpf}openstring = '';
var ${vpf}link_class = '$opt->{link_class}';
var ${vpf}link_class_open = '$opt->{link_class_open}';
var ${vpf}link_class_closed = '$opt->{link_class_closed}';
var ${vpf}link_style = '$opt->{link_style}';
var ${vpf}link_style_open = '$opt->{link_style_open}';
var ${vpf}link_style_closed = '$opt->{link_style_closed}';
var ${vpf}specific_image_toggle = $opt->{specific_image_toggle};
var ${vpf}specific_image_base = '$opt->{specific_image_base}';
var ${vpf}specific_image_link;
var ${vpf}image_link_extra = $opt->{image_link_extra};
var ${vpf}toggle_class = '$opt->{toggle_class}';
var ${vpf}toggle_anchor_clear = '$opt->{toggle_anchor_clear}';
var ${vpf}toggle_anchor_closed = '$opt->{toggle_anchor_closed}';
var ${vpf}toggle_anchor_open = '$opt->{toggle_anchor_open}';
var ${vpf}treebox = document.getElementById('${vpf}treebox');
if(${vpf}image_link_extra)
	${vpf}image_link_extra = ' ' + ${vpf}image_link_extra;
var alert_shown;
EOF

	push @out, "${vpf}specific_image_link = 1;"
		if $opt->{specific_image_link};

	push @out, <<EOF unless $opt->{no_emit_code};

function ${vpf}image_link (rec) {
	if(rec == undefined)
		return;
	var out;
	if(rec[ ${vpf}IMG_UP ]) {
		out = '<img src="';
		out += ${vpf}specific_image_base;
		out += rec[ ${vpf}IMG_UP ];
		out += '"';
		out += ${vpf}image_link_extra;
		out += '$Vend::Xtrailer>';
// alert('img=' + out);
	}
	else {
		out = rec[${vpf}NAME];
	}
	return out;
}

function ${vpf}tree_link (idx) {

	var out = '';

	var l = ${vpf}lines[idx];

	if(l == undefined) {
		alert("Bad idx=" + idx + ", no line there.");
		return;
	}

	if(l[${vpf}MV_LEVEL] > ${vpf}next_level)
		return '';

	var spec_toggle = 0;
	if(${vpf}specific_image_toggle > 0) {
		var toglevel = ${vpf}specific_image_toggle - 1;
// if(alert_shown == undefined) {
// alert('specific image toggle triggered, toglevel=' + toglevel + ", mv_level=" + l[${vpf}MV_LEVEL]);
// alert_shown = 1;
// }
		if(l[${vpf}MV_LEVEL] <= toglevel) {
			spec_toggle = 1;
		}
	}

	var i;
	var needed = l[${vpf}MV_LEVEL];
	for(i = 1; i <= needed; i++)
		out = out + '&nbsp;&nbsp;&nbsp;&nbsp;';

	var tstyle = ${vpf}link_style;
	var tclass = ${vpf}link_class;
	if(l[${vpf}MV_CHILDREN] > 0) {
		if(${vpf}openstatus[idx] == 1) {
			tclass = ${vpf}link_class_open;
			tstyle = ${vpf}link_style_open;
			if(spec_toggle > 0) {
				tanchor = '<img border="0" src="' + ${vpf}specific_image_base + l[${vpf}IMG_DN] + '"$Vend::Xtrailer>';
// if(alert_shown < 2) {
// alert('tanchor=' + tanchor);
// alert_shown = 2;
// }
			}
			else {
				tanchor = ${vpf}toggle_anchor_open;
			}
			${vpf}next_level = l[${vpf}MV_LEVEL] + 1;
		}
		else {
			tclass = ${vpf}link_class_closed;
			tstyle = ${vpf}link_style_closed;
			if(spec_toggle > 0) {
				tanchor = '<img border="0" src="' + ${vpf}specific_image_base + l[${vpf}IMG_UP] + '"$Vend::Xtrailer>';
// if(alert_shown < 2) {
// alert('tanchor=' + tanchor);
// alert_shown = 2;
// }
			}
			else {
				tanchor = ${vpf}toggle_anchor_closed;
			}
			${vpf}next_level = l[${vpf}MV_LEVEL];
		}

		out = out + '<a href="javascript:${vpf}toggit(' + idx + ');void(0)"';
		if(tclass)
			out = out + ' class="' + tclass + '"';
		if(tstyle)
			out = out + ' style="' + tstyle + '"';
		out = out + '>';
		out = out + tanchor;
		out = out + '</a>';
	}
	else {
		out = out + ${vpf}toggle_anchor_clear;
		next_level = l[${vpf}MV_LEVEL];
	}

	if(spec_toggle == 0) {
		if(l[${vpf}PAGE]) {
			out = out + '<a href="' + l[${vpf}PAGE] + ${vpf}openstring + '"';
			if(tclass)
				out = out + ' class="' + tclass + '"';
			if(tstyle)
				out = out + ' style="' + tstyle + '"';
			if(l[${vpf}DESCRIPTION])
				out = out + ' title="' + l[${vpf}DESCRIPTION] + '"';
			out = out + '>';
			if(${vpf}specific_image_link) 
				out += ${vpf}image_link(l);
			else
				out += l[${vpf}NAME];
			out += '</a>';
		}
		else {
			out = out + l[${vpf}NAME];
		}
	}
	out = out + "<br$Vend::Xtrailer>";

	return out;
}

function ${vpf}toggit (idx) {

	var l = ${vpf}lines[idx];
	if(l == undefined) {
		alert("bad index " + idx);
		return;
	}
	if(l[${vpf}MV_CHILDREN] < 1) {
		alert("nothing to toggle at index " + idx);
		return;
	}

	${vpf}openstatus[idx] = ${vpf}openstatus[idx] == 1 ? 0 : 1;
	${vpf}gen_openstring();
	${vpf}rewrite_tree();
}
function ${vpf}gen_openstring () {
	${vpf}openstring = '';
	for(var p = 0; p < ${vpf}openstatus.length; p++) {
		if(${vpf}openstatus[p])
			${vpf}openstring += p + ',';
	}
	${vpf}openstring = ${vpf}openstring.replace(/,+\$/, '');
	return;
}
function ${vpf}do_explode () {
	for(var i = 0; i < ${vpf}lines.length; i++)
		${vpf}openstatus[i] = 1;
	${vpf}gen_openstring();
	${vpf}rewrite_tree();
}
function ${vpf}do_collapse () {
	for(var i = 0; i < ${vpf}lines.length; i++)
		${vpf}openstatus[i] = 0;
	${vpf}gen_openstring();
	${vpf}rewrite_tree();
}
function ${vpf}rewrite_tree () {
	var thing = '';
	for(i = 0; i < ${vpf}lines.length; i++) {
		thing = thing + ${vpf}tree_link(i);
	}
	${vpf}treebox.innerHTML = thing;
	${vpf}next_level = 0;
}

// END CLIP

EOF

	push @out, <<EOF;

if(${vpf}collapse == 1 || ${vpf}explode == 1) {
	${vpf}openstatus.length = 0;
}
for( var i = 0; i < ${vpf}lines.length; i++) {
	if(${vpf}openstatus[i] == undefined)
		${vpf}openstatus[i] = ${vpf}explode;
}

${vpf}collapse = 0;
${vpf}explode = 0;
${vpf}gen_openstring();
${vpf}rewrite_tree();
</script>
EOF

	my $footer;
	$footer = ::interpolate_html($opt->{footer_template})
		if $opt->{footer_template};
	if($footer =~ /\S/) {
		$footer = Vend::Tags->uc_attr_list($opt, $footer);
		push @out, $footer;
	}

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
	$regex ||= qr/MSIE [5-9].*Windows|Mozilla.*Gecko|Opera.*[7-9]/;
	return $Vend::Session->{browser} =~ $regex;
}

## Returns a link line for a tree walk without DHTML.
sub tree_link {
	my ($template, $row, $opt) = @_;

	for(@{$opt->{_transform}}) {
		return unless $transform{$_}->($row, $opt->{$_});
	}

	$template ||= qq[
{MV_SPACER}{MV_CHILDREN?}<a href="{TOGGLE_URL}" class="{TOGGLE_CLASS}" style="{TOGGLE_STYLE}">{TOGGLE_ANCHOR}</a>{PAGE?}<a href="{HREF}" class="{TOGGLE_CLASS}" style="{TOGGLE_STYLE}">{/PAGE?}{NAME}{PAGE?}</a>{/PAGE?}{/MV_CHILDREN?}{MV_CHILDREN:}{TOGGLE_ANCHOR}{PAGE?}<A href="{HREF}" class="{LINK_CLASS}" style="{LINK_STYLE}">{/PAGE?}{NAME}{PAGE?}</a>{/PAGE?}{/MV_CHILDREN:}<br$Vend::Xtrailer>
];

	if(! $row->{page}) {
	}
	elsif ($row->{page} =~ /^\w+:/ or $row->{page} =~ m{^/}) {
		$row->{href} = $row->{page};
	}
	else {
		unless($row->{form} =~ /[\r\n]/) {
			$row->{form} = join "\n", split $Global::UrlSplittor, $row->{form};
		}
		my $add = ($::Scratch->{mv_add_dot_html} && $row->{page} !~ /\.\w+$/) || 0;
		$row->{href} = Vend::Tags->area({
							href => $row->{page},
							form => $row->{form},
							add_dot_html => $add,
							auto_format => 1,
						});
	}
	$row->{name} =~ s/ /&nbsp;/g;
	$opt->{toggle_base_url} ||= Vend::Tags->history_scan(
							{ var_exclude => 'toggle,collapse,expand' }
							);
	$row->{link_class} ||= $opt->{link_class};
	$row->{link_style} ||= $opt->{link_style};
	if($row->{mv_children}) {
		my $u = $opt->{toggle_base_url};
		$u .= $u =~ /\?/ ? $Global::UrlJoiner : "?";
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
	extra_value($opt->{extra_value}, $row)
			if $opt->{extra_value};
	return Vend::Tags->uc_attr_list($row, $template);
}

## Returns a javascript line from a tree walk.
## Designed as a [tree ..] iterator, first iteration
## returns UPPERCASE var name index defines for the fields.
sub tree_line {
	my($template, $row, $opt) = @_;

	my @out;
	my $fields;

	if (! defined $opt->{loopinc}) {
		my $vpf = $opt->{js_prefix} || 'mv_';
		$opt->{loopinc} = 0;
		$opt->{loopname} ||= $vpf . 'lines';
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
							img_sel
							target
							/ ];
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

		if($opt->{fields_repository}) {
			$opt->{fields_repository} = [ @$fields ];
		}
		push @$fields, 'open';
		for(my $i = 1; $i < @$fields; $i++) {
			push @out, "var $vpf\U$fields->[$i]\E = $i;";
		}
		pop @$fields;
		$opt->{loopfields} = $fields;
	}

	$fields = $opt->{loopfields};

	if(defined $opt->{next_level}) {
		return if $row->{mv_level} > $opt->{next_level};
		undef $opt->{next_level};
	}

	for(@{$opt->{_transform}}) {
		my $status = $transform{$_}->($row, $opt->{$_});
		$opt->{next_level} = $row->{mv_level}
			if ! $status;
		return unless $status;
	}

	if($row->{page} and $row->{page} !~ m{^(\w+:)?/}) {
		my $form = $row->{form};
		if($form and $form !~ /[\r\n]/) {
			$form = join "\n", split $Global::UrlSplittor, $form;
		}

		my $add = ($::Scratch->{mv_add_dot_html} && $row->{page} !~ /\.\w+$/) || 0;

		$row->{page} = Vend::Tags->area({
								href => $row->{page},
								form => $form,
								no_count => $opt->{timed},
								add_dot_html => $add,
								no_session_id => $opt->{timed},
								auto_format => 1,
							});

		unless($opt->{no_open}) {
			if($row->{page} =~ m{\?.+=}) {
				$row->{page} .= "$Global::UrlJoiner$opt->{open_variable}=";
			}
			else {
				$row->{page} .= "?$opt->{open_variable}=";
			}
		}
	}

	my @values = @{$row}{@$fields};

	for(@values) {
		$_ = Vend::Tags->jsq($_) unless $_ eq '0' || /^[1-9](?:\d*\.)?\d*$/;
	}
	push @out, "$opt->{loopname}\[" . $opt->{loopinc}++  . "] = [" . join(", ", @values) . "];";
	return join "\n", @out, '';
}

sub transforms_only {
	my ($template, $row, $opt) = @_;

	my %line;
	if(ref($row) eq 'ARRAY') {
		$opt->{_fa} ||= $opt->{object}{mv_field_names};
		@line{@{$opt->{_fa}}} = @$row;
		$row = \%line;
	}

	for(@{$opt->{_transform}}) {
		$row->{deleted} = 1, return unless $transform{$_}->($row, $opt->{$_});
	}
	return;
}


sub menu_link {
	my ($template, $row, $opt) = @_;

	# Set to a default if not passed
	$template ||= <<EOF unless $template =~ /\S/;
{PAGE:}
	<b>{NAME}:</b>
	<br$Vend::Xtrailer>
{/PAGE:}

{PAGE?}
&nbsp;&nbsp;&nbsp;
<a href="{HREF}"{DESCRIPTION?} title="{DESCRIPTION}"{/DESCRIPTION?}>{NAME}</a><br$Vend::Xtrailer>
{/PAGE?}
EOF

	my %line;
	if(ref($row) eq 'ARRAY') {
		$opt->{_fa} ||= $opt->{object}{mv_field_names};
		@line{@{$opt->{_fa}}} = @$row;
		$row = \%line;
	}

	$row->{mv_ip} = $opt->{mv_ip}++ || 0;
	$row->{mv_increment} = ++$opt->{mv_increment};

	for(@{$opt->{_transform}}) {
		return unless $transform{$_}->($row, $opt->{$_});
	}

	#return $row->{name} if ! $row->{page} and $row->{name} =~ /^\s*</;
	if(! $row->{page}) {
	}
	elsif ($row->{page} =~ /^\w+:/) {
		$row->{href} = $row->{page};
	}
	else {
		unless($row->{form} =~ /[\r\n]/) {
			$row->{form} = join "\n", split $Global::UrlSplittor, $row->{form};
		}
		my $add = $::Scratch->{mv_add_dot_html} && $row->{page} !~ /\.\w+$/;

		$row->{href} = Vend::Tags->area(
								{
									href => $row->{page},
									form => $row->{form},
									add_dot_html => $add,
									auto_format => 1,
								});
	}
	extra_value($opt->{extra_value}, $row)
			if $opt->{extra_value};
	return Vend::Tags->uc_attr_list($row, $template);
}

sub annfile {
	my $fn = shift;
	my $afn = $fn;
	$afn =~ s{(.*)/(.*)}{$2};
	my $base = $afn;
	if(my $dir = $1) {
		$afn = "...$afn";
		$afn = join "/", $dir, $afn;
	}
	else {
		$afn = "...$afn";
	}
	return $base unless -f $afn and -r _;
	
	open AFILE, "< $afn"
		or die "Cannot open annotation file $afn: $!\n";
	my $text = join "", <AFILE>;
	close AFILE;
	$text =~ s/^\s+//;
	$text =~ s/\s+$//;
	return $text;
}

sub make_tree_from_directory {
	my ($dir, $level, $prepend, $outfile) = @_;
	my @files = glob "$dir/*";
	my @out;
	$prepend ||= '';
	local $/;
	for(@files) {
		my %record;
		$record{msort} = $level;
		$record{name} = annfile($_);
		$record{description} = $_;
		if(-d $_) {
			push @out, \%record;
			push @out, make_tree_from_directory($_, $level + 1, $prepend);
		}
		else {
			if($prepend) {
				my $fn = $_;
				$fn =~ s:^/*[^/]+?/::;
				$record{page} = "$prepend$fn";
			}
			else {
				$record{page} = $_;
			}
			push @out, \%record;
		}
	}

	return @out unless $outfile;

	open OUT, "> $outfile"
		or do {
			logError("Couldn't write outfile %s: %s", $outfile, $!);
			return undef;
		};

	my @fields = qw/msort name page description/;
	print OUT join("\t", 'code', @fields);
	print OUT "\n";
	my $code = '0001';
	for(@out) {
		print OUT join "\t", $code++, @{$_}{@fields};
		print OUT "\n";
	}
	close OUT;
}

sub open_script {
	my $opt = shift;
	my $vpf = $opt->{js_prefix} || 'mv_';

	my $out = "<script>\n${vpf}openstatus = [";
	my @open =  split /,/, $CGI::values{$opt->{open_variable} || 'open'};
	my @o;

	my %hsh = (map { ($_, 1) } @open);

	for(0 .. $open[$#open]) {
		push @o, ($hsh{$_} ? 1 : 0);
	}
	$out .= join ",", @o;
	$out .= "];\n";
	$out .= "${vpf}explode = ";
	$out .= $CGI::values{$opt->{explode_variable} || 'explode'} ? 1 : 0;
	$out .= ";\n";
	$out .= "${vpf}collapse = ";
	$out .= $CGI::values{$opt->{collapse_variable} || 'collapse'} ? 1 : 0;
	$out .= ";\n";
	$out .= "${vpf}gen_openstring();\n";
	$out .= "${vpf}rewrite_tree();\n</script>";
}

sub menu {
	my ($name, $opt, $template) = @_;

	if($opt->{open_script}) {
		return open_script($opt);
	}
	
	Vend::Tags->tmp('mv_logical_page_used', $::Scratch->{mv_logical_page_used});
	reset_transforms($opt);

	if(! $name and ! $opt->{list}) {
		# Auto menu for pages
		if($::Scratch->{mv_menu}) {
			my @names= qw/code page form anchor description/;
			my $i = 0;
			my %hash = map { ( $_, $i++) } @names;
			my $code = '000';
			my @rows;
			my @items = split m{(?:</li\s*>)\s*<li>\s*}i, $::Scratch->{mv_menu};
			for(@items) {
				my ($page, $anchor, $form, $desc);
				m{
					<a \s+
						(?:[^>]+\s+)?
						title \s*=\s*
						(["']) # mandatory quote
							([^"'>\s]+)
						\1      # end quote
					}isx and $desc = $2;
				m{
					<a \s+
						(?:[^>]+\s+)?
						href \s*=\s*
						(["']?) # possible quote
							([^"'>\s]+)
						\1      # end quote
					}isx and $page = $2;
				($page, $form) = split /\?/, $page, 2
					if $page;
				s{<a\s+.*?>}{}is;
				s{</a>}{}i;
				push @rows, [ $code++, $page, $form, $anchor, $desc ];
			}
			$opt->{list} = [ \@rows, \%hash, \@names ];

		}
		else {
			my $page_name = $Global::Variable->{MV_PAGE};
			my $dir = Vend::Tags->var('MV_MENU_DIRECTORY', 2) || 'include/menus';
			while($page_name =~ s:/[^/]+$::) {
				my $fn = "$dir/auto/$page_name.txt";
#::logDebug("page name=$page_name, testing for $fn");
				if(-f $fn) {
					$opt->{file} = $fn;
					last;
				}
			}
			if(! $opt->{file} and -f "$dir/default.txt") {
				$opt->{file} = "$dir/default.txt";
			}
		}
	}

	$opt->{dhtml_browser} = dhtml_browser()
		unless defined $opt->{dhtml_browser};
	$opt->{menu_type} ||= 'simple';

	my $prefix = $opt->{prefix} || 'menu';
	$opt->{link_class} ||= $::Variable->{MV_DEFAULT_LINK_CLASS};

	$opt->{parse_header_footer} = 1 unless defined $opt->{parse_header_footer};

	if($opt->{parse_header_footer}) {
		$opt->{parse_header} = $opt->{parse_footer} = 1;
	}
	if($template and $template =~ s:\[$prefix-header\](.*?)\[/$prefix-header\]::si) {
		$opt->{header_template} = $1;
	}
	if($template and $template =~ s:\[$prefix-footer\](.*?)\[/$prefix-footer\]::si) {
		$opt->{footer_template} = $1;
	}

	my @transform;
	my @ordered_transform = qw/full_interpolate indicator_page page_class indicator_class localize entities nbsp/;
	my %ordered;
	@ordered{@ordered_transform} = @ordered_transform;

	for(keys %transform) {
		next if $ordered{$_};
		next unless $opt->{$_};
		my @fields = grep /\S/, split /[\s,\0]+/, $opt->{$_};
		$opt->{$_} = \@fields;
		push @transform, $_;
	}
	for(@ordered_transform) {
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
			if($opt->{file_tree}) {
				for(qw/ no_open no_wrap /) {
					$opt->{$_} = 1 unless defined $opt->{$_};
				}

				$opt->{img_open} ||= 'openfolder.gif';
				$opt->{img_closed} ||= 'closedfolder.gif';
			}

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
#::logDebug("toggle_anchor_clear=$opt->{toggle_anchor_clear}");
		}

		if($opt->{use_file}) {
			$opt->{file} = $::Variable->{MV_MENU_DIRECTORY} || 'include/menus';
			if(! $opt->{name}) {
				logError("No file or name specified for menu.");
			}
			my $nm = escape_chars($opt->{name});
			$opt->{file} .= "/$nm.txt";
			undef $opt->{file} unless -f $opt->{file};
		}
		elsif($opt->{directory}) {
			my $d = "$Vend::Cfg->{ScratchDir}/filetree";
			mkdir $d, 0777 unless -d $d;
			$opt->{file} = "$Vend::Cfg->{ScratchDir}/filetree/$Vend::SessionID.txt";
			make_tree_from_directory(
									$opt->{directory},
									0,
									delete $opt->{link_prepend},
									$opt->{file},
								)
				or do {
					logError("Unable to make tree from directory %s", $opt->{directory});
					return;
				};
		}

		return old_tree($name,$opt,$template) unless $opt->{dhtml_browser};
		return file_tree($name,$opt,$template) if $opt->{file_tree};
		return dhtml_tree($name,$opt,$template);
	}
	elsif($opt->{menu_type} eq 'flyout') {
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
							extra => $opt->{img_open_extra} || 'align="absbottom"',
							});
			$opt->{toggle_anchor_closed} = Vend::Tags->image( {
							src => $opt->{img_closed} || $menu_default_img{closed},
							border => 0,
							extra => $opt->{img_closed_extra} || 'align="absbottom"',
							});
			if($opt->{toggle_anchor_closed} =~ /\s+width="?(\d+)/i) {
				$opt->{img_clear_extra} ||= qq{height="1" width="$1"};
			}
			$opt->{toggle_anchor_clear} = Vend::Tags->image( {
							src => $opt->{img_clear} || $menu_default_img{clear},
							getsize => 0,
							border => 0,
							extra => $opt->{img_clear_extra},
							});
		}
		if($opt->{use_file}) {
			$opt->{file} = $::Variable->{MV_MENU_DIRECTORY} || 'include/menus';
			if(! $opt->{name}) {
				logError("No file or name specified for menu.");
			}
			my $nm = escape_chars($opt->{name});
			$opt->{file} .= "/$nm.txt";
			undef $opt->{file} unless -f $opt->{file};
		}

		return old_flyout($name,$opt,$template) unless $opt->{dhtml_browser};
		return dhtml_flyout($name,$opt,$template);
	}
	elsif($opt->{menu_type} eq 'simple') {
		if($opt->{search} || $opt->{list}) {
			## Do nothing
		}
		elsif(! $opt->{file}) {
			$opt->{file} = $::Variable->{MV_MENU_DIRECTORY} || 'include/menus';
			if(! $opt->{name}) {
				logError("No file or name specified for menu.");
			}
			my $nm = escape_chars($opt->{name});
			$opt->{file} .= "/$nm.txt";
		}
		return old_simple($name, $opt, $template) unless $opt->{dhtml_browser};
		return dhtml_simple($name, $opt, $template);
	}
	else {
		logError("unknown menu_type %s", $opt->{menu_type});
	}
}


1;
__END__
