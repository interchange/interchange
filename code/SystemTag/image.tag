# Copyright 2002-2011 Interchange Development Group and others
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.

UserTag image Order     src
UserTag image AttrAlias geometry makesize
UserTag image AttrAlias resize makesize
UserTag image AddAttr
UserTag image Version   1.25
UserTag image Routine   <<EOR
sub {
	my ($src, $opt) = @_;
	my ($image, $path, $secure, $sku);
	my ($imagedircurrent, $imagedir, $imagedirsecure);

	my @descriptionfields = grep /\S/, split /\s+/,
		$opt->{descriptionfields} || $::Variable->{DESCRIPTIONFIELDS} || $Vend::Cfg->{DescriptionField};
	@descriptionfields = qw( description ) if ! @descriptionfields;

	my @imagefields = grep /\S/, split /\s+/,
		$opt->{imagefields} || $::Variable->{IMAGEFIELDS};
	@imagefields = qw( image ) if ! @imagefields;

	my @imagesuffixes = qw( jpg gif png jpeg );
	my $filere = qr/\.\w{2,4}$/;
	my $absurlre = qr!^(?i:https?)://!;

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
		$imagedirsecure	= $Vend::Cfg->{ImageDirSecure} || $imagedir ;
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

	$opt->{getsize} = 1 unless defined $opt->{getsize}
		or (defined($opt->{height}) and defined($opt->{width}));
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
		my $ret = $src =~ /$absurlre/ ? $src : "$imagedircurrent$src";
		$ret =~ s/%(?!25)/%25/g;
		return $ret;
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
				# Support complete mogrify -geometry syntax
				# This matches: AxB, A or xB, followed by 0, 1, or 2 [+-]number
				# specs, followed by none or one of @!%><.
				$siz =~ m{^(()|\d+())(x\d+\3|x\d+\2|\3)([+-]\d+){0,2}([@!%><])?$}
					or do {
						logError("%s: Unable to make image with bad size '%s'", 'image tag', $siz);
						last MOGIT;
					};

				(my $siz_path = $siz) =~ s:[^\dx]::g;
				$dir .= "/$siz_path";
				
				my $newpath = "$dir/$fn";
				if(-f $newpath) {
					if($opt->{check_date}) {
						my $mod1 = -M $newpath;
						my $mod2 = -M $path;
						unless ($mod2 < $mod1) {
							$image =~ s:(/?)([^/]+$):$1$siz_path/$2:;
							$path = $newpath;
							last MOGIT;
						}
					}
					else {
						$image =~ s:(/?)([^/]+$):$1$siz_path/$2:;
						$path = $newpath;
						last MOGIT;
					}
				}

				$mask = umask(02);

				unless(-d $dir) {
					File::Path::mkpath($dir);
				}

				my $mgkpath = $newpath;
				my $ext;
				$mgkpath =~ s/\.(\w+)$/.mgk/
					and $ext = $1;

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
				system qq{$exec -geometry "$siz" '$newpath'};
				if($?) {
					logError("%s: Unable to mogrify image '%s'", 'image tag', $newpath);
					last MOGIT;
				}

				if(-f $mgkpath) {
					rename $mgkpath, $newpath
						or die "Could not overwrite image with new one!";
				}
				$image =~ s:(/?)([^/]+$):$1$siz_path/$2:;
				$path = $newpath;
			}
		}

		umask($mask) if defined $mask;

		if ($opt->{getsize} and $path) {
			eval {
				require Image::Size;
				my ($width, $height) = Image::Size::imgsize($path);
				$opt->{height} = $height
					if defined($height) and not exists($opt->{height});
				$opt->{width} = $width
					if defined($width) and not exists($opt->{width});
				if ($opt->{size_scratch_prefix}) {
					Vend::Interpolate::set_tmp($opt->{size_scratch_prefix} . '_' . $_, $opt->{$_})
						for qw/width height/;
				}
			};
		}
	}

	$image = $imagedircurrent . $image unless
		$image =~ /$absurlre/ or substr($image, 0, 1) eq '/';

	$image =~ s/%(?!25)/%25/g;
	return $image if $opt->{src_only};

	$opt->{title} = $opt->{alt} if ! defined $opt->{title} and $opt->{alt};

	my $opts = '';
	for (qw: width height alt title border hspace vspace align valign style class name id :) {
		if (defined $opt->{$_}) {
			my $val = $opt->{$_};
			$val = HTML::Entities::encode($val) if $val =~ /\W/;
			$opts .= qq{ $_="$val"};
		}
	}
	if($opt->{extra}) {
		$opts .= " $opt->{extra}";
	}
	$image =~ s/"/&quot;/g;
	return qq{<img src="$image"$opts$Vend::Xtrailer>};
}
EOR

