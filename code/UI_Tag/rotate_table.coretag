UserTag rotate-table Order rotate
UserTag rotate-table PosNumber 1
UserTag rotate-table Interpolate 1
UserTag rotate-table HasEndTag 1
UserTag rotate-table Routine <<EOR
sub {
	my ($rotate, $text) = @_;
	return $text unless $rotate;
	my $rotated = '';
	$text =~ s/(.*<TABLE.*?>)//si;
	my $out = $1 || '';
	$text =~ s:(.*?)</table\s*>:</TABLE>:si;
	my $table = $1;

	my @cols;

	while ($table =~ m:<TR.*?>(.*?)</TR>:sig) {
		push @cols, $1;
	}
	
	my $i = 0;
	my @rows;
	my @meta;
	my $rows = 0;
	my @r; my @c; my @m;
	my ($r,$c);

	for (@cols) {
		while(m:<T([HD])(.*?)>(.*?)</T\1>:sig) {
			my $meta = $1 . $2;
			push @r, $3;
			if($meta =~ /SPAN/i) {
				$meta =~ s/\bcolspan\s*=/ROWMETASPAN=/ig;
				$meta =~ s/\browspan\s*=/COLMETASPAN=/ig;
				$meta =~ s/(ROW|COL)META/$1/g;
			}
			push @m, $meta;
		}
		$meta[$i] = [@m];
		$rows[$i] = [@r];
		$i++;
		$rows = $rows < $#r ? $#r : $rows;
		undef @m;
		undef @r;
	}
	foreach $r (0 .. $rows) {
		$rotated .= "<TR>\n";
		foreach $c (0 .. $#cols) {
			$rotated .= "<T" . $meta[$c]->[$r] . ">";
			$rotated .= "$rows[$c]->[$r]";
			$rotated .= "</TD>\n"
		}
		$rotated .= "</TR>\n";
	}
	return $out . $rotated . $text;
}
EOR

