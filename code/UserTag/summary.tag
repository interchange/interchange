# Copyright 2002-2007 Interchange Development Group and others
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.
# 
# $Id: summary.tag,v 1.5 2007-03-30 23:40:57 pajamian Exp $

# [summary  amount=n.nn
#           name=label*
#           hide=1*
#           total=1*
#           reset=1*
#           format="%.2f"*
#           currency=1* ]
#
# Calculates column totals (if used properly. 8-\)
# 
#
UserTag summary Order     amount
UserTag summary PosNumber 1
UserTag summary addAttr
UserTag summary Version   $Revision: 1.5 $
UserTag summary Routine   <<EOF
sub {
    my ($amount, $opt) = @_;
	my $summary_hash = $::Instance->{tag_summary_hash} ||= {};
	my $name;
	unless ($name = $opt->{name} ) {
		$name = 'ONLY0000';
		%$summary_hash = () if Vend::Util::is_yes($opt->{reset});
	}
	else {
		$summary_hash->{$name} = 0 if Vend::Util::is_yes($opt->{reset});
	}
	$summary_hash->{$name} += $amount if length $amount;
	$amount = $summary_hash->{$name} if Vend::Util::is_yes($opt->{total});
	return '' if $opt->{hide};
	return sprintf($opt->{format}, $amount) if $opt->{format};
    return Vend::Util::currency($amount) if $opt->{currency};
    return $amount;
}
EOF
