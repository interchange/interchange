# Vend::MakeCat - Routines for Interchange catalog configurator
#
# $Id: MakeCat.pm,v 2.4.2.3 2002-11-26 03:21:10 jon Exp $
#
# Copyright (C) 1996-2002 Red Hat, Inc. and
# Interchange Development Group, http://www.icdevgroup.org/
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
# Software Foundation, Inc., 59 Temple Place, Suite 330, Boston,
# MA  02111-1307  USA.

package Vend::MakeCat;

use Cwd;
use File::Find;
use File::Copy;
use File::Basename;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(

add_catalog
addhistory
can_do_suid
conf_parse_http
copy_current_to_dir
copy_dir
description
do_msg
findexe
findfiles
get_id
get_ids
pretty
prompt
sethistory

);


use strict;

use vars qw($Force $Error $History $VERSION);
$VERSION = substr(q$Revision: 2.4.2.3 $, 10);

$Force = 0;
$History = 0;
my %Pretty = (
	qw/
	aliases				Aliases
	basedir				BaseDir
	catuser				CatUser
	cgibase				CgiBase
	cgidir				CgiDir
	cgiurl				CgiUrl
	demotype			DemoType
	documentroot		DocumentRoot
	imagedir			ImageDir
	imageurl			ImageUrl
	mailorderto			MailOrderTo
	interchangeuser		InterchangeUser
	interchangegroup	InterchangeGroup
	samplehtml			SampleHtml
	sampledir			SampleDir
	sampleurl			SampleUrl
	serverconf			ServerConf
	servername			ServerName
	sharedir			ShareDir
	shareurl			ShareUrl
	catroot				CatRoot
	vendroot			VendRoot
/,
	linkmode => 'Link mode',

);

my %Desc = (

	aliases    =>  <<EOF,
#
# Additional URL locations for the CGI program, as with CgiUrl.
# This is used when calling the catalog from more than one place,
# perhaps because your secure server is not the same name as the
# non-secure one.
#
# http://www.secure.domain/secure-bin/prog
#                         ^^^^^^^^^^^^^^^^
#
# We set it to the name of the catalog by default to enable the
# internal HTTP server.
#
EOF
	basedir    =>  <<EOF,
# 
# DIRECTORY where the Interchange catalog directories will go. These
# are the catalog files, such as the ASCII database source,
# Interchange page files, and catalog.cfg file. Catalogs will
# be an individual subdirectory of this directory.
#
EOF
	catuser    =>  <<EOF,
#
# The user name the catalog will be owned by.
#
EOF
	cgibase    =>  <<EOF,
#
# The URL-style location of the normal CGI directory.
# Only used to set the default for the CgiUrl setting.
# 
# http://www.virtual.com/cgi-bin/prog
#                       ^^^^^^^^
#
# If you have no CGI-bin directory, (your CGI programs end
# in .cgi), leave this blank.
#
EOF
	cgidir     =>  <<EOF,
# The location of the normal CGI directory. This is a
# file path, not a script alias.
#
# If all of your CGI programs must end in .cgi, this is
# should be the same as your HTML directory.
#
EOF
	cgiurl     =>  <<EOF,
# The URL location of the CGI program, without the http://
# or server name.
#
# http://www.virtual.com/cgi-bin/prog
#                       ^^^^^^^^^^^^^
#
# http://www.virtual.com/program.cgi
#                       ^^^^^^^^^^^^
#
EOF
	demotype   =>  <<EOF,
# The type of demo catalog to use. The standard one distributed is:
#
#    foundation
#
# If you have defined your own custom template catalog,
# you can enter its name.
#
# If you are new to Interchange, use "foundation" to start with.
EOF
	documentroot    =>  <<EOF,
# The base directory for HTML for this (possibly virtual) domain.
# This is a directory path name, not a URL -- it is your HTML
# directory.
#
EOF
		linkmode => <<EOF,
# Interchange can use either UNIX- or internet-domain sockets.
# Most ISPs would prefer UNIX mode, and it is more secure.
#
EOF
	mailorderto  =>  <<EOF,
# The email address where orders for this catalog should go.
# To have a secure catalog, either this should be a local user name and
# not go over the Internet -- or use the PGP option.
#
EOF
	permtype  =>  <<EOF,
# The type of permission structure for multiple user catalogs.
# Select M for each user in own group (with interchange user in group)
#        G for all users in group of interchange user
#        U for all catalogs owned by interchange user (must be catuser as well)
#
#        M is recommended, G works for most installations.
EOF
	interchangeuser  =>  <<EOF,
# The user name the Interchange server runs under on this machine. This
# should not be the same as the user that runs the HTTP server (i.e.
# NOT nobody).
#
EOF
	interchangegroup    =>  <<EOF,
# The group name the server-owned files should be set to.  This is
# only important if Interchange catalogs will be owned by multiple users
# and the group to be used is not the default for the catalog user.
#
# Normally this is left blank unless G mode was selected above.
# 
EOF
	sharedir => <<EOF,
# This is a directory path name (not a URL) where the administration user
# interface images from share/ should be copied to. These will normally be
# shared by all catalogs. Often this is the same as your DocumentRoot.
#
EOF
	shareurl => <<EOF,
# The URL base for the administration user interface images.
# This is a URL fragment, not an entire URL.
#
#         <IMG SRC="/interchange/en_US/bg.gif">
#                   (leave blank)
#
#         <IMG SRC="/~yourname/interchange/en_US/bg.gif">
#                   ^^^^^^^^^^
#
EOF
	imagedir   =>  <<EOF,
# Where the image files should be copied. A directory path
# name, not a URL.
#
EOF
	imageurl   =>  <<EOF,
# The URL base for the sample images. Sets the ImageDir
# directive in the catalog configuration file. This is a URL
# fragment, not a directory or file name.
#
#         <IMG SRC="/foundation/images/icon.gif">
#                   ^^^^^^^^^^^^^^^^^^
#
EOF
	samplehtml =>  <<EOF,
# Where the sample HTML files (not Interchange pages) should be installed.
# There is a difference. Usually a subdirectory of your HTML directory.
#
EOF
	sampleurl  =>  <<EOF,
# Our guess as to the URL to run this catalog, used for the
# client-pull screens and an informational message, not prompted for.
#
EOF
	serverconf =>  <<EOF,
# The server configuration file, if you are running
# Apache or NCSA. Often:
#                          /usr/local/apache/conf/httpd.conf
#                          /usr/local/etc/httpd/conf/httpd.conf
#
EOF
	servername =>  <<EOF,
# The server name, something like: www.company.com
#                                  www.company.com:8000
#                                  www.company.com/~yourname
#
EOF
	catroot   =>  <<EOF,
# Where the Interchange files for this catalog will go, pages,
# products, config and all.  This should not be in HTML document
# space! Usually a 'catalogs' directory below your home directory
# works well. Remember, you will want a test catalog and an online
# catalog.
#
EOF

	vendroot  =>  <<EOF,
# The directory where the Interchange software is installed.
#
EOF

);

