UserTag  sleep  Documentation <<EOD
Will cause a pause for the number of seconds specified. To pause
3 seconds, do:

	[sleep 3]

EOD

UserTag  sleep  Order seconds
UserTag  sleep  Routine <<EOR
sub {
	my $secs = shift || '10';
	if($secs > 60) {
		::logError("no sleeping for more than 60 seconds");
		return;
	}
	$secs = int($secs);
	sleep($secs);
	return $secs;
}
EOR
