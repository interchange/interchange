# Vend::File - Interchange file functions
#
# Copyright (C) 2002-2009 Interchange Development Group
# Copyright (C) 1996-2002 Red Hat, Inc.
#
# This program was originally based on Vend 0.2 and 0.3
# Copyright 1995 by Andrew M. Wilcox <amw@wilcoxsolutions.com>
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

package Vend::File;
require Exporter;

@ISA = qw(Exporter);

@EXPORT = qw(
	absolute_or_relative
	allowed_file
	catfile
	exists_filename
	file_allow
	file_modification_time
	file_name_is_absolute
	get_filename
	lockfile
	log_file_violation
	readfile
	readfile_db
	set_lock_type
	unlockfile
	writefile
);

use strict;
use Config;
use Fcntl;
use Errno;

unless( $ENV{MINIVEND_DISABLE_UTF8} ) {
	require Encode;
	import Encode qw( is_utf8 );
}

use Vend::Util;
use File::Path;
use File::Copy;
use subs qw(logError logGlobal);
use vars qw($VERSION @EXPORT @EXPORT_OK $errstr);
$VERSION = '2.33';

sub writefile {
    my($file, $data, $opt) = @_;
	my($encoding, $fallback);

	if ($::Variable->{MV_UTF8}) {
		$encoding = $opt->{encoding} ||= 'utf-8';
		undef $encoding if $encoding eq 'raw';
		$fallback = $opt->{fallback};
		$fallback = Encode::PERLQQ() unless defined $fallback;
	}

	$file = ">>$file" unless $file =~ /^[|>]/;
	if (ref $opt and $opt->{umask}) {
		$opt->{umask} = umask oct($opt->{umask});
	}
    eval {
		unless($file =~ s/^[|]\s*//) {
			if (ref $opt and $opt->{auto_create_dir}) {
				my $dir = $file;
				$dir =~ s/>+//;

				## Need to make this OS-independent, requires File::Spec support
				$dir =~ s:[\r\n]::g;   # Just in case
				$dir =~ s:(.*)/.*:$1: or $dir = '';
				if($dir and ! -d $dir) {
					eval{
						File::Path::mkpath($dir);
					};
					die "mkpath\n" unless -d $dir;
				}
			}
			# We have checked for beginning > or | previously
			open(MVLOGDATA, $file) or die "open\n";
            if ($encoding) {
                local $PerlIO::encoding::fallback = $fallback;
                binmode(MVLOGDATA, ":encoding($encoding)");
            }

			lockfile(\*MVLOGDATA, 1, 1) or die "lock\n";
			seek(MVLOGDATA, 0, 2) or die "seek\n";
			if(ref $data) {
				print(MVLOGDATA $$data) or die "write to\n";
			}
			else {
				print(MVLOGDATA $data) or die "write to\n";
			}
			unlockfile(\*MVLOGDATA) or die "unlock\n";
		}
		else {
            my (@args) = grep /\S/, Text::ParseWords::shellwords($file);
			open(MVLOGDATA, "|-") || exec @args;
            if ($encoding) {
                local $PerlIO::encoding::fallback = $fallback;
                binmode(MVLOGDATA, ":encoding($encoding)");
            }
			if(ref $data) {
				print(MVLOGDATA $$data) or die "pipe to\n";
			}
			else {
				print(MVLOGDATA $data) or die "pipe to\n";
			}
		}
		close(MVLOGDATA) or die "close\n";
    };

	my $status = 1;
    if ($@) {
		::logError ("Could not %s file '%s': %s\nto write this data:\n%s",
				$@,
				$file,
				$!,
				substr(ref($data) ? $$data : $data,0,120),
				);
		$status = 0;
    }

    if (ref $opt and defined $opt->{umask}) {                                        
        $opt->{umask} = umask oct($opt->{umask});                                    
    }

	return $status;
}

sub file_modification_time {
    my ($fn, $tolerate) = @_;
    my @s = stat($fn) or ($tolerate and return 0) or die "Can't stat '$fn': $!\n";
    return $s[9];
}

sub readfile_db {
	my ($name) = @_;
	return unless $Vend::Cfg->{FileDatabase};
	my ($tab, $col) = split /:+/, $Vend::Cfg->{FileDatabase};
	my $db = $Vend::Interpolate::Db{$tab} || ::database_exists_ref($tab)
		or return undef;
#::logDebug("tab=$tab exists, db=$db");

	# I guess this is the best test
	if($col) {
		return undef unless $db->column_exists($col);
	}
	elsif ( $col = $Global::Variable->{LANG} and $db->column_exists($col) ) {
		#do nothing
	}
	else {
		$col = 'default';
		return undef unless $db->column_exists($col);
	}

#::logDebug("col=$col exists, db=$db");
	return undef unless $db->record_exists($name);
#::logDebug("ifile=$name exists, db=$db");
	return $db->field($name, $col);
}

