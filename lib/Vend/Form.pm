# Vend::Form - Generate Form widgets
# 
# $Id: Form.pm,v 2.20 2002-10-30 17:39:06 mheins Exp $
#
# Copyright (C) 1996-2002 Red Hat, Inc. <interchange@redhat.com>
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

package Vend::Form;

require HTML::Entities;
*encode = \&HTML::Entities::encode_entities;
use Vend::Interpolate;
use Vend::Util;
use Vend::Tags;
use strict;
use POSIX qw{strftime};

use vars qw/@ISA @EXPORT @EXPORT_OK $VERSION %Template/;

require Exporter;
@ISA = qw(Exporter);

$VERSION = substr(q$Revision: 2.20 $, 10);

@EXPORT = qw (
	display
);

=head1 NAME

Vend::Form -- Interchange form element routines

=head1 SYNOPSIS

(no external use)

=head1 DESCRIPTION

Provides form element routines for Interchange, emulating the old
tag_accessories stuff. Allows user-added widgets.

=head1 ROUTINES

=cut

my $Some = '[\000-\377]*?';
my $Codere = '[-\w#/.]+';
my $Tag = new Vend::Tags;

%Template = (
	value =>
		qq({PREPEND}{VALUE}{APPEND})
		,
	selecthead =>
		qq({PREPEND}<select name="{NAME}")
		.
		qq({ROWS?} size="{ROWS}"{/ROWS?})
		.
		qq({MULTIPLE?} MULTIPLE{/MULTIPLE?})
		.
		qq({EXTRA?} {EXTRA}{/EXTRA?})
		.
		qq({JS?} {JS}{/JS?})
		.
		qq(>)
		,
	selecttail =>
		qq(</select>{APPEND})
		,
	textarea =>
		qq({PREPEND})
		.
		qq(<textarea name="{NAME}")
		.
		qq({ROWS?} rows="{ROWS}"{/ROWS?})
		.
		qq({COLS?} cols="{COLS}"{/COLS?})
		.
		qq({WRAP?} wrap="{WRAP}"{/WRAP?})
		.
		qq({EXTRA?} {EXTRA}{/EXTRA?})
		.
		qq(>{ENCODED}</textarea>)
			.
		qq({APPEND})
		,
	password =>
		qq({PREPEND}<input type="password" name="{NAME}" value="{ENCODED}")
		.
		qq({COLS?} size="{COLS}"{/COLS?}>)
		.
		qq({EXTRA?} {EXTRA}{/EXTRA?})
		.
		qq(>{APPEND})
		,
	text =>
		qq({PREPEND}<input type="text" name="{NAME}" value="{ENCODED}")
		.
		qq({COLS?} size="{COLS}"{/COLS?})
		.
		qq({EXTRA?} {EXTRA}{/EXTRA?})
		.
		qq(>{APPEND})
		,
	hidden =>
		qq({PREPEND}<input type="hidden" name="{NAME}" value="{ENCODED}")
		.
		qq({EXTRA?} {EXTRA}{/EXTRA?})
		.
		qq(>{APPEND})
		,
	hiddentext =>
		qq({PREPEND}<input type="hidden" name="{NAME}" value="{ENCODED}")
		.
		qq({EXTRA?} {EXTRA}{/EXTRA?})
		.
		qq(>{ENCODED}{APPEND})
		,
	boxstd =>
		qq(<input type="{VARIANT}" name="{NAME}" value="{TVALUE}")
		.
		qq({EXTRA?} {EXTRA}{/EXTRA?})
		.
		qq({SELECTED?} CHECKED{/SELECTED?})
		.
		qq(>&nbsp;{TLABEL})
		,
	boxnbsp =>
		qq(<input type="{VARIANT}" name="{NAME}" value="{TVALUE}")
		.
		qq({EXTRA?} {EXTRA}{/EXTRA?})
		.
		qq({SELECTED?} CHECKED{/SELECTED?})
		.
		qq(>&nbsp;{TLABEL}&nbsp;&nbsp;)
		,
	boxlabel =>
		qq(<td{TD_LABEL?} {TD_LABEL}{/TD_LABEL?}>)
		.
		qq({FONT?}<font size="{FONT}">{/FONT?})
		.
		qq({TLABEL}{FONT?}</font>{/FONT?})
		.
		qq(</td>)
		,
	boxvalue =>
		qq(<td{TD_VALUE?} {TD_VALUE}{/TD_VALUE?}>)
		.
		qq(<input type="{VARIANT}" name="{NAME}" value="{TVALUE}")
		.
		qq({EXTRA?} {EXTRA}{/EXTRA?})
		.
		qq({SELECTED?} CHECKED{/SELECTED?})
		.
		qq(>)
		.
		qq(</td>)
		,
	boxgroup =>
		qq(</tr><tr><td{TD_GROUP?} {TD_GROUP}{/TD_GROUP?} COLSPAN=2>)
		.
		qq(<b>{TVALUE}</b>)
		.
		qq(</td></tr>)
		,
);

