# Copyright 2002 Interchange Development Group (http://www.icdevgroup.org/)
# Licensed under the GNU GPL v2. See file LICENSE for details.
# $Id: output_to.tag,v 1.2 2005-02-09 13:39:42 docelic Exp $

UserTag output-to Order      name
UserTag output-to addAttr
UserTag output-to hasEndTag
UserTag output-to Version    $Revision: 1.2 $
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
