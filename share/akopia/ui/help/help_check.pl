#!/usr/bin/perl -w

#
# help_check.pl
# a quick hack
#
# checks to see which topic names are used but don't exist,
# and vice versa
#
# crutch: uses rgrep, a not necessarily common system tool
#

use Cwd;
$oldpwd = getcwd;

chdir "../../../..";
@lines = `rgrep -r help_name *`;
foreach (@lines) {
	next if /help_check\.pl/;
	push (@{ $help_name{$1} }, $_), next if /\[\s*set\s*help_name\s*\]\s*(\S+)\s*\[/;
	push (@{ $help_name{$1} }, $_), next if /help_name=([^&\s]+)/;
}

print "Unused help files:\n";
chdir "$oldpwd/src";
@files = glob("*.html");
foreach (@files) {
	s/\.html$//i;
	++$files{$_};
	print "$_.html\n" unless $help_name{$_};
}

print "\nHelp topics referencing non-existent files:\n";
foreach (sort keys %help_name) {
	print "$_\n" unless $files{$_};
}

print "\nAll help topics used in UI templates:\n";
foreach $topic (sort keys %help_name) {
	print "* $topic: ";
	foreach (@{$help_name{$topic}}) {
		print /(^[^:]+)/, " ";
	}
	print "\n";
}
