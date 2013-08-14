# Copyright 2002-2007 Interchange Development Group and others
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.
# 
# $Id: weight.tag,v 1.9 2007-07-18 00:16:26 jon Exp $

UserTag weight Order   attribute
UserTag weight addAttr
UserTag weight Version $Revision: 1.9 $
UserTag weight Routine <<EOR
sub {
	my ($attr, $opt) = @_;
	$opt ||= {};
	
	my $cart;
	if($opt->{cart}) {
		$cart = $Vend::Session->{carts}{$opt->{cart}} || [];
	}
	else {
		$cart = $Vend::Items;
	}

	my $wsub;

	my $field = $opt->{field} || 'weight';
	my $table = $opt->{table};
	my $osub;

	if($opt->{options}) {
	   BUILDO: {
		 my $oattr = $Vend::Cfg->{OptionsAttribute}
		 	or last BUILDO;
		 my $odb = dbref($opt->{options_table} || 'options')
		 	or last BUILDO;
		 my $otab = $odb->name();
		 my $q = qq{
		 			SELECT o_group, weight FROM $otab
					WHERE  sku = ?
					AND    weight is not null
					AND    weight <> ''
					};
		 my $sth = $odb->dbh()->prepare($q)
		 	or last BUILDO;
		 if($oattr and $odb) {
			 $osub = sub {
				my $it = shift;
				my $oweight = 0;
				if($it->{$oattr} eq 'Simple') {
					$sth->execute($it->{code});
					while(my $ref = $sth->fetchrow_arrayref) {
						my ($opt, $wtext) = @$ref;
						next unless length($it->{$opt});
						my $whash = get_option_hash($wtext);
						next unless $whash;
						$oweight += $whash->{$it->{$opt}};
					}
				}
				return $oweight;
			};
		};
	  }
	}

	my $exclude;
	my %exclude;
	if(my $thing = $opt->{exclude_attribute}) {
	  eval {
		if(ref($thing) eq 'HASH') {
			for(keys %$thing) {
				$exclude{$_} = qr{$thing->{$_}};
			}
		}
		else {
			my ($k, $v) = split /=/, $thing;
			$exclude{$k} = qr{$v};
		}
	  };
	  if($@) {
	  	::logError("Bad weight exclude option: %s", ::uneval($thing));
	  }
	  else {
	  	$exclude = 1;
	  }
	}

	my $zero_unless;
	my %zero_unless;
	if(my $thing = $opt->{zero_unless_attribute}) {
	  eval {
		if(ref($thing) eq 'HASH') {
			for(keys %$thing) {
				$zero_unless{$_} = qr{$thing->{$_}};
			}
		}
		else {
			my ($k, $v) = split /=/, $thing;
			$zero_unless{$k} = qr{$v};
		}
	  };
	  if($@) {
	  	::logError("Bad weight zero_unless option: %s", ::uneval($thing));
	  }
	  else {
	  	$zero_unless = 1;
	  }
	}

	if($attr) {
		$attr = $opt->{field} || 'weight';
		$wsub = sub {
			return shift(@_)->{$attr};
		};
	}
	elsif($opt->{fill_attribute}) {
		$attr = $opt->{fill_attribute};
		$wsub = sub {
			my $it = shift;
			return $it->{$attr} if defined $it->{$attr};
			my $tab = $table || $it->{mv_ib} || $Vend::Cfg->{ProductFiles}[0];
			$it->{$attr} = tag_data($tab,$field,$it->{code}) || 0;
			if($opt->{matrix} and ! $it->{$attr} and $it->{mv_sku}) {
				$it->{$attr} = Vend::Data::product_field($field,$it->{mv_sku});
			}
			return $it->{$attr};
		};
	}
	else {
		$wsub = sub {
			my $it = shift;
			my $tab = $table || $it->{mv_ib} || $Vend::Cfg->{ProductFiles}[0];
			my $w = tag_data($tab,$field,$it->{code}) || 0;
			if(! $w and $opt->{matrix} and $it->{mv_sku}) {
				$w = Vend::Data::product_field($field,$it->{mv_sku});
			}
			return $w;
		};
	}

	my $total = 0;
	CARTCHECK:
	for(@$cart) {
		if($exclude) {
			my $found;
			for my $k (keys %exclude) {
				$found = 1, last if $_->{$k} =~ $exclude{$k};
			}
			next if $found;
		}
		if($zero_unless) {
			for my $k (keys %zero_unless) {
				return 0 unless $_->{$k} =~ $zero_unless{$k};
			}
		}
		next if $_->{mv_free_shipping} && ! $opt->{no_free_shipping};
		$total += $_->{quantity} * $wsub->($_);
		next unless $osub;
		$total += $_->{quantity} * $osub->($_);
	}

	if(my $adder_thing = $opt->{tot_adder}) {
		my $adder = 0;
		my $calc_range = sub {
			my $current = shift;
			my $range = shift;
			my $add = shift;
			my ($l,$h) = split /[-:_]+/, $range;
			$l =~ s/^k//g;
			if($l < $current && $h >= $current){
				return $add;
			}
			else {
				return 0;
			}
		};

		eval {
			if(ref($adder_thing) eq 'HASH') {
				for(keys %$adder_thing) {
					$adder = $calc_range->($total, $_, $adder_thing->{$_});
					last if $adder != 0;
				}
			}
			elsif ($adder_thing =~ /=/) {
				my ($k, $v) = split /=/, $adder_thing;
				$adder = $calc_range->($total, $k, $v);
			}
			else {
				$adder = $adder_thing;
			}
		};

		if($@) {
			::logError("Bad weight adder option: %s", ::uneval($adder_thing));
		}
		else {
			$total += $adder;
		}
	}
	
	unless($opt->{no_set}) {
		$::Scratch->{$opt->{weight_scratch} ||= 'total_weight'} = $total;
	}

	return $total unless $opt->{hide};
	return;
}
EOR

