#!/usr/bin/perl -w

#
# help_make.pl
#
# Processes macros __LIKE_THIS__ in src/*.html using a template
# src/help_template.txt and saves the results in the current directory.
#
# Free under terms of the GNU General Public License.
#

use strict; 
use Cwd 'getcwd';

$| = 1;
undef $/;


# subdirectory of help HTML fragment files
my $srcname = "src";

# template file name (inside $srcname/ subdirectory)
my $templatefilename = "help_template.txt";

# top menu bar links to omit as needed
# (if template file is set up correctly)
my %menulinks = qw(
	index.html	HOME
	faq.html	FAQ
);

# help files to ignore in topic index listings
my %ignoretopicfiles = qw(
	index.html	1
	404.html	1
);


print <<'EOT';
Interchange context-sensitive help generator
Copyright (C) 2000 Akopia, Inc. <info@akopia.com>

EOT

die "No $srcname/ directory in which to find help fragments to process!"
	unless -d $srcname;
my $writedir = getcwd;
print "Complete help files will be written to $writedir\n";
my $srcdir = "$writedir/$srcname";
chdir $srcdir or die "Couldn't chdir to $srcdir: $!";
print "Reading help fragments from $srcdir\n";

# read and cache HTML template
open TEMPLATE, "<$templatefilename" or die "Couldn't read template file '$templatefilename': $!";
my $templatefile = <TEMPLATE>;
close TEMPLATE or warn "Couldn't close template file '$templatefilename': $!";

my (%topictitletofile, $filename, @reprocessfilenames);

foreach $filename (<*.html>) {
	my $file = &readfile($filename);
	next unless $file;
	print "Processing '$filename'";
	my $finalhelp = $templatefile;

	# remove link for this menu if appropriate
	if ($menulinks{$filename}) {
		my $filetoken = $menulinks{$filename};
		$finalhelp =~ s/__MENU_START_${filetoken}__.*?__MENU_END_${filetoken}__//s;
	}

	# remove unused menu link tokens
	foreach (sort values %menulinks) {
		$finalhelp =~ s/__MENU_START_${_}__//;
		$finalhelp =~ s/__MENU_END_${_}__//;
	}

	# substitute in main content
	$finalhelp =~ s/__HELP_CONTENT__/$file/g;

	# extract and cache page title
	my $title;
	if ($file =~ s|<\s*title\s*>\s*(.+)\s*<\s*/\s*title\s*>||i) {
		$title = $1;
		print " ($title)";
		$topictitletofile{$title} = $filename unless $ignoretopicfiles{$filename};
		$finalhelp =~ s/__HELP_TITLE__/$title/g;
	}

	# is postprocessing necessary?
	# (for topic list that isn't complete yet)
	push @reprocessfilenames, $filename if $finalhelp =~ /__HELP_TOPICS_LIST__/;

	print (&writefile($filename, $finalhelp) ? ": done\n" : ": error\n");
}

# build general HTML list of topic links
my $helptopicslist = "<ul>\n";
foreach (sort keys %topictitletofile) {
	$helptopicslist .= "<li><a href=\"$topictitletofile{$_}\">$_</a>\n";
}
$helptopicslist .= "</ul>\n";

# chdir back to main directory for reprocessing
chdir $writedir or die "Couldn't chdir to $writedir: $!";
foreach $filename (@reprocessfilenames) {
	my $file = &readfile($filename);
	next unless $file;
	print "Reprocessing '$filename'";
	$file =~ s/__HELP_TOPICS_LIST__/$helptopicslist/g;
	print (&writefile($filename, $file) ? ": done\n" : ": error\n");
}


sub readfile {
	my ($filename) = @_;
    open IN, "<$filename" or warn("Couldn't read '$filename': $!"), return undef;
	my $file = <IN>;
	close IN or warn("Couldn't close '$filename': $!"), return undef;
	return $file;
}

sub writefile {
	my ($filename, $data) = @_;
	my $pathname = "$writedir/$filename";
	open OUT, ">$pathname" or warn("Couldn't write '$filename': $!"), return undef;
	print OUT $data;
	close OUT or warn("Couldn't close '$filename': $!"), return undef;
	return 1;
}