$Template{default} = $Template{text};

sub attr_list {
	my ($body, $hash) = @_;
	return $body unless ref($hash) eq 'HASH';
	$body =~ s!\{([A-Z_]+)\}!$hash->{lc $1}!g;
	$body =~ s!\{([A-Z_]+)\|($Some)\}!$hash->{lc $1} || $2!eg;
	$body =~ s!\{([A-Z_]+)\s+($Some)\}! $hash->{lc $1} ? $2 : ''!eg;
	$body =~ s!\{([A-Z_]+)\?\}($Some){/\1\?\}! $hash->{lc $1} ? $2 : ''!eg;
	$body =~ s!\{([A-Z_]+)\:\}($Some){/\1\:\}! $hash->{lc $1} ? '' : $2!eg;
	return $body;
}

sub show_data {
	my $opt = shift;
	my $ary = shift;
	return undef if ! $ary;
	my @out;
	for(@$ary) {
		push @out, join "=", @$_;
	}
	my $delim = Vend::Interpolate::get_joiner($opt->{delimiter}, ',');
	return join $delim, @out;
}

sub show_options {
	my $opt = shift;
	my $ary = shift;
	return undef if ! $ary;
	my @out;
	eval {
		@out = map {$_->[0]} @$ary;
	};
	my $delim = Vend::Interpolate::get_joiner($opt->{delimiter}, ',');
	return join $delim, @out;
}

sub template_sub {
	my $opt = shift;
	return attr_list($Template{$opt->{type}} || $Template{default}, $opt);
}

## Retrieve the *first* current label
sub current_label {
	my($opt, $data) = @_;
	my $val;
	my $default;
	if (defined $opt->{value}) {
		$val = $opt->{value};
	}
	elsif(defined $opt->{default}) {
		$val = $opt->{default};
	}
	$val =~ s/\0//;
	for(@$data) {
		my ($setting, $label) = @$_;
		$default = $label if $label =~ s/\*$//;
		return ($label || $setting) if $val eq $setting;
	}
	return $default;
}

sub links {
	my($opt, $opts) = @_;
#warn "called links opts=$opts\n";

	$opt->{joiner} = Vend::Interpolate::get_joiner($opt->{joiner}, "<BR>");
	my $name = $opt->{name};
	my $default = defined $opt->{value} ? $opt->{value} : $opt->{default};

	$opt->{extra} = " $opt->{extra}" if $opt->{extra};

	my $template = $opt->{template} || <<EOF;
<A HREF="{URL}"{EXTRA}>{SELECTED <B>}{LABEL}{SELECTED </B>}</A>
EOF

	my $o_template = $opt->{o_template} || <<EOF;
<B>{TVALUE}</B>
EOF

	my $href = $opt->{href} || $Global::Variable->{MV_PAGE};
	$opt->{form} = "mv_action=return" unless $opt->{form};

	my @out;
	for(@$opts) {
#warn "iterating links opt $_ = " . uneval_it($_) . "\n";
		my $attr = { extra => $opt->{extra}};
		
		s/\*$// and $attr->{selected} = 1;

		($attr->{value},$attr->{label}) = @$_;
		encode($attr->{label}, $ESCAPE_CHARS::std);
		if($attr->{value} =~ /^\s*\~\~(.*)\~\~\s*$/) {
			my $lab = $1;
			$lab =~ s/"/&quot;/g;
			$opt->{tvalue} = $lab;
			$opt->{tlabel} = $lab;
			push @out, attr_list($o_template, $opt);
			next;
		}

		next if ! $attr->{value} and ! $opt->{empty};
		if( ! length($attr->{label}) ) {
			$attr->{label} = $attr->{value} or next;
		}

		if ($default) {
			$attr->{selected} = $default eq $attr->{value} ? 1 : '';
		}

		my $form = $opt->{form};

		$attr->{url} = Vend::Interpolate::tag_area(
						$href,
						'',
						{
							form => "$name=$attr->{value}\n$opt->{form}",
							secure => $opt->{secure},
						},
						);
		push @out, attr_list($template, $attr);
	}
	return join $opt->{joiner}, @out;
}

my @Years;
my @Months;
my @Days;

INITTIME: {
	my @t = localtime();
	(@Years) = ( $t[5] + 1899 .. $t[5] + 1910 );

	for(1 .. 12) {
		$t[4] = $_ - 1;
		$t[5] = 1;
		push @Months, [sprintf("%02d", $_), POSIX::strftime("%B", @t)];
	}

	for(1 .. 31) {
		push @Days, [sprintf("%02d", $_), $_];
	}
}

