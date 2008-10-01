# Copyright 2003-2008 Interchange Development Group and others
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.
# 
# $Id: capture_page.tag,v 1.12 2008-10-01 09:21:45 racke Exp $

UserTag capture_page Order   page file
UserTag capture_page addAttr
UserTag capture_page Version $Revision: 1.12 $
UserTag capture_page Routine <<EOR
sub {
	my ($page, $file, $opt) = @_;

	# check if we are using a file
	if ($file) {
		# check if we are allowed to write the file
		unless (Vend::File::allowed_file($file, 1)) {
			Vend::File::log_file_violation($file, 'capture_page');
			return 0;
		}

		if ($opt->{expiry}) {
			my $stat = (stat($file))[9];

			if ($stat > $opt->{expiry}) {
				if ($opt->{touch}) {
					my $now = time();
					unless (utime ($now, $now, $file)) {
						::logError ("Error on touching file $file: $!\n");
					}
				}
				return;
			}
		}
	}

	if ($opt->{scan}) {
		Vend::Page::do_scan($opt->{scan});
	}

	$::Scratch->{mv_no_count} = 1;

	# save mapped output
	my (@output, %outptr, %outfilter, %outextended, $multiout, $content, $retval);

	@output = @Vend::Output;
	%outptr = %Vend::OutPtr;
	%outfilter = %Vend::OutFilter;
	%outextended = %Vend::OutExtended;
	$multiout = $Vend::MultiOutput;

	# clear mapped output
	@Vend::Output = %Vend::OutPtr = %Vend::OutFilter = %Vend::OutExtended = ();
	$Vend::MultiOutput = 0;
		
	Vend::Page::display_page($page, {return => 1});

	for my $part (@Vend::Output) {
 		Vend::Interpolate::substitute_image($part);
		$content .= $$part;
 	}

	# restore mapped output
	@Vend::Output = @output;
	%Vend::OutPtr = %outptr;
	%Vend::OutFilter = %outfilter;
	%Vend::OutExtended = %outextended;
	$Vend::MultiOutput = $multiout;

	if ($opt->{scratch}) {
		$::Scratch->{$opt->{scratch}} = $content;
		$retval = 1;
	}

	if ($file) {
	   $retval = Vend::File::writefile (">$file", \$content,
           {auto_create_dir => $opt->{auto_create_dir},
         	umask => $opt->{umask}});
	}

	return $retval;
}
EOR
