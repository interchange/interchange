# Vend::Form - Generate Form widgets
# 
# $Id: Form.pm,v 2.1 2002-01-31 14:58:41 mheins Exp $
#
# Copyright (C) 1996-2001 Red Hat, Inc. <interchange@redhat.com>
#
# This program was originally based on Vend 0.2 and 0.3
# Copyright 1995 by Andrew M. Wilcox <awilcox@world.std.com>
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
use Data::Dumper;
use Vend::Interpolate;
use Vend::Util;
use Vend::Tags;
use strict;

use vars qw/@ISA @EXPORT @EXPORT_OK $VERSION %Template/;

require Exporter;
@ISA = qw(Exporter);

$VERSION = substr(q$Revision: 2.1 $, 10);

@EXPORT = qw (
	display
);

=head1 NAME

Vend::Form -- Interchange form element routines

=head1 SYNOPSIS

(no external use)

=head1 DESCRIPTION

TBA.

=cut

use Safe;

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
		qq(>{VALUE}{APPEND})
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

my $Safe;

sub string_to_ref {
	my ($string) = @_;
	if(! $Vend::Cfg->{ExtraSecure} and $MVSAFE::Safe) {
		return eval $string;
	}
	elsif ($MVSAFE::Safe) {
		die errmsg("not allowed to eval in Safe mode.");
	}
	my $safe = $Safe ||= new Safe;
	return $safe->reval($string);
}

