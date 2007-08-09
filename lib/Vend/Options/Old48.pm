# Vend::Options::Old48 - Interchange 4.8 compatible product options
#
# $Id: Old48.pm,v 1.14 2007-08-09 13:40:55 pajamian Exp $
#
# Copyright (C) 2002-2007 Interchange Development Group <interchange@icdevgroup.org>
# Copyright (C) 2002-2003 Mike Heins <mikeh@perusion.net>

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
#

package Vend::Options::Old48;

$VERSION = substr(q$Revision: 1.14 $, 10);

=head1 NAME

Vend::Options::Old48 - Interchange Compatibility Options Support

=head1 SYNOPSIS

    [item-options]
 
        or
 
    [price code=SKU]
 
=head1 PREREQUISITES

Vend::Options

=head1 DESCRIPTION

The Vend::Options::Old48 module implements simple and matrix product
options for Interchange. It is compatible with Interchange 4.8.x
matrix options. Newer versions use Simple and Matrix options instead.

If the Interchange Variable MV_OPTION_TABLE is not set, it defaults
to "options", which combines options for Simple, Matrix, and
Modular into that one table. This goes along with foundation and
construct demos up until Interchange 4.9.8.

The "options" table remains the default for matrix options.

=head1 AUTHORS

Mike Heins <mikeh@perusion.net>

=head1 CREDITS

    Jon Jensen <jon@swelter.net>

=cut

use Vend::Util;
use Vend::Data;
use Vend::Interpolate;
use Vend::Options;

sub option_cost {
	my ($item, $opt) = @_;

}

