# Interchange.pm - Interchange access for Perl scripts
#
# Copyright (C) 2002-2018 Interchange Development Group
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

package Interchange;
require Exporter;

@ISA = qw(Exporter);

@EXPORT = qw();
@EXPORT_OK = qw();

require 5.014_001;
use strict;
use Fcntl;
use vars qw($VERSION @EXPORT @EXPORT_OK);
$VERSION = '1.6';

BEGIN {
	($Global::VendRoot = $ENV{INTERCHANGE_ROOT})
		if defined $ENV{INTERCHANGE_ROOT};
	($Global::CatRoot = $ENV{INTERCHANGE_CATDIR})
		if defined $ENV{INTERCHANGE_ROOT};
	
$Global::VendRoot = $Global::VendRoot || '/work/minivend';
#$Global::VendRoot = $Global::VendRoot || '~_~INSTALLARCHLIB~_~';
$Global::CatRoot =   $Global::CatRoot || '/work/minivend';
#$Global::VendRoot = $Global::VendRoot || '~_~INSTALLARCHLIB~_~';
$Global::ConfigFile = 'minivend.structure';

}

my $Eval_routine;
my $Eval_routine_file;
my $Pretty_uneval;
my $Fast_uneval;
my $Fast_uneval_file;

### END CONFIGURABLE MODULES

# leaving out 0, O and 1, l
my $random_chars = "ABCDEFGHIJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";

# Return a string of random characters.

sub random_string {
    my ($len) = @_;
    $len = 8 unless $len;
    my ($r, $i);

    $r = '';
    for ($i = 0;  $i < $len;  ++$i) {
	$r .= substr($random_chars, int(rand(length($random_chars))), 1);
    }
    $r;
}

sub hexify {
    my $string = shift;
    $string =~ s/(\W)/sprintf '%%%02x', ord($1)/ge;
    return $string;
}

sub unhexify {
    my $s = shift;
    $s =~ s/%(..)/chr(hex($1))/ge;
    return $s;
}

## UNEVAL

# Returns a string representation of an anonymous array, hash, or scaler
# that can be eval'ed to produce the same value.
# uneval([1, 2, 3, [4, 5]]) -> '[1,2,3,[4,5,],]'
# Uses either Storable::freeze or Data::Dumper::DumperX or uneval 
# in 

