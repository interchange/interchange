UserTag timed-display Order	start stop
UserTag timed-display HasEndTag
UserTag timed-display Routine <<EOR
sub {
	my ($start, $stop, $body) = @_;

	my $now = $Tag->convert_date({ fmt => '%Y%m%d%H%M%S',});
	my $else = pull_else($body);

	if (!$start){
		$start = $now - 1;
	}
	if (!$stop){
		$stop = '599900010000';#forever or at least after I die.
	}

	$start = $Tag->convert_date({ fmt => '%Y%m%d%H%M%S', body => $start,});
	$stop = $Tag->convert_date({ fmt => '%Y%m%d%H%M%S', body => $stop,});

	return $body if !$start;

	if ($start < $now and $now < $stop){
		return $body;
	}
	else {
		return $else;
	}
}

EOR

UserTag timed-display Documentation <<EOD

Purpose: To allow for date specific display of text or html in pages.

Usage: 

[timed-display start=2007060608 stop=2007060612]
Some text/code to display between June 06, 2007 between 8am and Noon.
[/timed-display]

For open ended display you can just specify a start date. 
To start immediately and end on a specific date you can just specify a stop date.

The start and stop date use the convert_date tag, so you can use any format acceptable by that tag to specify your start and stop dates. (see convert_date documentation)

EOD