sub display_options_matrix {
	my ($item, $opt, $loc) = @_;

	$loc ||= $Vend::Cfg->{Options_repository}{Old48} || \%Default;
#::logDebug("Matrix options by module, old");
	my $sku = $item->{mv_sku} || $item->{code};
	my $db;
	my $tab;

	if(not $db = $opt->{options_db}) {
		$tab = $opt->{table} || $::Variable->{MV_OPTION_TABLE} || 'options';
		$db = database_exists_ref($tab)
			or do {
				logOnce(
						"Matrix options: unable to find table %s for item %s",
						$tab,
						$sku,
					);
				return undef;
			};
	}

	my $record;
	if(not $record = $opt->{options_record}) {
		$db->record_exists($sku)
			or do {
				logOnce(
					"Matrix options: unable to find record in table %s for item %s",
					$tab,
					$sku,
				);
				return;
			};
		$record = $db->row_hash($sku) || {};
	}

	my $tname = $db->name();

	if(not $opt->{display_type} ||= $record->{display_type}) {
		$opt->{display_type} = $record->{o_matrix} == 2 ? 'separate' : 'single';
	}

	$opt->{display_type} = lc $opt->{display_type};

	my $map;
	if(not $map = $opt->{options_map}) {
		$map = $opt->{options_map} = {};
		if(my $remap = $opt->{remap} || $::Variable->{MV_OPTION_TABLE_MAP}) {
			remap_option_record($record, $map, $remap);
		}
	}

	my @rf;
	my @out;
	my $out;
	
    my $inv_func;
    if($opt->{inventory}) {
        my ($tab, $col) = split /:+/, $opt->{inventory};
        MAKEFUNC: {
            my $idb = dbref($tab)
                or do {
                    logError("Bad table %s for inventory function.", $tab);
                    last MAKEFUNC;
                };
            $idb->test_column($col)
                or do {
                    logError(
                        "Bad column %s in table %s for inventory function.",
                        $col,
                        $tab,
                    );
                    last MAKEFUNC;
                };
            $inv_func = sub {
                my $key = shift;
                return $idb->field($key, $col);
            };
        }
    }

	my $rsort = find_sort($opt, $db, $loc);

	if($opt->{display_type} eq 'separate') {
		for(qw/code o_enable o_group o_value o_label o_widget price/) {
			push @rf, ($map->{$_} || $_);
		}
		my @def;
		if($item and $item->{code}) {
			@def = split /-/, $item->{code};
		}
		my $fsel = $map->{sku} || 'sku';
		my $rsel = $db->quote($sku, $fsel);
		
		my $q = "SELECT " .
				join (",", @rf) .
				" FROM $tname where $fsel = $rsel $rsort";
#::logDebug("tag_options matrix query: $q");
		my $ary = $db->query($q); 
#::logDebug("tag_options matrix ary: " . ::uneval($ary));
		my $ref;
		my $i = 0;
		my $phony = { %{$item || { }} };
		foreach $ref (@$ary) {

			next unless $ref->[3];

			# skip based on inventory if enabled
			if($inv_func) {
				my $oh = $inv_func->($ref->[0]);
				next if $oh <= 0;
			}

			$i++;

			# skip unless o_value
			$phony->{mv_sku} = $def[$i];

			if ($opt->{label}) {
				$ref->[4] = "<b>$ref->[4]</b>" if $opt->{bold};
				push @out, $ref->[4];
			}
			push @out, Vend::Interpolate::tag_accessories(
							$sku,
							'',
							{ 
								passed => $ref->[3],
								type => $opt->{type} || $ref->[5] || 'select',
								attribute => 'mv_sku',
								price_data => $ref->[6],
								price => $opt->{price},
								extra => $opt->{extra},
								js => $opt->{js},
								item => $phony,
							},
							$phony || undef,
						);
		}
		
		$phony->{mv_sku} = $sku;
		my $begin = Vend::Interpolate::tag_accessories(
							$sku,
							'',
							{ 
								type => 'hidden',
								attribute => 'mv_sku',
								item => $phony,
								default => $sku,
							},
							$phony,
						);
		if($opt->{td}) {
			for(@out) {
				$out .= "<td>$begin$_</td>";
				$begin = '';
			}
		}
		else {
			$opt->{joiner} = "<br$Vend::Xtrailer>" if ! $opt->{joiner};
			$out .= $begin;
			$out .= join $opt->{joiner}, @out;
		}
	}
	else {
		for(qw/code o_enable o_group description price weight volume differential o_widget/) {
			push @rf, ($map->{$_} || $_);
		}
		my $ccol = $map->{code} || 'code';
		my $lcol = $map->{sku} || 'sku';
		my $lval = $db->quote($sku, $lcol);

		my $q = "SELECT " . join(",", @rf);
		$q .= " FROM $tname where $lcol = $lval AND $ccol <> $lval $rsort";
#::logDebug("tag_options matrix query: $q");
		my $ary = $db->query($q); 
#::logDebug("tag_options matrix ary: " . ::uneval($ary));
		my $ref;
		my $price = {};
		foreach $ref (@$ary) {
			# skip unless description
			next unless $ref->[3];

			# skip based on inventory if enabled
			if($inv_func) {
				my $oh = $inv_func->($ref->[0]);
				next if $oh <= 0;
			}

			$ref->[3] =~ s/,/&#44;/g;
			$ref->[3] =~ s/=/&#61;/g;
			$price->{$ref->[0]} = $ref->[4];
			push @out, "$ref->[0]=$ref->[3]";
		}
		$out .= "<td>" if $opt->{td};
		$out .= Vend::Interpolate::tag_accessories(
							$sku,
							'',
							{ 
								attribute => 'code',
								default => undef,
								extra => $opt->{extra},
								item => $item,
								js => $opt->{js},
								name => 'mv_sku',
								passed => join(",", @out),
								price => $opt->{price},
								price_data => $price,
								type => $opt->{type} || $ref->[8] || 'select',
							},
							$item || undef,
						);
		$out .= "</td>" if $opt->{td};
#::logDebug("matrix option returning $out");
	}

	return $out;
}

