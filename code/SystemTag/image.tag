UserTag image Version 0.03
UserTag image Order src
UserTag image AddAttr
UserTag image Documentation <<EOD

=head2 image

This is a general-purpose tag for inserting HTML C<< <img> >> tags based on
various settings, with the ability to test whether an image exists,
predetermine its pixel dimensions, retrieve the image name from the
product database field B<image> for that sku, automatically pull product
descriptions from the database for use in the B<alt> and B<title>
attributes, and access http/secure and storefront/admin UI image
directory names.

A convenient use is for displaying product images, for example on the
flypage:

	[image [item-code]]

Given sku os29000 in the Foundation demo, and assuming the products
database specifies os29000.gif in the B<image> field for os29000,
the tag returns HTML code something like this:

	<img src="/foundation/images/os29000.gif" width=120 height=150
	alt="3' Step Ladder" title="3' Step Ladder">

If file os29000.gif hadn't existed, or the products database B<image>
field were empty, the tag would check for files called "(sku).jpg",
"(sku).gif", etc. and use the first one it found.

You can also specify a particular image filename, but also give the
sku to look up the description in the database:

	[image sku="[item-code]" src="/foundation/silly/putty.jpg"]

You can force the use of an image filename even if the file doesn't
exist (for example, if it is on a different server). Any absolute URL
(http://... or https://...) is always accepted without checking, and
the B<force> attribute overrides checking on any filename.

One peculiar use is with the B<dir_only> parameter to return the correct
prefix for images (normal or secure), primarily for adding to image names
found in e.g. JavaScript code (rollovers, etc.) that we can't hope to
have Interchange parse on its own as it does for plain HTML by default.

Parameters for this tag are:

=over 4

=item alt

Text to use for the C<< <img alt="..."> >> attribute. By default, this will
be filled with the B<description> from the product database if a sku (not
a filename) is provided.

=item default

Set this attribute to an image filename or relative or absolute URL
to use if the file named in the B<src> attribute or the filename
found in the product table B<image> field are not found.

Defaults to scratch mv_defaultimage if set.

=item descriptionfields

A whitespace-separated list of fields in the product database from which
to draw the description, used as the default in alt and title attributes.
Catalog variable DESCRIPTIONFIELDS is a fallback if this option is not
passed in.

=item dir_only

Set this attribute to 1 to return only the text of configuration
variable ImageDir or ImageDirSecure, depending on whether the page is
being delivered through the web server by http or https.

=item exists_only

Set this attribute to 1 if you want to check only whether an appropriate
image file exists. The tag will return '1' if an image exists, and nothing
if not.

=item force

Skip checking for existence of image file.

=item getsize

Use the Perl Image::Size module, if available, to determine the image's
width and height in pixels, and pass them as arguments to the <img> tag.

This is the default behavior; pass B<getsize=0> to disable.

=item imagesubdir

Look for any image filenames in the named subdirectory of the ImageDir,
rather than directly in the ImageDir.

For example, with the Foundation demo, the individual product images are
in the subdirectory B<items/>, so you would set B<imagesubdir=items>. This
is better than passing in B<src="items/os28009.gif"> because the tag
knows the sku and can do products database lookups based on it.

Defaults to scratch mv_imagesubdir if set.

=item makesize

If ImageMagick is installed, you can display an arbitrary size of
the image, creating it if necessary.

This will create a subdirectory corresponding to the size, (i.e. 64x48)
and copy the source image to it. It will then use the ImageMagick C<mogrify>
command to resize.

This requires a writable image directory, of course.

Looks for the c<mogrify> command in the path (with /usr/X11R6/bin added).
If it will not be found there, or to improve performance slightly, you
can set in interchange.cfg:

	Variable IMAGE_MOGRIFY  /path/to/mogrify

Sets umask to 2 temporarily when creating directories or files.

=item secure

This attribute forces using either secure or insecure image directories,
regardless of the actual current delivery method. Set to 1 to force
secure, 0 to force insecure. Note that this is not a quick way to force
using a secure B<URL> -- just a secure directory path.

=item sku

Specify a sku explicitly if you want to first try an arbitrarily-named
image in B<src>, then if it does not exist, fall back to sku-derived
image filenames.

=item src

Image filename to use. May also be a plain sku, or an image basename
which will be tried with various image suffixes (.jpg, .gif, .png, etc.)

=item title

Text to use for the <img title="..."> attribute, used by more recent
browsers for e.g. rollover tip text display. This attribute defaults the
same text as the B<alt> attribute.

=item ui

Set this attribute to 1 to use admin UI image URL prefixes in catalog or
global variables UI_IMAGE_DIR and UI_IMAGE_DIR_SECURE instead of regular
catalog image prefixes from ImageDir and ImageDirSecure.

=back

=cut

EOD

UserTag image Routine <<EOR
sub {
	my ($src, $opt) = @_;
	my ($image, $path, $secure, $sku);
	my ($imagedircurrent, $imagedir, $imagedirsecure);

	my @descriptionfields = grep /\S/, split /\s+/,
		$opt->{descriptionfields} || $::Variable->{DESCRIPTIONFIELDS};
	@descriptionfields = qw( description ) if ! @descriptionfields;

	my @imagefields = qw( image );
	my @imagesuffixes = qw( jpg gif png jpeg );
	my $filere = qr/\.\w{2,4}$/;
	my $absurlre = qr/^(?i:https?)/;

	if ($opt->{ui}) {
		# unless no image dir specified, add locale string
		my $locale = $Scratch->{mv_locale} ? $Scratch->{mv_locale} : 'en_US';
		$imagedir		= $::Variable->{UI_IMAGE_DIR}
						|| $Global::Variable->{UI_IMAGE_DIR};
		$imagedirsecure	= $::Variable->{UI_IMAGE_DIR}
						|| $Global::Variable->{UI_IMAGE_DIR};
		for ($imagedir, $imagedirsecure) {
			if ($_) {
				$_ .= '/' if substr($_, -1, 1) ne '/';
				$_ .= $locale . '/';
			}
		}
	} else {
		$imagedir		= $Vend::Cfg->{ImageDir};
		$imagedirsecure	= $Vend::Cfg->{ImageDirSecure};
	}

	# make sure there's a trailing slash on directories
	for ($imagedir, $imagedirsecure) {
		$_ .= '/' if $_ and substr($_, -1, 1) ne '/';
	}

	if (defined $opt->{secure}) {
		$secure = $opt->{secure} ? 1 : 0;
	} else {
		$secure = $CGI::secure;
	}

	$imagedircurrent = $secure ? $imagedirsecure : $imagedir;

	return $imagedircurrent if $opt->{dir_only};

	$opt->{getsize} = 1 unless defined $opt->{getsize};
	$opt->{imagesubdir} ||= $::Scratch->{mv_imagesubdir}
		if defined $::Scratch->{mv_imagesubdir};
	$opt->{default} ||= $::Scratch->{mv_imagedefault}
		if defined $::Scratch->{mv_imagedefault};

	if ($opt->{sku}) {
		$sku = $opt->{sku};
	} else {
		# assume src option is a sku if it doesn't look like a filename
		if ($src !~ /$filere/) {
			$sku = $src;
			undef $src;
		}
	}

	if($opt->{name_only} and $src) {
		return $src =~ /$absurlre/ ? $src : "$imagedircurrent$src";
	}

	if ($src =~ /$absurlre/) {
		# we have no way to check validity or create/read sizes of full URLs,
		# so we just assume they're good
		$image = $src;
	} else {

		my @srclist;
		push @srclist, $src if $src;
		if ($sku) {
			# check all products tables for image fields
			for ( @{$Vend::Cfg->{ProductFiles}} ) {
				my $db = Vend::Data::database_exists_ref($_)
					or die "Bad database $_?";
				$db = $db->ref();
				my $view = $db->row_hash($sku)
					if $db->record_exists($sku);
				if (ref $view eq 'HASH') {
					for (@imagefields) {
						push @srclist, $view->{$_} if $view->{$_};
					}
					# grab product description for alt attribute
					unless (defined $opt->{alt}) {
						for (@descriptionfields) {
							($opt->{alt} = $view->{$_}, last)
								if $view->{$_};
						}
					}
				}
			}
		}
		push @srclist, $sku if $sku;
		push @srclist, $opt->{default} if $opt->{default};

		if ($opt->{imagesubdir}) {
			$opt->{imagesubdir} .= '/' unless $opt->{imagesubdir} =~ m:/$:;
		}
		my $dr = $::Variable->{DOCROOT};
		my $id = $imagedircurrent;
		$id =~ s:/+$::;
		$id =~ s:/~[^/]+::;

		IMAGE_EXISTS:
		for my $try (@srclist) {
			($image = $try, last) if $try =~ /$absurlre/;
			$try = $opt->{imagesubdir} . $try;
			my @trylist;
			if ($try and $try !~ /$filere/) {
				@trylist = map { "$try.$_" } @imagesuffixes;
			} else {
				@trylist = ($try);
			}
			for (@trylist) {
				if ($id and m{^[^/]}) {
					if ($opt->{force} or ($dr and -f "$dr$id/$_")) {
						$image = $_;
						$path = "$dr$id/$_";
					}
				} elsif (m{^/}) {
					if ($opt->{force} or ($dr and -f "$dr/$_")) {
						$image = $_;
						$path = "$dr/$_";
					}
				}
				last IMAGE_EXISTS if $image;
			}
		}

		return unless $image;
		return 1 if $opt->{exists_only};

		my $mask;

		if($opt->{makesize} and $path) {
			my $dir = $path;
			$dir =~ s:/([^/]+$)::;
			my $fn = $1;
			my $siz = $opt->{makesize};
			MOGIT: {
				$siz =~ s/\W+//g;
				$siz =~ m{^\d+x\d+$}
					or do {
						logError("%s: Unable to make image with bad size '%s'", 'image tag', $siz);
						last MOGIT;
					};

				$dir .= "/$siz";
				
				my $newpath = "$dir/$fn";
				if(-f $newpath) {
					$image =~ s:(/?)([^/]+$):$1$siz/$2:;
					$path = $newpath;
					last MOGIT;
				}

				$mask = umask(02);

				unless(-d $dir) {
					File::Path::mkpath($dir);
				}

				File::Copy::copy($path, $newpath)
					or do {
						logError("%s: Unable to create image '%s'", 'image tag', $newpath);
						last MOGIT;
					};
				my $exec = $Global::Variable->{IMAGE_MOGRIFY};
				if(! $exec) {
					my @dirs = split /:/, "/usr/X11R6/bin:$ENV{PATH}";
					for(@dirs) {
						next unless -x "$_/mogrify";
						 $exec = "$_/mogrify";
						 $Global::Variable->{IMAGE_MOGRIFY} = $exec;
						last;
					}
				}
				last MOGIT unless $exec;
				system "$exec -geometry $siz $newpath";
				if($?) {
					logError("%s: Unable to mogrify image '%s'", 'image tag', $newpath);
					last MOGIT;
				}

				$image =~ s:(/?)([^/]+$):$1$siz/$2:;
				$path = $newpath;
			}
		}

		umask($mask) if defined $mask;

		if ($opt->{getsize} and $path) {
			eval {
				require Image::Size;
				my ($width, $height) = Image::Size::imgsize($path);
				($opt->{width}, $opt->{height}) = ($width, $height)
					if $width and $height;
			};
		}
	}

	$opt->{title} = $opt->{alt} if ! defined $opt->{title} and $opt->{alt};

	my $opts = '';
	for (qw: width height alt title border hspace vspace :) {
		if (defined $opt->{$_}) {
			my $val = $opt->{$_};
			$val = '"' . HTML::Entities::encode($val) . '"'
				if $val =~ /\W/;
			$val = '""' if $val eq '';
			$opts .= qq{ $_=$val};
		}
	}
	if($opt->{extra}) {
		$opts .= " $opt->{extra}";
	}
	$image = $imagedircurrent . $image unless
		$image =~ /$absurlre/ or substr($image, 0, 1) eq '/';
	$image =~ s/"/&quot;/g;
	return qq{<img src="$image"$opts>};
}
EOR
