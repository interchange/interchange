# Vend::Ship - Interchange shipping code
# 
# $Id: Ship.pm,v 2.28 2008-04-11 08:44:20 danb Exp $
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

package Vend::Ship;

require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(
				do_error
		);

use Vend::Util;
use Vend::Interpolate;
use Vend::Data;
use strict;
no warnings qw(uninitialized numeric);

use constant MAX_SHIP_ITERATIONS => 100;
use constant MODE  => 0;
use constant DESC  => 1;
use constant CRIT  => 2;
use constant MIN   => 3;
use constant MAX   => 4;
use constant COST  => 5;
use constant QUERY => 6;
use constant OPT   => 7;

my %Ship_remap = ( qw/
							CRITERION   CRIT
							CRITERIA    CRIT
							MAXIMUM     MAX
							MINIMUM     MIN
							PRICE       COST
							QUALIFIER   QUAL
							CODE        PERL
							SUB         PERL
							UPS_TYPE    TABLE
							DESCRIPTION DESC
							ZIP         GEO 
							LOOKUP      TABLE
							DEFAULT_ZIP DEFAULT_GEO 
							SQL         QUERY
					/);

sub do_error {
	my $msg = errmsg(@_);
	Vend::Tags->error({ name => 'shipping', set => $msg });
	unless ($::Limit->{no_ship_message}) {
		$Vend::Session->{ship_message} ||= '';
		$Vend::Session->{ship_message} .= $msg . ($msg =~ / $/ ? '' : ' ');
	}
	return undef;
}

sub make_three {
	my ($zone, $len) = @_;
	$len = 3 if ! $len;
	while ( length($zone) < $len ) {
		$zone = "0$zone";
	}
	return $zone;
}

use vars qw/%Ship_handler/;

%Ship_handler = (
		TYPE =>
					sub { 
							my ($v,$k) = @_;
							$$v =~ s/^(.).*/$1/;
							$$v = lc $$v;
							$$k = 'COST';
					}
		,
);

sub process_new_beginning {
	my ($shipping, $record, $line) = @_;
	my @new;
	my $first;

	$line ||= '';
	if($line =~ /^[^\s:]+\t/) {
		@new = split /\t/, $line;
	}
	elsif($line =~ /^(\w+)\s*:\s*(.*)/s) {
		@new = ($1, $2, '', 0, 99999999, 0);
		$first = 1;
	}

	$Vend::Cfg->{Shipping_desc}{$new[MODE]} ||= $new[DESC] if @new;

	if (@$record) {
		my $old_mode = $record->[MODE];
		if(! ref($record->[OPT]) ) {
			$record->[OPT] = string_to_ref($record->[OPT]);
		}

		if ($old_mode and ! $Vend::Cfg->{Shipping_hash}{$old_mode}) {
			$record->[OPT]{description} ||= $Vend::Cfg->{Shipping_desc}{$old_mode};
			$Vend::Cfg->{Shipping_hash}{$old_mode} = $record->[OPT];
		}
		else {
			$record->[OPT]{description} ||= $record->[DESC];
		}

		push @$shipping, [ @$record ];
	}

	@$record = @new;

	return $first;
}

