# The discount-space is rather equivalent to the values-space functionality.
# Interchange keeps discount information in a single hash at $Vend::Session->{discount}.
# This is fine except when you start using multiple shopping carts to represent different
# portions of the store and fundamentally different transactions; any common item codes
# will result in one cart's discounts leaking into that of the other cart...
#
# Consequently, we can use a discount space to give a different namespace to various discounts.
# This can be used in parallel with mv_cartname for different shopping carts.
# Set up a master hash of different discount namespaces in the session. Treat the default one
# as 'main' (like Interchange does with the cart). When discount space is called and a name
# is given, point the $Vend::Session->{discount} to the appropriate hashref held in this master
# hash.

# Some options:
# clear - this will empty the discounts for the space specified, after switching to that space.
# current - this will not change the namespace; it simply returns the current space name.

UserTag discount_space  order  name
UserTag discount_space  AttrAlias  space   name
UserTag discount_space  AddAttr
UserTag discount_space  Routine <<EOF
sub {
	my ($namespace, $opt) = @_;
	$namespace ||= 'main';
#::logDebug("Tag discount-space called for namespace '$namespace'! Clear: '$opt->{clear}' Current: '$opt->{current}'");

	unless ($Vend::Session->{discount} and $Vend::Session->{discount_space}) {
		# Initialize the discount space hash, and just assign whatever's in
		# the current discount hash to it as the 'main' entry.
		# Furthermore, instantiate the discount hash if it doesn't already exist, otherwise
		# the linkage between that hashref and the discount_space hashref might break...
		$Vend::Session->{discount_space}{main} = $Vend::Session->{discount} ||= {};
#::logDebug('Tag discount-space: initializing discount_space hash; first call to this tag for this session.');
		$Vend::DiscountSpace = 'main';
		$::Discounts = $Vend::Session->{discount};
	}

	return $Vend::DiscountSpace if $opt->{current};

	$::Discounts = $Vend::Session->{discount_space}{$namespace} ||= {};
	$Vend::DiscountSpace = $namespace;
#::logDebug("Tag discount-space: set discount space to '$namespace'");

	%$::Discounts = () if $opt->{clear};

	return undef;
}
EOF