# Reads in an arbitrary file.  Returns the entire contents,
# or undef if the file could not be read.
# Careful, needs the full path, or will be read relative to
# VendRoot..and will return binary. Should be tested by
# the user.
#
# To ensure security in multiple catalog setups, leading /
# is not allowed if $Global::NoAbsolute) is true and the file
# is not part of the TemplateDir, VendRoot, or is owned by the
# defined CatalogUser.

# If catalog FileDatabase is enabled and there are no contents, we can retrieve
# the file from the database.

sub readfile {
    my($ifile, $no, $loc, $opt) = @_;
    my($contents,$encoding,$fallback);
    local($/);

	$opt ||= {};
	
	if ($::Variable->{MV_UTF8}) {
		$encoding = $opt->{encoding} ||= 'utf-8';
		$fallback = $opt->{fallback};
		$fallback = Encode::PERLQQ() unless defined $fallback;
		undef $encoding if $encoding eq 'raw';
	}
	
	unless(allowed_file($ifile)) {
		log_file_violation($ifile);
		return undef;
	}

	my $file;

	if (file_name_is_absolute($ifile) and -f $ifile) {
		$file = $ifile;
	}
	else {
		for (".", @{$Vend::Cfg->{TemplateDir} || []}, @{$Global::TemplateDir || []}) {
			my $candidate = "$_/$ifile";
			log_file_violation($candidate), next if ! allowed_file($candidate);
			next if ! -f $candidate;
			$file = $candidate;
			last;
		}
	}

	if(! $file) {

		$contents = readfile_db($ifile);
		return undef unless defined $contents;
	}
	else {
		return undef unless open(READIN, "< $file");
		$Global::Variable->{MV_FILE} = $file;

		binmode(READIN) if $Global::Windows;

        if ($encoding) {
            local $PerlIO::encoding::fallback = Encode::PERLQQ();
            binmode(READIN, ":encoding($encoding)");
        }

		undef $/;
		$contents = <READIN>;
		close(READIN);
#::logDebug("done reading contents");

        # at this point, $contents should be either raw if encoding is
        # not specified or PerlUnicode.
	}

	if (
		$Vend::Cfg->{Locale}
			and
		(defined $loc ? $loc : $Vend::Cfg->{Locale}->{readfile} )
		)
	{
		Vend::Util::parse_locale(\$contents);
	}
    return $contents;
}

### flock locking

# sys/file.h:
my $flock_LOCK_SH = 1;          # Shared lock
my $flock_LOCK_EX = 2;          # Exclusive lock
my $flock_LOCK_NB = 4;          # Don't block when locking
my $flock_LOCK_UN = 8;          # Unlock

sub flock_lock {
    my ($fh, $excl, $wait) = @_;
    my $flag = $excl ? $flock_LOCK_EX : $flock_LOCK_SH;

    if ($wait) {
	my $trylimit = $::Limit->{file_lock_retries} || 5;
	my $failedcount = 0;
        while (
                ! flock($fh, $flag)
                    and
                $failedcount < $trylimit
               )
        {
           $failedcount++;
           select(undef,undef,undef,0.05 * $failedcount);
        }
        die "Could not lock file after $trylimit tries: $!\n" if ($failedcount == $trylimit);
        return 1;
    }
    else {
        if (! flock($fh, $flag | $flock_LOCK_NB)) {
            if ($!{EAGAIN} or $!{EWOULDBLOCK}) {
				return 0;
            }
            else {
                die "Could not lock file: $!\n";
            }
        }
        return 1;
    }
}

sub flock_unlock {
    my ($fh) = @_;
    flock($fh, $flock_LOCK_UN) or die "Could not unlock file: $!\n";
}

sub fcntl_lock {
    my ($fh, $excl, $wait) = @_;
    my $flag = $excl ? F_WRLCK : F_RDLCK;
    my $op = $wait ? F_SETLKW : F_SETLK;

	my $struct = pack('sslli', $flag, 0, 0, 0, $$);

    if ($wait) {
        fcntl($fh, $op, $struct) or die "Could not fcntl_lock file: $!\n";
        return 1;
    }
    else {
        if (fcntl($fh, $op, $struct) < 0) {
            if ($!{EAGAIN} or $!{EWOULDBLOCK}) {
                return 0;
            }
            else {
                die "Could not fcntl_lock file: $!\n";
            }
        }
        return 1;
    }
}

