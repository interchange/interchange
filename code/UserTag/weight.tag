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
			return $it->{$attr};
		};
	}
	else {
		$wsub = sub {
			my $it = shift;
			my $tab = $table || $it->{mv_ib} || $Vend::Cfg->{ProductFiles}[0];
			return tag_data($tab,$field,$it->{code});
		};
	}

	my $total = 0;
	for(@$cart) {
		$total += $_->{quantity} * $wsub->($_);
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

=item no-set

Don't set the weight in scratch.

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
