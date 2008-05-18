# Vend::Options - Interchange item options base module
#
# $Id: Options.pm,v 2.8 2007-08-09 13:40:53 pajamian Exp $
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

package Vend::Options;
require Exporter;

$VERSION = substr(q$Revision: 2.8 $, 10);

@ISA = qw(Exporter);

@EXPORT = qw(
				find_joiner
				find_options_type
				find_sort
				inventory_function
				option_cost
				remap_option_record
		);

use Vend::Util;
use Vend::Data;
use Vend::Interpolate;
use strict;

sub remap_option_record {
	my ($record, $map) = @_;

	my %rec;
	my @del;
	my ($k, $v);
	while (($k, $v) = each %$map) {
		next unless defined $record->{$v};
		$rec{$k} = $record->{$v};
		push @del, $v;
	}
	delete @{$record}{@del};
	@{$record}{keys %rec} = (values %rec);
	
	return;
}

sub find_options_type {
	my ($item, $opt) = @_;

	my $attrib;
	return $item->{$attrib}
		if	$attrib = $Vend::Cfg->{OptionsAttribute}
		and defined $item->{$attrib};

	my $sku = $item->{mv_sku} || $item->{code};

	$opt = get_option_hash($opt);

	my $module;

	if($Vend::Cfg->{OptionsEnable}) {
		my ($tab, $field) = split /:+/, $Vend::Cfg->{OptionsEnable};
		if(! $field) {
			$field = $tab;
			undef $tab;
		}
		elsif($tab =~ /=/) {
			my $att;
			($att, $tab) = split /\s*=\s*/, $tab;
			$attrib ||= $att;
		}
		$attrib ||= $field;
		$Vend::Cfg->{OptionsAttribute} ||= $attrib;

		if(! defined $item->{$attrib}) {
			$tab = $item->{mv_ib} || product_code_exists_tag($sku)
					or do {
						logOnce('error', "options: Unknown product %s.", $sku);
						return;
					};
			$item->{$attrib} = tag_data($tab, $field, $sku);
		}
		$module = $item->{$attrib} || '';
	}
	else {
		## Old style options
		my $loc = $Vend::Cfg->{Options_repository}{Old48} || {};
		my $table = $opt->{table}
				  ||= (
				  		$loc->{table} || $::Variable->{MV_OPTION_TABLE} || 'options'
					);
		my $db = $Vend::Interpolate::Db{$table} || database_exists_ref($table)
				or return;
		$db->record_exists($sku)
				or return;
		my $record = $opt->{options_record} = $db->row_hash($sku)
				or return;
		$opt->{options_db} = $db;
		remap_option_record($record, $loc->{map})
			if  $loc->{remap};

		return '' unless $record->{o_enable};

		$module = 'Old48';

		if($record->{o_matrix}) {
			$opt->{display_routine}
				= 'Vend::Options::Old48::display_options_matrix';
		}
		elsif($record->{o_modular}) {
			$module = 'Modular';
		}
		else {
			$opt->{display_routine}
				= 'Vend::Options::Old48::display_options_simple';
		}
	}

	return $module;
}

sub inventory_function {
	my $opt = shift;
	return unless $opt->{inventory};
	my $inv_func;
	my ($t, $c) = split /[.:]+/, $opt->{inventory};
	my $idb;
	if($idb = database_exists_ref($t)) {
		$inv_func = $idb->field_accessor($c);
	}
	return $inv_func;
}

sub find_joiner {
	my $opt = shift;
	if($opt->{report}) {
		$opt->{joiner}		||= ', ';
		$opt->{separator} 	||= ': ';
		$opt->{type}		||= 'display';
	}
	else {
		$opt->{joiner} ||= "<br$Vend::Xtrailer>";
	}
	return;
}

sub find_sort {
	my $opt = shift;
	my $db = shift;
	my $loc = shift || $Vend::Cfg->{Options_repository}{$opt->{options_type}} || {};
#::logDebug("called find_sort from " . scalar(caller()) . ", opt=" . ::uneval($opt));
	$opt->{sort} = defined $opt->{sort} ? $opt->{sort} : $loc->{sort};
	return '' unless $opt->{sort};
	my @fields = split /\s*,\s*/, $opt->{sort};
	my $map = $loc->{map} ||= {};
	for(@fields) {
		my $extra; 
		$extra = ' DESC' if s/\s+(r(?:ev(?:erse)?)?|desc(?:ending)?)//i;
		$_ = $map->{$_} || $_;
		unless (defined $db->test_column($_)) {
			logOnce(
				"%s options sort field %s does not exist, returning unsorted",
				'Matrix',
				$_,
				);
			return undef;
		}
		$_ .= $extra if $extra;
	}

	return "ORDER BY " . join(",", @fields);
}

sub tag_options {
	my ($sku, $opt) = @_;
	my $item;
	if(ref $sku) {
		$item = $sku;
		$sku = $item->{mv_sku} || $item->{code};
	}
	$item ||= { code => $sku };
	$opt = get_option_hash($opt);
	find_joiner($opt);

	my $module = find_options_type($item, $opt)
		or return '';
	$opt->{options_type} = $module;
#::logDebug("tag_options module=$module");

	my $loc = $Vend::Cfg->{Options_repository}{$module} || {};
	no strict 'refs';
	my $routine;
	if($opt->{admin_page}) {
		$opt->{routine_description} ||= "admin page";
		$routine = $opt->{admin_page_routine}
			||= "Vend::Options::${module}::admin_page";
	}
	else {
		$opt->{routine_description} ||= "display";
		$routine = $opt->{display_routine};
		$routine ||= $loc->{display_routine}
				||= "Vend::Options::${module}::display_options";
#::logDebug("tag_options display routine=$routine");
	}
	my $sub = \&{"$routine"};
	if(! defined $sub) {
		::logOnce(
			"Options type %s %s routine %s not found, aborting options for %s.",
			$module,
			$opt->{routine_description},
			$routine,
			$sku,
			);
		return undef;
	}
#::logDebug("main tag_options item=" . ::uneval($item) . ", opt=" . ::uneval($opt));
	return $sub->($item, $opt, $loc);
}

sub option_cost {
	my ($item, $table, $final) = @_;

	my $module = find_options_type($item)
		or return undef;
#::logDebug("price_options module=$module");
	my $loc = $Vend::Cfg->{Options_repository}{$module} || {};
	return undef if $loc->{no_pricing};
	no strict 'refs';
	my $routine = $loc->{price_routine};
	$routine ||= "Vend::Options::${module}::price_options";
	my $sub = \&{"$routine"};
#::logDebug("price_options sub=$sub");

	if(! defined $sub) {
		::logOnce(
			"Options type %s not found, aborting option_cost for %s.",
			$module,
			$item->{code},
			);
		return undef;
	}
	return $sub->($item, $table, $final, $loc);
}

1;
__END__
