UserTag css Order name
UserTag css addAttr
UserTag css Routine <<EOR
sub {
	my ($name, $opt) = @_;

	use vars qw/$Tag/;

=head1 NAME

css -- ITL tag to build css files for <link>

=head1 SYNOPSIS

[css name=CSS_VAR (options)]

=head1 DESCRIPTION

Builds a CSS file from a Variable (or other source) and generates a
link to it. 

In the simplest case:

	[css THEME_CSS]

it looks for the file C<images/them_css.css>, and if it exists generates
a <C<link rel=stylesheet href="/standard/images/theme_css.css">> HTML
tag to call it.

=head2 OPTIONS

=over 4

=item basefile

If the Variable being used is dynamic via DirConfig, this should be the
file that it is contained in. The file will be checked for mod time, and
if it is newer than the CSS file the CSS will be rebuilt.

=item imagedir

An image prefix to use instead of the default (the ImageDir directive).

=item literal

The literal CSS to use instead of a Variable. Normally, you would do:

	[set my_css]
	BODY { }
 
	TD { font-size: 11 pt}
	[/set]

Then call with:

	[css literal="[scratch my_css]"]

=item media

If you need a media code for the <C<link>> tag, you can set it here. In
other words:

	[css name=THEME_CSS media=PRINT]

will generate:

	<link rel="stylesheet" media="PRINT" href="/found/images/theme_css.css">

=item mode

The mode (in octal) of the file to be created.

=item output-dir

The output directory to place the generated CSS file in, by default "images".
Obviously you must make the ImageDir match this.

=item relative

Makes the generated CSS file be relative to the directory the IC page is
in. If the current page is "info/index", and the CSS tag is called,
it will write the output to <images/info/theme_css.css> and generate:

	<link rel="stylesheet" media="PRINT" href="/found/images/info/theme_css.css">

=item timed

Regenerates the file on a timed basis. Default is the number of minutes,
but you can pass any standard Interchange interval (i.e. seconds, minutes,
days, weeks).

=back

=head1 AUTHOR

Mike Heins, Perusion <mikeh@perusion.com>

=cut

	return unless $name;

	my $bn = lc $name;
	$bn .= '.css';

	my $dir = $opt->{output_dir} ||= 'images';

	my $add_imagedir = ! $opt->{no_imagedir};

	my $id = $opt->{imagedir} || $Vend::Cfg->{ImageDir};

	$id =~ s:/*$:/:;

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
				logError("CSS dir %s has no write permission.", $dir);
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

