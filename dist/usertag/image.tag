UserTag image Version 0.01
UserTag image AddAttr
UserTag image Documentation <<EOD

=head2 image

This tag will eventually be a general-purpose tag for inserting HTML
<img> tags based on various settings, with the ability to test whether
an image exists, etc.

Currently it is only used to return the correct prefix for images (normal
or secure), primarily for adding to image names found in e.g. JavaScript
code (rollovers, etc.) that we can't hope to have Interchange parse on
its own as it does for plain HTML by default.

Parameters for this tag are:

=over 4

=item dir_only

Set this attribute to 1 to return only the text of configuration
variable ImageDir or ImageDirSecure, depending on whether the page is
being delivered through the web server by http or https.

(The tag current is a noop if this is not set.)

=item secure

This attribute forces using either secure or insecure URLs, regardless
of the actual current delivery method. Set to 1 to force secure, 0 to
force insecure.

=item ui

Set this attribute to 1 to use admin UI image URL prefixes in catalog or
global variables UI_IMAGE_DIR and UI_IMAGE_DIR_SECURE instead of regular
catalog image prefixes from ImageDir and ImageDirSecure.

=back

EOD

UserTag image Routine <<EOR
sub {
	my ($opt) = @_;
	my ($imagedircurrent, $imagedir, $imagedirsecure, $secure);

	if ($opt->{ui}) {
		# unless no image dir specified, add locale string and
		# make sure there's a trailing slash
		my $l = $Scratch->{mv_locale} ? $Scratch->{mv_locale} : 'en_US';
		$imagedir		= $::Variable->{UI_IMAGE_DIR}
						|| $Global::Variable->{UI_IMAGE_DIR};
		$imagedirsecure	= $::Variable->{UI_IMAGE_DIR}
						|| $Global::Variable->{UI_IMAGE_DIR};
		for ($imagedir, $imagedirsecure) {
			if ($_) {
				$_ .= '/' if substr($_, -1, 1) ne '/';
				$_ .= $l . '/';
			}
		}
	} else {
		$imagedir		= $Vend::Cfg->{ImageDir};
		$imagedirsecure	= $Vend::Cfg->{ImageDirSecure};
	}

	if (defined $opt->{secure}) {
		$secure = $opt->{secure} ? 1 : 0;
	} else {
		$secure = $CGI::secure;
	}

	$imagedircurrent = $secure ? $imagedirsecure : $imagedir;

	return $imagedircurrent if $opt->{dir_only};

	return;
}
EOR