sub price_options {
	my ($item, $table, $final, $loc) = @_;

#::logDebug("option_cost table=$table");
	$loc ||= $Vend::Cfg->{Options_repository}{Old48} || {};

	my $sku = $item->{mv_sku} || $item->{code};
	my $db = database_exists_ref($table)
		or return undef;
#::logDebug("option_cost db=$db");

	my $map = $loc->{map} || {};
	my $fsel = $map->{sku} || 'sku';
	my $rsel = $db->quote($sku, $fsel);
	my @rf;
	for(qw/o_group price/) {
		push @rf, ($map->{$_} || $_);
	}

	my $q = "SELECT " . join (",", @rf) . " FROM $table WHERE $fsel = $rsel";
#::logDebug("option_cost query=$q");
	my $ary = $db->query($q); 
	return if ! $ary->[0];
	my $ref;
	my $price = 0;
	my $f;

	foreach $ref (@$ary) {
#::logDebug("checking option " . uneval_it($ref));
		next unless defined $item->{$ref->[0]};
		$ref->[1] =~ s/^\s+//;
		$ref->[1] =~ s/\s+$//;
		$ref->[1] =~ s/==/=:/g;
		my %info = split /\s*[=,]\s*/, $ref->[1];
		if(defined $info{ $item->{$ref->[0]} } ) {
			my $atom = $info{ $item->{$ref->[0]} };
			if($atom =~ s/^://) {
				$f = $atom;
				next;
			}
			elsif ($atom =~ s/\%$//) {
				$f = $final if ! defined $f;
				$f += ($atom * $final / 100);
			}
			else {
				$price += $atom;
			}
		}
	}
#::logDebug("option_cost returning price=$price f=$f");
	return ($price, $f);
}

sub display_options_simple {
	my ($item, $opt) = @_;
#::logDebug("Simple options, item=" . ::uneval($item) . "\nopt=" . ::uneval($opt));
	my $map = $opt->{options_map} ||= {};
#::logDebug("Simple options by module, old");

	my $sku = $item->{code};
	my $db;
	my $tab;
	if(not $db = $opt->{options_db}) {
		$tab = $opt->{table} ||= $::Variable->{MV_OPTION_TABLE_SIMPLE}
							 ||= $::Variable->{MV_OPTION_TABLE}
							 ||= 'options';
		$db = database_exists_ref($tab)
			or do {
				logOnce(
						"Simple options: unable to find table %s for item %s",
						$tab,
						$sku,
					);
				return undef;
			};
	}

	my $tname = $db->name();

	my @rf;
	my @out;
	my $out;

	my $ishash = defined $item->{mv_ip} ? 1 : 0;

	for(qw/code o_enable o_group o_value o_label o_widget price o_height o_width/) {
		push @rf, ($map->{$_} || $_);
	}

	my $fsel = $map->{sku} || 'sku';
	my $rsel = $db->quote($sku, $fsel);
	
	my $q = "SELECT " . join (",", @rf) . " FROM $tname where $fsel = $rsel";

	if(my $rsort = find_sort($opt, $db, $loc)) {
		$q .= " $rsort";
	}
#::logDebug("tag_options simple query: $q");

	my $ary = $db->query($q)
		or return; 

	my $ref;
	foreach $ref (@$ary) {
		# skip unless o_value
		next unless $ref->[3];
		if ($opt->{label}) {
			$ref->[4] = "<b>$ref->[4]</b>" if $opt->{bold};
			push @out, $ref->[4];
		}
		my $precursor = $opt->{report}
					  ? "$ref->[2]$opt->{separator}"
					  : qq{<input type="hidden" name="mv_item_option" value="$ref->[2]">};
		push @out, $precursor . Vend::Interpolate::tag_accessories(
						$sku,
						'',
						{ 
							attribute => $ref->[2],
							default => undef,
							extra => $opt->{extra},
							item => $item,
							name => $ishash ? undef : "mv_order_$ref->[2]",
							js => $opt->{js},
							passed => $ref->[3],
							price => $opt->{price},
							price_data => $ref->[6],
							height => $opt->{height} || $ref->[7],
							width  => $opt->{width} || $ref->[8],
							type => $opt->{type} || $ref->[5] || 'select',
						},
						$item || undef,
					);
	}
	if($opt->{td}) {
		for(@out) {
			$out .= "<td>$_</td>";
		}
	}
	else {
		$opt->{joiner} = "<br$Vend::Xtrailer>" if ! $opt->{joiner};
		$out .= join $opt->{joiner}, @out;
	}
	return $out;
}

*display_options = \&display_options_simple;

1;