sub read_shipping {
	my ($file, $opt) = @_;
	$opt = {} unless $opt;
    my($code, $desc, $min, $criterion, $max, $cost, $mode);

	my $loc;
	$loc = $Vend::Cfg->{Shipping_repository}{default}
			if $Vend::Cfg->{Shipping_repository};

	$loc ||= {};

	my $base_dir = $loc->{directory} || $loc->{dir} || $Vend::Cfg->{ProductDir};

	my @files;
	if ($file) {
		push @files, $file;
	}
	elsif($opt->{add} or $Vend::Cfg->{Variable}{MV_SHIPPING}) {
		$file = "$Vend::Cfg->{ScratchDir}/shipping.asc";
		Vend::Util::writefile(">$file", $opt->{add} || $Vend::Cfg->{Variable}{MV_SHIPPING});
		push @files, $file;
	}
	else {
		my %found;
		if($Vend::Cfg->{Shipping}) {
			my $repos = $Vend::Cfg->{Shipping_repository};
			for(keys %$repos) {
				next unless $file = $repos->{$_}{config_file};
				$file = Vend::Util::catfile($base_dir, $file)
					unless $file =~ m{/};
#::logDebug("found shipping file=$file");
				$found{$file} = 1;
				push @files, $file;
			}
		}
		$file = $Vend::Cfg->{Special}{'shipping.asc'}
				|| Vend::Util::catfile($base_dir, 'shipping.asc');

		if(-f $file and !$found{$file}) {
			push @files, $file;
		}
	}

#::logDebug("shipping files=" . ::uneval(\@files));
	my @flines;
	for(@files) {
		push @flines, split /\n/, readfile($_);
#::logDebug("shipping lines=" . scalar(@flines));
	}

	if ($Vend::Cfg->{CustomShipping} =~ /^select\s+/i) {
		($Vend::Cfg->{SQL_shipping} = 1, return)
			if $Global::Foreground;
		my $ary;
		my $query = interpolate_html($Vend::Cfg->{CustomShipping});
		eval {
			$ary = query($query, { wantarray => 1} );
		};
		if(! ref $ary) {
			logError("Could not make shipping query %s: %s" ,
						$Vend::Cfg->{CustomShipping},
						$@);
			return undef;
		}
		my $out;
		for(@$ary) {
			push @flines, join "\t", @$_;
		}
	}
	
	$Vend::Cfg->{Shipping_desc} ||= {};

	my %seen;
	my $append = '00000';
	my @line;
	my $prev = '';
	my $waiting;
	my @shipping;
	my $first;
    for(@flines) {

		# Strip CR, we hope
		s/\s+$//;

		# Handle continued lines
		if(s/\\$//) {
			$prev .= $_;
			next;
		}
		elsif($waiting) {
			if($_ eq $waiting) {
				undef $waiting;
				$_ = $prev;
				$prev = '';
				s/\s+$//;
			}
			else {
				$prev .= "$_\n";
				next;
			}
		}
		elsif($prev) {
			$_ = "$prev$_";
			$prev = '';
		}

		if (s/<<(\w+)$//) {
			$waiting = $1;
			$prev .= $_;
			next;
		}

		next if ! /\S/ or /^\s*#/;
		s/\s+$//;

		if(/^[^\s:]+\t/ or /^\w+\s*:/s) {
			## This along with process_new_beginning replaces
			## two previous branches that had same code doing
			## same thing.

			$first = process_new_beginning(\@shipping, \@line, $_);
		}
		else {
			no strict 'refs';
			s/^\s+//;
			my($k, $v) = split /\s+/, $_, 2;
			my $prospect;
			$k = uc $k;
			$k = $Ship_remap{$k}
				if defined $Ship_remap{$k};

			if ($k eq 'MIN') {
				# Special case handling for minimum line.
				if ($first) {
					undef $first;
				}
				else {
					# Push the record we have to this point.
					my @lcopy = @line;
					process_new_beginning(\@shipping, \@lcopy);
				}
			}

			$Ship_handler{$k}->(\$v, \$k, \@line)
				if defined $Ship_handler{$k};
			eval {
				if(defined &{"$k"}) {
						$line[&{"$k"}] = $v;
				}
				else {
					$line[OPT] = {} unless $line[OPT];
					$k = lc $k;
					$line[OPT]->{$k} = $v;
				}
			};
			logError(
				"bad shipping index %s for mode %s in $file",
				$k,
				$line[0],
				) if $@;
		}
	}

	process_new_beginning(\@shipping, \@line);

	if($waiting) {
		logError(
			"Failed to find end-of-line termination '%s' in shipping read",
			$waiting,
		);
	}

	my $row;
	my %zones;
	my %def_opts;
	$def_opts{PriceDivide} = 1 if $Vend::Cfg->{Locale};

	foreach $row (@shipping) {
		my $cost = $row->[COST];
		my $o = get_option_hash($row->[OPT]);
		for(keys %def_opts) {
			$o->{$_} = $def_opts{$_}
				unless defined $o->{$_};
		}
		$row->[OPT] = $o;
		my $zone;
		if ($cost =~ s/^\s*o\s+//) {
			$o = get_option_hash($cost);
			%def_opts = %$o;
		}
		elsif ($zone = $o->{zone} or $cost =~ s/^\s*c\s+(\w+)\s*//) {
			$zone = $1 if ! $zone;
			next if defined $zones{$zone};
			my $ref;
			if ($o->{zone}) {
				$ref = {};
				my @common = qw/
							mult_factor				
							str_length				
							eas
							quiet
							zone_data
							zone_file				
							zone_name				
						/; 
				@{$ref}{@common} = @{$o}{@common};
				$ref->{zone_name} = $zone
					if ! $ref->{zone_name};
			}
			elsif ($cost =~ /^{[\000-\377]+}$/ ) {
				eval { $ref = eval $cost };
			}
			else {
				$ref = {};
				my($name, $file, $length, $multiplier) = split /\s+/, $cost;
				$ref->{zone_name} = $name || undef;
				$ref->{zone_file} = $file if $file;
				$ref->{mult_factor} = $multiplier if defined $multiplier;
				$ref->{str_length} = $length if defined $length;
			}
			if ($@
				or ref($ref) !~ /HASH/
				or ! $ref->{zone_name}) {
				logError(
					"Bad shipping configuration for mode %s, skipping.",
					$row->[MODE]
				);
				$row->[MODE] = 'ERROR';
				next;
			}
			$ref->{zone_key} = $zone;
			$ref->{str_length} = 3 unless defined $ref->{str_length};
			$zones{$zone} = $ref;
		}
    }

	if($Vend::Cfg->{UpsZoneFile} and ! defined $Vend::Cfg->{Shipping_zone}{'u'} ) {
			 $zones{'u'} = {
				zone_file	=> $Vend::Cfg->{UpsZoneFile},
				zone_key	=> 'u',
				zone_name	=> 'UPS',
				};
	}
	UPSZONE: {

		for (keys %zones) {
			my $ref = $zones{$_};
			if (! $ref->{zone_data}) {
				$ref->{zone_file} = Vend::Util::catfile(
											$base_dir,
											"$ref->{zone_name}.csv",
										) if ! $ref->{zone_file};
				$ref->{zone_data} =  readfile($ref->{zone_file});
			}
			unless ($ref->{zone_data}) {
				logError( "Bad shipping file for zone '%s', lookup disabled.",
							$ref->{zone_key},
						);
				next;
			}
			my (@zone) = grep /\S/, split /[\r\n]+/, $ref->{zone_data};
			shift @zone while @zone and $zone[0] !~ /^(Postal|Dest.*Z|low)/;
			if($zone[0] =~ /^Postal/) {
				$zone[0] =~ s/,,/,/;
				for(@zone[1 .. $#zone]) {
					s/,/-/;
				}
			}
			@zone = grep /\S/, @zone;
			@zone = grep /^[^"]/, @zone;
			if($zone[0] !~ /\t/) {
				my $len = $ref->{str_length} || 3;
				@zone = grep /\S/, @zone;
				@zone = grep /^[^"]/, @zone;
				$zone[0] =~ s/[^\w,]//g;
				$zone[0] =~ s/^\w+/low,high/;
				@zone = grep /,/, @zone;
				$zone[0] =~	s/\s*,\s*/\t/g;
				for(@zone[1 .. $#zone]) {
					s/^\s*(\w+)\s*,/make_three($1, $len) . ',' . make_three($1, $len) . ','/e;
					s/^\s*(\w+)\s*-\s*(\w+),/make_three($1, $len) . ',' . make_three($2, $len) . ','/e;
					s/\s*,\s*/\t/g;
				}
			}
			$ref->{zone_data} = \@zone;
		}
	}
	for (keys %zones) {
		$Vend::Cfg->{Shipping_zone}{$_} = $zones{$_};
	}
	$Vend::Cfg->{Shipping_line} = []
		if ! $Vend::Cfg->{Shipping_line};
	unshift @{$Vend::Cfg->{Shipping_line}}, @shipping;
	1;
}

sub resolve_shipmode {
	my ($type, $opt) = @_;

#::logDebug("Called resolve_shipmode");
	my $loc;
	if($loc = $Vend::Cfg->{Shipping_repository}{resolution}) {
		while( my ($k, $v) = each %$loc) {
			$opt->{$k} = $v unless defined $opt->{$k};
		}
	}
	
	my $sv = $opt->{shipmode_var} || 'mv_shipmode';
	my $current		= $::Values->{$sv};

	my $state	= $::Values->{$opt->{state_var} || 'state'};
	my $country = $::Values->{$opt->{country_var} || 'country'};

	my $sdb;
	$sdb = dbref($opt->{state_table} || 'state') unless $opt->{no_state};

	$opt->{state_modes_field}	||= 'shipmodes';
	$opt->{country_modes_field}	||= 'shipmodes';
	$opt->{state_field}			||= 'state';
	$opt->{country_field}		||= 'country';
	
	my $cdb;

	my $shipmodes;
	if($sdb and $state and $country) {
#::logDebug("Trying state modes");
		$shipmodes = $sdb->single(
						$opt->{state_modes_field},
						{
							$opt->{state_field} => $state,
							$opt->{country_field} => $country,
						},
						);
	}
#::logDebug("Shipmodes now '$shipmodes'");

	if(! $shipmodes and $country) {
#::logDebug("Trying country modes");
		$cdb = dbref($opt->{country_table} || 'country');
		$shipmodes = $cdb->field($country, $opt->{country_modes_field});
	}
#::logDebug("Shipmodes now '$shipmodes'");

	my @modes = grep /\S/, split /[\s,\0]+/, $shipmodes;

	my $current_ok;
	my $default;
	for(@modes) {
		$default ||= $_;
		$current_ok = 1		if $_ eq $current;
	}

	my $mode;
	my $valid;
	if($current_ok) {
		$mode = $current;
		$valid = 1;
	}
	else {
		$mode = $default;
	}

	return $valid if $opt->{check_validity};

	unless($opt->{no_set}) {
		$::Values->{$sv} = $mode;
	}

	if($opt->{possible}) {
		my $out = join " ", @modes;
#::logDebug("Returning possible '$out'");
		return $out;
	}
	return $mode;
}

my $Ship_its = 0;

sub push_warning {
	$Vend::Session->{warnings} = [$Vend::Session->{warnings}]
		if ! ref $Vend::Session->{warnings};
	push @{$Vend::Session->{warnings}}, errmsg(@_);
	return;
}

sub shipping {
	my($mode, $opt) = @_;

	$opt ||= {};

	return undef unless $mode;
    my $save = $Vend::Items;
	my $qual;
	my $final;

	$Vend::Session->{ship_message} = '' if ! $Ship_its;
	die "Too many levels of shipping recursion ($Ship_its)" 
		if $Ship_its++ > MAX_SHIP_ITERATIONS;
	my @bin;

#::logDebug("Check BEGIN, must get to FINAL. Vend::Items=$Vend::Items main=$::Carts->{main}");
	if ($opt->{cart}) {
		my @carts = grep /\S/, split /[\s,]+/, $opt->{cart};
		for(@carts) {
			next unless $::Carts->{$_};
			push @bin, @{$::Carts->{$_}};
		}
	}
	else {
		@bin = @$Vend::Items;
	}
#::logDebug("doing shipping, mode=$mode");
#::logDebug("doing shipping, mode=$mode bin=" . uneval(\@bin));

	$Vend::Session->{ship_message} = '' if $opt->{reset_message};

	my($field, $code, $i, $total, $cost, $multiplier, $formula, $error_message);

#	my $ref = $Vend::Cfg;
#
#	if(defined $Vend::Cfg->{Shipping_criterion}->{$mode}) {
#		$ref = $Vend::Cfg;
#	}
#	elsif($Vend::Cfg->{Shipping}) {
#		my $locale = 	$::Scratch->{mv_currency}
#						|| $::Scratch->{mv_locale}
#						|| $::Vend::Cfg->{DefaultLocale}
#						|| 'default';
#		$ref = $Vend::Cfg->{Shipping}{$locale};
#		$field = $ref->{$mode};
#	}
#
#	if(defined $ref->{Shipping_code}{$mode}) {
#		$final = tag_perl($opt->{table}, $opt, $Vend::Cfg->{Shipping_code});
#		goto SHIPFORMAT;
#	}

	$@ = 1;

	# Security hole if we don't limit characters
	$mode !~ /[\s,;{}]/ and 
		eval {'what' =~ /$mode/};

	if ($@) {
#::logDebug("Check ERROR, must get to FINAL. Vend::Items=$Vend::Items main=$::Carts->{main}");
		logError("Bad character(s) in shipping mode '$mode', returning 0");
		goto SHIPFORMAT;
	}

	my $row;
	my @lines;
	@lines = grep $_->[0] =~ /^$mode/, @{$Vend::Cfg->{Shipping_line}};
	goto SHIPFORMAT unless @lines;
#::logDebug("shipping lines selected: " . uneval(\@lines));
	my $q;
	if($lines[0][QUERY]) {
		my $q = interpolate_html($lines[0][QUERY]);
		$q =~ s/=\s+?\s*/= '$mode' /g;
		$q =~ s/\s+like\s+?\s*/ LIKE '%$mode%' /ig;
		my $ary = query($q, { wantarray => 1 });
		if(ref $ary) {
			@lines = @$ary;
#::logDebug("shipping lines reselected with SQL: " . uneval(\@lines));
		}
		else {
#::logDebug("shipping lines failed reselect with SQL query '$q'");
		}
	}

	my $lopt = $lines[0][OPT];
	if(ref($lopt) eq 'HASH') {
		$lopt = { %$lopt };
	}
	my $o = get_option_hash($lopt) || {};

#::logDebug("shipping opt=" . uneval($o));

	if($o->{limit}) {
		$o->{filter} = '(?i)\s*[1ty]' if ! $o->{filter};
#::logDebug("limiting, filter=$o->{filter} limit=$o->{limit}");
		my $patt = qr{$o->{filter}};
		@bin = grep $_->{$o->{limit}} =~ $patt, @bin;
	}
	$::Carts->{mv_shipping} = \@bin;

	Vend::Interpolate::tag_cart('mv_shipping');

#::logDebug("Check 2, must get to FINAL. Vend::Items=" . uneval($Vend::Items) . " main=" . uneval($::Carts->{main}) . " mv_shipping=" . uneval($::Carts->{mv_shipping}));

	if($o->{perl}) {
		$Vend::Interpolate::Shipping   = $lines[0];
		$field = $lines[0][CRIT];
		$field = tag_perl($opt->{tables}, $opt, $field)
			if $field =~ /[^\w:]/;
		$qual  = tag_perl($opt->{tables}, $opt, $o->{qual})
					if $o->{qual};
	}
	elsif ($o->{mml}) {
		$Vend::Interpolate::Shipping   = $lines[0];
		$field = tag_perl($opt->{tables}, $opt, $lines[0][CRIT]);
		$qual =  tag_perl($opt->{tables}, $opt, $o->{qual})
					if $o->{qual};
	}
	elsif($lines[0][CRIT] =~ /[[\s]|__/) {
		($field, $qual) = split /\s+/, interpolate_html($lines[0][CRIT]), 2;
		if($qual =~ /{}/) {
			logError("Bad qualification code '%s', returning 0", $qual);
			goto SHIPFORMAT;
		}
	}
	else {
		$field = $lines[0][CRIT];
	}

	goto SHIPFORMAT unless $field;

	# See if the field needs to be returned by a Interchange function.
	# If a space is encountered, a qualification code
	# will be set up, with any characters after the first space
	# used to determine geography or other qualifier for the mode.
	
	# Uses the quantity on the order form if the field is 'quantity',
	# otherwise goes to the database.
    $total = 0;

	if($field =~ /^[\d.]+$/) {
#::logDebug("Is a number selection");
		$total = $field;
	}
	elsif($field eq 'quantity') {
#::logDebug("quantity selection");
    	for (@$Vend::Items) {
			next unless $_->{quantity};
			$total = $total + $_->{quantity};
    	}
	}
	elsif ( index($field, ':') != -1) {
#::logDebug("outboard field selection");
		my ($base, $field) = split /:+/, $field;
		my $db = database_exists_ref($base);
		unless ($db and db_column_exists($db,$field) ) {
			logError("Bad shipping field '$field' or table '$base'. Returning 0");
			goto SHIPFORMAT;
		}
    	foreach $i (0 .. $#$Vend::Items) {
			my $item = $Vend::Items->[$i];
			$total += (database_field($base, $item->{code}, $field) || 0) *
						$item->{quantity};
		}
	}
	else {
#::logDebug("standard field selection");
	    my $use_modifier;

	    if ($::Variable->{MV_SHIP_MODIFIERS}){
			my @pieces = grep {$_ = quotemeta $_} split(/[\s,|]+/,$::Variable->{MV_SHIP_MODIFIERS});
			my $regex = join('|',@pieces);
			$use_modifier = 1 if ($regex && $field =~ /^($regex)$/);
	    }

	    my $col_checked = 0;
	    foreach my $item (@$Vend::Items){
		my $value;
		if ($use_modifier && defined $item->{$field}){
		    $value = $item->{$field};
		}
		else{
		    unless ($col_checked++ || column_exists $field){
			logError("Custom shipping field '$field' doesn't exist. Returning 0");
			$total = 0;
			goto SHIPFORMAT;
		    }
		    my $base = $item->{mv_ib} || $Vend::Cfg->{ProductFiles}[0];
		    $value = tag_data($base, $field, $item->{code});
		}
		$total += ($value * $item->{quantity});
	    }
	}

	if ($field eq 'weight') {
		if (my $callout_name = $Vend::Cfg->{SpecialSub}{weight_callout}) {
#::logDebug("Execute weight callout '$callout_name(...)'");
			my $weight_callout_sub = $Vend::Cfg->{Sub}{$callout_name} 
				|| $Global::GlobalSub->{$callout_name};
			eval {
				$total = $weight_callout_sub->($total) || 0;
			};
			::logError("Weight callout '$callout_name' died: $@") if $@;
		}
	}
	
	# We will LAST this loop and go to SHIPFORMAT if a match is found
	SHIPIT: 
	foreach $row (@lines) {
#::logDebug("processing mode=$row->[MODE] field=$field total=$total min=$row->[MIN] max=$row->[MAX]");

		next unless  $total <= $row->[MAX] and $total >= $row->[MIN];

		if($qual) {
			next unless
				$row->[CRIT] =~ m{(^|\s)$qual(\s|$)} or
				$row->[CRIT] !~ /\S/;
		}

		my $ropt = $row->[OPT];
		if(ref($ropt) eq 'HASH' ) {
			$ropt = { %$ropt };
		}
		$o = get_option_hash($ropt, $o)
			if $ropt;
		# unless field begins with 'x' or 'f', straight cost is returned
		# - otherwise the quantity is multiplied by the cost or a formula
		# is applied
		my $what = $row->[COST];
		if($what !~ /^[a-zA-Z]\w+$/) {
			$what =~ s/^\s+//;
			$what =~ s/[ \t\r]+$//;
		}
		if($what =~ /^(-?(?:\d+(?:\.\d*)?|\.\d+))$/) {
			$final += $1;
			last SHIPIT unless $o->{continue};
		}
		elsif ($what =~ /^f\s*(.*)/i) {
			$formula = $o->{formula} || $1;
			$formula =~ s/\@\@TOTAL\@\\?\@/$total/ig;
			$formula =~ s/\@\@CRIT\@\\?\@/$total/ig;
			$formula = interpolate_html($formula)
				if $formula =~ /__\w+__|\[\w/;
			$cost = $Vend::Interpolate::ready_safe->reval($formula);
			if($@) {
				$error_message   = errmsg(
								"Shipping mode '%s': bad formula. Returning 0.",
								$mode,
							);
				logError($error_message);
				last SHIPIT;
			}
			$final += $cost;
			last SHIPIT unless $o->{continue};
		}
		elsif ($what =~ /^>>(\w+)/) {
			my $newmode = $1;
			local($opt->{redirect_from});
			$opt->{redirect_from} = $mode;
			return shipping($newmode, $opt);
		}
		elsif ($what eq 'x') {
			$final += ($o->{multiplier} * $total);
			last SHIPIT unless $o->{continue};
		}
		elsif ($what =~ s/^x\s*(-?[\d.]+)\s*$/$1/) {
			$final += ($what * $total);
			last SHIPIT unless $o->{continue};
		}
		elsif ($what =~ s/^([uA-Z])\s*//) {
			my $zselect = $o->{zone} || $1;
			my ($type, $geo, $adder, $mod, $sub);
			($type, $adder) = @{$o}{qw/table adder/};
			$o->{geo} ||= 'zip';
			if(! $type) {
				$what = interpolate_html($what);
				($type, $geo, $adder, $mod, $sub) = split /\s+/, $what, 5;
				$o->{adder}    = $adder;
				$o->{round}    = 1  if $mod =~ /round/;
				$o->{at_least} = $1 if $mod =~ /min\s*([\d.]+)/;
			}
			else {
				$geo = $::Values->{$o->{geo}} || $o->{default_geo};
			}
#::logDebug("ready to tag_ups type=$type geo=$geo total=$total zone=$zselect options=$o");
			$cost = tag_ups($type,$geo,$total,$zselect,$o);
			$final += $cost;
			last SHIPIT unless $o->{continue};
		}
		elsif ($what =~ s/^s\s*//) {
			$what =~ s/\s+(.*)//;
			my $extra = $1;
			my $loc = $Vend::Cfg->{Shipping_repository}{$what}
				or return do_error("Unknown custom shipping type '%s'", $what);
			for(keys %$loc) {
				$o->{$_} = $loc->{$_} unless defined $o->{$_};
			}
			my $routine = $o->{cost_routine} || "Vend::Ship::${what}::calculate";
			my $sub = \&{"$routine"};
			if(! defined $sub) {
				::logOnce(
					"Shipping type %s %s routine %s not found, aborting options for %s.",
					$what,
					$opt->{routine_description} || 'calculation',
					$routine,
					$mode,
					);
				return undef;
			}
#::logDebug("ready to calculate custom Ship type=$what total=$total options=$o");
			$cost = $sub->($mode, $total, $row, $o, $opt, $extra);
			$final += $cost;
			last SHIPIT unless $o->{continue};
		}
		elsif ($what =~ s/^([im])\s*//) {
			my $select = $1;
			$what =~ s/\@\@TOTAL\@\@/$total/g;
			my ($item, $field, $sum);
			my (@items) = @{$Vend::Items};
			my @fields = split /\s+/, $qual;
			if ($select eq 'm') {
				$sum = { code => $mode, quantity => $total };
			}
			foreach $item (@items) {
				for(@fields) {
					if(s/(.*):+//) {
						$item->{$_} = tag_data($1, $_, $item->{code});
					}
					else {
						$item->{$_} = product_field($_, $item->{code});
					}
					$sum->{$_} += $item->{$_} if defined $sum;
				}
			}
			@items = ($sum) if defined $sum;
			for(@items) {
				$cost = Vend::Data::chain_cost($_, $what);
				if($cost =~ /[A-Za-z]/) {
					$cost = shipping($cost);
				}
				$final += $cost;
			}
			last SHIPIT unless $o->{continue};
		}
		elsif ($what =~ s/^e\s*//) {
			$error_message = $what;
			$error_message =~ s/\@\@TOTAL\@\@/$total/ig;
			$final = 0 unless $final;
			last SHIPIT unless $o->{continue};
		}
		else {
			$error_message = errmsg( "Unknown shipping call '%s'", $what);
			undef $final;
			last SHIPIT;
		}
	}

	if ($final == 0 and $o->{'next'}) {
		return shipping($o->{'next'}, $opt);
	}
	elsif(defined $o->{additional}) {
		my @extra = grep /\S/, split /[\s\0,]+/, $row->[OPT]->{additional};
		for(@extra) {
			$final += shipping($_, {});
		}
	}

#::logDebug("Check 3, must get to FINAL. Vend::Items=$Vend::Items main=$::Carts->{main}");


	SHIPFORMAT: {
		$Vend::Session->{ship_message} .= $error_message . ($error_message =~ / $/ ? '' : ' ')
			if defined $error_message;
		delete $::Carts->{mv_shipping};
		$Vend::Items = $save;
#::logDebug("Check FINAL. Vend::Items=$Vend::Items main=$::Carts->{main}");
		last SHIPFORMAT unless defined $final;
#::logDebug("ship options: " . uneval($o) );
		$final /= $Vend::Cfg->{PriceDivide}
			if $o->{PriceDivide} and $Vend::Cfg->{PriceDivide} != 0;
		$o->{free} = interpolate_html($o->{free}) if $o->{free} =~ /[_@[]/;
		unless ($o->{free}) {
			return '' if $final == 0;
			$o->{adder} =~ s/\@\@TOTAL\@\\?\@/$final/g;
			$o->{adder} =~ s/\@\@CRIT\@\\?\@/$total/g;
			$o->{adder} = $Vend::Interpolate::ready_safe->reval($o->{adder});
			$final += $o->{adder} if $o->{adder};
			$final = POSIX::ceil($final) if is_yes($o->{round});
			if($o->{at_least}) {
				$final = $final > $o->{at_least} ? $final : $o->{at_least};
			}
		}
		if($opt->{default}) {
			if(! $opt->{handling}) {
				$::Values->{mv_shipmode} = $mode;
			}
			else {
				$::Values->{mv_handling} = $mode;
			}
			undef $opt->{default};
		}
		if (my $callout_name = $Vend::Cfg->{SpecialSub}{shipping_callout}) {
#::logDebug("Execute shipping callout '$callout_name(...)'");
			my $sub = $Vend::Cfg->{Sub}{$callout_name} 
				|| $Global::GlobalSub->{$callout_name};
			eval {
				my $callout_result = $sub->($final, $mode, $opt, $o);
				$final = $callout_result if defined $callout_result;
			};
			::logError("Shipping callout '$callout_name' died: $@") if $@;
		}
		return $final unless $opt->{label};
		my $number;
		if($o->{free} and $final == 0) {
			$number = $opt->{free} || $o->{free};
#::logDebug("This is free, mode=$mode number=$number");
		}
		else {
			return $final unless $opt->{label};
#::logDebug("actual options: " . uneval($o));
			$number = Vend::Util::currency( 
											$final,
											$opt->{noformat},
									);
		}

		$opt->{format} ||= '%M=%D (%F)' if $opt->{output_options};
		
		my $label = $opt->{format} || '<option value="%M"%S>%D (%F)';
		my $sel = $::Values->{mv_shipmode} eq $mode;
#::logDebug("label start: $label");
		my %subst = (
						'%' => '%',
						M => $opt->{redirect_from} || $mode,
						T => $total,
						S => $sel ? ' SELECTED' : '',
						C => $sel ? ' CHECKED' : '',
						D => $row->[DESC] || $Vend::Cfg->{Shipping_desc}{$mode},
						L => $row->[MIN],
						H => $row->[MAX],
						O => '$O',
						F => $number,
						N => $final,
						E => defined $error_message ? "(ERROR: $error_message)" : '',
						e => $error_message,
						Q => $qual,
					);
#::logDebug("labeling, subst=" . ::uneval(\%subst));
		$subst{D} = errmsg($subst{D});
		if($opt->{output_options}) {
			for(qw/ D E F f /) {
				next unless $subst{$_};
				$subst{$_} =~ s/,/&#44;/g;
			}
		}
		$label =~ s/(%(.))/exists $subst{$2} ? $subst{$2} : $1/eg;
#::logDebug("label intermediate: $label");
		$label =~ s/(\$O{(.*?)})/$o->{$2}/eg;
#::logDebug("label returning: $label");
		return $label;
	}

	# If we got here, the mode and quantity fit was not found
	$Vend::Session->{ship_message} ||= '';
	my $fmt = "No match found for mode '%s', quantity '%s', ";
	$fmt .= "qualifier '%s', " if $qual;
	$fmt .= "returning 0.";
	$Vend::Session->{ship_message} .= errmsg($fmt, $mode, $total, $qual);
	return undef;
}

sub tag_handling {
	my ($mode, $opt) = @_;
	$opt = { noformat => 1, convert => 1 } unless $opt;

	if($opt->{default}) {
		undef $opt->{default}
			if tag_shipping( undef, {handling => 1});
	}

	$opt->{handling} = 1;
	if(! $mode) {
		$mode = $::Values->{mv_handling} || undef;
	}
	return tag_shipping($mode, $opt);
}

sub tag_shipping {
	my($mode, $opt) = @_;
	$opt = { noformat => 1, convert => 1 } unless $opt;

	return resolve_shipmode($mode, $opt)
		if $opt->{possible} || $opt->{resolve} || $opt->{check_validity};

	$Ship_its = 0;
	if(! $mode) {
		if($opt->{widget} || $opt->{label}) {
			$mode = resolve_shipmode(undef, { no_set => $opt->{no_set}, possible => 1});
		}
		else {
			$mode = $opt->{handling}
					? ($::Values->{mv_handling})
					: ($::Values->{mv_shipmode} || 'default');
		}
	}

	my $loc = $Vend::Cfg->{Shipping_repository}
			&& $Vend::Cfg->{Shipping_repository}{default};
	$loc ||= {};

	$Vend::Cfg->{Shipping_line} = [] 
		if $opt->{reset_modes};
	read_shipping(undef, $opt) if $Vend::Cfg->{SQL_shipping};
	read_shipping(undef, $opt) if $opt->{add};
	read_shipping($opt->{file}) if $opt->{file};
	my $out;

#::logDebug("Shipping mode(s) $mode");
	my (@modes) = grep /\S/, split /[\s,\0]+/, $mode;
	if($opt->{default}) {
		undef $opt->{default}
			if tag_shipping($::Values->{mv_shipmode});
	}
	if($opt->{label} || $opt->{widget}) {
		my @out;
		if($opt->{widget}) {
			$opt->{label} = 1;
			$opt->{output_options} = 1;
		}
		for(@modes) {
			my $return = shipping($_, $opt);
#::logDebug("pushing $return");
			#push @out, shipping($_, $opt);
			push @out, $return;
		}
		@out = grep /=.+/, @out;

		if(! @out and ! $opt->{hide_error}) {
			my $message = $loc->{no_modes_message} || 'Not enough information';
			@out = "=" . errmsg($message);
		}

		if($opt->{widget}) {
			my $o = { %$opt };
			$o->{type} = delete $o->{widget};
			$o->{passed} = join ",", @out;
			$o->{name} ||= 'mv_shipmode';
			$o->{value} ||= $::Values->{mv_shipmode};
			$out = Vend::Form::display($o);
		}
		else {
			$out = join "", @out;
		}
	}
	else {
		### If the user has assigned to shipping or handling,
		### we use their value
		if($Vend::Session->{assigned}) {
			my $tag = $opt->{handling} ? 'handling' : 'shipping';
			$out = $Vend::Session->{assigned}{$tag} 
				if defined $Vend::Session->{assigned}{$tag} 
				&& length( $Vend::Session->{assigned}{$tag});
		}
		### If no assignment has been made, we read the shipmodes
		### and use their value
		unless (defined $out) {
			$out = 0;
			for(@modes) {
				$out += shipping($_, $opt) || 0;
			}
		}
		$out = Vend::Util::round_to_frac_digits($out);
		## Conversion would have been done above, force to 0, as
		## found by Frederic Steinfels
		$out = currency($out, $opt->{noformat}, 0, $opt);
	}
	return $out unless $opt->{hide};
	return;
}

sub tag_ups {
	my($type,$zip,$weight,$code,$opt) = @_;
	my(@data);
	my(@fieldnames);
	my($i,$point,$zone);

	$weight += $opt->{packaging_weight} if $opt->{packaging_weight};

	if($opt->{source_grams}) {
		$weight *= 0.00220462;
	}
	elsif($opt->{source_kg}) {
		$weight *= 2.20462;
	}
	elsif($opt->{source_oz}) {
		$weight /= 16;
	}

	if($opt->{oz}) {
		$weight *= 16;
	}

#::logDebug("tag_ups: type=$type zip=$zip weight=$weight code=$code opt=" . uneval($opt));

	if(my $modulo = $opt->{aggregate}) {
		$modulo = 150 if $modulo < 10;
		if($weight > $modulo) {
			my $cost = 0;
			my $w = $weight;
			while($w > $modulo) {
				$w -= $modulo;
				$cost += tag_ups($type, $zip, $modulo, $code, $opt);
			}
			$cost += tag_ups($type, $zip, $w, $code, $opt);
			return $cost;
		}
	}

	$code = 'u' unless $code;

	unless (defined $Vend::Database{$type}) {
		logError("Shipping lookup called, no database table named '%s'", $type);
		return undef;
	}
	unless (ref $Vend::Cfg->{Shipping_zone}{$code}) {
		logError("Shipping '%s' lookup called, no zone defined", $code);
		return undef;
	}
	my $zref = $Vend::Cfg->{Shipping_zone}{$code};
	
	unless (defined $zref->{zone_data}) {
		logError("$zref->{zone_name} lookup called, zone data not found");
		return undef;
	}

	my $zdata = $zref->{zone_data};
	# UPS doesn't like fractional pounds, rounds up

	# here we can adapt for pounds/kg
	if ($zref->{mult_factor}) {
		$weight = $weight * $zref->{mult_factor};
	}
	$weight = POSIX::ceil($weight);

	unless($opt->{no_zip_process}) {
		$zip =~ s/\W+//g;
		$zip = uc $zip;
	}

	my $rawzip = $zip;

	my $country;
	if($opt->{country_prefix}) {
		$country = $::Values->{country} || '';
		$country = uc $country;
		$country =~ s/\W+//g;
		$country =~ m{^\w\w$} 
			or do {
				logDebug('Country code not present with country_prefix');
				return undef;
			};
		$zip = $country . ":" . $zip;
	}
	else {
		$zip = substr($zip, 0, ($zref->{str_length} || 3));
	}

	@fieldnames = split /\t/, $zdata->[0];
	for($i = 2; $i < @fieldnames; $i++) {
		next unless $fieldnames[$i] eq $type;
		$point = $i;
		last;
	}

	unless (defined $point) {
		logError("Zone '%s' lookup failed, type '%s' not found", $code, $type)
			unless $zref->{quiet};
		return undef;
	}

	my $eas_point;
	my $eas_zone;
	if($zref->{eas}) {
		for($i = 2; $i < @fieldnames; $i++) {
			next unless $fieldnames[$i] eq $zref->{eas};
			$eas_point = $i;
			last;
		}
	}

#::logDebug("tag_ups looking in zone data.");
	my $zip_trimmed;
	for(@{$zdata}[1..$#{$zdata}]) {
		@data = split /\t/, $_;

                unless($zip_trimmed) {
			if ( $data[0] =~ m{^(([A-Z][A-Z]):)?(\w+)} and $2 eq $country ) {
				$zip = substr($zip, 0, length($1.$3));
				$zip_trimmed++;
			}
		}		

		next unless ($zip ge $data[0] and $zip le $data[1]);
		$zone = $data[$point];
		$eas_zone = $data[$eas_point] if defined $eas_point;
		return 0 unless $zone;
		last;
	}

	if (! defined $zone) {
		$Vend::Session->{ship_message} .=
			"No zone found for geo code $zip, type $type. ";
#::logDebug("tag_ups no zone $zone.");
		return undef;
	}
	elsif (!$zone or $zone eq '-') {
		$Vend::Session->{ship_message} .=
			"No $type shipping allowed for geo code $zip. ";
#::logDebug("tag_ups empty zone $zone.");
		return undef;
	}

	my $cost;
	$cost =  tag_data($type,$zone,$weight);
	$cost += tag_data($type,$zone,$eas_zone)  if defined $eas_point;
	$Vend::Session->{ship_message} .=
								errmsg(
									"Zero cost returned for mode %s, geo code %s. ",
									$type,
									$zip,
								)
		unless $cost;
#::logDebug("tag_ups cost: $cost");
	if($cost > 0) {
		if($opt->{surcharge_table}) {
			$opt->{surcharge_field} ||= 'surcharge';
			my $xarea = tag_data(
							$opt->{surcharge_table},
							$opt->{surcharge_field},
							$rawzip);
			$cost += $xarea if $xarea;
		}
		if($opt->{residential}) {
			my $v =	length($opt->{residential}) > 2
					? $opt->{residential}
					: 'mv_ship_residential';
			my $f = $opt->{residential_field} || 'res';
#::logDebug("residential check, f=$f v=$v");
			if( $Values->{$v} ) {
				my $rescharge = tag_data($type,$f,$weight);
#::logDebug("residential check type=$type weight=$weight, rescharge: $rescharge");
				$cost += $rescharge if $rescharge;
			}
		}
	}
	return $cost;
}

sub tag_shipping_desc {
	my $mode = 	shift;
	my $key = shift || 'description';
	$mode = $mode || $::Values->{mv_shipmode} || 'default';
	return errmsg($Vend::Cfg->{Shipping_hash}{$mode}{$key});
}

=head1 NAME

Vend::Ship -- Shipping module for Interchange

=head1 DESCRIPTION

The behavior of this module is described in the Interchange documentation.

=head1 AUTHOR

Mike Heins, mike@perusion.net

=cut
1;
