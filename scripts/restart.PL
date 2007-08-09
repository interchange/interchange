#!/usr/bin/perl
##!~_~perlpath~_~
#
# Interchange restarter
#
# $Id: restart.PL,v 2.6 2007-08-09 13:40:57 pajamian Exp $
#
# Copyright (C) 2002-2007 Interchange Development Group
# Copyright (C) 1996-2002 Red Hat, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA  02110-1301  USA.

use strict;

BEGIN {
	($Global::VendRoot = $ENV{MINIVEND_ROOT})
		if defined $ENV{MINIVEND_ROOT};
	$Global::VendRoot = $Global::VendRoot || '/usr/local/interchange';
#	$Global::VendRoot = $Global::VendRoot || '~_~INSTALLARCHLIB~_~';
	$Global::VendBin = $Global::VendBin || '/usr/local/interchange/bin';
#	$Global::VendBin = $Global::VendBin || '~_~INSTALLBIN~_~';
}

### END CONFIGURATION VARIABLES

my $force;
if($ARGV[0] eq '-f') {
	shift(@ARGV);
	$force = ' -q ';
}

$ENV{PATH} = "/bin:/usr/bin";
$ENV{IFS}  = " ";

# Untaint alphanuerics, periods, slashes, and minus signs
# for options
my $tmp;
for(@ARGV) {
	m{([-./\w]+)};
	$tmp = $1;
	$_ = $tmp;
}

sub prompt {
    my($pr) = shift || '? ';
    my($def) = shift;
    my $ans = '';

	return $def if $force;

    print $pr;
    print "[$def] " if $def;
	chomp($ans = <STDIN>);
    $ans ? $ans : $def;
}

sub get_id {
	my @files;
	@files = ("$Global::VendRoot/.uid", "$Global::VendRoot/_uid"); 
	my $uid;
	for(@files) {
		open(UID, "< $_") or next;
		$uid = <UID>;
		chomp($uid);
		last;
	}
	return $uid;
}

my($name,$Trysu);
if ($< == 0) {
	$name = get_id() || 'YOUR_INTERCHANGE_USER_NAME';
	die "Interchange user ID not set in $Global::VendRoot/_uid.\n" if $name eq 'YOUR_INTERCHANGE_USER_NAME';
	if(! $force and -t) {
		print <<EOM;

The Interchange server should not be run as root. It should run
as a the user name you configured in when you set up the catalogs.

The name we think should run it is: $name

If you are starting the server from /etc/rc.local or another
startup file, you can use this:

su -f -c $Global::VendBin/restart $name

or if that fails:

	su $name <<EOF
$Global::VendBin/restart
EOF

EOM
		my $ask = prompt("Do you want me to start it as '$name' now? ", 'y');
		exit 2 unless $ask =~ /^\s*y/i;
		$Trysu = 1;
	} else {
		$Trysu = 1;
	}

}

if(defined $Trysu) {
	if($^O =~ /bsd|solaris|irix/i) {
	exec <<EndOfExec or die "Couldn't exec: $!\n";
su $name <<EOF
$Global::VendBin/interchange $force -r
EOF
EndOfExec
	} else {
		exec qq{su -f -c "$Global::VendBin/interchange $force -r" $name};
	}
} else {
	exec qq{$Global::VendBin/interchange $force -r};
}

=head1 NAME

restart -- call bin/interchange C<->r with possible su

=head1 VERSION

1.0

=head1 SYNOPSIS

	restart [-f]

=head1 DESCRIPTION

The C<restart> script just tries to execute C<interchange> C<-r> with the proper permissions. If
the user is "root", a prompt will be made to see if you want to start as the guessed
user ID. (This is the contents of the $Global::VendRoot/_uid file.)

=head1 OPTIONS

The C<-f> flag prevents the prompt for superuser and forces quiet mode; this is how you might call Interchange from 
a system startup script.

=head1 SEE ALSO

interchange(1), http://www.icdevgroup.org/

=head1 AUTHOR

Mike Heins

