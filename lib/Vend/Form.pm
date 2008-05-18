# Vend::Form - Generate Form widgets
# 
# $Id: Form.pm,v 2.76 2008-05-10 14:39:53 mheins Exp $
#
# Copyright (C) 2002-2008 Interchange Development Group
# Copyright (C) 1996-2002 Red Hat, Inc.
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

package Vend::Form;

require HTML::Entities;
*encode = \&HTML::Entities::encode_entities;
use Vend::Interpolate;
use Vend::Util;
use Vend::Tags;
use strict;
no warnings qw(uninitialized numeric);
use POSIX qw{strftime};

use vars qw/@ISA @EXPORT @EXPORT_OK $VERSION %Template %ExtraMeta/;

require Exporter;
@ISA = qw(Exporter);

$VERSION = substr(q$Revision: 2.76 $, 10);

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
		qq({DISABLED?} disabled{/DISABLED?})
		.
		qq({MULTIPLE?} multiple{/MULTIPLE?})
		.
		qq({EXTRA?} {EXTRA}{/EXTRA?})
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
		qq({DISABLED?} disabled{/DISABLED?})
		.
		qq({MAXLENGTH?} maxlength="{MAXLENGTH}"{/MAXLENGTH?})
		.
		qq({TTITLE?} title="{TTITLE}"{/TTITLE?})
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
		qq({COLS?} size="{COLS}"{/COLS?})
		.
		qq({MAXLENGTH?} maxlength="{MAXLENGTH}"{/MAXLENGTH?})
		.
		qq({EXTRA?} {EXTRA}{/EXTRA?})
		.
		qq(>{APPEND})
		,
	file =>
		qq({PREPEND}<input type="file" name="{NAME}" value="{ENCODED}")
		.
		qq({TTITLE?} title="{TTITLE}"{/TTITLE?})
		.
		qq({COLS?} size="{COLS}"{/COLS?})
		.
		qq({EXTRA?} {EXTRA}{/EXTRA?})
		.
		qq(>{APPEND})
		,
	filetext =>
		qq({PREPEND}<input type="file" name="{NAME}" value="{ENCODED}")
		.
		qq({TTITLE?} title="{TTITLE}"{/TTITLE?})
		.
		qq({COLS?} size="{COLS}"{/COLS?})
		.
		qq({EXTRA?} {EXTRA}{/EXTRA?})
		.
		qq(><br{XTRAILER}><textarea cols="{WIDTH}" rows="{HEIGHT}" name="{NAME}">{ENCODED}</textarea>{APPEND})
		,
	text =>
		qq({PREPEND}<input type="text" name="{NAME}" value="{ENCODED}")
		.
		qq({COLS?} size="{COLS}"{/COLS?})
		.
		qq({TTITLE?} title="{TTITLE}"{/TTITLE?})
		.
		qq({DISABLED?} disabled{/DISABLED?})
		.
		qq({MAXLENGTH?} maxlength="{MAXLENGTH}"{/MAXLENGTH?})
		.
		qq({TTITLE?} title="{TTITLE}"{/TTITLE?})
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
		qq(>{FILTERED?}{FILTERED}{/FILTERED?}{FILTERED:}{ENCODED}{/FILTERED:}{APPEND})
		,
	boxstd =>
		qq(<input type="{VARIANT}" name="{NAME}" value="{TVALUE}")
		.
		qq({EXTRA?} {EXTRA}{/EXTRA?})
		.
		qq({TTITLE?} title="{TTITLE}"{/TTITLE?})
		.
		qq({DISABLED?} disabled{/DISABLED?})
		.
		qq({SELECTED?} checked{/SELECTED?})
		.
		qq(>&nbsp;{TTITLE?}<span title="{TTITLE}">{/TTITLE?}{TLABEL}{TTITLE?}</span>{/TTITLE?})
		,
	boxnbsp =>
		qq(<input type="{VARIANT}" name="{NAME}" value="{TVALUE}")
		.
		qq({TTITLE?} title="{TTITLE}"{/TTITLE?})
		.
		qq({EXTRA?} {EXTRA}{/EXTRA?})
		.
		qq({DISABLED?} disabled{/DISABLED?})
		.
		qq({SELECTED?} checked{/SELECTED?})
		.
		qq(>&nbsp;{TTITLE?}<span title="{TTITLE}">{/TTITLE?}{TLABEL}{TTITLE?}</span>{/TTITLE?}&nbsp;&nbsp;)
		,
	boxlabel =>
		qq(<td{TD_LABEL?} {TD_LABEL}{/TD_LABEL?}{TTITLE?} title="{TTITLE}"{/TTITLE?}>)
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
		qq({TTITLE?} title="{TTITLE}"{/TTITLE?})
		.
		qq({DISABLED?} disabled{/DISABLED?})
		.
		qq({EXTRA?} {EXTRA}{/EXTRA?})
		.
		qq({SELECTED?} checked{/SELECTED?})
		.
		qq(>)
		.
		qq(</td>)
		,
	boxgroup =>
		qq(</tr><tr><td{TD_GROUP?} {TD_GROUP}{/TD_GROUP?} colspan="2">)
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
	1 while $body =~ s!\{([A-Z_]+)\?\}($Some){/\1\?\}! $hash->{lc $1} ? $2 : ''!eg;
	1 while $body =~ s!\{([A-Z_]+)\:\}($Some){/\1\:\}! $hash->{lc $1} ? '' : $2!eg;
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
	my $idx = shift || 0;
	return undef if ! $ary;
	my @out;
	eval {
		@out = map {$_->[$idx]} @$ary;
	};
	my $delim = Vend::Interpolate::get_joiner($opt->{delimiter}, ',');
	return join $delim, @out;
}