UserTag weight Documentation <<EOD
=head1 NAME

ITL tag [weight] -- calculate shipping weight from cart

=head1 SYNOPSIS

 [weight]
 [weight
    attribute=1*
    cart=cartname*
    field=sh_weight*
    fill-attribute=weight*
    zero-unless-attribute="attribute=regex"
    exclude-attribute="attribute=regex"
    hide=1|0*
	matrix=1
    no-set=1|0*
    table=weights*
    weight-scratch=sh_weight*
 ]

=head1 DESCRIPTION

Calculates total weight of items in shopping cart, by default setting
a scratch variable (default "total_weight").

=head2 Options

=over 4

=item attribute

If set, weight tag will calculate from the field in the item itself instead
of going to the database. This is the most efficient, and can be enabled
by using this in catalog.cfg:

	AutoModifier  weight

The default is not set, using the database every time.

=item cart

The cart to calculate for. Defaults to current cart.

=item field

The fieldname to use -- default "weight". This applies both to attribute
and database.

=item exclude-attribute

If an attribute I<already in the cart hash> matches the regex, it
will not show up as weight. Can be a scalar or hash.

	[weight exclude-attribute="prod_group=Gift Certificates"]

and 

	[weight exclude-attribute.prod_group="Gift Certificates"]

are identical, but with the second form you can do:

	[weight
		exclude-attribute.prod_group="Gift Certificates"
		exclude-attribute.category="Downloads"
	]

The value is a regular expression, so you can group with C<|>,
or make case insensitive with:

	[weight exclude-attribute.prod_group="(?i)certificate"]

If the regular expression does not compile, an error is logged
and no exclusion is done.

It is IMPORTANT to note that you must have the attribute pre-filled
for this to work -- no database accesses will be done. If you want
to do this, use L<AutoModifier>, i.e. put in catalog.cfg:

	AutoModifier prod_group

=item fill-attribute

Sets the attribute from the database the first time, and uses it thereafter.
Sets to weight of a single unit, of course.

=item hide

Don't display the weight, only set in Scratch. It makes no sense to
use hide=1 and no-set=1.

=item matrix

If set, will get the weight from the ProductFiles for the mv_sku
attribute of the item. In other words, if the weight for a variant
is not set, it will use the weight for the base SKU.

=item no-set

Don't set the weight in scratch.

=item options

Scan the options table for applicable options and adjust weight
accordingly. Only works for "Simple" type options set in the
OptionsEnable attribute, and the o_group and weight fields must
represent the option attribute and the weight text. The weight text is a
normal Interchange option hash string type, i.e. 

	titanium=-1.2, iron=1.5

where "titanium" and "iron" are the values of an option
setting like "blade".

Will only work if your options table is SQL/DBI.

=item table

Specify a table to use to look up weights. Defaults to the table the
product was ordered from (or the first ProductFiles).

=item weight-scratch

The scratch variable name to set -- default is "total_weight".

=item zero-unless-attribute

Same as C<exclude-attribute> except that a zero weight is returned
unless B<all> items match the expression. This allows you to do
something like only offer Book Rate shipping when all items have
a prod_group of "Books".

=item totadder

Similar to 'adder' in shipping.asc, except that it allows you to add
lbs vs dollars to the total weight. There are 3 ways to add

1. Simply add X lbs per cart

[weight tot_adder=1]

Will add 1 lb to total_weight after all other weight calcs.

2. Add X lbs depending on a range of weight

[weight tot_adder.k0_25=2]

Will add 2 lbs to total_weight if weight between 0 and including 25, after all other weight calcs.

3. Add X lbs depending on multiple ranges of weight

[weight tot_adder.k0_3=1
		tot_adder.k3_6=2 
		tot_adder.k6_10=3 
		tot_adder.k10_16=4
		tot_adder.k16_25=5
	]

Will add 1 lbs to total_weight if weight greater than 0 and including 3, after all other weight calcs.
Will add 2 lbs to total_weight if weight greater than 3 and including 6, after all other weight calcs.
Will add 3 lbs to total_weight if weight greater than 6 and including 10, after all other weight calcs.
Will add 4 lbs to total_weight if weight greater than 10 and including 16, after all other weight calcs.
Will add 5 lbs to total_weight if weight greater than 16 and including 25, after all other weight calcs.


=back

=head1 AUTHOR

Mike Heins

=cut
EOD
