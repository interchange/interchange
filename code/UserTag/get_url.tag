UserTag get-url Order url
UserTag get-url AddAttr
UserTag get-url Documentation <<EOD

=pod

	[get-url url="valid_url" strip=1*]

Uses the LWP libraries to fetch a URL and return the contents.
If the C<strip> option is set, strips everything up to C<< <body> >> and
everything after C<< </body> >>.

=cut

EOD

UserTag get-url Routine <<EOR
require LWP::Simple;
sub {
	my ($url, $opt) = @_;
	my $html = LWP::Simple::get($url);
	if($opt->{strip}) {
		$html =~ s/.*<body[^>]*>//si;
		$html =~ s:</body>.*::si;
	}
	return $html;
}
EOR

