# Copyright 2002-2005 Interchange Development Group (http://www.icdevgroup.org/)
# Licensed under the GNU GPL v2. See file LICENSE for details.
# $Id: rand.tag,v 1.4 2005-11-08 18:14:42 jon Exp $

UserTag rand Order     file
UserTag rand posNumber 1
UserTag rand addAttr
UserTag rand hasEndTag
UserTag rand Version   $Revision: 1.4 $
UserTag rand Routine   <<EOR
sub {
	my ($file, $opt, $inline) = @_;
	my $sep = $opt->{separator} || '\[alt\]';
	$inline = ::readfile($file)
		if $file;
	my @pieces = split /$sep/, $inline;
	return $pieces[int(rand(scalar @pieces))] ;
}
EOR