sub get_option_hash {
	my $string = shift;
	my $merge = shift;
	if (ref $string) {
		return $string unless ref $merge;
		for(keys %{$merge}) {
			$string->{$_} = $merge->{$_}
				unless defined $string->{$_};
		}
		return $string;
	}
	return {} unless $string =~ /\S/;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	if($string =~ /^{/ and $string =~ /}/) {
		return string_to_ref($string);
	}

	my @opts;
	unless ($string =~ /,/) {
		@opts = grep $_ ne "=", Text::ParseWords::shellwords($string);
		for(@opts) {
			s/^(\w+)=(["'])(.*)\2$/$1$3/;
		}
	}
	else {
		@opts = split /\s*,\s*/, $string;
	}

	my %hash;
	for(@opts) {
		my ($k, $v) = split /[\s=]+/, $_, 2;
		$hash{$k} = $v;
	}
	if($merge) {
		return \%hash unless ref $merge;
		for(keys %$merge) {
			$hash{$_} = $merge->{$_}
				unless defined $hash{$_};
		}
	}
	return \%hash;
}

sub attr_list {
	my ($body, $hash) = @_;
	return $body unless ref($hash) eq 'HASH';
	$body =~ s!\{($Codere)\}!$hash->{lc $1}!g;
	$body =~ s!\{($Codere)\|($Some)\}!$hash->{lc $1} || $2!eg;
	$body =~ s!\{($Codere)\s+($Some)\}! $hash->{lc $1} ? $2 : ''!eg;
	$body =~ s!\{($Codere)\?\}($Some){/\1\?\}! $hash->{lc $1} ? $2 : ''!eg;
	$body =~ s!\{($Codere)\:\}($Some){/\1\:\}! $hash->{lc $1} ? '' : $2!eg;
	return $body;
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

sub movecombo {
	my ($opt, $opts) = @_;
	my $name = $opt->{name};
	$opt->{name} = "X$name";
	my $ejs = ",1" if $opt->{rows} > 1;
	$opt->{extra} .= qq{ onChange="addItem(this.form['X$name'],this.form['$name']$ejs)"}
            unless $opt->{extra};
	my $out = dropdown($opt, $opts);
	if($opt->{rows} > 1) {
		$out .= qq(<TEXTAREA ROWS="$opt->{rows}");
		$out .= qq( WRAP="virtual" COLS="$opt->{cols}");
		$out .= qq( NAME="$name">$opt->{value}</TEXTAREA>);
	}
	return $out;
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
::logDebug("called select opt=" . ::uneval($opt) . "\nopts=" . ::uneval($opts));

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
		$re_b = '(?:\0|^)';
		$re_e = '(?:\0|$)';
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
		if($value =~ /^\s*\~\~(.*)\~\~\s*$/) {
			my $label = $1;
			$label =~ s/"/&quot;/g;
			if($optgroup_one++) {
				$run .= "</optgroup>";
			}
			$run .= qq{<optgroup label="$label">};
			next;
		}
		$run .= '<option';
		$select = '';
		s/\*$// and $select = 1;
		if ($default) {
			$select = '';
		}

		my $extra;
		if($price->{$value}) {
			$extra = currency($price->{$value}, undef, 1);
			$extra = " ($extra)";
		}

		my $vvalue = $value;
		$vvalue =~ s/"/&quot;/;
		$run .= qq| value="$vvalue"|;
		if ($default) {
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

		$opt->{tvalue} = HTML::Entities::encode($value);

		$label =~ s/ /&nbsp;/g if $xlt;
		$opt->{tlabel} = $label;

		$run .= attr_list($template, $opt);
		$run .= '</TR>' if $inc && ! ($i % $inc);
	}
	$run .= $footer;
}

sub produce_range {
	my ($ary, $max) = @_;
	$max = $Vend::Cfg->{Limit}{option_list} if ! $max;
	my @do;
	for (my $i = 0; $i < scalar(@$ary); $i++) {
		$ary->[$i] =~ /^\s* ([a-zA-Z0-9]+) \s* \.\.+ \s* ([a-zA-Z0-9]+) \s* $/x
			or next;
		my @new = $1 .. $2;
		if(@new > $max) {
			::logError(
				"Refuse to add %d options to option list via range, max %d.",
				scalar(@new),
				$max,
				);
			next;
		}
		push @do, $i, \@new;
	}
	my $idx;
	my $new;
	while($new = pop(@do)) {
		my $idx = pop(@do);
		splice @$ary, $idx, 1, @$new;
	}
	return;
}

sub scalar_to_array {
	my ($passed, $opt) = @_;
	return $passed if ref($passed) eq 'ARRAY'
		and (
			! scalar @$passed
				or
			ref($passed->[0]) eq 'ARRAY'
		);

	$opt ||= {};
	my @out;

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
			push @out, [split /\s*=\s*/, $_, 2];
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
		die "bad data type to scalar_to_array";
	}
}

sub display {
	my($opt, $item) = @_;

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
		$opt->{value} = $opt->{default} || $opt->{override};
	}

	$opt->{default} = $opt->{value}    if defined $opt->{value};

	my $ishash;
	if(ref ($item) eq 'HASH') {
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
	$opt->{field}     ||= $opt->{attribute};
	$opt->{prepend}   = ''  unless defined $opt->{prepend};
	$opt->{append}    = ''  unless defined $opt->{append};
	$opt->{delimiter} = ',' unless length($opt->{delimiter});
	$opt->{cols}      ||= $opt->{width} || $opt->{size};

	my $data;
	

	if($opt->{passed}) {
		$data = scalar_to_array($opt->{passed}, $opt);
	}
	elsif($opt->{column} and $opt->{table}) {
		my $key = $opt->{outboard} || $item->{code} || $opt->{code};
		$opt->{passed} = $Tag->data($opt->{table}, $opt->{column}, $key);
		$data = scalar_to_array($opt->{passed}, $opt);
	}
	elsif(! $Global::VendRoot) {
		# Not in Interchange
	}
	elsif($opt->{lookup_query}) {
		my $tab = $opt->{table} || $Vend::Cfg->{ProductFiles}[0];
		my $db = Vend::Data::database_exists_ref($tab);
		$data = $db->query($opt->{lookup_query})
			if $db;
	}
	elsif(my $look = $opt->{lookup}) {
		## Replace with Vend::Specific stuff
		my $tab = $opt->{table} || $Vend::Cfg->{ProductFiles}[0];
		my @f = split /\s*,\s*/, $look;
		my $order = $opt->{sort} || $f[1] || $f[0];
		LOOK: {
			last LOOK unless $tab;
			my $db = Vend::Data::database_exists_ref($tab)
				or last LOOK;
			my $q = qq{SELECT DISTINCT $look FROM $tab ORDER BY $order};
			eval {
				$data = $db->query($q);
			};
		}
	}

	# This handles the embedded attribute information in certain types,
	# for example: 
	# 
	#	text_60       is the same as type => 'text', width => '60'
	#   datetime_ampm is the same as type => 'datetime', ampm => 1

#::logDebug("type=$opt->{type}");
	parse_type($opt);
#::logDebug("type=$opt->{type} after parse_type(opt)");

	# Action taken for various types
	my %daction = (
		value       => \&processed_value,
		display     => \&current_label,
		show        => sub { return $data },
		select      => \&dropdown,
		default     => \&template_sub,
		radio       => \&box,
		checkbox    => \&box,
		links		=> \&links,
		movecombo	=> \&movecombo,
		combo		=> \&combo,
	);

## Some legacy stuff
	if($ishash) {
		my $adder;
		$adder = $item->{mv_ip} if	defined $item->{mv_ip}
								and $opt->{item} || ! $opt->{name};
		$opt->{name} = $opt->{attribute} unless $opt->{name};
		$opt->{name} .= $adder if defined $adder;
#::logDebug("tag_accessories: name=$name");
	}
	else {
		$opt->{name} = "mv_order_$opt->{attribute}" unless $opt->{name};
	}

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
    $opt->{encoded} = HTML::Entities::encode($opt->{value});

	my $sub = $daction{$opt->{type}} || $daction{default};
	return $sub->($opt, $data);
}

sub parse_type {
	my $opt = shift;
	if(ref($opt) ne 'HASH') {
		warn "parse_type: needs passed hash reference";
		return $opt;
	}

	return if $opt->{type} =~ /^[a-z]+$/;
	$opt->{type} = lc $opt->{type} || 'text';

	my $type = $opt->{type};
	return if $type =~ /^[a-z]+$/;

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
			$opt->{nbsp};
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
}

sub test {
	my $out = qq{<form action="/">\n};
	for(qw/
		text_60
		select
		links
		multi
		combo
	/)
	{
		$out .= display({
			name   => 'SelectName',
			value  => 'Test',
			type   => $_,
			left   => 1,
			breakmod   => 2,
			passed => '
				=--select it--,
				~~Valid~~,
				Test=Testing,
				Testing1=Testing again,
				Testing2=Testing again and again,
				Testing3=Testing again redux,
				Testing4=Testing redux redux,
				~~Invalid~~,
				Not=Not,
				Not1=Not again,
				Not2=Not again and again,
				',
		} );
	}
	$out .= "</form>\n";
	return $out;
}

1;
