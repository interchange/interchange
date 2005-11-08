# Copyright 2002-2005 Interchange Development Group (http://www.icdevgroup.org/)
# Licensed under the GNU GPL v2. See file LICENSE for details.
# $Id: assume_identity.tag,v 1.4 2005-11-08 18:14:39 jon Exp $

UserTag assume-identity   Order        file locale
UserTag assume-identity   addAttr
UserTag assume-identity   PosNumber    2
UserTag assume-identity   Version      $Revision: 1.4 $
UserTag assume-identity   Routine      <<EOR
sub {
	my ($file, $locale, $opt) = @_;
	my $pn;
	if($opt and $opt->{name}) {
		$pn = $opt->{name};
	}
	else {
		$pn = $file;
		$pn =~ s/\.\w+$//;
		$pn =~ s:^pages/::;
	}
	$Global::Variable->{MV_PAGE} = $pn;
	$locale = 1 unless defined $locale;
	return Vend::Interpolate::interpolate_html(
		Vend::Util::readfile($file, undef, $locale)
	);
}
EOR
