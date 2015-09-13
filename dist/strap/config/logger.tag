UserTag logger Order name file
UserTag logger addAttr
UserTag logger Routine <<EOR
sub {
	my ($name, $file, $opt) = @_;
	use vars qw/$Tag/;

	my $log = sub {
		my $msg = errmsg(@_);
		Log( $msg, { file => $file });
		return;
	};
	my $die = sub {
		my $msg = errmsg(@_);
		$Tag->error( { name => $name, set => $msg });
		Log( "died: $msg", { file => $file });
		return;
	};
	my $warn = sub {
		my $msg = errmsg(@_);
		$Tag->warnings( $msg );
		Log( $msg, { file => $file });
		return;
	};

	return($log, $die, $warn);
}
EOR
UserTag logger Documentation <<EOD
	Use like:
	my ($log, $die, $warn) = $Tag->logger('munge_mv_order', 'logs/munge.log');
EOD
