# SessionFile.pm:  stores session information in files
#
# $Id: SessionFile.pm,v 1.4.2.1 2000-12-14 17:01:37 zarko Exp $
#
# Copyright (C) 1996-2000 Akopia, Inc. <info@akopia.com>
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

package Vend::SessionFile;
require Tie::Hash;
@ISA = qw(Tie::Hash);

use Symbol;
use strict;
use Vend::Util;

use vars qw($VERSION);
$VERSION = substr(q$Revision: 1.4.2.1 $, 10);

my $SessionDir;
my $CommDir;
my $CommLock;
my $SessionFile;
my $SessionLock;
my %Unlinks;
my %HaveLock;
my $Li;
my $Fi;
my $Lh;
my $Fh;
my $Last;
my @Each;

sub TIEHASH {
	my($self, $dir, $nfs) = @_;
	die "Vend::SessionFile: directory name\n"
		unless $dir;
	$SessionDir = $dir;
	if($nfs) {
		*lockfile = \*Vend::Util::fcntl_lock;
		*unlockfile = \*Vend::Util::fcntl_unlock;
	}
	bless {}, $self;
}

sub keyname {
	return Vend::Util::get_filename(shift, 2, 1, $SessionDir);
}

sub comm_keyname {
	my $file = shift;
	$file =~ m{(.*/(\w+))};
	return $Vend::Cfg->{IPCdir}
			? ( Vend::Util::get_filename($2, 2, 1, $Vend::Cfg->{IPCdir} ) )
			: $1;
}

sub FETCH {
	my($self, $key) = @_;
#::logDebug("fetch $key");
	$SessionFile = keyname($key);
	$SessionLock = $SessionFile . ".lock";
	return undef unless -f $SessionFile;
	my $str;
	unless ($HaveLock{$SessionFile}) {
		$Lh = gensym();
		open($Lh, "+>>$SessionLock")
			or die "Can't open '$SessionLock': $!\n";
		lockfile($Lh, 1, 1);
	}
	my $ref = Vend::Util::eval_file($SessionFile);
	if($Vend::Cfg->{IPC}) {
		$CommDir	= comm_keyname($SessionFile);
#::logDebug("fetch CommDir=$CommDir");
		$CommLock = "$CommDir/lock";
		my $currmask;
		unless (-d $CommDir) {
			undef $HaveLock{$SessionFile};
			$currmask = umask($Vend::Cfg->{IPCmode} ^ 0777);
			Vend::Util::exists_filename(
								$SessionFile,
								2,
								1,
								$Vend::Cfg->{IPCdir} || $SessionDir,
			);
			mkdir $CommDir, 0777
				or die "mkdir $CommDir: $!\n";
		}
		unless($HaveLock{$SessionFile}) {
			$Li = gensym();
			open($Li, "+>>$CommLock")
				or die "Can't open '$CommLock': $!\n";
			lockfile($Li, 1, 1)
				or die "lock $CommLock: $!\n";
			chmod($CommLock, $Vend::Cfg->{IPCmode} || 0777);
		}
		# We know directory pre-existed if $currmask is not defined
		$ref = {} if ! $ref;
		if(! defined $currmask) {
			opendir(COMMDIR, $CommDir);
			my @handles = grep defined $Vend::Cfg->{IPCkeys}{$_}, readdir COMMDIR;
			my $ary = $Unlinks{$SessionFile} = [];
			for(@handles) {
				$ref->{$_} = Vend::Util::eval_file("$CommDir/$_");
				push @$ary, "$CommDir/$_";
			}
			umask($currmask);
		}
	}
	$HaveLock{$SessionFile} = 1;
#::logDebug("retrieving from $SessionFile: " . ::uneval($ref));
	return $ref;
}

sub FIRSTKEY {
	my ($self) = @_;
	require File::Find
		or die "No standard Perl library File::Find!\n";
	@Each = ();
	File::Find::find( sub {
						return if ! -f $File::Find::name;
						return if $File::Find::name =~ /\.lock$/;
						push @Each, $File::Find::name;
					},
					$SessionDir,
	);
	&NEXTKEY;
}

sub NEXTKEY {
	my $key = shift @Each;
	my $last = $Last;
	$Last = $key;
	return $key;
}

sub EXISTS {
#::logDebug("check existance $_[1]");
	return Vend::Util::exists_filename($_[1], 2, 1, $SessionDir);
}

# IPC not handled yet
sub DELETE {
	my($self,$key) = @_;
	my $filename = keyname($key);
	unlink $filename;
	return 1 if $Global::Windows;
	my $lockname = $filename . ".lock";
	unlink $lockname;
}

sub STORE {
	my($self, $key, $ref) = @_;
#::logDebug("store $key");
	$SessionFile = keyname($key);
	$SessionLock = $SessionFile . ".lock";
	unlink $SessionFile;
	unless ($HaveLock{$SessionFile}) {
		$Lh = gensym();
		open($Lh, "+>>$SessionLock")
			or die "Can't open '$SessionLock': $!\n";
		lockfile($Lh, 1, 1)
			or die "lock $SessionLock: $!\n";
		
	}
	if($Vend::Cfg->{IPC}) {
		$CommDir = comm_keyname($SessionFile);
#::logDebug("CommDir=$CommDir exists=" . -d $CommDir);
		my $currmask = umask($Vend::Cfg->{IPCmode} ^ 0777);
		unless(-d $CommDir) {
			Vend::Util::exists_filename(
								$SessionFile,
								2,
								1,
								$Vend::Cfg->{IPCdir} || $SessionDir,
			);
#::logDebug("mkdir $CommDir at store");
			undef $HaveLock{$SessionFile};
			mkdir $CommDir, 0777
				or die "mkdir $CommDir: $!\n";
		}
#::logDebug("CommDir=$CommDir exists=" . -d $CommDir);
		unless ($HaveLock{$SessionFile}) {
			$CommLock = "$CommDir/lock";
			$Li = gensym();
			open($Li, "+>>$CommLock")
				or die "creat $CommLock: $!\n";
			lockfile($Li, 1, 1)
				or die "lock '$CommLock': $!\n";
			chmod($CommLock, $Vend::Cfg->{IPCmode} || 0777);
#::logDebug("locked $CommLock");
		}
		elsif ($Unlinks{$SessionFile})  {
#::logDebug("unlinking unlinks");
			unlink(@{$Unlinks{$SessionFile}});
		}
		if($Vend::Cfg->{IPCdir}) {
#::logDebug("creating IPC copy");
			Vend::Util::uneval_file($ref,"$CommDir/Session");
		}
		umask($currmask);
	}
	$HaveLock{$SessionFile} = 1;
#::logDebug("storing in $SessionFile: " . ::uneval($ref));
	Vend::Util::uneval_file($ref,$SessionFile);
}
	
sub DESTROY {
	my($self) = @_;
	unlockfile($Li) and close($Li)
		if $Li;
	unlockfile($Lh)
		and delete $HaveLock{$SessionFile};
	close($Lh);
	undef $self;
}

1;
__END__