sub uneval_it {
    my($o) = @_;		# recursive
    my($r, $s, $i, $key, $value);

	local($^W) = 0;
    $r = ref $o;
    if (!$r) {
	$o =~ s/([\\"\$@])/\\$1/g;
	$s = '"' . $o . '"';
    } elsif ($r eq 'ARRAY') {
	$s = "[";
	foreach $i (0 .. $#$o) {
	    $s .= uneval_it($o->[$i]) . ",";
	}
	$s .= "]";
    } elsif ($r eq 'HASH') {
	$s = "{";
	while (($key, $value) = each %$o) {
	    $s .= "'$key' => " . uneval_it($value) . ",";
	}
	$s .= "}";
    } else {
	$s = "'something else'";
    }

    $s;
}

use subs 'uneval_fast';

sub uneval_it_file {
	my ($ref, $fn) = @_;
	open(UNEV, ">$fn") 
		or die "Can't create $fn: $!\n";
	print UNEV uneval_fast($ref);
	close UNEV;
}

sub eval_it_file {
	my ($fn) = @_;
	local($/) = undef;
	open(UNEV, "< $fn") or return undef;
	my $ref = evalr(<UNEV>);
	close UNEV;
	return $ref;
}

# See if we have Storable and the user has OKed its use
# If so, session storage/write will be about 5x faster
eval {
	die unless $ENV{MINIVEND_STORABLE} || -f "$Global::VendRoot/_session_storable";
	require Storable;
	import Storable 'freeze';
	$Fast_uneval     = \&Storable::freeze;
	$Fast_uneval_file  = \&Storable::store;
	$Eval_routine    = \&Storable::thaw;
	$Eval_routine_file = \&Storable::retrieve;
};

# See if Data::Dumper is installed with XSUB
# If it is, session writes will be about 25-30% faster
eval {
		require Data::Dumper;
		import Data::Dumper 'DumperX';
		$Data::Dumper::Indent = 1;
		$Data::Dumper::Terse = 1;
		$Pretty_uneval = \&Data::Dumper::DumperX;
		$Fast_uneval = \&Data::Dumper::DumperX
			unless defined $Fast_uneval;
};

*uneval_fast = defined $Fast_uneval       ? $Fast_uneval       : \&uneval_it;
*evalr       = defined $Eval_routine      ? $Eval_routine      : sub { eval shift };
*eval_file   = defined $Eval_routine_file ? $Eval_routine_file : \&eval_it_file;
*uneval_file = defined $Fast_uneval_file  ? $Fast_uneval_file  : \&uneval_it_file;
*uneval      = defined $Pretty_uneval     ? $Pretty_uneval     : \&uneval_it;

# Returns a URL which will run the ordering system again.  Each URL
# contains the session ID as well as a unique integer to avoid caching
# of pages by the browser.

my %Special = (
					
				);
sub new {
	my ($class, @options) = 
	my ($k, $v);
	my $self = {};
	while (defined ($k = shift(@options))) {
		($self->{$k} = shift(@options), next)
			unless defined $Special{lc $k};
		my $arg = shift @options;
		$Special{lc $k}->($self, $arg);
	}

	if(! $self->{Cfg}{CatRoot}) {
		for( $ENV{INTERCHANGE_CATDIR}, ) {
		if(-f $ENV{INTERCHANGE_CATDIR}) {
		}
	}
	}
	unless (defined $self->{session}) {
	}
	bless $self, $class;
}

sub vendUrl {
    my($path, $arguments, $r) = @_;
    $r = $Vend::Cfg->{VendURL}
		unless defined $r;

	my @parms;

	if(defined $Vend::Cfg->{AlwaysSecure}{$path}) {
		$r = $Vend::Cfg->{SecureURL};
	}

	my($id, $ct);
	$id = $Vend::SessionID
		unless $CGI::cookie && $::Scratch->{mv_no_session_id};

    $r .= '/' . $path;
	$r .= '.html' if $::Scratch->{mv_add_dot_html} and $r !~ /\.html?$/;
	push @parms, "mv_session_id=$id"			 	if defined $id;
	push @parms, "mv_arg=" . hexify($arguments)	if defined $arguments;
	push @parms, "mv_cat=$Vend::Cfg->{CatalogName}"
				if defined $Vend::VirtualCat;
	return $r unless @parms;
    return $r . '?' . join("&", @parms);
} 

sub secure_vendUrl {
	return vendUrl($_[0], $_[1], $Vend::Cfg->{SecureURL});
}

my $use = undef;

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
        flock($fh, $flag) or die "Could not lock file: $!\n";
        return 1;
    }
    else {
        if (! flock($fh, $flag | $flock_LOCK_NB)) {
            if ($! =~ m/^Try again/
                or $! =~ m/^Resource temporarily unavailable/
                or $! =~ m/^Operation would block/) {
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


### Select based on os, vestigial

use vars qw($lock_function $unlock_function);

$lock_function = \&flock_lock;
$unlock_function = \&flock_unlock;
sub fcntl_lock {
    my ($fh, $excl, $wait) = @_;
    my $flag = $excl ? F_WRLCK : F_RDLCK;
    my $buf = pack("ssLL",$flag,0,0,0);

    LOCKLOOP:{
        if ($wait) {
            if (! fcntl($fh, F_SETLKW, $buf)) {
                redo LOCKLOOP if $! =~ m/^Interrupted/;
                die "Could not lock file: $!\n";
            }
        }
        else {
            if (! fcntl($fh, F_SETLK, $buf)) {
                redo LOCKLOOP if $! =~ m/^Interrupted/;
                if ($! =~ m/^Try again/
                    or $! =~ m/^Resource temporarily unavailable/
                    or $! =~ m/^Operation would block/) {
                    return 0;
                }
                die "Could not lock file: $!\n";
            }
        }
        return 1;
    }
}

sub fcntl_unlock {
    my ($fh) = @_;
    my $buf = pack("ssLL",F_WRLCK,0,0,0);
    fcntl($fh, F_UNLCK, $buf) or die "Could not unlock file: $!\n";
}

sub set_lock_function {
	my ($self, $arg) = @_;
	if(!$arg) {
		return ($self->{_config}{lock_type} ||= 'flock');
	}
	elsif ($arg eq 'flock') {
		$lock_function = \&flock_lock;
		$unlock_function = \&flock_unlock;
		return ($self->{_config}{lock_type} = 'flock');
	}
	elsif($arg eq 'fcntl') {
		$lock_function = \&fcntl_lock;
		$unlock_function = \&fcntl_unlock;
		return ($self->{_config}{lock_type} = 'fcntl');
	}
	elsif ($arg eq 'none') {
		warn "Using NO locking: I hope you know what you are doing!"
			unless $^O =~ /win32/i;
		$lock_function = sub {1};
		$unlock_function = sub {1};
		return ($self->{_config}{lock_type} = 'none');
	}
	else {
		die "unknown lock function $arg";
	}
}

sub lockfile {
    &$lock_function(@_);
}

sub unlockfile {
    &$unlock_function(@_);
}

# Returns the total number of items ordered.
# Uses the current cart if none specified.

sub tag_nitems {
	my($self, $opt) = @_;
	
	$opt->{cart} = ($self->{_config}{current_cart} ||= 'main')
		unless $opt->{cart};
	
	my ($attr, $sub);
	if($opt->{qualifier}) {
		$attr = $opt->{qualifier};
		my $qr;
		$qr = qr{$opt->{compare}}
			if $opt->{compare};
		if($opt->{compare}) {
			$sub = sub { 
							$_[0] =~ $qr;
						};
		}
		else {
			$sub = sub { return $_[0] };
		}
	}

    my $total = 0;
    foreach my $item (@{$opt->{cart}}) {
		next if $attr and ! $sub->($item->{$attr});
		$total += $item->{'quantity'};
    }
    $total;
}

sub errmsg {
	my($fmt, @strings) = @_;
	my $location;
	if($Vend::Cfg->{Locale} and defined $Vend::Cfg->{Locale}{$fmt}) {
	 	$location = $Vend::Cfg->{Locale};
	}
	elsif($Global::Locale and defined $Global::Locale->{$fmt}) {
	 	$location = $Global::Locale;
	}
	return sprintf $fmt, @strings if ! $location;
	if(ref $location->{$fmt}) {
		$fmt = $location->{$fmt}[0];
		@strings = @strings[ @{ $location->{$fmt}[1] } ];
	}
	else {
		$fmt = $location->{$fmt};
	}
	return sprintf $fmt, @strings;
}

# Here for convenience in calls
sub set_cookie {
    my ($name, $value, $expire) = @_;
    $::Instance->{Cookies} = []
        if ! $::Instance->{Cookies};
    @{$::Instance->{Cookies}} = [$name, $value, $expire];
    return;
}

# Here for convenience in calls
sub read_cookie {
	my ($lookfor, $string) = @_;
	$string = $ENV{HTTP_COOKIE}
		unless defined $string;
	return undef unless $string =~ /\b$lookfor=([^\s;]+)/i;
 	return unhexify($1);
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
	$dir = $Vend::Cfg->{ScratchDir} unless $dir;
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

my $abspat = $^O =~ /win32/i ? '^([a-z]:)?[\\\\/]' : '^/';

sub file_name_is_absolute {
    my($file) = @_;
    $file =~ m{$abspat}oi ;
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

1;
__END__
