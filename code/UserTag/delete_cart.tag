# Copyright 2002-2005 Interchange Development Group (http://www.icdevgroup.org/)
# Licensed under the GNU GPL v2. See file LICENSE for details.
# $Id: delete_cart.tag,v 1.5 2005-11-08 18:14:42 jon Exp $

UserTag delete_cart Order     nickname
UserTag delete_cart AttrAlias name nickname
UserTag delete_cart Version   $Revision: 1.5 $
UserTag delete_cart Routine   <<EOR
sub {
	my($nickname) = @_;

	$Tag->userdb({function => 'delete_cart', nickname => $nickname});

	return '';
}
EOR
