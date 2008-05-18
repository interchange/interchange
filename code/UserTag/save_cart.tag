# Copyright 2002-2007 Interchange Development Group and others
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.
# 
# $Id: save_cart.tag,v 1.7 2007-12-16 10:15:09 kwalsh Exp $

UserTag save_cart Order     nickname recurring keep
UserTag save_cart AttrAlias name nickname
UserTag save_cart Version   $Revision: 1.7 $
UserTag save_cart Routine   <<EOR
sub {
	my($nickname,$recurring,$keep) = @_;

	my $add = 0;
	my %names = ();

	$nickname =~ s/://g;
	$recurring = ($recurring?"r":"c");

	foreach(split("\n",$Tag->value('carts'))) {
		my($n,$t,$r) = split(':',$_);
		$names{$n} = $r;
		if($r eq $recurring) {
			if($n eq $nickname) {
				#$Tag->userdb({function => 'delete_cart', nickname => $_});
				$add = 1;
			}
		}
	}
	if($add) {
		while($names{"$nickname,$add"} eq $recurring) {
			$add++;
		}
		$nickname .= ",$add";
	}

	my $nn = join(':',$nickname,time(),$recurring);

	unless ($Tag->userdb({function => 'set_cart', nickname => $nn})) {
		return '';
	}

	$Carts->{main} = [] unless is_yes($keep);

	return '';
}
EOR
