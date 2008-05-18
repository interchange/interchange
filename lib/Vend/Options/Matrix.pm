# Vend::Options::Matrix - Interchange Matrix product options
#
# $Id: Matrix.pm,v 1.17 2007-11-10 07:02:18 pajamian Exp $
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

package Vend::Options::Matrix;

$VERSION = substr(q$Revision: 1.17 $, 10);

=head1 NAME

Vend::Options::Matrix - Interchange Matrix Options Support

=head1 SYNOPSIS

    [item-options]
 
        or
 
    [price code=SKU]
 
=head1 PREREQUISITES

Vend::Options

=head1 DESCRIPTION

The Vend::Options::Matrix module implements matrix product options for
Interchange. It is compatible with Interchange 4.8.x matrix options.

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
use strict;

use vars qw/%Default/;

%Default = (
				no_pricing => 1,
				item_add_routine => 'Vend::Options::Matrix::testit',
				table => 'options',
				sort => 'o_sort',
				variant_table => 'variants',
				variant_sort => 'description',
			);

my $Admin_page;

sub price_options { }

sub testit {
	::logDebug("triggered routine testit! args=" . ::uneval(\@_));
}

sub display_options {
	my ($item, $opt, $loc) = @_;

#::logDebug("Matrix options by module");
	my $sku = $item->{mv_sku} || $item->{code};
	
	$loc ||= $Vend::Cfg->{Options_repository}{Matrix} || \%Default;

	my $map = $loc->{map} || {};

	my $tab = $opt->{table} ||= $loc->{table} || 'options';
	my $db = database_exists_ref($tab)
			or do {
				logOnce(
						"Matrix options: unable to find table %s for item %s",
						$tab,
						$sku,
					);
				return undef;
			};

	my $record = $db->row_hash($sku) || {};
	$record->{display_type} ||= $loc->{display_type};

	my $tname = $db->name();

	$opt->{display_type} ||= $record->{display_type};

	$opt->{display_type} = lc $opt->{display_type};
	$opt->{translate} = $loc->{translate} unless defined $opt->{translate};

	my @rf;
	my @out;
	my $out;
	
	# Will be different based on whether separate or not....
	my $rsort;

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

	use constant SEP_CODE		=> 0;
	use constant SEP_GROUP		=> 1;
	use constant SEP_VALUE		=> 2;
	use constant SEP_LABEL		=> 3;
	use constant SEP_WIDGET		=> 4;
	use constant SEP_PRICE		=> 5;
	use constant SEP_WHOLE		=> 6;
	use constant SEP_HEIGHT         => 7;
	use constant SEP_WIDTH          => 8;
	use constant SEP_SIMPLE         => 9;
	use constant CODE			=> 0;
	use constant DESCRIPTION	=> 1;
	use constant PRICE			=> 2;

#::logDebug("ready to query options");
	if($opt->{display_type} eq 'separate') {
		for(qw/
			code
			o_group
			o_value
			o_label
			o_widget
			price
			wholesale
			o_height
			o_width
			o_simple
		/) {
			push @rf, ($map->{$_} || $_);
		}
		my @def;
		if($item and $item->{code}) {
			@def = split /-/, $item->{code};
		}
		my $fsel = $map->{sku} || 'sku';
		my $rsel = $db->quote($sku, $fsel);
		$rsort = find_sort($opt, $db, $loc);
		
		my $q = "SELECT " .
				join (",", @rf) .
				" FROM $tname where $fsel = $rsel $rsort";
#::logDebug("tag_options matrix query: $q");
		my $ary = $db->query($q); 
#::logDebug("tag_options matrix ary: " . ::uneval($ary));
		my $ishash = defined $item->{mv_ip} ? 1 : 0;
		my $ref;
		my $i = 0;
		my $phony = { %{$item || { }} };
		foreach $ref (@$ary) {

			next unless $ref->[SEP_VALUE];

			# skip based on inventory if enabled
			if($inv_func) {
				my $oh = $inv_func->($ref->[SEP_CODE]);
				next if $oh <= 0;
			}

			$i++;

			# skip unless o_value
			$phony->{mv_sku} = $def[$i];

			my $passed = $ref->[SEP_VALUE];
			if($opt->{blank_label}) {
				$passed = "=$opt->{blank_label}, $passed";
			}
			if ($opt->{label}) {
				my $lab = $ref->[SEP_LABEL];
				$lab = errmsg($lab) if $opt->{translate};
				$lab = "<b>$lab</b>" if $opt->{bold};
				push @out, $lab;
			}

			my $ary = Vend::Form::options_to_array($passed);

			if($opt->{translate}) {
				for(@$ary) {
					$_->[1] = errmsg($_->[1]);
				}
			}

			my $precursor = '';
			$precursor = "$ref->[SEP_GROUP]$opt->{separator}" if $opt->{report};
			$precursor = qq{<input type="hidden" name="mv_item_option" value="$ref->[SEP_GROUP]">} if $ref->[SEP_SIMPLE];

			if ($ref->[SEP_SIMPLE]) {
			    push @out, $precursor . Vend::Interpolate::tag_accessories(
				$sku,
				'',
				{
				    attribute => $ref->[SEP_GROUP],
				    default => undef,
				    extra => qq/id="$ref->[SEP_GROUP]" $opt->{extra}/,
				    item => $item,
				    js => $opt->{js},
				    name => $ishash ? undef : "mv_order_$ref->[SEP_GROUP]",
				    option_template => $opt->{option_template},
				    passed => $ary,
				    price => $opt->{price},
				    price_data => $ref->[SEP_PRICE],
				    height => $opt->{height} || $ref->[SEP_HEIGHT],
				    width  => $opt->{width} || $ref->[SEP_WIDTH],
				    type => $opt->{type} || $ref->[SEP_WIDGET] || 'select',
				},
				$item || undef,
				);

			} else {
			    push @out, $precursor . Vend::Interpolate::tag_accessories(
				$sku,
				'',
				{ 
				    passed => $ary,
				    type => $opt->{type} || $ref->[SEP_WIDGET] || 'select',
				    attribute => 'mv_sku',
				    price_data => $ref->[SEP_PRICE],
				    price => $opt->{price},
				    extra => qq/id="$ref->[SEP_GROUP]" $opt->{extra}/,
				    js => $opt->{js},
				    item => $phony,
				},
				$phony || undef,
				);
			}
		}
		
		$phony->{mv_sku} = $sku;
		my $begin = '';
		unless ($opt->{report}) {
			$begin = Vend::Interpolate::tag_accessories(
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
		}
		
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
		my $vtab = $opt->{variant_table} || $loc->{variant_table};
		my $vdb = database_exists_ref($vtab)
			or do {
				logOnce(
					"Matrix options: unable to find variant table %s for item %s",
					$vtab,
					$sku,
				);
				return undef;
			};

		$opt->{type} ||= $record->{widget};
		$rsort = $opt->{variant_sort} || $loc->{variant_sort};
		$rsort = "ORDER BY $rsort" if $rsort;
		$rsort ||= '';

		for(qw/code description price/) {
			push @rf, ($map->{$_} || $_);
		}
		my $lcol = $map->{sku} || 'sku';
		my $lval = $vdb->quote($sku, $lcol);

		my $vname = $vdb->name();

		my $q = "SELECT " . join(",", @rf);
		$q .= " FROM $vname WHERE $lcol = $lval $rsort";
#::logDebug("tag_options matrix query: $q");
		my $ary = $vdb->query($q); 
#::logDebug("tag_options matrix ary: " . ::uneval($ary));
		my $ref;
		my $price = {};
		foreach $ref (@$ary) {
			# skip unless description
			next unless $ref->[DESCRIPTION];

			# skip based on inventory if enabled
			if($inv_func) {
				my $oh = $inv_func->($ref->[CODE]);
				next if $oh <= 0;
			}

			my $desc = $ref->[DESCRIPTION];
			$desc =~ s/,/&#44;/g;
			$desc =~ s/=/&#61;/g;
			$price->{$ref->[CODE]} = $ref->[PRICE];
			push @out, "$ref->[CODE]=$desc";
		}

		if($opt->{blank_label}) {
			unshift @out, "=$opt->{blank_label}";
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
								type => $opt->{type} || 'select',
							},
							$item || undef,
						);
		$out .= "</td>" if $opt->{td};
#::logDebug("matrix option returning $out");
	}

	return $out;

}

sub admin_page {
	my $item = shift;
	my $opt = shift;
	my $page = $Tag->file('include/Options/Matrix') || $Admin_page;
	Vend::Util::parse_locale(\$page);
	return interpolate_html($page);
}

$Admin_page = <<'EoAdminPage';
EoAdminPage

1;