sub show_labels {
	return show_options($_[0], $_[1], 1);
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
	return $val || $default;
}

sub links {
	my($opt, $opts) = @_;

	$opt->{joiner} = Vend::Interpolate::get_joiner($opt->{joiner}, "<br$Vend::Xtrailer>");
	my $name = $opt->{name};
	my $default = defined $opt->{value} ? $opt->{value} : $opt->{default};

	$opt->{extra} = " $opt->{extra}" if $opt->{extra};

	my $template = $opt->{template} || <<EOF;
<a href="{URL}"{EXTRA}>{SELECTED <b>}{LABEL}{SELECTED </b>}</a>
EOF

	my $o_template = $opt->{o_template} || <<EOF;
<b>{TVALUE}</b>
EOF

	my $href = $opt->{href} || $Global::Variable->{MV_PAGE};
	$opt->{form} = "mv_action=return" unless $opt->{form};

	my $no_encode = $opt->{pre_filter} eq 'decode_entities' ? 1 : 0;

	my @out;
	for(@$opts) {
#warn "iterating links opt $_ = " . uneval_it($_) . "\n";
		my $attr = { extra => $opt->{extra}};
		
		s/\*$// and $attr->{selected} = 1;

		($attr->{value},$attr->{label}) = @$_;
		encode($attr->{label}, $ESCAPE_CHARS::std) unless $no_encode;
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

		$attr->{label} =~ s/\s/&nbsp;/g if $opt->{nbsp};

		$attr->{url} = Vend::Interpolate::tag_area(
						$href,
						undef,
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
		$t[3] = 1;
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

	my $sel_extra;
	my $opt_extra;
	for(qw/ class style extra /) {
		my $stag = "select_$_";
		my $otag = "option_$_";
		my $selapp;
		my $optapp;

		if($_ eq 'extra') {
			$selapp = " $opt->{$stag}";
			$optapp = " $opt->{$otag}";
		}
		else {
			$selapp = qq{ $_="$opt->{$stag}"};
			$optapp = qq{ $_="$opt->{$otag}"};
		}
		$sel_extra .= $opt->{$stag} ? $selapp : '';
		$opt_extra .= $opt->{$otag} ? $optapp : '';
	}

	my @t = localtime($now || time);
	my $sel = 0;
	my $out = qq{<select name="$name"$sel_extra>};
	my $o;
	if ($opt->{blank}) {
		$out .= qq{<option value="0"$opt_extra>------</option>};
	} elsif (not $val) {
		# use current time with possible adjustments as default value
		$t[2]++ if $t[2] < 23;
		$val = POSIX::strftime("%Y%m%d%H00", @t);
	}
	for(@Months) {
		$o = qq{<option value="$_->[0]"$opt_extra>} . errmsg($_->[1]) . '</option>';
		($out .= $o, next) unless ! $sel and $val;
		$o =~ s/>/ SELECTED>/ && $sel++
			if substr($val, 4, 2) eq $_->[0];
		$out .= $o;
	}
	$sel = 0;
	$out .= qq{</select>};
	$out .= qq{<input type="hidden" name="$name" value="/">};
	$out .= qq{<select name="$name"$sel_extra>};
	if ($opt->{blank}) {
		$out .= qq{<option value="0"$opt_extra>--</option>};
	}
	for(@Days) {
		$o = qq{<option value="$_->[0]"$opt_extra>$_->[1]} . '</option>';
		($out .= $o, next) unless ! $sel and $val;
		$o =~ s/>/ SELECTED>/ && $sel++
			if substr($val, 6, 2) eq $_->[0];
		$out .= $o;
	}
	$sel = 0;
	$out .= qq{</select>};
	$out .= qq{<input type="hidden" name="$name" value="/">};
	$out .= qq{<select name="$name"$sel_extra>};
	if(my $by = $opt->{year_begin} || $::Variable->{UI_DATE_BEGIN}) {
		my $cy = $t[5] + 1900;
		my $ey = $opt->{year_end}  || $::Variable->{UI_DATE_END} || ($cy + 10);
		if($by < 100) {
			$by = $cy - abs($by);
		}
		if($ey < 100) {
			$ey += $cy;
		}
		@Years = $by <= $ey ? ($by .. $ey) : reverse ($ey .. $by);
	}
	if ($opt->{blank}) {
		$out .= qq{<option value="0000"$opt_extra>----</option>};
	}
	for(@Years) {
		$o = qq{<option$opt_extra>$_} . '</option>';
		($out .= $o, next) unless ! $sel and $val;
		$o =~ s/>/ SELECTED>/ && $sel++
			if substr($val, 0, 4) eq $_;
		$out .= $o;
	}
	$out .= qq{</select>};
	return $out unless $opt->{time};

	$val =~ s/^(\d{8})//;
	# If the date is blank (0000-00-00), treat time of 00:00 as blank,
	# not midnight, in the option selection below
	my $blank_time = ($opt->{blank} and $1 !~ /[1-9]/);
	$val =~ s/\D+//g;
	$val = round_to_fifteen($val);
	$out .= qq{<input type="hidden" name="$name" value=":">};
	$out .= qq{<select name="$name"$sel_extra>};
	if ($opt->{blank}) {
		$out .= qq{<option value="0"$opt_extra>--:--</option>};
	}
	
	my $ampm = defined $opt->{ampm} ? $opt->{ampm} : 1;
	my $mod = '';
	undef $sel;
	my %special = qw/ 0 midnight 12 noon /;
	
	my @min;

	$opt->{minutes} ||= '';

	if($opt->{minutes} =~ /half/i) {
		@min = (0,30);
	}
	elsif($opt->{minutes} =~ /hourly/i) {
		@min = (0);
	}
	elsif($opt->{minutes} =~ /ten/i) {
		@min = (0,10,20,30,40,50);
	}
	elsif($opt->{minutes} =~ /[\0,]/) {
		@min = grep /^\d+$/ && $_ <= 59, split /[\0,\s]+/, $opt->{minutes};
	}
	else {
		@min = (0,15,30,45);
	}

	$opt->{start_hour} ||= 0;
	for(qw/start_hour end_hour/) {
		$opt->{$_} = int(abs($opt->{$_}));
		if($opt->{$_} > 23) {
			$opt->{$_} = 0;
		}
	}
	$opt->{start_hour}	||= 0;
	$opt->{end_hour}	||= 23;

	for my $hr ( $opt->{start_hour} .. $opt->{end_hour} ) {
		next if defined $opt->{start_hour} and $hr < $opt->{start_hour};
		next if defined $opt->{end_hour} and $hr > $opt->{end_hour};
		for my $min ( @min ) {
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
			$o = sprintf qq{<option value="%s"$opt_extra>%s}, $time, $disp_hour;
			($out .= $o, next) unless ! $sel and $val;
#::logDebug("prospect=$time actual=$val");
			$o =~ s/>/ SELECTED>/ && $sel++
				if ! $blank_time and $val eq $time;
			$out .= $o;
		}
	}
	$out .= "</select>";
	return $out;
}

sub option_widget_box {
	my ($name, $val, $lab, $default, $width) = @_;
	my $half = int($width / 2);
	my $sel = $default ? ' SELECTED' : '';
	$val =~ s/"/&quot;/g;
	$lab =~ s/"/&quot;/g;
	$width = 10 if ! $width;
	return qq{<tr><td><small><input type="text" name="$name" value="$val" size="$half"></small></td><td><small><input type="text" name="$name" value="$lab" size="$width"></small></td><td><small><select name="$name"><option value="0">no<option value="1"$sel>default*</select></small></td></tr>};
}

sub option_widget {
	my($opt) = @_;
	my($name, $val) = ($opt->{name}, $opt->{value});
	
	my $width = $opt->{width} || 16;
	$opt->{filter} = 'option_format'
		unless length($opt->{filter});
	$val = Vend::Interpolate::filter_value($opt->{filter}, $val);
	my @opts = split /\s*,\s*/, $val;

	my $out = qq{<table cellpadding="0" cellspacing="0"><tr><th><small>};
	$out .= errmsg('Value');
	$out .= qq{</small></th><th align="left" colspan="2"><small>};
	$out .= errmsg('Label');
	$out .= qq{</small></th></tr>};

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
	$out .= "</table>";
}


sub movecombo {
	my ($opt, $opts) = @_;
	my $name = $opt->{name};
	$opt->{name} = "X$name";
	my $usenl = $opt->{rows} > 1 ? 1 : 0;
	my $only = $opt->{replace} ? 1 : 0;
	$opt->{extra} .= qq{ onChange="addItem(this.form['X$name'],this.form['$name'],$usenl,$only)"}
            unless $opt->{extra} =~ m/\bonchange\s*=/i;

	$opt->{rows} = $opt->{height} unless length($opt->{rows});
	$opt->{cols} = $opt->{width} unless length($opt->{cols});

	my $tbox = '';
	my $out = dropdown($opt, $opts);

	my $template = $opt->{o_template} || '';
	if(! $template) {
		if($opt->{rows} > 1) {
			$template .= q(<textarea rows="{ROWS|4}" wrap="{WRAP|virtual}");
			$template .= q( cols="{COLS|20}" name="{NAME}">{ENCODED}</textarea>);
		}
		else {
			$template .= qq(<input type="text" size="{COLS||40}");
			$template .= qq( name="{NAME}" value="{ENCODED}">);
		}
	}
	$opt->{name} = $name;
	$tbox = attr_list($template, $opt);

	return $opt->{reverse} ? $tbox . $out : $out . $tbox;
}

sub combo {
	my ($opt, $opts) = @_;
	my $addl;
	if($opt->{textarea}) {
		my $template = $opt->{o_template};
		if(! $template) {
			$template = "<br$Vend::Xtrailer>";
			if(! $opt->{rows} or $opt->{rows} > 1) {
				$template .= q(<textarea rows="{ROWS|2}" wrap="{WRAP|virtual}");
				$template .= q( cols="{COLS|60}" name="{NAME}">);
				$template .= '{ENCODED}'
					unless $opt->{conditional_text} and length($opt->{value}) < 3;
				$template .= q(</textarea>);
			}
			else {
				$template .= qq(<input type="text" size="{COLS|40}");
				$template .= qq( name="{NAME}" value=");
				$template .= '{ENCODED}'
					unless $opt->{conditional_text} and length($opt->{value}) < 3;
				$template .= qq(">);
			}
		}
		$addl = attr_list($template, $opt);
	}
	else {
		$addl = qq|<input type="text" name="$opt->{name}"|;
		$addl   .= qq| size="$opt->{cols}" value="">|;
	}
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
#::logDebug("template for selecthead: $Template{selecthead}");
#::logDebug("opt is " . ::uneval($opt));
	my $run = attr_list($Template{selecthead}, $opt);
#::logDebug("run is now: $run");
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
	my $no_encode = $opt->{pre_filter} eq 'decode_entities' ? 1 : 0;
	
	for(@$opts) {
		my ($value, $label, $help) = @$_;
		encode($label, $ESCAPE_CHARS::std) unless $no_encode;
		encode($help, $ESCAPE_CHARS::std) if $help;
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

		$select = '' if defined $default;

		my $extra = '';
		my $attr = {};
		if(my $p = $price->{$value}) {
			$attr->{negative} = $p < 0 ? 1 : 0;
			$attr->{price_noformat} = $p;
			$attr->{absolute} = currency(abs($p), undef, 1);
			$attr->{price} = $extra = currency($p, undef, 1);
			$extra = " ($extra)";
		}

		my $vvalue = $value;
		encode($vvalue, $ESCAPE_CHARS::std);
		$run .= qq| value="$vvalue"|;
		$run .= qq| title="$help"| if $help;
		if (length($default)) {
			$regex	= qr/$re_b\Q$value\E$re_e/;
			$default =~ $regex and $select = 1;
		} elsif (defined($default) && length($value) == 0) {
			$select = 1;
		}
		$run .= ' SELECTED' if $select;
		$run .= '>';
		if($opt->{option_template}) {
			$attr->{label} = $label || $value;
			$attr->{value} = $value;
			$run .= attr_list($opt->{option_template}, $attr);
		}
		elsif($label) {
			$run .= $limit->($label);
			$run .= $extra;
		}
		else {
			$run .= $limit->($value);
			$run .= $extra;
		}
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
	my $yes = defined $opt->{yes_value} ? $opt->{yes_value} : 1;
	my $no  = defined $opt->{no_value} ? $opt->{no_value} : '';
	my $yes_title = defined $opt->{yes_title} ? $opt->{yes_title} : errmsg('Yes');
	my $no_title  = defined $opt->{no_title} ? $opt->{no_title} : errmsg('No');
	my @opts;
	my $routine = $opt->{subwidget} || \&dropdown;
	if($opt->{variant} eq 'checkbox') {
		@opts = [$yes, ' '];
	}
	else {
		@opts = (
					[$no, $no_title],
					[$yes, $yes_title],
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
		$header = '<table>';
		$footer = '</table>';
		$template = '<tr>' unless $inc;
		$template .= $Template{boxvalue};
		$template .= $Template{boxlabel};
		$template .= '</tr>' unless $inc;
		$o_template = $Template{boxgroup};
	}
	elsif ($opt->{right}) {
		$header = '<table>';
		$footer = '</table>';
		$template = '<tr>' unless $inc;
		$template .= $Template{boxlabel};
		$template .= $Template{boxvalue};
		$template .= '</tr>' unless $inc;
		$o_template = $Template{boxgroup};
	}
	else {
		$template = $Template{boxstd};
	}
	$o_template ||= "<br$Vend::Xtrailer><b>{TVALUE}</b><br$Vend::Xtrailer>";

	my $run = $header;

	my $price = $opt->{price} || {};

	my $i = 0;
	my $default = $opt->{value};
	my $no_encode = $opt->{pre_filter} eq 'decode_entities' ? 1 : 0;

	for(@$opts) {
		my($value,$label,$help) = @$_;
		encode($label, $ESCAPE_CHARS::std) unless $no_encode;
		encode($help, $ESCAPE_CHARS::std) if $help;
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

		$run .= '<tr>' if $inc && ! ($i % $inc);
		$i++;

		undef $opt->{selected};
		$label =~ s/\*$//
			and $opt->{selected} = 1;
		$opt->{selected} = '' if defined $opt->{value};

		my $extra;
		my $attr = { label => $label, value => $value };
		if(my $p = $price->{$value}) {
			$attr->{negative} = $p < 0 ? 1 : 0;
			$attr->{price_noformat} = $p;
			$attr->{absolute} = currency(abs($p), undef, 1);
			$attr->{price} = $extra = currency($p, undef, 1);
			$label .= "&nbsp;($attr->{price})";
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

		if($opt->{option_template}) {
			$opt->{tlabel} = attr_list($opt->{option_template}, $attr);
			$opt->{tlabel} =~ s/ /&nbsp;/g if $xlt;
		}
		else {
			$label =~ s/ /&nbsp;/g if $xlt;
			$opt->{tlabel} = $label;
		}

		$opt->{ttitle} = $help;

		$run .= attr_list($template, $opt);
		$run .= '</tr>' if $inc && ! ($i % $inc);
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
		$passed = Vend::Interpolate::filter_value($passed, 'option_format');
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
	}
	else {
		die "bad data type to options_to_array";
	}

	if ($opt->{applylocale}) {
		for (@out) {
			$_->[1] = errmsg($_->[1]);
		}
	}

	return \@out;
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

	if($opt->{js_check}) {
		my @checks = grep /\w/, split /[\s,\0]+/, $opt->{js_check};
		for(@checks) {
			if(my $sub = Vend::Util::codedef_routine('JavaScriptCheck', $_)) {
				$sub->($opt);
			}
			else {
				::logError('Unknown %s: %s', 'JavaScriptCheck', $_);
			}
		}
	}

	# This handles the embedded attribute information in certain types,
	# for example: 
	# 
	#	text_60       is the same as type => 'text', width => '60'
	#   datetime_ampm is the same as type => 'datetime', ampm => 1

	# Warning -- this sets $opt->{type} and has possible side-effects
	#            in $opt
	my $type = parse_type($opt);

#::logDebug("name=$opt->{name} type=$type");

	my $look;

	if($look = $opt->{lookup_query}) {
#::logDebug("lookup_query called, opt=" . uneval($opt));
		my $tab = $opt->{db} || $opt->{table} || $Vend::Cfg->{ProductFiles}[0];
		my $db = Vend::Data::database_exists_ref($tab);
		my @looks = split /\s*;\s*/, $look;
		$data = [];
		for my $l (@looks) {
			next unless $db;
			next unless $l =~ /^\s*select\s+/i;
			my $qr = $db->query($l);
			ref($qr) eq 'ARRAY' and push @$data, @$qr;
		}
		if($data->[0] and @{$data->[0]} > 2) {
			my $j = $opt->{label_joiner} || '-';
			for(@$data) {
				$_->[1] = join $j, splice @$_, 1;
			}
		}
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
	elsif(! $opt->{already_got_data} and $opt->{column} and $opt->{table} ) {
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

		unless($opt->{lookup_merge}) {
			unshift @$data, @$ary if $ary;
		}
		elsif($ary) {
			my %existing;
			for(@$ary) {
				$existing{$_->[0]}++;
			}
			for(@$data) {
				next if $existing{$_->[0]};
				push @$ary, $_;
			}
			$data = $ary;
		}
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

	if(length($opt->{blank_default}) and ! length($opt->{value}) ) {
		$opt->{value} = $opt->{blank_default};
	}

    $opt->{encoded} = encode($opt->{value}, $ESCAPE_CHARS::std);
	if($opt->{display_filter}) {
		my $newv = Vend::Interpolate::filter_value(
								$opt->{display_filter},
								$opt->{value},
							);
		$opt->{filtered} = encode($newv, $ESCAPE_CHARS::std);
	}
    $opt->{value} =~ s/&#91;/\[/g if $opt->{enable_itl};

	if($opt->{class}) {
		if($opt->{extra}) {
			$opt->{extra} =~ s{(^|\s+)class=(["'])?[^\s'"]+\2}{$1};
			$opt->{extra} =~ s/\s+$//;
			$opt->{extra} .= qq{ class="$opt->{class}"};
		}
		else {
			$opt->{extra} = qq{class="$opt->{class}"};
		}
	}

	# Optimization for large lists, we cache the widgets
	$Vend::UserWidget ||= Vend::Config::map_widgets();
	$Vend::UserWidgetDefault ||= Vend::Config::map_widget_defaults();

	my $sub =  $Vend::UserWidget->{$type};
	if(! $sub and $Global::AccumulateCode) {
		$sub = Vend::Config::code_from_file('Widget', $type)
			and $Vend::UserWidget->{$type} = $sub;
	}

	# Last in case "default" widget is removed
	$sub ||= $Vend::UserWidget->{default} || \&template_sub;

	if(my $attr = $Vend::UserWidgetDefault->{$type}) {
		while (my ($k, $v) = each %$attr) {
			next if defined $opt->{$k};
			$opt->{$k} = $v;
		}
	}

	if($opt->{variant}) {
#::logDebug("variant='$opt->{variant}'");
		$opt->{subwidget}	=  $Vend::UserWidget->{$opt->{variant}}
							||  $Vend::UserWidget->{default};
	}

	if(my $c = $opt->{check}) {
		$c = "$opt->{name}=$c" unless $c =~ /=/;
		HTML::Entities::encode($c);
		$opt->{append} .= qq{<input type="hidden" name="mv_individual_profile" value="$c">};
	}

	if($opt->{js}) {
		$opt->{extra} ||= '';
		$opt->{extra} .= " $opt->{js}";
		$opt->{extra} =~ s/^\s+//;
	}
	return $sub->($opt, $data);
}

sub parse_type {
	my $opt = shift;
	if(ref($opt) ne 'HASH') {
		warn "parse_type: needs passed hash reference";
		return $opt;
	}

	my %alias = (qw/ datetime date_time /);
	my $type = $opt->{type} = lc($opt->{type}) || 'text';
	$type = $alias{$type} if $alias{$type};
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
	elsif($type =~ /^(date|time)(.*)/i) {
		$opt->{type} = lc $1;
		my $extra = $2;
		if ($extra) {
			$opt->{time} = 1 if $extra =~ /time/i;
			$opt->{ampm} = 1 if $extra =~ /ampm/i;
			$opt->{blank} = 1 if $extra =~ /blank/i;
			($extra =~ /\(\s*(\s*\d+\s*(,\s*\d+\s*)+)\s*\)/i
					and $opt->{minutes} = $1)
			  or
			($extra =~ /half/i and $opt->{minutes} = 'half_hourly') 
			  or 
			($extra =~ /hourly/i and $opt->{minutes} = 'hourly')
			  or 
			($extra =~ /tens/i and $opt->{minutes} = 'tens')
			;
			if($extra =~ s/(\d+)-(\d+)//) {
				$opt->{start_hour} = $1;
				$opt->{end_hour} = $2;
			}
			$opt->{time_adjust} = $1
				if $extra =~ /([+-]?\d+)/i;
		}
#::logDebug("minutes=$opt->{minutes}");
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
		elsif ($type  =~ /left[\s_]*(\d*)/i ) {
			$opt->{breakmod} = $1;
			$opt->{left} = 1;
		}
		elsif ($type  =~ /right[\s_]*(\d*)/i ) {
			$opt->{breakmod} = $1;
			$opt->{right} = 1;
		}
	}
	elsif($type =~ /^combo[ _]*(?:(\d+)(?:[ _]+(\d+))?)?/i) {
		$opt->{rows} = $opt->{rows} || $1 || 1;
		$opt->{cols} = $opt->{cols} || $2 || 16;
		$opt->{type} = 'combo';
	}
	elsif($type =~ /^fillin_combo[ _]*(?:(\d+)(?:[ _]+(\d+))?)?/i) {
		$opt->{rows} ||= $1;
		$opt->{cols} ||= $2;
		$opt->{type} = 'combo';
		$opt->{textarea} = 1;
		$opt->{reverse} = 1;
		$opt->{conditional_text} = 1;
	}
	elsif($type =~ /^reverse_combo[ _]*(?:(\d+)(?:[ _]+(\d+))?)?/i) {
		$opt->{rows} = $opt->{rows} || $1 || 1;
		$opt->{cols} = $opt->{cols} || $2 || 16;
		$opt->{type} = 'combo';
		$opt->{reverse} = 1;
	}
	elsif($type =~ /^links_*nbsp/i) {
		$opt->{nbsp} = 1;
		$opt->{type} = 'links';
	}
	elsif($type =~ /^move_*combo[ _]*(?:(\d+)(?:[ _]+(\d+))?)?/i) {
		$opt->{rows} = $opt->{rows} || $opt->{height} || $1 || 1;
		$opt->{cols} = $opt->{cols} || $opt->{width} || $2 || 16;
		$opt->{type} = 'movecombo';
		$opt->{replace} = 1 if $type =~ /replace/;
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