sub findexe {
	my($exe) = @_;
	my($dir,$path) = ('', $ENV{PATH});
	$path =~ s/\(\)//g;
	$path =~ s/\s+/ /g;
	my(@dirs) = split /[\s:]+/, $path;
	foreach $dir (@dirs) {
		return "$dir/$exe" if -x "$dir/$exe";
	}
	return '';
}

sub findfiles {
	my($file) = @_;
	return undef if $^O =~ /win32/i;
	my $cmd;
	my @files;
	if($cmd = findexe('locate')) {
		@files = `locate \\*/$file`;
	}
	else {
		@files = `find / -name $file -print 2>/dev/null`;
	}
	return undef unless @files;
	chomp @files;
	return @files;
}

sub pretty {
	my($parm) = @_;
	return defined $Pretty{lc $parm} ? $Pretty{lc $parm} : $parm;
}

sub description {
	my($parm) = @_;
	return defined $Desc{lc $parm} ? $Desc{lc $parm} : '';
}

sub can_do_suid {
	return 0 if $^O =~ /win32/i;
	my $file = "tmp$$.fil";
	my $status;

	open(TEMPFILE,">$file");
	close TEMPFILE;
	eval { chmod 04755, $file; $@ = ''};
	$status = $@ ? 0 : 1;
	unlink $file;
	return $status;
}

sub get_id {
	return 'everybody' if $^O =~ /win32/i;
	my $file = -f "$Global::VendRoot/error.log"
				? "$Global::VendRoot/error.log" : '';
	return '' unless $file;
	my ($name);

	my($uid) = (stat($file))[4];
	$name = (getpwuid($uid))[0];
	return $name;
}

sub get_ids {
	return ('everybody', 'nogroup') if $^O =~ /win32/i;
	my $file = "tmp$$.fil";
	my ($name, $group);

	open(TEMPFILE,">$file");
	close TEMPFILE;
	my($uid,$gid) = (stat($file))[4,5];
	unlink $file;
	$name = (getpwuid($uid))[0];
	$group = (getgrgid($gid))[0];
	return ($name,$group);
}

