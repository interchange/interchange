UserTag get-url Order url
UserTag get-url AddAttr
UserTag get-url Interpolate
UserTag get-url Documentation <<EOD

=pod

usage: 
[get-url url="valid_url" method="POST" strip=1 content_type="x-www-form-urlencoded" content="name=Brev" authuser="username" authpass="password" useragent="useragent string"]

Uses the LWP libraries to fetch a URL and return the contents.

The optional C<method> setting can be one of GET, HEAD, POST, or PUT.
Default (or no value) proceeds as GET.

If the C<strip> option is set, strips everything up to C<< <body> >> and
everything after C<< </body> >>.

Optional setting C<content_type> is defaulted to x-www-form-urlencoded.

Optional C<content> setting are the CGI variables to pass.  Method 
should accordingly be POST or PUT.  List should be ampersand-separated, 
i.e. "fname=Brev&lname=Patterson&state=UT". Make sure to URL Encode the
variables themselves, try using the interchange [filter op='urlencode']
tag.

Optional C<authuser> and C<authpass> are the username/password used for
authentication. Default is not to send authorization information.

=cut

EOD

UserTag get-url Routine <<EOR
require LWP::UserAgent;
sub {
	my ($url, $opt) = @_;
	my $html = '';
	
	my $ua = LWP::UserAgent->new;

	my $method = '';
	if($opt->{method}) { 
		$method = $opt->{method}; 
		if("GET HEAD POST PUT" !~ /$method/) {
			$method = "GET";
		}
	}
	else { $method = "GET"; }

	$method = uc $method;

    if($opt->{timeout}) {
		my $to = Vend::Config::time_to_seconds($opt->{timeout});
		$ua->timeout($to);
	}

	if($opt->{useragent} ) {
			$ua->agent($opt->{useragent});
	}

	if($opt->{form}) {
		$opt->{content} = Vend::Interpolate::escape_form($opt->{form});
	}

	my $do_content;

	if(($opt->{content}) && ("PUT POST" =~ /$method/)) { 
		$opt->{content_type} ||= 'application/x-www-form-urlencoded';
		$do_content = 1;
	}
	elsif($opt->{content}) {
		$url .= $opt->{url} =~ /\?/ ? '&' : '?';
		$url .= $opt->{content};
	}

	my $req = HTTP::Request->new($method, $url);

	if($do_content) {
		$req->content_type($opt->{content_type});
		$req->content($opt->{content});
	}

	if($opt->{authuser} && $opt->{authpass}) {
		$req->authorization_basic($opt->{authuser}, $opt->{authpass});
	}


	my $res = $ua->request($req);

	if ($res->is_success) {
		$html .= $res->content;
	} else {
		$html .= "Failed - " . $res->status_line;
	}

	if($opt->{strip}) {
		$html =~ s/.*<body[^>]*>//si;
		$html =~ s:</body>.*::si;
	}
	return $html;
}
EOR
