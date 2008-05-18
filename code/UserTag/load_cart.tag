# Copyright 2002-2007 Interchange Development Group and others
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.
# 
# $Id: load_cart.tag,v 1.5 2007-03-30 23:40:57 pajamian Exp $

UserTag load_cart Order     nickname
UserTag load_cart AttrAlias name nickname
UserTag load_cart Version   $Revision: 1.5 $
UserTag load_cart Routine   <<EOR
sub {
	my($nickname) = @_;

	my($jn,$updated,$recurring) = split(':',$nickname);

	$Tag->userdb({function => 'get_cart', nickname => $nickname, merge => 1});
	$Scratch->{just_nickname} = $jn;

	if($recurring eq 'c') {
		$Tag->userdb({function => 'delete_cart', nickname => $nickname});
	}

	return '';
}
EOR