sub fcntl_unlock {
    my ($fh) = @_;
	my $struct = pack('sslli', F_UNLCK, 0, 0, 0, $$);
	if (fcntl($fh, F_SETLK, $struct) < 0) {
		if ($!{EAGAIN} or $!{EWOULDBLOCK}) {
			return 0;
		}
		else {
			die "Could not un-fcntl_lock file: $!\n";
		}
	}
	return 1;
}

my $lock_function = \&flock_lock;
my $unlock_function = \&flock_unlock;

sub set_lock_type {
	if ($Global::LockType eq 'none') {
		::logDebug("using NO locking");
		$lock_function = sub {1};
		$unlock_function = sub {1};
	}
	elsif ($Global::LockType =~ /fcntl/i) {
		::logDebug("using fcntl(2) locking");
		$lock_function = \&fcntl_lock;
		$unlock_function = \&fcntl_unlock;
	}
	else {
		$lock_function = \&flock_lock;
		$unlock_function = \&flock_unlock;
	}
	return; # VOID
}
 
sub lockfile {
    &$lock_function(@_);
}

sub unlockfile {
    &$unlock_function(@_);
}

### Still necessary, sad to say.....
if($Global::Windows) {
	set_lock_type('none');
}
elsif($^O =~ /hpux/) {
	set_lock_type('fcntl');
}

# Return a quasi-hashed directory/file combo, creating if necessary
sub exists_filename {
    my ($file,$levels,$chars, $dir) = @_;
	my $i;
	$levels = 1 unless defined $levels;
	$chars = 1 unless defined $chars;
	$dir = $Vend::Cfg->{ScratchDir} unless $dir;
    for($i = 0; $i < $levels; $i++) {
		$dir .= "/";
		$dir .= substr($file, $i * $chars, $chars);
		return 0 unless -d $dir;
	}
	return -f "$dir/$file" ? 1 : 0;
}

# Return a quasi-hashed directory/file combo, creating if necessary
sub get_filename {
    my ($file,$levels,$chars, $dir) = @_;
	my $i;
	$levels = 1 unless defined $levels;
	$chars = 1 unless defined $chars;

	# Accomodate PermanentDir not existing in pre-5.3.1 catalogs
	# Block is better than always doing -d test
	if(! $dir) {
		$dir = $Vend::Cfg->{ScratchDir};
	}
	else {
		mkdir $dir, 0777 unless -d $dir;
	}

    for($i = 0; $i < $levels; $i++) {
		$dir .= "/";
		$dir .= substr($file, $i * $chars, $chars);
		mkdir $dir, 0777 unless -d $dir;
	}
    die "Couldn't make directory $dir (or parents): $!\n"
		unless -d $dir;
    return "$dir/$file";
}

# These were stolen from File::Spec
# Can't use that because it INSISTS on object
# calls without returning a blessed object

my $abspat = $^O =~ /win32/i ? qr{^([a-zA-Z]:)?[\\/]} : qr{^/};
my $relpat = qr{\.\.[\\/]};

sub file_name_is_absolute {
    my($file) = @_;
    $file =~ $abspat;
}

sub absolute_or_relative {
    my($file) = @_;
    $file =~ $abspat or $file =~ $relpat;
}

sub make_absolute_file {
	my ($path, $global) = @_;
	# empty string stays empty
	return unless length($path);
	# is file already an absolute path?
	return $path if $path =~ $abspat;
	# use global or catalog root?
	my $prefix = ($global ? $Global::VendRoot : $Vend::Cfg->{VendRoot});
	return catfile($prefix, $path);
}

sub win_catfile {
    my $file = pop @_;
    return $file unless @_;
    my $dir = catdir(@_);
    $dir =~ s/(\\\.)$//;
    $dir .= "\\" unless substr($dir,length($dir)-1,1) eq "\\";
    return $dir.$file;
}

sub unix_catfile {
    my $file = pop @_;
    return $file unless @_;
    my $dir = catdir(@_);
    for ($dir) {
	$_ .= "/" unless substr($_,length($_)-1,1) eq "/";
    }
    return $dir.$file;
}

sub unix_path {
    my $path_sep = ":";
    my $path = $ENV{PATH};
    my @path = split $path_sep, $path;
    foreach(@path) { $_ = '.' if $_ eq '' }
    @path;
}

sub win_path {
    local $^W = 1;
    my $path = $ENV{PATH} || $ENV{Path} || $ENV{'path'};
    my @path = split(';',$path);
    foreach(@path) { $_ = '.' if $_ eq '' }
    @path;
}

