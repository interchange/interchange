# Copyright 2002-2005 Interchange Development Group (http://www.icdevgroup.org/)
# Licensed under the GNU GPL v2. See file LICENSE for details.
# $Id: output_to.tag,v 1.3 2005-11-08 18:14:36 jon Exp $

UserTag output-to Order      name
UserTag output-to addAttr
UserTag output-to hasEndTag
UserTag output-to Version    $Revision: 1.3 $
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
