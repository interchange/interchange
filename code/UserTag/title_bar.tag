# Copyright 2002-2007 Interchange Development Group and others
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.
# 
# $Id: title_bar.tag,v 1.4 2007-03-30 23:40:57 pajamian Exp $

UserTag title-bar Order        width size color
UserTag title-bar PosNumber    3
UserTag title-bar Interpolate  1
UserTag title-bar HasEndTag    1
UserTag title-bar Version      $Revision: 1.4 $
UserTag title-bar Routine      <<EOR
sub {
	my ($width, $size, $color, $text) = @_;
	$width = 500 unless defined $width;
	$size = 6 unless defined $size;
	$color = ($::Variable->{HEADERBG} || '#444444') unless defined $color;
	$color = qq{BGCOLOR="$color"} unless $color =~ /^\s*bgcolor=/i;
	my $tcolor = $::Variable->{HEADERTEXT} || 'WHITE';
	$text = qq{<FONT COLOR="$tcolor" SIZE="$size">$text</FONT>};
	return <<EOF;
<TABLE CELLSPACING=0 CELLPADDING=6 WIDTH="$width"><TR><TD VALIGN=CENTER $color>$text</TD></TR></TABLE>
EOF
}
EOR
