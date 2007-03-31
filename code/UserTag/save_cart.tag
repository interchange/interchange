# Copyright 2002-2007 Interchange Development Group and others
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.
# 
# $Id: save_cart.tag,v 1.4.2.1 2007-03-31 00:20:18 pajamian Exp $

UserTag save_cart Order     nickname recurring
UserTag save_cart AttrAlias name nickname
UserTag save_cart Version   $Revision: 1.4.2.1 $
UserTag save_cart Routine   <<EOR
sub {
	my($nickname,$recurring) = @_;

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

	$Tag->userdb({function => 'set_cart', nickname => $nn});

	$Carts->{main} = [];

	return '';
}
EOR
