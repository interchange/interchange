UserTag weight Order attribute
UserTag weight addAttr
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
					AND    weight != ''
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
	for(@$cart) {
		$total += $_->{quantity} * $wsub->($_);
		next unless $osub;
		$total += $_->{quantity} * $osub->($_);
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

=back

=head1 AUTHOR

Mike Heins

=cut
EOD
