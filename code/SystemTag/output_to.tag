# Copyright 2002-2007 Interchange Development Group and others
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.
# 
# $Id: output_to.tag,v 1.4 2007-03-30 23:40:49 pajamian Exp $

UserTag output-to Order      name
UserTag output-to addAttr
UserTag output-to hasEndTag
UserTag output-to Version    $Revision: 1.4 $
UserTag output-to Routine    <<EOR
sub {
	my ($name, $opt, $body) = @_;
	$name ||= '';
	$name = lc $name;
	my $nary = $Vend::OutPtr{$name} ||= [];
	push @Vend::Output, \$body;
	push @$nary, $#Vend::Output;
	return;
}
EOR
