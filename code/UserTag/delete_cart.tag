# Copyright 2002 Interchange Development Group (http://www.icdevgroup.org/)
# Licensed under the GNU GPL v2. See file LICENSE for details.
# $Id: delete_cart.tag,v 1.3 2004-10-16 17:47:31 docelic Exp $

UserTag delete_cart Order nickname
UserTag delete_cart AttrAlias name nickname
UserTag delete_cart Routine <<EOR
sub {
	my($nickname) = @_;

	$Tag->userdb({function => 'delete_cart', nickname => $nickname});

	return '';
}
EOR

