UserTag quick_table HasEndTag
UserTag quick_table Interpolate
UserTag quick_table Order   border
UserTag quick_table Routine <<EOR
sub {
	my ($border,$input) = @_;
	$border = " BORDER=$border" if $border;
	my $out = "<TABLE ALIGN=LEFT$border>";
	my @rows = split /\n+/, $input;
	my ($left, $right);
	for(@rows) {
		$out .= '<TR><TD ALIGN=RIGHT VALIGN=TOP>';
		($left, $right) = split /\s*:\s*/, $_, 2;
		$out .= '<B>' unless $left =~ /</;
		$out .= $left;
		$out .= '</B>' unless $left =~ /</;
		$out .= '</TD><TD VALIGN=TOP>';
		$out .= $right;
		$out .= '</TD></TR>';
		$out .= "\n";
	}
	$out .= '</TABLE>';
}
EOR

