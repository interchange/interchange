UserTag read-ui-page Order page 
UserTag read-ui-page addAttr
UserTag read-ui-page Documentation <<EOD
[read-ui-page page="<filespec>"]

Returns the structure of a page.

Returns the content in the ui_content key of the hash, which is the
section between <!-- BEGIN CONTENT --> and <!-- END CONTENT -->.


Returns the component settings as an array with the elements
as major keys, i.e:

	[control-set]
		[size]1[/size]
		[color]red[/color]
	[/control-set]

	[control-set]
		[size]5[/size]
		[color]green[/color]
		[banner]Very Green[/banner]
	[/control-set]

becomes:

	[
		{ size => 1, color => 'red' },
		{ size => 5, color => 'green', banner => 'Very Green' },
	]

If the textref=1 is passed in the tag call, a stringified version is
returned.

EOD

UserTag read-ui-page Routine <<EOR
sub {
	my ($pn, $opt) = @_;
	
	my $suffix  = $Vend::Cfg->{HTMLsuffix} || '.html';
	my $pagedir = $Vend::Cfg->{PageDir} || 'pages';
	my $name = $pn;
	my $data;

	if($pn) {
		if(not -f $pn) {
			$pn .= $suffix if $pn !~ /$suffix$/;
		}
		if(not -f $pn) {
			$pn = "$pagedir/$pn";
		}
		$data = Vend::Util::readfile($pn, $Global::NoAbsolute, 0);
	}
	else {
		$data = $opt->{body} || '';
	}

	return undef unless length($data);

	my $ref = {
			ui_page_file => $pn,
			ui_page_name => $name,
		};
			
	if ( 
		$data =~ m{
			<!--\s+begin\s+content\s+-->
			\n?
			(.*?)
			\n?
			<!--\s+end\s+content\s+-->
			}xsi
		)
	{
		$ref->{ui_content} = $1;
	}
	else {
		$ref->{ui_content} = $data;
	}

	my @comps;

	sub _setref {
		my ($ref, $key, $val) = @_;
		$key = lc $key;
		$key =~ tr/-/_/;
Log("_setref key=$key val=$val");
		$ref->{$key} = $val;
	}

	if($data =~ m/
						\[control \s+ reset .*? \]
						(.*?)
						\[control \s+ reset .*? \]
					/six)
	{
		# New style
		my $stuff = $1;
		while($stuff =~ m{\[control-set\](.*?)\[/control-set\]}isg ) {
			my $sets = $1;
			my $r = {};
			$sets =~ s{\[([-\w]+)\](.*?)\[/\1\]}{ _setref($r, $1, $2) }eisg;
			push @comps, $r;
		}
	}


	$ref->{ui_component} = \@comps;
	my $tref = {};

	# Global controls
	my $comp_text = $data;
	while($comp_text =~ m{\[(set|tmp|seti)\s+([^\]]+)\](.*?)\[/\1\]}isg ) {
		$tref->{$2} = $3;
	}

	$ref->{ui_page_setting} = $tref;

Log("page reference: " . uneval($ref) );
	return $opt->{textref} ? uneval_it($ref) : $ref;

}
EOR
