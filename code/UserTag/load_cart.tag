# Copyright 2002 Interchange Development Group (http://www.icdevgroup.org/)
# Licensed under the GNU GPL v2. See file LICENSE for details.
# $Id: load_cart.tag,v 1.2 2004-10-16 21:50:43 docelic Exp $

UserTag load_cart Order nickname
UserTag load_cart AttrAlias name nickname
UserTag load_cart Routine <<EOR
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
