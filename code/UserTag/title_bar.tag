# Copyright 2002 Interchange Development Group (http://www.icdevgroup.org/)
# Licensed under the GNU GPL v2. See file LICENSE for details.
# $Id: title_bar.tag,v 1.2 2005-02-10 14:38:39 docelic Exp $

UserTag title-bar Order        width size color
UserTag title-bar PosNumber    3
UserTag title-bar Interpolate  1
UserTag title-bar HasEndTag    1
UserTag title-bar Version      $Revision: 1.2 $
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