my $Windows = ($^O =~ /win32/i ? 1 : 0);

sub get_rename {
	my ($bn, $extra) = @_;
	$extra = '~' unless $extra;
	$bn =~ s:(.*/)::;
	my $dn = $1;
	return $dn . "/.$extra." . $bn;
}

sub compare_file {
	my($first,$second) = @_;
	return 0 unless -f $first && -f $second;
	return 0 unless -s $first == -s $second;
	local $/;
	open(FIRST, "< $first") or return undef;
	open(SECOND, "< $second") or (close FIRST and return undef);
	binmode(FIRST);
	binmode(SECOND);
	$first = '';
	$second = '';
	while($first eq $second) {
		read(FIRST, $first, 1024);
		read(SECOND, $second, 1024);
		last if length($first) < 1024;
	}
	close FIRST;
	close SECOND;
	$first eq $second;
}

sub install_file {
	my ($srcdir, $targdir, $filename, $opt) = @_;
	$opt = {} unless $opt;
	if (ref $srcdir) {
		$opt = $srcdir;
		$srcdir  = $opt->{Source} || die "Source dir for install_file not set.\n";
		$targdir = $opt->{Target} || die "Target dir for install_file not set.\n";
		$filename = $opt->{Filename} || die "File name for install_file not set.\n";
	}
	my $srcfile  = $srcdir . '/' . $filename;
	my $targfile = $targdir . '/' . $filename;
	my $mkdir = File::Basename::dirname($targfile);
	my $extra;
	my $perms;

	if(! -d $mkdir) {
		File::Path::mkpath($mkdir)
			or die "Couldn't make directory $mkdir: $!\n";
		my $perm = $opt->{Perms} || '';
		if ( $perm =~ /^(m|g)/i ) {
			$perms = (stat($mkdir))[2] | 060;
			chmod $perms, $mkdir;
		}
	}

	if (! -f $srcfile) {
		die "Source file $srcfile missing.\n";
	}
	elsif (
		$opt->{Perm_hash}
			and $opt->{Perm_hash}->{$filename}
		)
	{
		$perms = $opt->{Perm_hash}->{$filename};
	}
	elsif ( $opt->{Perms} =~ /^(m|g)/i ) {
		$perms = (stat(_))[2] | 0660;
	}
	elsif ( $opt->{Perms} =~ /^u/i ) {
		$perms = (stat(_))[2] | 0600;
	}
	else {
		$perms = (stat(_))[2] & 0777;
	}

	if( ! $Windows and -f $targfile and ! compare_file($srcfile, $targfile) ) {
		open (GETVER, "< $targfile")
			or die "Couldn't read $targfile for version update: $!\n";
		while(<GETVER>) {
			/VERSION\s+=.*?\s+([\d.]+)/ or next;
			$extra = $1;
			$extra =~ tr/0-9//cd;
			last;
		}
		$extra = '~' unless $extra;
		my $rename = get_rename($targfile, $extra);
		while (-f $rename ) {
			$extra .= '~';
			$rename = get_rename($targfile, $extra);
		}
		rename $targfile, $rename
			or die "Couldn't rename $targfile to $rename: $!\n";
	}

	File::Copy::copy($srcfile, $targfile)
		or die "Copy of $srcfile to $targfile failed: $!\n";
	if($opt->{Substitute}) {
			my $bak = "$targfile.mv";
			rename $targfile, $bak;
			open(SOURCE, "< $bak")			or die "open $bak: $!\n";
			open(TARGET, ">$targfile")		or die "create $targfile: $!\n";
			local($/) = undef;
			my $page = <SOURCE>; close SOURCE;

			$page =~ s/^#>>(.*)(__MVR_(\w+)__.*)\n\1.*/#>>$1$2/mg;
			$page =~ s/^#>>(.*__MVR_(\w+)__.*)/#>>$1\n$1/mg;
			1 while $page =~ s/^([^#].*)__MVR_(.*)/$1__MVC_$2/mg;
			$page =~ s/__MVC_(\w+)__/$opt->{Substitute}{lc $1}/g;

			print TARGET $page				or die "print $targfile: $!\n";
			close TARGET					or die "close $targfile: $!\n";
			unlink $bak						or die "unlink $bak: $!\n";
	}
	chmod $perms, $targfile;
}

sub copy_current_to_dir {
	my($target_dir, $exclude_pattern, $opt) = @_;
	return copy_dir('.', @_);
}

sub copy_dir {
	my($source_dir, $target_dir, $exclude_pattern, $opt) = @_;
	return undef unless -d $source_dir;
	my $orig_dir;
	if($source_dir ne '.') {
		$orig_dir = cwd();
		chdir $source_dir or die "chdir: $!\n";
	}
	my @files; 
	my $wanted = sub {  
		return unless -f $_;
		my $name = $File::Find::name;
		$name =~ s:^\./::;
		return if $exclude_pattern and $name =~ m{$exclude_pattern}o;
		push (@files, $name);
	};
	File::Find::find($wanted, '.');  

	# also exclude directories that match $exclude_pattern
	@files = grep !m{$exclude_pattern}o, @files if $exclude_pattern;
	eval {
		for(@files) {
			install_file('.', $target_dir, $_, $opt);
		}
	};
	my $msg = $@;
	chdir $orig_dir if $orig_dir;
	die "$msg" if $msg;
	return 1;
}

use vars q!$Prompt_sub!;
my $History_add;
my $History_set;
my $term;
eval {
	require Term::ReadLine;
	import Term::ReadLine;
	$term = new Term::ReadLine::Perl 'Interchange Configuration';
	die "No Term::ReadLine::Perl" unless defined $term;

	readline::rl_set('EditingMode', 'emacs');
	readline::rl_bind('C-B', 'catch_at');
	$Prompt_sub = sub {
		my ($prompt, $default) = @_;
		if($Force) {
			print "$prompt SET TO --> $default\n";
			return $default;
		}
		$prompt =~ s/^\s*(\n+)/print $1/ge;
		$prompt =~ s/\n+//g;
		my $out = $term->readline($prompt, $default);
		return '@' if ! defined $out;
		return $out;
	};
	$History_add = sub {
		my ($line) = @_;
		$term->addhistory($line)
			if $line =~ /\S/;
	};
	$History_set = sub {
		$term->SetHistory(@_);
	};
	$History = 1;

};


sub prompt {
	return &$Prompt_sub(@_)
		if defined $Prompt_sub;
	my($prompt) = shift || '? ';
	my($default) = shift;
	if($Force) {
		print "$prompt SET TO --> $default\n";
		return $default;
	}
	my($ans);

	print $prompt;
	print "[$default] " if $default;
	local ($/) = "\n";
	chomp($ans = <STDIN>);
	length($ans) ? $ans : $default;
}

sub addhistory {
	return '' unless defined $History_add;
	&{$History_add}(@_);
}

sub sethistory {
	return '' unless defined $History_set;
	&{$History_set}(@_);
}

sub do_msg {
	my ($msg, $size) = @_;
	$size = 60 unless defined $size;
	my $len = length $msg;
	
	return "$msg.." if ($len + 2) >= $size;
	$msg .= '.' x ($size - $len);
	return $msg;
}


sub add_catalog {
		my ($file, $directive, $configname, $value, $dynamic) = @_;
		my ($newcfgline, $mark, @out);
		my ($tmpfile) = "$file.$$";
		if (-f $file) {
			rename ($file, $tmpfile)
				or die "Couldn't rename $file: $!\n";
		}
		else {
			File::Copy::copy("$file.dist", $tmpfile);
		}
		open(CFG, "< $tmpfile")
			or die "Couldn't open $tmpfile: $!\n";
		$newcfgline = sprintf "%-19s %s\n", $directive, $value;
		while(<CFG>) {
			$mark = $. if /^#?\s*catalog\s+/i;
			warn "\nDeleting old configuration $configname.\n"
				if s/^(\s*$directive\s+$configname\s+)/#$1/io;
			push @out, $_;
		}
		close CFG;
		open(NEWCFG, ">$file")
			or die "\nCouldn't write $file: $!\n";
		if (defined $mark) {
			print NEWCFG @out[0..$mark-1];
			print NEWCFG $newcfgline;
			print NEWCFG @out[$mark..$#out];
		}
		else { 
			warn "\nNo $directive previously defined. Adding $configname at top.\n";
			print NEWCFG $newcfgline;
			print NEWCFG @out;
		}
		close NEWCFG || die "close: $!\n";
		unlink $tmpfile;

		if($dynamic and ! $Windows) {
			my $pidfile = $dynamic;
			$pidfile =~ s:/[^/]+$::;
			$pidfile .= "/$Global::ExeName.pid";
			my $pid;
			PID: {
				local ($/);
				open(PID, "< $pidfile") or die "open $pidfile: $!\n";
				$pid = <PID>;
				$pid =~ /(\d+)/;
				$pid = $1;
			}

			open(RESTART, "<+$dynamic") or
				open(RESTART, ">>$dynamic") or
					die "Couldn't write $dynamic to add catalog: $!\n";
			Vend::Util::lockfile(\*RESTART, 1, 1) 	or die "lock $dynamic: $!\n";
			printf RESTART "%-19s %s\n", $directive, $value;
			Vend::Util::unlockfile(\*RESTART) 		or die "unlock $dynamic: $!\n";
			close RESTART;
			kill 'HUP', $pid;
		}
		1;
}

my %Http_hash = (
					qw(
						scriptalias		1
						addhandler		1
						alias			1
					)
				);

my %Http_process = (
						scriptalias		=> sub {
												my ($junk, $val) = @_;
												$val =~ s!/+$!!;
												return $val;
											},
				);

my %Http_scalar = (
					qw(
						user			1
						group			1
						serveradmin		1
						resourceconfig	1
						documentroot	1
					)
				);


sub conf_parse_http {
	my ($file) = @_;

	my $virtual = {};
	my $servers = {};
	my $newfile;

	open(HTTPDCONF, "< $file")
		or do { $Error = "Can't open $file: $!"; return undef};
	local($/) = undef;
	my $data = <HTTPDCONF>;
	close(HTTPDCONF);

	
	if($data =~ s/^\s*resourceconfig\s+(.*)//) {
		$newfile = $1;
	}

	unless(defined $newfile) {
		$newfile = $file;
		$newfile =~ s:[^/]+$::;
		$newfile .= 'srm.conf';
	}

	SRMCONF: {
		if (-f $newfile) {
			open(HTTPDCONF, "< $newfile")
				or last SRMCONF;
			$data .= <HTTPDCONF>;
			close(HTTPDCONF);
		}
	}

	$data =~ s!
				<virtualhost
				\s+
					([^>\n]+)
				\s*>\s+
					([\000-\377]*?)
				</virtualhost>!
				$virtual->{$1} = $2; ''!xieg;

	$virtual->{' '} = $data;

	my @data;
	my $servname;
	my $handle;
	my $main;
	foreach $handle (sort keys %$virtual) {

		undef $servname;
		@data = split /[\r\n]+/, $virtual->{$handle};
		my $port = $handle;
		$port =~ s/.*:(\d+).*/$1/ or $port = '';
		@data = grep /^\s*[^#]/, @data;
		for(@data) {
			next unless /^\s*servername\s+(.*)/i;
			$servname = $1;
			$servname =~ s/\s+$//;
			if(defined $servers->{$servname} and $port) {
				$servname .= ":$port";
			}
			elsif(defined $servers->{$servname} and $port) {
				$Error = "Server $servname defined twice.";
				return undef;
			}
			$servers->{$servname} = {};
		}
		
		if($handle eq ' ') {
			$servname = `hostname` unless $servname;
			$servname =~ s/\s+$//;
			$main = $servname;
		}
		next unless $servname;

		my ($line, $directive, $param, $key, $val);
		foreach $line (@data) {
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			($directive,$param) = split /\s+/, $line, 2;
			$directive = lc $directive;
			if(defined $Http_hash{$directive}) {
				$servers->{$servname}->{$directive} = {}
					unless defined $servers->{$servname}->{$directive};
				($key,$val) = split /\s+/, $param, 2;
				$val =~ s/^\s*"// and $val =~ s/"\s*$//;
				if (defined $Http_process{$directive}) {
					$key = &{$Http_process{$directive}}('key', $key);
					$val = &{$Http_process{$directive}}('value', $val);
				}
				$servers->{$servname}->{$directive}->{$key} = $val;
			}
			elsif(defined $Http_scalar{$directive}) {
				$param =~ s/^"// and $param =~ s/"\s*$//;
				if (defined $servers->{$servname}->{$directive}) {
					undef $servers->{$servname};
					$Error = "$directive defined twice in $servname, only allowed once.";
					return undef;
				}
				if (defined $Http_process{$directive}) {
					$param = &{$Http_process{$directive}}($param);
				}
				$servers->{$servname}->{$directive} = $param;
			}
		}
	}
			
	return $servers;
}

package readline;

use vars qw/$AcceptLine/;

sub F_Catch_at {
		$AcceptLine = '@';
}

__END__
