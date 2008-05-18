# Copyright 2003-2007 Interchange Development Group and others
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.
# 
# $Id: css.tag,v 1.8 2007-03-30 23:40:56 pajamian Exp $

UserTag css Order   name
UserTag css addAttr
UserTag css Version $Revision: 1.8 $
UserTag css Routine <<EOR
sub {
	my ($name, $opt) = @_;

	use vars qw/$Tag/;

	return unless $name;

	my $bn = lc $name;
	$bn .= '.css';

	my $dir = $opt->{output_dir} ||= 'images';

	my $id = "";

	if (! $opt->{no_imagedir} ) {
		$id = $opt->{imagedir} || $Vend::Cfg->{ImageDir};
		$id =~ s:/*$:/:;
	}

	$dir =~ s:/+$::;

	if($opt->{relative}) {
		my @dirs = split m{/}, $Global::Variable->{MV_PAGE};
		pop @dirs;
		if(@dirs) {
			$id .= join "/", @dirs, '';
			$dir = join "/", $dir, @dirs;
		}
	}

	my $sourcetime;
	if($opt->{basefile}) {
		$sourcetime = (stat($opt->{basefile}))[9];
#::logDebug("basefile=$opt->{basefile} sourcetime=$sourcetime");
	}

	my $url = "$id$bn";
	my $fn  = "$dir/$bn";


	my $write;
	my $success;

	my @stat = stat($fn);
	my $writable;

	if(@stat) {
		$writable = -w _;
		if($opt->{basefile}) {
			if($sourcetime > $stat[9]) {
#::logDebug("Found a basefile, out of date at modtime=$stat[9]");
				$write = 1;
			}
			else {
#::logDebug("Found a basefile, in date at modtime=$stat[9]");
				$success = 1;
			}
		}
		elsif($opt->{timed}) {
			my $now = time();
			$opt->{timed} .= ' min' if $opt->{timed} =~ /^\d+$/;
			my $secs = Vend::Config::time_to_seconds($opt->{timed});
#::logDebug("timed seconds = $secs");
			my $fliptime = $stat[9] + $secs;
#::logDebug("fliptime=$fliptime now=$now");
			if ($fliptime <= $now) {
				$write = 1;
			}
			else {
				$success = 1;
			}
		}
		else {
			$success = 1;
		}
	}
	else {
		$writable = -w $dir;
		$write = 1;
	}


	my $extra = '';
	$extra .= qq{ media="$opt->{media}"} if $opt->{media};

	my $css;

	WRITE: {
		last WRITE unless $write;
		if(! $writable) {
			if(@stat) {
				logError("CSS file %s has no write permission.", $fn);
			}
			else {
				if ( -d $dir ) {
					logError("CSS dir %s has no write permission.", $dir);
				}
				else {
					logError("CSS dir %s does not exist.", $dir);
				}
			}
			last WRITE;
		}
		my $mode = $opt->{mode} ? oct($opt->{mode}) : 0644;
		$css = length($opt->{literal})
					? $opt->{literal}
					: interpolate_html($Tag->var($name));
		$css =~ s/^\s*<style.*?>\s*//si;
		$css =~ s:\s*</style>\s*$:\n:i;
		$success = $Tag->write_relative_file($fn, $css) && chmod($mode, $fn)
			or logError("Error writing CSS file %s, returning in page", $fn);
	}

	return qq{<link rel="stylesheet" href="$url">}  if $success;
	return qq{<style type="text/css">\n$css</style>};
}
EOR