sub round_to_fifteen {
	my $val = shift;
#::logDebug("round_to_fifteen val in=$val");
	$val = substr($val, 0, 4);
	$val = "0$val" if length($val) == 3;
	return '0000' if length($val) < 4;
	if($val !~ /(00|15|30|45)$/) {
		my $hr = substr($val, 0, 2);
		$hr =~ s/^0//;
		my $min = substr($val, 2, 2);
		$min =~ s/^0//;
		if($min > 45 and $hr < 23) {
			$hr++;
			$min = 0;
		}
		elsif($min > 30) {
			$min = 45;
		}
		elsif($min > 15) {
			$min = 30;
		}
		elsif($min > 0) {
			$min = 15;
		}
		elsif ($hr == 23) {
			$min = 45;
		}
		else {
			$min = 0;
		}
		$val = sprintf('%02d%02d', $hr, $min);
	}
#::logDebug("round_to_fifteen val out=$val");
	return $val;
}

sub date_widget {
	my($opt) = @_;

	my $name = $opt->{name};
	my $val  = $opt->{value};

	if($val =~ /\D/) {
		$val = Vend::Interpolate::filter_value('date_change', $val);
	}
	my $now;
	if($opt->{time} and $opt->{time_adjust} =~ /([-+]?)(\d+)/) {
		my $sign = $1 || '+';
		my $adjust = $2;
		$adjust *= 3600;
		$now = time;
		$now += $sign eq '+' ? $adjust : -$adjust;
	}

	my @t = localtime($now || time);
	if (not $val) {
		$t[2]++ if $t[2] < 23;
		$val = POSIX::strftime("%Y%m%d%H00", @t);
	}
	my $sel = 0;
	my $out = qq{<SELECT NAME="$name">};
	my $o;
	for(@Months) {
		$o = qq{<OPTION VALUE="$_->[0]">} . errmsg($_->[1]) . '</OPTION>';
		($out .= $o, next) unless ! $sel and $val;
		$o =~ s/>/ SELECTED>/ && $sel++
			if substr($val, 4, 2) eq $_->[0];
		$out .= $o;
	}
	$sel = 0;
	$out .= qq{</SELECT>};
	$out .= qq{<INPUT TYPE=hidden NAME="$name" VALUE="/">};
	$out .= qq{<SELECT NAME="$name">};
	for(@Days) {
		$o = qq{<OPTION VALUE="$_->[0]">$_->[1]} . '</OPTION>';
		($out .= $o, next) unless ! $sel and $val;
		$o =~ s/>/ SELECTED>/ && $sel++
			if substr($val, 6, 2) eq $_->[0];
		$out .= $o;
	}
	$sel = 0;
	$out .= qq{</SELECT>};
	$out .= qq{<INPUT TYPE=hidden NAME="$name" VALUE="/">};
	$out .= qq{<SELECT NAME="$name">};
	if(my $by = $opt->{year_begin} || $::Variable->{UI_DATE_BEGIN}) {
		my $cy = $t[5] + 1900;
		my $ey = $opt->{year_end}  || $::Variable->{UI_DATE_END} || ($cy + 10);
		if($by < 100) {
			$by = $cy - abs($by);
		}
		if($ey < 100) {
			$ey += $cy;
		}
		@Years = ($by .. $ey);
	}
	for(@Years) {
		$o = qq{<OPTION>$_} . '</OPTION>';
		($out .= $o, next) unless ! $sel and $val;
		$o =~ s/>/ SELECTED>/ && $sel++
			if substr($val, 0, 4) eq $_;
		$out .= $o;
	}
	$out .= qq{</SELECT>};
	return $out unless $opt->{time};

	$val =~ s/^\d{8}//;
	$val =~ s/\D+//g;
	$val = round_to_fifteen($val);
	$out .= qq{<INPUT TYPE=hidden NAME="$name" VALUE=":">};
	$out .= qq{<SELECT NAME="$name">};
	
	my $ampm = defined $opt->{ampm} ? $opt->{ampm} : 1;
	my $mod = '';
	undef $sel;
	my %special = qw/ 0 midnight 12 noon /;
	
	for my $hr ( 0 .. 23) {
		for my $min ( 0,15,30,45 ) {
			my $disp_hour = $hr;
			if($opt->{ampm}) {
				if( $hr < 12) {
					$mod = 'am';
				}
				else {
					$mod = 'pm';
					$disp_hour = $hr - 12 unless $hr == 12;
				}
				$mod = errmsg($mod);
				$mod = " $mod";
			}
			if($special{$hr} and $min == 0) {
				$disp_hour = errmsg($special{$hr});
			}
			elsif($ampm) {
				$disp_hour = sprintf("%2d:%02d%s", $disp_hour, $min, $mod);
			}
			else {
				$disp_hour = sprintf("%02d:%02d", $hr, $min);
			}
			my $time = sprintf "%02d%02d", $hr, $min;
			$o = sprintf qq{<OPTION VALUE="%s">%s}, $time, $disp_hour;
			($out .= $o, next) unless ! $sel and $val;
#::logDebug("prospect=$time actual=$val");
			$o =~ s/>/ SELECTED>/ && $sel++
				if $val eq $time;
			$out .= $o;
		}
	}
	$out .= "</SELECT>";
	return $out;
}

