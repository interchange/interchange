UserTag get-url Order url
UserTag get-url AddAttr
UserTag get-url Documentation <<EOD

usage: [get-url url="valid_url" strip=1*]

Uses the LWP libraries to fetch a URL and return the contents.
If the strip option is set, strips everything up to <body> and
everything after </body>

EOD

UserTag get-url Routine <<EOR
sub {
	my ($url, $opt) = @_;
	eval {
		require LWP::Simple;
	};
	if($@) {
		::logError("Cannot use get-url tag, no LWP modules installed.");
		return undef;
	}
	my $html = LWP::Simple::get($url);
	if($opt->{strip}) {
		$html =~ s/.*<body[^>]*>//si;
		$html =~ s:</body>.*::si;
	}
	return $html;
}
EOR