sub win_catdir {
    my @args = @_;
    for (@args) {
	# append a slash to each argument unless it has one there
	$_ .= "\\" if $_ eq '' or substr($_,-1) ne "\\";
    }
    my $result = canonpath(join('', @args));
    $result;
}

sub win_canonpath {
    my($path) = @_;
    $path =~ s/^([a-z]:)/\u$1/;
    $path =~ s|/|\\|g;
    $path =~ s|\\+|\\|g ;                          # xx////xx  -> xx/xx
    $path =~ s|(\\\.)+\\|\\|g ;                    # xx/././xx -> xx/xx
    $path =~ s|^(\.\\)+|| unless $path eq ".\\";   # ./xx      -> xx
    $path =~ s|\\$|| 
             unless $path =~ m#^([a-z]:)?\\#;      # xx/       -> xx
    $path .= '.' if $path =~ m#\\$#;
    $path;
}

sub unix_canonpath {
    my($path) = @_;
    $path =~ s|/+|/|g ;                            # xx////xx  -> xx/xx
    $path =~ s|(/\.)+/|/|g ;                       # xx/././xx -> xx/xx
    $path =~ s|^(\./)+|| unless $path eq "./";     # ./xx      -> xx
    $path =~ s|/$|| unless $path eq "/";           # xx/       -> xx
    $path;
}

sub unix_catdir {
    my @args = @_;
    for (@args) {
	# append a slash to each argument unless it has one there
	$_ .= "/" if $_ eq '' or substr($_,-1) ne "/";
    }
    my $result = join('', @args);
    # remove a trailing slash unless we are root
    substr($result,-1) = ""
	if length($result) > 1 && substr($result,-1) eq "/";
    $result;
}

my $catdir_routine;
my $canonpath_routine;
my $catfile_routine;
my $path_routine;

if($^O =~ /win32/i) {
	$catdir_routine = \&win_catdir;
	$catfile_routine = \&win_catfile;
	$path_routine = \&win_path;
	$canonpath_routine = \&win_canonpath;
}
else {
	$catdir_routine = \&unix_catdir;
	$catfile_routine = \&unix_catfile;
	$path_routine = \&unix_path;
	$canonpath_routine = \&unix_canonpath;
}

sub path {
	return &{$path_routine}(@_);
}

sub catfile {
	return &{$catfile_routine}(@_);
}

sub catdir {
	return &{$catdir_routine}(@_);
}

sub canonpath {
	return &{$canonpath_routine}(@_);
}

#print "catfile a b c --> " . catfile('a', 'b', 'c') . "\n";
#print "catdir a b c --> " . catdir('a', 'b', 'c') . "\n";
#print "canonpath a/b//../../c --> " . canonpath('a/b/../../c') . "\n";
#print "file_name_is_absolute a/b/c --> " . file_name_is_absolute('a/b/c') . "\n";
#print "file_name_is_absolute a:b/c --> " . file_name_is_absolute('a:b/c') . "\n";
#print "file_name_is_absolute /a/b/c --> " . file_name_is_absolute('/a/b/c') . "\n";

my %intrinsic = (
	ic_super => sub { return 1 if $Vend::superuser; },
	ic_admin => sub { return 1 if $Vend::admin; },
	ic_logged => sub {
					my ($fn, $checkpath, $write, $sub) = @_;
					return 0 unless $Vend::username;
					return 0 unless $Vend::Session->{logged_in};
					return 0 if $sub and $Vend::login_table ne $sub;
					return 1;
					},
	ic_session => sub {
					my ($fn, $checkpath, $write, $sub, $compare) = @_;
					my $false = $sub =~ s/^!\s*//;
					my $status	= length($compare)
								? ($Vend::Session->{$sub} eq $compare)
								: ($Vend::Session->{$sub});
					return ! $false if $status;
					return $false;
					},
	ic_scratch => sub {
					my ($fn, $checkpath, $write, $sub, $compare) = @_;
					my $false = $sub =~ s/^!\s*//;
					my $status	= defined $compare && length($compare)
								? ($::Scratch->{$sub} eq $compare)
								: ($::Scratch->{$sub});
					return ! $false if $status;
					return $false;
					},
	ic_userdb => sub {
		my ($fn, $checkpath, $write, $profile, $sub, $mode) = @_;
		return 0 unless $Vend::username;
		return 0 unless $Vend::Session->{logged_in};
		$profile ||= 'default';
		$sub     ||= 'file_acl';
		my $u = new Vend::UserDB profile => $profile;
		$mode ||= $write ? 'w' : 'r';
		my $func = "check_$sub";
		my %o = ( 
			location => $fn,
			mode => $mode,
		);
		return undef unless $u->can($func);
		my $status = $u->$func( %o );
		unless(defined $status) {
			$o{location} = $checkpath;
			$status = $u->$func( %o );
		}
#::logDebug("status=$status back from userdb: " . ::uneval(\%o));
		return $status;
	},
);

