UserTag read-ui-page Order page 
UserTag read-ui-page addAttr
UserTag read-ui-page Documentation <<EOD
[read-ui-page page="<filespec>"]

Returns the structure of a page.


ui_component

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

ui_component_text

	The component settings as text, in the event component settings are
	not to be edited.

ui_page_setting

	Returns the page global settings as a hash. Reads [set|tmp|seti ..][/set]
	in the area above the first template region (i.e. @_LEFTONLY_TOP_@), but outside
	of the [control] region.

		[set page_title]Some title[/set]
		[set members_only][/set]

	becomes:

		{ page_title => 'Some title', members_only => 1 }

ui_page_setting_text

	The text of the page setting area, used if the page settings are not to
	be edited.

If the textref=1 is passed in the tag call, a stringified version is
returned.

ui_content

    Returns the content, which is the section between
	<!-- BEGIN CONTENT --> and <!-- END CONTENT -->.

EOD

UserTag read-ui-page Routine <<EOR
sub {
	my ($pn, $opt) = @_;
#::logDebug("read_ui_page pn=$pn");
	my $suffix  = $Vend::Cfg->{HTMLsuffix} || '.html';
	my $tmpdir  = $Vend::Cfg->{ScratchDir} || 'tmp';
	my $pagedir = $Vend::Cfg->{PageDir} || 'pages';
	$tmpdir .= "/pages/$Session->{id}";
	File::Path::mkpath($tmpdir) unless -d $tmpdir;
	my $name = $pn;
	my $data;
	my $inprocess;

	### We look for a saved but unpublished page in 
	### the temporary space for the user, and use that if
	### it is there. Otherwise, we read normally.
	if($pn) {
		FINDPN: {
			$pn = "$tmpdir/$name";
			if(-f $pn) {
				$inprocess = 1;
				last FINDPN;
			}

			if ($pn !~ /$suffix$/) {
				$pn .= $suffix;
				if(-f $pn) {
					$inprocess = 1;
					last FINDPN;
				}
			}

			$pn = $name;
			last FINDPN if -f $pn;

			$pn .= $suffix if $pn !~ /$suffix$/;
		}
		$data = Vend::Util::readfile($pn, $Global::NoAbsolute, 0);
	}
	else {
		$data = $opt->{body} || '';
	}

	return undef unless length($data);

	my $ref = {
			ui_page_file	=> $pn,
			ui_page_name	=> $name,
			ui_component	=> [],
			ui_page_setting	=> {},
			ui_pre_region	=> [],
			ui_post_region	=> [],
			ui_page_inprocess => $inprocess,
		};

	my $preamble;
	my $postamble;
			
	if ( 
		$data =~ m{
			(.*)
			<!--\s+begin\s+content\s+-->
			\n?
			(.*?)
			\n?
			<!--\s+end\s+content\s+-->
			(.*)
			}xsi
		)
	{
		$preamble = $1;
		$ref->{ui_content} = $2;
		$postamble = $3;
	}
	else {
		$ref->{ui_content} = $data;
		return uneval($ref) if $opt->{textref};
		return $ref;
	}

	my @comps;

	sub _setref {
		my ($ref, $key, $val) = @_;
		$key = lc $key;
		$key =~ tr/-/_/;
#Log("_setref key=$key val=$val");
		$ref->{$key} = $val;
	}

	if ( 
		$preamble =~ s{
			<!--\s+begin\s+preamble\s+-->
			\n?
			(.*?)
			\n?
			<!--\s+end\s+preamble\s+-->\n?
			}{}xsi
		)
	{
		$ref->{ui_page_preamble} = $1;
	}

	if ( 
		$postamble =~ s{
			<!--\s+begin\s+postamble\s+-->
			\n?
			(.*?)
			\n?
			<!--\s+end\s+postamble\s+-->
			}{}xsi
		)
	{
		$ref->{ui_page_postamble} = $1;
	}

	while ($preamble =~ s/^[ \t]*((?:\@_|__|\@\@)[A-Z][A-Z_]+[A-Z](?:_\@|__|\@\@))[ \t]*$//m ) {
		push @{$ref->{ui_pre_region}}, $1;
	}

	while($postamble =~ s/^[ \t]*((?:\@_|__|\@\@)[A-Z][A-Z_]+[A-Z](?:_\@|__|\@\@))//m ) {
		push @{$ref->{ui_post_region}}, $1;
	}

	$postamble =~ s/^\s+//;
	$postamble =~ s/\s+$//;
	$ref->{ui_page_end} = $postamble;

	if($preamble =~ s/
						(\[control \s+ reset .*? \]
						*?
						\[control \s+ reset .*? \])
					//six)
	{
		# New style
		my $stuff = $1;
		$ref->{ui_component_text} = $stuff;
		while($stuff =~ s{\[control-set\](.*?)\[/control-set\]}{}is ) {
			my $sets = $1;
			my $r = {};
			$sets =~ s{\[([-\w]+)\](.*?)\[/\1\]}{ _setref($r, $1, $2) }eisg;
			push @comps, $r;
		}

		$stuff =~ s/^\s+//;
		$stuff =~ s/\s+$//;
		$ref->{ui_component} = \@comps;
	}

	my $tref = {};

	# Global controls
	$ref->{ui_page_setting_text} = '';
	while($preamble =~ s{(\[(set|tmp|seti)\s+([^\]]+)\](.*?)\[/\2\])}{}is ) {
		$tref->{$3} = $4;
		$ref->{ui_page_setting_text} .= "$1\n";
	}

	$preamble =~ s/^\s+//;
	$preamble =~ s/\s+$//;
	$ref->{ui_page_begin} = $preamble;

	$ref->{ui_page_setting} = $tref;

#Log("page reference: " . uneval($ref) );
	return uneval_it($ref) if $opt->{textref};
	return $ref;

}
EOR
