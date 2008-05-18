# Copyright 2002-2007 Interchange Development Group and others
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.
# 
# $Id: rand.tag,v 1.5 2007-03-30 23:40:57 pajamian Exp $

UserTag rand Order     file
UserTag rand posNumber 1
UserTag rand addAttr
UserTag rand hasEndTag
UserTag rand Version   $Revision: 1.5 $
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