sub option_widget_box {
	my ($name, $val, $lab, $default, $width) = @_;
	my $half = int($width / 2);
	my $sel = $default ? ' SELECTED' : '';
	$val =~ s/"/&quot;/g;
	$lab =~ s/"/&quot;/g;
	$width = 10 if ! $width;
	return qq{<TR><TD><SMALL><INPUT TYPE=text NAME="$name" VALUE="$val" SIZE=$half></SMALL></TD><TD><SMALL><INPUT TYPE=text NAME="$name" VALUE="$lab" SIZE=$width></SMALL></TD><TD><SMALL><SMALL><SELECT NAME="$name"><OPTION value="0">no<OPTION value="1"$sel>default*</SELECT></SMALL></SMALL></TD></TR>};
}

sub option_widget {
	my($opt) = @_;
	my($name, $val) = ($opt->{name}, $opt->{value});
	
	my $width = $opt->{width} || 16;
	$opt->{filter} = 'option_format'
		unless length($opt->{filter});
	$val = Vend::Interpolate::filter_value('option_format', $val);
	my @opts = split /\s*,\s*/, $val;
	my $out = "<TABLE CELLPADDING=0 CELLSPACING=0><TR><TH><SMALL>Value</SMALL></TH><TH ALIGN=LEFT COLSPAN=2><SMALL>Label</SMALL></TH></TR>";
	my $done;
	my $height = $opt->{height} || 5;
	$height -= 2;
	for(@opts) {
		my ($v,$l) = split /\s*=\s*/, $_, 2;
		next unless $l || length($v);
		$done++;
		my $default;
		($l =~ s/\*$// or ! $l && $v =~ s/\*$//)
			and $default = 1;
		$out .= option_widget_box($name, $v, $l, $default, $width);
	}
	while($done++ < $height) {
		$out .= option_widget_box($name, '', '', '', $width);
	}
	$out .= option_widget_box($name, '', '', '', $width);
	$out .= option_widget_box($name, '', '', '', $width);
	$out .= "</TABLE>";
}


sub movecombo {
	my ($opt, $opts) = @_;
	my $name = $opt->{name};
	$opt->{name} = "X$name";
	my $ejs = ",1" if $opt->{rows} > 1;
	$opt->{extra} .= qq{ onChange="addItem(this.form['X$name'],this.form['$name']$ejs)"}
            unless $opt->{extra};
	my $tbox = '';
	my $out = dropdown($opt, $opts);

	my $template = $opt->{o_template} || '';
	if(! $template) {
		if($opt->{rows} > 1) {
			$template .= q(<textarea rows="{ROWS|4}" wrap="{WRAP|virtual}");
			$template .= q( cols="{COLS|20}" name="{NAME}">{ENCODED}</textarea>);
		}
		else {
			$template .= qq(<input TYPE="text" size="{COLS||40}");
			$template .= qq( name="{NAME}" value="{ENCODED}">);
		}
	}
	$opt->{name} = $name;
	$tbox = attr_list($template, $opt);

	return $opt->{reverse} ? $tbox . $out : $out . $tbox;
}

sub combo {
	my ($opt, $opts) = @_;
	my $addl = qq|<INPUT TYPE=text NAME="$opt->{name}"|;
	$addl   .= qq| SIZE="$opt->{cols}" VALUE="">|;
	if($opt->{reverse}) {
		$opt->{append} = length($opt->{append}) ? "$addl$opt->{append}" : $addl;
	}
	else {
		$opt->{prepend} = length($opt->{prepend}) ? "$opt->{prepend}$addl" : $addl;
	}
	return dropdown($opt, $opts);
}

sub dropdown {
	my($opt, $opts) = @_;
#::logDebug("called select opt=" . ::uneval($opt) . "\nopts=" . ::uneval($opts));
	$opt->{multiple} = 1 if $opt->{type} eq 'multiple';

	$opts ||= [];

	my $price = $opt->{price} || {};

	my $select;
	my $run = attr_list($Template{selecthead}, $opt);
	my ($multi, $re_b, $re_e, $regex);
#::logDebug("select multiple=$opt->{multiple}");
	if($opt->{multiple}) {
		$multi = 1;
		if($opt->{rawvalue}) {
			$re_b = '(?:\0|^)';
			$re_e = '(?:\0|$)';
		}
		else {
			$re_b = '(?:[\0,\s]|^)';
			$re_e = '(?:[\0,\s]|$)';
		}
	}
	else {
		$re_b = '^';
		$re_e = '$';
	}

	my $limit;
	if($opt->{cols}) {
		my $cols = $opt->{cols};
		$limit = sub {
			return $_[0] if length($_[0]) <= $cols;
			return substr($_[0], 0, $cols - 2) . '..';
		};
	}
	else {
		$limit = sub { return $_[0] };
	}

	my $default = $opt->{value};

	my $optgroup_one;
	
	for(@$opts) {
		my ($value, $label) = @$_;
		encode($label, $ESCAPE_CHARS::std);
		if($value =~ /^\s*\~\~(.*)\~\~\s*$/) {
			my $label = $1;
			if($optgroup_one++) {
				$run .= "</optgroup>";
			}
			$run .= qq{<optgroup label="$label">};
			next;
		}
		$run .= '<option';
		$select = '';

		if($label) {
			$label =~ s/\*$// and $select = 1;
		}
		else {
			$value =~ s/\*$// and $select = 1;
		}

		if (defined $default) {
			$select = '';
		}

		my $extra;
		if($price->{$value}) {
			$extra = currency($price->{$value}, undef, 1);
			$extra = " ($extra)";
		}

		my $vvalue = $value;
		encode($vvalue, $ESCAPE_CHARS::std);
		$run .= qq| value="$vvalue"|;
		if (length($default)) {
			$regex	= qr/$re_b\Q$value\E$re_e/;
			$default =~ $regex and $select = 1;
		}
		$run .= ' SELECTED' if $select;
		$run .= '>';
		if($label) {
			$run .= $limit->($label);
		}
		else {
			$run .= $limit->($value);
		}
		$run .= $extra if $extra;
	}
	$run .= "</optgroup>" if $optgroup_one++;
	$run .= attr_list($Template{selecttail}, $opt);
}

=head2 yesno

Provides an easy "Yes/No" widget. C<No> returns a value of blank/false,
and C<Yes> returns 1/true.

Calling:

  {
    name => 'varname' || undef,       ## Derived from item if called by
                                       # [PREFIX-options] or [PREFIX-accessories]
    type => 'yesno' || 'yesno radio', ## Second is shorthand for variant=>radio
    variant => 'radio' || 'select',   ## Default is select
  }

The data array passed by C<passed> is never used, it is overwritten
with the equivalent of '=No,1=Yes'. C<No> and C<Yes> are generated from
the locale, so if you want a translated version set those keys in the locale.

If you want another behavior the same widget can be constructed with:

	[display passed="=My no,0=My yes" type=select ...]

=cut


sub yesno {
	my $opt = shift;
	$opt->{value} = is_yes($opt->{value});
	my @opts;
	my $routine = $opt->{subwidget} || \&dropdown;
	if($opt->{variant} eq 'checkbox') {
		@opts = [1, ' '];
	}
	else {
		@opts = (
					['', errmsg('No')],
					['1', errmsg('Yes')],
				);
	}
	return $routine->($opt, \@opts);
}

=head2 noyes

Same as C<yesno> except sense is reversed. C<No> returns a value of 1/true,
and C<Yes> returns blank/false.

=cut

sub noyes {
	my $opt = shift;
	$opt->{value} = is_no($opt->{value});
	my @opts = (
					['1', errmsg('No')],
					['', errmsg('Yes')],
				);
	my $routine = $opt->{subwidget} || \&dropdown;
	return $routine->($opt, \@opts);
}

sub box {
	my($opt, $opts) = @_;
#::logDebug("Called box type=$opt->{type}");
	my $inc = $opt->{breakmod};
	my ($xlt, $template, $o_template, $header, $footer, $row_hdr, $row_ftr);

	$opt->{variant} ||= $opt->{type};

	$header = $template = $footer = $row_hdr = $row_ftr = '';

	if($opt->{nbsp}) {
		$xlt = 1;
		$template = $Template{boxnbsp};
	}
	elsif ($opt->{left}) {
		$header = '<TABLE>';
		$footer = '</TABLE>';
		$template = '<TR>' unless $inc;
		$template .= $Template{boxvalue};
		$template .= $Template{boxlabel};
		$template .= '</TR>' unless $inc;
		$o_template = $Template{boxgroup};
	}
	elsif ($opt->{right}) {
		$header = '<TABLE>';
		$footer = '</TABLE>';
		$template = '<TR>' unless $inc;
		$template .= $Template{boxlabel};
		$template .= $Template{boxvalue};
		$template .= '</TR>' unless $inc;
		$o_template = $Template{boxgroup};
	}
	else {
		$template = $Template{boxstd};
	}
	$o_template ||= '<BR><b>{TVALUE}</b><BR>';

	my $run = $header;

	my $price = $opt->{price} || {};

	my $i = 0;
	my $default = $opt->{value};

	for(@$opts) {
		my($value,$label) = @$_;
		encode($label, $ESCAPE_CHARS::std);
		if($value =~ /^\s*\~\~(.*)\~\~\s*$/) {
			my $lab = $1;
			$lab =~ s/"/&quot;/g;
			$opt->{tvalue} = $lab;
			$opt->{tlabel} = $lab;
			$run .= attr_list($o_template, $opt);
			$i = 0;
			next;
		}
		$value = ''     if ! length($value);
		$label = $value if ! length($label);

		$run .= '<TR>' if $inc && ! ($i % $inc);
		$i++;

		undef $opt->{selected};
		$label =~ s/\*$//
			and $opt->{selected} = 1;
		$opt->{selected} = '' if defined $opt->{value};

		my $extra;
		if($price->{$value}) {
			$label .= "&nbsp;(" . currency($price->{$value}, undef, 1) . ")";
		}

		$value eq ''
			and defined $default
			and $default eq ''
			and $opt->{selected} = 1;

		if(length $value) {
			my $regex	= $opt->{contains}
						? qr/\Q$value\E/ 
						: qr/\b\Q$value\E\b/;
			$default =~ $regex and $opt->{selected} = 1;
		}

		$opt->{tvalue} = encode($value, $ESCAPE_CHARS::std);

		$label =~ s/ /&nbsp;/g if $xlt;
		$opt->{tlabel} = $label;

		$run .= attr_list($template, $opt);
		$run .= '</TR>' if $inc && ! ($i % $inc);
	}
	$run .= $footer;
}

sub options_to_array {
	my ($passed, $opt) = @_;
	return $passed if ref($passed) eq 'ARRAY'
		and (
			! scalar @$passed
				or
			ref($passed->[0]) eq 'ARRAY'
		);

	$opt ||= {};
	my @out;

	if($passed =~ m{^[^=]*\0}) {
		$passed = filter_value($passed, 'option_format');
	}

	my $delim = $opt->{delimiter} || ',';
	$delim = '\s*' . $delim . '\s*';

	if (ref $passed eq 'SCALAR') {
		$passed = [ split /$delim/, $$passed ];
	}
	elsif(! ref $passed) {
		$passed = [ split /$delim/, $passed ];
	}

	if (ref $passed eq 'ARRAY') {
		for(@$passed) {
			push @out, [split /\s*=\s*/, HTML::Entities::decode($_), 2];
		}
		return \@out;
	}
	elsif (ref $passed eq 'HASH') {
		my @keys;
		my $sub;
		my $nsub = sub { ($_->{$a} || $a) <=> ($_->{$b} || $b) };
		my $asub = sub { ($_->{$a} || $a) cmp ($_->{$b} || $b) };
		if(! $opt->{sort_option}) {
			$sub = $asub;
		}
		elsif($opt->{sort_option} eq 'none') {
			# do nothing
		}
		elsif($opt->{sort_option} =~ /n/i) {
			$sub = $nsub;
		}
		else {
			$sub = $asub;
		}

		@keys = $sub ? (sort $sub keys %$passed) : (keys %$passed);

		for(@keys) {
			push @out, [$_, $passed->{$_}];
		}
		return \@out;
	}
	else {
		die "bad data type to options_to_array";
	}
}

sub display {
	my($opt, $item, $data) = @_;

if($opt->{debug}) {
	::logDebug("display called, options=" . uneval($opt));
	::logDebug("item=" . uneval($item)) if $item;
}

	if(! ref $opt) {
		### Has effect of simple default widget for name
		### or some text output
		if($opt =~ /^$Codere$/) {
			$opt = { name => $opt };
		}
		else {
			return $opt;
		}
	}
	elsif (ref $opt eq 'ARRAY') {
		### Handle multiple things passed
		my @out;
		for(@$opt) {
			push @out, display( ref $_ eq 'ARRAY' ? @$_ : ($_));
		}
		return join "", @out;
	}

	if($opt->{override}) {
		$opt->{value} = $opt->{default};
	}

	$opt->{default} = $opt->{value}    if defined $opt->{value};

	if($opt->{pre_filter} and defined $opt->{value}) {
		$opt->{value} = Vend::Interpolate::filter_value(
							$opt->{pre_filter},
							$opt->{value},
						);
	}

	my $ishash;
	if(ref ($item) eq 'HASH') {
#::logDebug("item=$item");
		$ishash = 1;
	}
	else {
		$item = get_option_hash($item || $opt->{item});
	}
#::logDebug("item=" . ::uneval($item));

	# Just in case
	$opt  ||= {};
	$item ||= {};

	## Set some defaults, can't have attribute or type '0';
	## Note the fact that attribute can take its value from name
	## and vice-versa
	$opt->{attribute} ||= $opt->{name};
	$opt->{prepend}   = ''  unless defined $opt->{prepend};
	$opt->{append}    = ''  unless defined $opt->{append};
	$opt->{delimiter} = ',' unless length($opt->{delimiter});
	$opt->{cols}      ||= $opt->{width} || $opt->{size};
	$opt->{rows}      ||= $opt->{height};

	# This handles the embedded attribute information in certain types,
	# for example: 
	# 
	#	text_60       is the same as type => 'text', width => '60'
	#   datetime_ampm is the same as type => 'datetime', ampm => 1

	# Warning -- this sets $opt->{type} and has possible side-effects
	#            in $opt
	my $type = parse_type($opt);

#::logDebug("type=$type");

	my $look;

	if($look = $opt->{lookup_query}) {
		my $tab = $opt->{table} || $Vend::Cfg->{ProductFiles}[0];
		my $db = Vend::Data::database_exists_ref($tab);
		$data = $db->query($look)
			if $db;
		$data ||= [];
	}
	elsif($look = $opt->{lookup}) {
#::logDebug("lookup called, opt=" . uneval($opt));
		LOOK: {
			my $tab = $opt->{db} || $opt->{table} || $Vend::Cfg->{ProductFiles}[0];
			my $db = Vend::Data::database_exists_ref($tab)
				or last LOOK;
			my $fld = $opt->{field} || $look;
			my $key = $look;

			if($key ne $fld and $fld !~ /,/) {
				$fld = "$key,$fld";
			}

			my @f = split /\s*,\s*/, $fld;
			my $order = $opt->{sort} || $f[1] || $f[0];
			last LOOK unless $tab;
			my $q = qq{SELECT DISTINCT $fld FROM $tab ORDER BY $order};
			eval {
				$data = $db->query($q) || die;
				if(@f > 2) {
					for(@$data) {
						my $join = $opt->{label_joiner} || '-';
						my $string = join $join, splice @$_, 1;
						$_->[1] = $string;
					}
				}
			};
		}
	}
	elsif($opt->{passed}) {
		$data = options_to_array($opt->{passed}, $opt);
	}
	elsif($opt->{column} and $opt->{table}) {
		GETDATA: {
			last GETDATA if $opt->{table} eq 'mv_null';
			my $key = $opt->{outboard} || $item->{code} || $opt->{code};
			last GETDATA unless length($key);
			last GETDATA unless ::database_exists_ref($opt->{table});
			$opt->{passed} = $Tag->data($opt->{table}, $opt->{column}, $key)
				and
			$data = options_to_array($opt->{passed}, $opt);
		}
	}

	## This means a lookup was attempted above
	if($look and $data) {
		my $ary;
		if($opt->{options}) {
			$ary = options_to_array($opt->{options}, $opt) || [];
		}
		elsif(! scalar(@$data)) {
			$ary = [['', errmsg('--no current values--')]];
		}
		if($opt->{lookup_exclude}) {
			my $sub;
			eval {
				$sub = sub { $_[0] !~ m{$opt->{lookup_exclude}} };
			};
			if ($@) {
				logError(
					"Bad lookup pattern m{%s}: %s", $opt->{lookup_exclude}, $@,
				);
				undef $sub;
			}
			if($sub) {
				@$data = grep $_,
							map {
								$sub->(join '=', @$_)
									or return undef;
								return $_;
							} @$data;
			}
		}
		unshift @$data, @$ary if $ary;
	}

## Some legacy stuff, has to do with default behavior when called from
## item-accessories or item-options
	if($ishash) {
		my $adder;
		$adder = $item->{mv_ip} if	defined $item->{mv_ip}
								and $opt->{item} || ! $opt->{name};
		$opt->{name} = $opt->{attribute}
			unless $opt->{name};
		$opt->{value} = $item->{$opt->{attribute} || $opt->{name}};
		$opt->{name} .= $adder if defined $adder;
#::logDebug("tag_accessories: name=$opt->{name} ISHASH");
	}
	else {
#::logDebug("display: name=$opt->{name} IS NOT HASH");
		$opt->{name} = "mv_order_$opt->{attribute}" unless $opt->{name};
	}

	$opt->{price} = get_option_hash($opt->{price_data})
		if $opt->{price};

	$opt->{name} ||= $opt->{attribute};

	if(defined $opt->{value}) {
		# do nothing
	}
	elsif(defined $item->{$opt->{name}}) {
	   $opt->{value}   = $item->{$opt->{name}};
	}
	elsif($opt->{cgi_default} and ! $opt->{override}) {
		my $def = $CGI::values{$opt->{name}};
		$opt->{value} = $def if defined($def);
	}
	elsif($opt->{values_default} and ! $opt->{override}) {
		my $def = $::Values->{$opt->{name}};
		$opt->{value} = $def if defined($def);
	}

	$opt->{value} = $opt->{default} if ! defined $opt->{value};
    $opt->{encoded} = encode($opt->{value}, $ESCAPE_CHARS::std);
    $opt->{value} =~ s/&#91;/\[/g if $opt->{enable_itl};

	# Action taken for various types
	my %daction = (
		checkbox    => \&box,
		combo		=> \&combo,
		date		=> \&date_widget,
		default     => \&template_sub,
		display     => \&current_label,
		links		=> \&links,
		movecombo	=> \&movecombo,
		multiple    => \&dropdown,
		noyes		=> \&noyes,
		option_format => \&option_widget,
		options     => \&show_options,
		radio       => \&box,
		select      => \&dropdown,
		show        => \&show_data,
		value       => sub { my $opt = shift; return $opt->{encoded} },
		realvalue   => sub { my $opt = shift; return $opt->{value} },
		yesno		=> \&yesno,
	);

	## The user/admin widget space
	# Optimization for large lists
	unless($Vend::UserWidget) {
		my $ref;
		$Vend::UserWidget	= ($ref = $Vend::Cfg->{CodeDef}{Widget})
							? $ref->{Routine}
							: {};
		if(my $ref = $Global::CodeDef->{Widget}{Routine}) {
			while ( my ($k, $v) = each %$ref) {
				next if $Vend::UserWidget->{$k};
				$Vend::UserWidget->{$k} = $v;
			}
		}
	}

	my $sub =  $Vend::UserWidget->{$type}
			|| $daction{$type}
			|| $daction{default};

	if($opt->{variant}) {
#::logDebug("variant='$opt->{variant}'");
		$opt->{subwidget}	=  $Vend::UserWidget->{$opt->{variant}}
							|| $daction{$opt->{variant}}
							|| $daction{default};
	}

	return $sub->($opt, $data);
}

sub parse_type {
	my $opt = shift;
	if(ref($opt) ne 'HASH') {
		warn "parse_type: needs passed hash reference";
		return $opt;
	}

	my $type = $opt->{type} = lc($opt->{type}) || 'text';
	return $type if $type =~ /^[a-z][a-z0-9]*$/;

	if($type =~ /^text/i) {
		my $cols;
		if ($type =~ /^textarea(?:_(\d+)_(\d+))?(_[a-z]+)?/i) {
			my $rows = $1 || $opt->{rows} || 4;
			$cols = $2 || $opt->{cols} || 40;
			$opt->{type} = 'textarea';
			$opt->{rows} = $rows;
			$opt->{cols} = $cols;
		}
		elsif("\L$type" =~ /^text_?(\d+)$/) {
			$opt->{cols} = $1;
			$opt->{type} = 'text';
		}
		else {
			$opt->{type} = 'text';
		}
	}
	elsif($type =~ /^date_?time(.*)/i) {
		my $extra = $1;
		$opt->{type} = 'date';
		$opt->{time} = 1;
		$opt->{ampm} = 1
			if $extra =~ /ampm/i;
		$opt->{time_adjust} = $1
			if $extra =~ /([+-]?\d+)/i;
	}
	elsif($type =~ /^hidden_text/i) {
		$opt->{type} = 'hiddentext';
	}
	elsif($type =~ /^password/i) {
		$type =~ /(\d+)/ and $opt->{cols} = $1;
		$opt->{type} = 'password';
	}
	# Ranging type, for price breaks based on quantity
	elsif ($type =~ s/^range:?(.*)//) {
		my $select = $1 || 'quantity';
		$opt->{type} = 'range';
		my $default;
		$opt->{default} = $opt->{item}{$select}
			 if $opt->{item};
	}
	elsif ($type =~ /^(radio|check)/i) {
		$opt->{type} = 'box';
		if ($type =~ /check/i) {
			$opt->{type} = 'checkbox';
		}
		else {
			$opt->{type} = 'radio';
		}

		if ($type  =~ /font(?:size)?[\s_]*(-?\d)/i ) {
			$opt->{fontsize} = $1;
		}

		if($type =~ /nbsp/i) {
			$opt->{nbsp} = 1;
		}
		elsif ($type  =~ /left[\s_]*(\d?)/i ) {
			$opt->{breakmod} = $1;
			$opt->{left} = 1;
		}
		elsif ($type  =~ /right[\s_]*(\d?)/i ) {
			$opt->{breakmod} = $1;
			$opt->{right} = 1;
		}
	}
	elsif($type =~ /^combo[ _]*(?:(\d+)(?:[ _]+(\d+))?)?/i) {
		$opt->{rows} = $opt->{rows} || $1 || 1;
		$opt->{cols} = $opt->{cols} || $2 || 16;
		$opt->{type} = 'combo';
	}
	elsif($type =~ /^reverse_combo[ _]*(?:(\d+)(?:[ _]+(\d+))?)?/i) {
		$opt->{rows} = $opt->{rows} || $1 || 1;
		$opt->{cols} = $opt->{cols} || $2 || 16;
		$opt->{type} = 'combo';
		$opt->{reverse} = 1;
	}
	elsif($type =~ /^move_combo[ _]*(?:(\d+)(?:[ _]+(\d+))?)?/i) {
		$opt->{rows} = $opt->{rows} || $1 || 1;
		$opt->{cols} = $opt->{cols} || $2 || 16;
		$opt->{type} = 'movecombo';
	}
	elsif($type =~ /multi/i) {
		$opt->{type} = 'select';
		$opt->{multiple} = 1;
		$type =~ /.*?multiple\s+(.*)/
			and $opt->{extra} ||= $1;
	}
	elsif($type =~ /^yesno/i) {
		$type =~ s/^yesno[_\s]+//;
		$opt->{type}    = 'yesno';
		$type =~ s/\W+//g;
		$opt->{variant} = $type =~ /radio/ ? 'radio' : $type;
	}
	elsif($type =~ /^noyes/i) {
		$type =~ s/^noyes[_\s]+//;
		$opt->{type}    = 'noyes';
		$type =~ s/\W+//g;
		$opt->{variant} = $type =~ /radio/ ? 'radio' : $type;
	}

	return $opt->{type};
}

1;
