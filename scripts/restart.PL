#$self = {
#	INSTALLPRIVLIB => '/usr/local/minivend/lib',
#	INSTALLARCHLIB => '/usr/local/minivend',
#};

use Config;
require 'scripts/initp.pl';

sub doit {
	my ($key) = @_;
	my $val;
	if ($MV::Self->{RPMBUILDDIR} and $val = $MV::Self->{$key}) {
		$val =~ s!^$MV::Self->{RPMBUILDDIR}/!/!; 
		return $val;
	}
	return $MV::Self->{$key} unless $key =~ /[a-z]/;
	return $Config{$key};
}

DOIT: {
	local ($/);
	local($_) = <<'_EoP_';
#!/usr/bin/perl
##!~_~perlpath~_~
#
# Interchange restarter
#
# $Id: restart.PL,v 1.5 2000-09-19 20:27:47 zarko Exp $
#
# Copyright (C) 1996-2000 Akopia, Inc. <info@akopia.com>
#
# See the file 'Changes' for information.
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
# Software Foundation, Inc., 59 Temple Place, Suite 330, Boston,
# MA  02111-1307  USA.

$Global::VendRoot = $Global::VendRoot || '/usr/local/minivend';
#$Global::VendRoot = $Global::VendRoot || '~_~INSTALLARCHLIB~_~';
$Global::VendBin = $Global::VendBin || '/usr/local/minivend/bin';
#$Global::VendBin = $Global::VendBin || '~_~INSTALLBIN~_~';

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

if ($< == 0) {
	$name = get_id() || 'YOUR_MINIVEND_USER_NAME';
	die "Interchange user ID not set in $Global::VendRoot/_uid.\n" if $name eq 'YOUR_MINIVEND_USER_NAME';
	if(-t) {
		print <<EOM unless $force;

The Interchange server should not be run as root. It should run
as a the user name you configured in when you set up the catalogs.

The name we think should run it is: $name

If you are starting the server from /etc/rc.local or another
startup file, you can use this:

su -f -c $VendBin/start $name

or if that fails:

	su $name <<EOF
$Global::VendBin/start
EOF

EOM
		my $ask = prompt("Do you want me to start it as '$name' now? ", 'y');
		exit 2 unless $ask =~ /^\s*y/i;
		$Trysu = 1;
	}
	else {
		$Trysu = 1;
	}

}

if (defined $Trysu) {
	if($^O =~ /bsd|solaris|irix/i) {
	exec <<EndOfExec or die "Couldn't exec: $!\n";
su $name <<EOF
$Global::VendBin/interchange $force -r
EOF
EndOfExec
	}
	else {
		exec qq{su -f -c "$Global::VendBin/interchange $force -r" $name};
	}
}
else {
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

interchange(1), mvdocs(8), http://www.akopia.com/

=head1 AUTHOR

Mike Heins, <heins@akopia.com>


_EoP_
	s{.*\n(#(.*)~_~(\w+)~_~(.*))}{$2 . doit($3) . "$4\n$1"}eg;
	my $file = $0;
	$file =~ s/\.PL$//;
	open(OUT, ">$file") 
		or die "Create $file: $!\n";
	print OUT $_;
}
