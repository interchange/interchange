# Copyright 2002 Interchange Development Group (http://www.icdevgroup.org/)
# Licensed under the GNU GPL v2. See file LICENSE for details.
# $Id: delete_cart.tag,v 1.4 2005-02-10 14:38:39 docelic Exp $

UserTag delete_cart Order     nickname
UserTag delete_cart AttrAlias name nickname
UserTag delete_cart Version   $Revision: 1.4 $
UserTag delete_cart Routine   <<EOR
sub {
	my($nickname) = @_;

	$Tag->userdb({function => 'delete_cart', nickname => $nickname});

	return '';
}
EOR