sub _intrinsic {
	my ($thing, $fn, $checkpath, $write) = @_;
	$thing =~ s/^\s+//;
	$thing =~ s/\s+$//;
	my @checks = split /\s*;\s*/, $thing;
	my $status = 1;
	for(@checks) {
		my ($check, @args) = split /:/, $_;
		my $sub = $intrinsic{$check}
			or do {
				## $errstr is package global
				$errstr = ::errmsg("Bad intrinsic check '%s', denying.", $_);
				return undef;
			};
		unless( $sub->($fn, $checkpath, $write, @args) ) {
			## $errstr is package global
			$errstr = ::errmsg(
						"Failed intrinsic check '%s'%s for %s, denying.",
						$_,
						$write ? " (write)" : '',
						$fn,
						);
			$status = 0;
			last;
		}
	}
	return $status;
}

sub check_user_write {
	my $fn = shift;
	my $un = $Global::CatalogUser->{$Vend::Cat}
		or return undef;
	my ($mode,$own, $grown) = (stat($fn))[2,4,5];
	return 0 unless defined $own;
	my $uid = getpwnam($un);
	return 1 if $uid eq $own and $mode & 0200;
	return 0 unless $mode & 020;
	my @members = split /\s+/, (getgrgid($grown))[3];
	for(@members) {
		return 1 if $un eq $_;
	}
	return 0;
}

sub check_user_read {
	my $fn = shift;
	my $un = $Global::CatalogUser->{$Vend::Cat}
		or return undef;
	my ($mode,$own, $grown) = (stat($fn))[2,4,5];
	return 0 unless defined $own;
	my $uid = getpwnam($un);
	return 1 if $uid eq $own and $mode & 0400;
	return 0 unless $mode & 040;
	my @members = split /\s+/, (getgrgid($grown))[3];
	for(@members) {
		return 1 if $un eq $_;
	}
	return 0;
}

sub file_control {
	my ($fn, $write, $global, @caller) = @_;
	return 1 if $Vend::superuser and ! $global;
	my $subref = $global ? $Global::FileControl : $Vend::Cfg->{FileControl};
	my $f = $fn;
	CHECKPATH: {
		do {
			if(ref($subref->{$f}) eq 'CODE') {
				return $subref->{$f}->($fn, $f, $write, @caller);
			}
			elsif ($subref->{$f}) {
				return _intrinsic($subref->{$f}, $fn, $f, $write);
			}
		} while $f =~ s{/[^/]*$}{};
	}
	return 1;
}

sub allowed_file {
	my $fn = shift;
	my $write = shift;
	my $status = 1;
	$Vend::File::errstr = '';
	if(	$Global::NoAbsolute
			and
		$fn !~ $Global::AllowedFileRegex->{$Vend::Cat}
			and
		absolute_or_relative($fn)
		)
	{
		if($Vend::admin and ! $write and $fn =~ /^$Global::RunDir/ and $fn !~ $relpat) {
			$status = 1;
		}
		else {
			$status = $write ? check_user_write($fn) : check_user_read($fn);
		}
	}
	if($status and $Global::FileControl) {
		$status &= file_control($fn, $write, 1, caller(0))
			or $Vend::File::errstr ||=
							::errmsg(
								 "Denied %s access to %s by global FileControl.",
								 $write ? 'write' : 'read',
								 $fn,
							 );
	}
	if($status and $Vend::Cfg->{FileControl}) {
		$status &= file_control($fn, $write, 0, caller(0))
		  or $Vend::File::errstr ||=
		  					::errmsg(
								 "Denied %s access to %s by catalog FileControl.",
								 $write ? 'write' : 'read',
								 $fn,
							 );
	}
	
#::logDebug("allowed_file check for $fn: $status");
	return $status;
}

sub log_file_violation {
	my ($file, $action) = @_;
	my $msg;

	unless ($msg = $Vend::File::errstr) {
		if ($action) {
			$msg = ::errmsg ("%s: Can't use file '%s' with NoAbsolute set",
							 $action, $file);
		} else {
			$msg = ::errmsg ("Can't use file '%s' with NoAbsolute set",
							 $file);
		}
	}

	::logError($msg);
	::logGlobal({ level => 'warning' }, $msg);
}

1;
__END__
