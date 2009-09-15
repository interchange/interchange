# Vend::MakeCat - Routines for Interchange catalog configurator
#
# $Id: MakeCat.pm,v 2.17 2007-08-09 13:40:53 pajamian Exp $
#
# Copyright (C) 2002-2007 Interchange Development Group
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

package Vend::MakeCat;

use Cwd;
use File::Find;
use File::Copy;
use File::Basename;
use Sys::Hostname;
use Vend::Util;
require Vend::Safe;
$Safe = new Vend::Safe;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(

%Conf
%Content
%Ever
%History
%IfRoot
%Commandline
%Postprocess
%Prefix
%Window
$Force
$Safe

add_catalog
addhistory
applicable_directive
can_do_suid
check_root_execute
compare_file
conf_parse_http
copy_current_to_dir
copy_dir
description
debug
directory_process
do_msg
error_message
find_inet_info
findexe
findfiles
get_id
get_ids
get_rename
history
inet_host
inet_port
install_file
label
prefix
pretty
prompt
read_additional
readconfig
sethistory
strip_na
strip_trailing_slash
substitute
sum_it
unique_ary
validate

);


use strict;

use vars qw($Safe $Force $Error $History $VERSION);

$Safe->share(qw/%Conf %Ever &debug/);

use vars qw/
	%Alias
	%Conf
	%Content
	%Commandline
	%Ever
	%History
	%IfRoot
	%Postprocess
	%Special_sub
	%Prefix
	%Window
/;

$VERSION = substr(q$Revision: 2.17 $, 10);

$Force = 0;
$History = 0;

%Alias = (
	serverconf => {
						linux => '/etc/httpd/conf/httpd.conf',
					},
);

my %Watch = qw/
		cfg_extramysql 1
		/;

my %Pretty = (
	qw/
	aliases				Aliases
	basedir				BaseDir
	catroot				CatRoot
	catuser				CatUser
	cgibase				CgiBase
	cgidir				CgiDir
	cgiurl				CgiUrl
	demotype			DemoType
	documentroot		DocumentRoot
	imagedir			ImageDir
	imageurl			ImageUrl
	interchangegroup	InterchangeGroup
	interchangeuser		InterchangeUser
	mailorderto			MailOrderTo
	samplehtml			SampleHtml
	sampleurl			SampleUrl
	serverconf			ServerConf
	servername			ServerName
	sharedir			ShareDir
	shareurl			ShareUrl
	vendroot			VendRoot
/,
	linkmode => 'Link mode',

);

my %Label = (
	add_catalog		=> 'Add catalog to interchange.cfg',
    aliases			=> 'Link aliases',
	basedir			=> 'Base directory for catalogs',
	catroot			=> 'Catalog directory',
	catuser			=> 'Catalog user',
	catalogname		=> 'Catalog name',
	cgibase			=> 'CGI base URL',
	cgidir			=> 'CGI Directory',
	cgiurl			=> 'URL call for catalog',
	demotype		=> 'Catalog skeleton',
	documentroot	=> 'Document Root',
	imagedir		=> 'Image directory',
	imageurl		=> 'Image base URL',
	interchangeuser	=> 'Interchange daemon username',
	interchangegroup	=> 'Interchange daemon groupname',
	linkhost		=> 'Link host',
	linkmode		=> 'Link mode',
	linkport		=> 'Link port',
	mailorderto		=> 'Email address for orders',
	permtype		=> 'Permission Type',
	run_catalog		=> 'Add catalog to running server',
	samplehtml		=> 'Catalog HTML base directory',
	servconflist	=> 'Server config files found',
	serverconf		=> 'Server config file',
	serverlist		=> 'Servers in httpd.conf',
	servername		=> 'Server name',
	sharedir		=> 'Share Directory',
	shareurl		=> 'Share URL',
	win_addcatalog	=> 'Add catalog to Interchange',
	win_catinfo		=> 'Catalog Initialization Information',
	win_greeting	=> 'Make an Interchange Catalog',
	win_servername	=> 'HTTP ServerName',
	win_server		=> 'HTTP Server Information',
	win_serverconf	=> 'HTTP Server Configuration File',
	win_linkinfo	=> 'Link Program Information',
	win_urls		=> 'URL and Directory Information',
);

my %Desc = (
	add_catalog => <<EOF,
# To make the catalog active, you must add it to the
# interchange.cfg file. If you don't select this, then you will
# have to manually add it later.
EOF

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
# DIRECTORY where the Interchange catalog directories will go.
# These are the catalog files, such as the ASCII database source,
# Interchange page files, and catalog.cfg file. Catalogs will be
# an individual subdirectory of this directory.
#
EOF

	catalogname => <<EOF,
# Select a short, mnemonic name for the catalog. This will be
# used to set the defaults for naming the catalog, executable,
# and directory, so you will have to type in this name
# frequently.
#
# NOTE: This will be the name of 'vlink' or 'tlink', the link CGI
#       program. Depending on your CGI setup, it may also have
#       the extension .cgi added.
#
# Only the characters [-a-zA-Z0-9_] are allowed, and it is
# strongly suggested that the catalog name be all lower case.
#
# If you are doing the demo for the first time, you might use
# "standard".
EOF

	catroot   =>  <<EOF,
# Where the Interchange files for this catalog will go, pages,
# products, config and all. This should not be in HTML document
# space! Usually a 'catalogs' directory below your home directory
# works well. Remember, you will want a test catalog and an
# online catalog.
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
#    standard
#
# If you have defined your own custom template catalog,
# you can enter its name.
#
# If you are new to Interchange, use "standard" to start with.
EOF

	documentroot    =>  <<EOF,
# The base directory for HTML for this (possibly virtual) domain.
# This is a directory path name, not a URL -- it is your HTML
# directory.
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
#         <IMG SRC="/standard/images/icon.gif">
#                   ^^^^^^^^^^^^^^^^
#
EOF

	interchangegroup    =>  <<EOF,
# The group name the server-owned files should be set to. This is
# only important if Interchange catalogs will be owned by
# multiple users and the group to be used is not the default for
# the catalog user.
#
# Normally this is left blank.
EOF

	interchangeuser  =>  <<EOF,
# The user name the Interchange server runs under on this
# machine. This should not be the same as the user that runs the
# HTTP server (i.e. NOT nobody).
EOF

	linkhost => <<EOF,
# If you are using INET mode, you need to set the host the link
# CGI will talk to.
#
# If Interchange is running on the same server as your web
# server, this should be "localhost" or "127.0.0.1". If the web
# server is on a different machine, it is the IP address of the
# machine Interchange is running on.
EOF

	linkmode => <<EOF,
# Interchange can use either UNIX- or internet-domain sockets.
# Most ISPs would prefer UNIX mode, and it is more secure.
#
# If you already have a program there, or use mod_interchange,
# select NONE. You will then need to copy the program by hand or
# otherwise ensure its presence.
EOF

	linkport => <<EOF,
# If you are using INET mode, you need to set the port the
# link CGI will talk to. The IANA standard for Interchange is
# port 7786.
EOF

	mailorderto  =>  <<EOF,
# The email address where orders for this catalog should go. To
# have a secure catalog, either this should be a local user name
# and not go over the Internet -- or use the PGP option.
#
EOF

	permtype  =>  <<EOF,
# The type of permission structure for multiple user catalogs.
#
# Select:
#    M for each user in own group (with interchange user in group)
#    G for all users in group of interchange user
#    U for all catalogs owned by interchange user
#      (should be catuser as well)
#
#    M is recommended, G works for most installations.
EOF

	run_catalog  =>  <<EOF,
# You can add this catalog to the running Interchange server. You
# may not want to do this if you are using a SQL database, as you
# will not be able to monitor the database creation activity.
#
# If you don't do it, then you can restart Interchange to
# activate the new catalog.
EOF

	samplehtml =>  <<EOF,
# Where the sample HTML files (not Interchange pages) should be
# installed. There is a difference. Usually a subdirectory of
# your HTML directory.
#
EOF

	sampleurl  =>  <<EOF,
# Our guess as to the URL to run this catalog, used for the
# client-pull screens and an informational message, not prompted for.
#
EOF

	servconflist =>  <<EOF,
# A list of server configuration files automatically found.
# When you use history to change this, it will be reflected
# in the next field to save you entering the file name.
#
EOF

	serverconf =>  <<EOF,
# The server configuration file, if you are running
# Apache or NCSA. Often:
#                          /etc/httpd/conf/httpd.conf
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
#         <IMG SRC="/interchange-5/en_US/bg.gif">
#                   (leave blank)
#
#         <IMG SRC="/~yourname/interchange-5/en_US/bg.gif">
#                   ^^^^^^^^^^
#
EOF

	vendroot  =>  <<EOF,
# The directory where the Interchange software is installed.
#
EOF

	win_addcatalog		=> <<EOF,
# You should add the catalog callout to interchange.cfg, and
# optionally can add it into the running server.
EOF

	win_catinfo		=> <<EOF,
# We need to set base template type and directory for your catalog.
EOF

	win_greeting		=> <<EOF,
# Welcome to Interchange!
#
# You can now configure a working catalog.
#
# You can exit by selecting the "Cancel" button below, but your
# catalog will not be built until you complete the configuration.
EOF

	win_linkinfo		=> <<EOF,
# We need to get information necessary for compiling the link
# program(s).
EOF

	win_server		=> <<EOF,
# We need to know some basic HTTP Server configuration information.
EOF

	win_serverconf		=> <<EOF,
# If you are using Apache or another HTTP server with the same
# type of configuration file, we can read it and set some
# defaults based on the server name you are using.
EOF

	win_servername		=> <<EOF,
# Since you are running Apache, we can give you a choice of the
# server names defined in the httpd.conf file you selected. This
# will be used to pre-set items like DocumentRoot, ScriptAlias
# (cgi-bin), etc.
#
# If you don't see your server, pick the empty option and go to
# the next screen.
EOF

	win_urls		=> <<EOF,
# We need to set the HTML, image, and executable paths for your
# catalog.
EOF

);

my %Validate = (
	demotype => <<EOF,
The demotype skeleton directory must exist. In addition, if you
are root the files must be owned by root and not be group-
or world-writable.
EOF
);

my %Build_error = (
	demotype => <<EOF,
There were errors in copying the demo files.  Cannot
continue.  Check to see if permissions are correct.
EOF

);

my $Wname = 'content00';

sub readconfig {
	my ($file, $ref) = @_;
	return undef unless $file;
	return undef unless -f $file;
	$ref = {} unless ref $ref;
	open (INICONF, "< $file")
		or die "open $file: $!\n";
	local($/);
	my $data = <INICONF>;
	close INICONF;
	my $novirt;

	my %virtual;

	$data =~ s/^\s*#.*//mg;
	$data =~ m{(\[<)}
		or $novirt = 1;
	my $first = $1;
	if($first eq '<') {
		$data =~ s!
				<catalog\s+
				
					([^>\n]+)
				\s*>\s+
					((?s:.)*?)
				</catalog>!
				$virtual{$1} = $2; ''!xieg;

		$virtual{'_base'} = $data;
	}
	else {
		my %recognize = ( base => '_base' );
		my @lines = grep /\S/, split /\n/, $data;
		my $handle;
		for(@lines) {
			if(/^\[(.*?)\]\s*$/) {
				my $hh = $1;
				if($hh =~ /^catalog\s+(\S+)/) {
					$handle = $1;
				}
				elsif($recognize{$hh}) {
					$handle = $recognize{$hh};
				}
				else {
					undef $handle;
				}
				$virtual{$handle} = '' if ! $virtual{$handle};
				next;
			}
			next unless $handle;
			next unless /\S/;
			$virtual{$handle} .= $_;
		}
	}

	my $out = {};
	foreach my $hk (keys %virtual) {
		my $ref = $out->{$hk} = {};
		my @lines = grep /\S/, split /\n/, $virtual{$hk};
		for(@lines) {
			s/^\s+//;
			s/\s+$//;
			my ($k, $v) = split /\s*=\s*/, $_, 2;
			$ref->{$k} = $v;
		}
	}
	return $out;
}

sub read_additional {
	my ($file) = @_;

	if (! $file) {
		$file = "$Conf{vendroot}/$Conf{demotype}/config/additional_fields";
		return undef unless -f $file;
	}

	my $help = $file;
	$help =~ s/_fields$/_help/ or undef $help;
	my $data;

	SPLIT: {
		local ($/);
		open ADDLFIELDS, "< $file"
			or return undef;
		$data = <ADDLFIELDS>;
		close ADDLFIELDS;
	}

	HELP: {
		local($/) = "";
		last HELP unless open  ADDLHELP, "< $help";
		while(<ADDLHELP>) {
			s/^[.\t ]+$//mg;
			my ($k, $v) = split /\n/, $_, 2;
			$Desc{lc $k} = $v;
		}
		close ADDLHELP;
	}

	my @chunks;
	if($data =~ /^\s*</) {
		@chunks = read_common_config($data);
		return read_additional_new(@chunks);
	}
	else {
		@chunks = split /\n\n+/, $data;
		return read_additional_old(@chunks);
	}
}

sub read_additional_old {
	my (@chunks) = @_;

	my @addl_windows;
	my %label;

	my $winref;

	for(@chunks) {
		my $noprompt = '';
		my $grp;
		my $realgrp;
		my $wid;
		my $cref = {};
		s/\s+$//;
		my ($var, $prompt, $default) = split /\n/, $_, 3;

		($var, $realgrp, $wid) = split /\t/, $var;

		$cref->{widget} = $wid if $wid;

		my $label;
		($prompt, $label) = split /\t/, $prompt, 2;

		my $subcode;
		my $mainparam;

		if($var =~ s/{\s*([A-Z0-9]+)(\s*\S.*?)?\s*}\s*//) {
			$mainparam = lc $1;
			my $test = $2;
			$test =~ s/'?__MVC_([A-Z0-9]+)__'?/\$Conf{\L$1}/g; 
			$subcode = <<EOF;
sub {
	my \$status;
	if(\$Conf{$mainparam} $test) {
		\$status = 1;
	}
	else {
		\$status = 0;
	}
	return \$status;
}
EOF

			my $sub = eval $subcode;
			if($@) {
				undef $sub;
			}
			$cref->{conditional} = $sub;
		}
		$var =~ s/\s+//g;
		$var =~ s:^!::
			and $noprompt = 1;
		$var =~ s/\W+//g;
		$var = lc $var;
debug("conditional code: $subcode") if $Watch{$var};

		$cref->{help} = description($var);
		$cref->{group} ||= $realgrp;
		$grp = $cref->{group} || $var;

		if(! $var and $cref->{group}) {
			$Window{$cref->{group}} ||= { };
			$Window{$cref->{group}}->{banner} = $label || $prompt;
			$Window{$cref->{group}}->{help}    =
			$Window{$cref->{group}}->{message} = description($cref->{group});
			push @addl_windows, $cref->{group};
			next;
		}
		elsif($grp ne $var) {
			if (! $Window{$grp}) {
				$Window{$grp} = { };
				push @addl_windows, $grp;
			}
			elsif($mainparam) {
				$Window{$grp}{conditional} = $cref->{conditional}
					if !  $Window{$grp}{conditional};
			}
			$Window{$grp}{contents} = [] if ! $Window{$grp}{contents};
			push @{$Window{$grp}{contents}}, $var;
		}
		else {
			push @addl_windows, $var;
		}

		my (@history)  = split /\t/, $default;
		$default = $Conf{$var} || $history[0] || '';

		if($label =~ /\S/) {
			$cref->{banner} = $prompt;
			$cref->{label} = $label;
		}
		else {
			$cref->{label} = $prompt;
		}

		my $presubcode;
		if($default =~ s/__MVC_([A-Z0-9]+)__/\$Conf{\L$1}/g) {
			$default =~ s/\@/\\\@/g;
			my $presubcode = qq{
				sub {
					return qq[$default]
				}
			};
			my $presub = eval $presubcode;
			if($@) {
debug("error evaling prefix sub for $var: $presubcode");
			}
			$cref->{prefix} = $presub;
			$cref->{prefix_source} = $presubcode;
		}
		else {
			$cref->{prefix} = $default;
		}
		$cref->{options} = \@history;
		if ($noprompt) {
			if($cref->{conditional}) {
				my $snippet = <<EOF;

	\$Conf{$var} = q{$default} if \$status;
	return \$status;
}
EOF
				# Appease vi {
				$subcode =~ s/\s*return .*\s+}\s*$/$snippet/;
				$cref->{conditional} = eval $subcode;
				$cref->{conditional_source} = $subcode;
			}
			else {
				$Conf{$var} = substitute($default);
				$cref->{conditional} = sub { 0 };
			}
		}
		if($mainparam || $cref->{group}) {
			my $winref;
			if($cref->{group}) {
				$winref = $Window{$cref->{group}};
			}
			else {
				$winref = $Content{$mainparam};
				$winref->{additional} ||= [];
				push @{$winref->{additional}}, $var;
			}
			$winref->{override} ||= {};
			$winref->{override}{$var} = $cref;
			$Content{$var} = $cref unless $Content{$var};
		}
		elsif ($Content{$var}) {
die("generated duplicate param for $var with no group or mainparam.\n");
debug("generated duplicate param for $var with no group or mainparam.\n");
		}
		else {
			$Content{$var} = $cref;
		}
#debug( "ref for $var: " . ::uneval($cref));
	}
	close ADDLFIELDS;
#debug("read_additional: returning: " . join ",", @addl_windows);
	my %seen;

	# Multiple conditions may define them more than once
	@addl_windows = grep !$seen{$_}++, @addl_windows;;
	return @addl_windows;
}

sub read_additional_new {
	my ($help, @chunks) = @_;
	my $winref;
	my @addl_windows;
	
	foreach my $cref (@chunks) {
		my $grp;
		my $subcode;
		my $mainparam;
		my $var;
		my $default;
		my $cond_code;

		if(! ref $cref) {
			# Bad chunk
			next;
		}

		$cref->{_additional} = 1;

		if($cond_code = $cref->{conditional}) {
			delete $cref->{conditional};
			if($cond_code =~ /^sub\s+{.*}\s*$/s) {
				$subcode = $cond_code;
			}
			else {
				$cond_code =~ m{^[A-Z][A-Z0-9]+$}
					and $cond_code = "\U__MVC_${cond_code}__";
				$cond_code =~ m{__MVC_([A-Z0-9]+)__}
					and $mainparam = lc $1;
				$cond_code =~ s{(['"]?)__MVC_([A-Z0-9]+)__\1}
							   {'$Conf{' . lc $2 . '}'   }eg;

				# Appease vi }
				$subcode = <<EOF;
		sub {
			my \$status;
			if($cond_code) {
				\$status = 1;
			}
			else {
				\$status = 0;
			}
			return \$status;
		}
EOF
			}
		}

		if($subcode) {
			my $sub = eval $subcode;
			if($@) {
debug("Problem evaluating sub: $subcode");
				undef $sub;
			}
			$cref->{conditional} = $sub;
		}

		for my $code (qw/callback/) {
			my $cb = $cref->{$code}
				or next;
			if($cb =~ /^\s*sub\s+{/) {
				# Appease vi }
				local($SIG{__DIE__});
				$cref->{$code} = eval $cb;
				$cref->{"${code}_source"} = $cb;
			}
			elsif($cb =~ /^\s*\[.*\]\s*$/s) {
				$cref->{$code} = eval($cb);
				$cref->{"${code}_source"} = $cb;
			}
			elsif($cb =~ /[a-z]/) {
				my @items = Text::ParseWords::shellwords($cref->{$code});
				@items = map { lc $_ } @items;
				$cref->{$code} = \@items;
				$cref->{"${code}_source"} = $cb;
			}
		}

		for my $code (qw/options history/) {
			my $cb = $cref->{$code}
				or next;
			if($cb =~ /^\s*sub\s+{.*}\s*$/s) {
				local($SIG{__DIE__});
				$cref->{$code} = eval $cb;
				$cref->{"${code}_source"} = $cb;
			}
			elsif($cb =~ /^\s*\[.*\]\s*$/s) {
				$cref->{$code} = eval($cb);
				$cref->{"${code}_source"} = $cb;
			}
			elsif($cb =~ /[a-z]/) {
				my @items = Text::ParseWords::shellwords($cref->{$code});
				$cref->{$code} = \@items;
				$cref->{"${code}_source"} = $cb;
			}
		}

		for my $code (qw/check_routine/) {
			my $cb = $cref->{$code}
				or next;
			if($cb =~ /^\s*sub\s+{/) {
				# Appease vi }
				$cref->{$code} = eval $cb;
				$cref->{"${code}_source"} = $cb;
			}
			else {
				undef $cref->{$code};
			}
		}

		$var = $cref->{name} || $Wname++;
		$var =~ s/\s+//g;
		$var =~ s/\W+//g;
		$cref->{name} = $var = lc $var;
$::Subcode{$var} = $subcode;
debug("conditional code: $subcode") if $Watch{$var};

		$grp = $cref->{group} || $var;

		if($cref->{_window}) {
			if(my $wref = $Window{$var}) {
				for(keys %$wref) {
					$cref->{$_} = $wref->{$_}
						unless defined $cref->{$_};
				}
			}
			$cref->{help} ||= description($var);
			$cref->{message} ||= $cref->{help};
			$cref->{banner}  ||= $cref->{label};
			push @addl_windows, $var;
			$Window{$var} = $cref;
			next;
		}
		elsif($grp ne $var) {
			if (! $Window{$grp}) {
				$Window{$grp} = { };
				push @addl_windows, $grp;
			}
			elsif($mainparam) {
				$Window{$grp}{conditional} = $cref->{conditional}
					if !  $Window{$grp}{conditional};
			}
			$Window{$grp}{contents} = [] if ! $Window{$grp}{contents};
			push @{$Window{$grp}{contents}}, $var;
		}
		else {
			push @addl_windows, $var;
		}

		if(! $cref->{default} and ref $cref->{history} eq 'ARRAY') {
			$cref->{default} = $cref->{history}[0];
		}

		$cref->{help}    ||= description($var);
		$cref->{message} ||= $cref->{help};

		# Set default one of three ways
		if($cref->{default}) {
			$default = $cref->{default};
		}

		if($default =~ /\t/ and ! $cref->{history}) {
			$cref->{history} = [ split /\t/, $default ];
			$default =~ s/\t.*//;
			$cref->{default} = $default;
		}
		$cref->{label} = $cref->{prompt} if ! $cref->{label};

		my $presubcode;
		if($cref->{default} =~ s/__MVC_([A-Z0-9]+)__/\$Conf{\L$1}/g) {
			$cref->{default} =~ s/\@/\\\@/g;
			my $presubcode = qq{
				sub {
					return qq[$cref->{default}]
				}
			};
			my $presub = eval $presubcode;
			if($@) {
debug("error evaling prefix sub for $var: $presubcode");
			}
			$cref->{default} = $cref->{prefix} = $presub;
			$cref->{default_source} = $presubcode;
		}
		else {
			$cref->{default} = $cref->{prefix} = $default;
		}

		$cref->{options} = $cref->{history} if ! $cref->{options};
		if ($cref->{noprompt}) {
			if($cref->{conditional}) {
				# Appease vi {
				my $snippet = <<EOF;

	\$Conf{$var} = q{$default} if \$status;
	return \$status;
}
EOF
				# Appease vi {
				$subcode =~ s/\s*return .*\s+}\s*$/$snippet/;
				$cref->{conditional} = eval $subcode;
				if($@) {
debug("Problem evaluating sub: $subcode");
				}
				$cref->{conditional_source} = $presubcode;
			}
			else {
				$Conf{$var} = $default;
				$cref->{conditional} = sub { 0 };
			}
		}
		if($cref->{always_set}) {
			$Conf{$var} = substitute($default);
		}

		if($mainparam || $cref->{group}) {
			my $winref;
			if($cref->{group}) {
				$winref = $Window{$cref->{group}};
			}
			else {
				$winref = $Content{$mainparam};
				$winref->{additional} ||= [];
				push @{$winref->{additional}}, $var;
			}
			$winref->{override} ||= {};
			$winref->{override}{$var} = $cref;
		}
		elsif ($Content{$var}) {
debug("generated duplicate param for $var with no group or mainparam.");
die("generated duplicate param for $var with no group or mainparam.");
		}
		else {
			$Content{$var} = $cref;
			push @addl_windows, $var;
		}
#debug( "ref for $var: " . ::uneval($cref));
	}
	my %seen;

	# Multiple conditions may define them more than once
	@addl_windows = grep !$seen{$_}++, @addl_windows;;
debug("read_additional returning windows: " . join ",", @addl_windows);
#debug("Here is the whole shebang:\n" . uneval(\%Window) . "\ncontent:\n" . uneval(\%Content));
	return @addl_windows;
}

sub read_common_config {
	my $data = shift;
#debug("read_common_config called with data=$data");
	my @lines = split /\n/, $data;
	my $prev = '';
	my $waiting;

	my @out;
	my $out = \@out;
	my $wref;
	my $cref;

	my $type;
	for(@lines) {
		# Strip CR, we hope
		s/\s+$//;

		# Handle continued lines
		if(s/\\$//) {
			$prev .= $_;
			next;
		}
		elsif($waiting) {
			if($_ eq $waiting) {
				undef $waiting;
				$_ = $prev;
				$prev = '';
				s/\s+$//;
			}
			else {
				$prev .= "$_\n";
				next;
			}
		}
		elsif($prev) {
			$_ = "$prev$_";
			$prev = '';
		}

		if (s/<<(\w+)$//) {
			$waiting = $1;
			$prev .= $_;
			next;
		}

		next unless /\S/;
		next if /^\s*#/;
		if(m{
				^ \s* < 
						(\w+)
						(?:\s+(\w[-\w]*\w))?
					\s*>\s*
			}x) 
		{
			$type = lc $1;
			my $name = $2 || undef;
			if($name) {
				$name = lc $name;
				$name =~ tr/-/_/;
			}
			if(defined $cref and $cref->{_window} and $type ne 'window') {
				$wref = $cref;
				$out = $wref->{content_array} ||= [];
			}
			else {
				push @$out, $cref if $cref;
			}
			$cref = { "_$type" => 1, name => $name };
			next;
		}
		elsif (m{^\s*</(\w[-\w]+\w)\s*>\s*}) {
			my $ender = lc $1;
			$ender =~ tr/-/_/;
			if(! $cref) {
				push @out, $wref if $wref;
				$out = \@out;
				undef $type;
				undef $wref;
				undef $cref;
			}
			elsif($ender eq $type) {
				if($type eq 'window') {
					push @out, ($wref || $cref);
					undef $cref;
					undef $wref;
					$out = \@out;
				}
				else {
					push @$out, $cref;
					undef $cref;
				}
			}
			else {
				die errmsg("Syntax error in config input: %s", $_);
			}
			next;
		}

		s/^\s*(\w[-\w]*\w)(\s+|$)//
			or do {
				die "Problem reading config reference type=$type: $_\n";
			};
		my $parm = lc $1;
		$cref ||= {};
		$parm =~ tr/-/_/;
		$cref->{$parm} = $_;
	}
	push @out, $cref if $cref;
	my @extra;
	for my $ref (@out) {
		if($ref->{content_array} and $ref->{_window}) {
			for (@{delete $ref->{content_array}}) {
				$_->{name} ||= $Wname++;
debug("popping $_->{name} from $ref->{name} content array");
				$_->{group} = $ref->{name};
				push @extra, $_;
			}
		}
	}
	push @out, @extra;
#debug("read_common_config: " . uneval(\@out) );
	return @out;
}

sub read_commands {
	my ($file, $wref) = @_;

	my @data;
	my @files;
	my $pre_post;
	if(! $file) {
		@files = (
			"$Conf{vendroot}/$Conf{demotype}/config/precopy_commands",
		    "$Conf{vendroot}/$Conf{demotype}/config/postcopy_commands",
		);
		$pre_post = 1;
	}
	else {
		@files = ($file);
		$wref = {} unless $wref;
	}

	for (my $i = 0; $i < @files; $i++) {
		my $fn = $files[$i];
		next if ! $fn;
		next if ! -f $fn;
		open CMDFILE, "< $fn"
			or do {
				my $msg = errmsg(
							"Cannot %s commands file %s: %s",
							errmsg('open'),
							$fn,
							$!,
						  );
				die "$msg\n";
			};
		local ($/);
		$data[$i] = <CMDFILE>;
		close CMDFILE
			or do {
				my $msg = errmsg(
							"Cannot %s commands file %s: %s",
							errmsg('close'),
							$fn,
							$!,
						  );
				die "$msg\n";
			};
	}

	my $cmd_num = "cmd000";

	return undef unless @data;
	foreach my $block (@data) {
		my $root_msg = $> == 0 ? <<EOF : '';

Because you are root, you should be very careful
what commands you run.  If you are unsure about the
ownership of any files, or of what the effects might
be, please uncheck the box next to the command.
EOF
		if($pre_post eq '1') {
			if(! $Window{precopy_commands}) {
				$Window{precopy_commands} = {
					contents => [],
					conditional => 0,
					message => 'Resolving catalog initialization commands',
				};
			}
			$wref = $Window{precopy_commands};
			$pre_post = 2;
		}
		elsif ($pre_post == 2) {
			if(! $Window{postcopy_commands}) {
				$Window{postcopy_commands} = {
					contents => [],
					banner => 'Resolving catalog finalization commands',
				};
			}
			$wref = $Window{postcopy_commands};
			$pre_post = 3;
		}
		next unless $block;

		my @cmds;
		if($block =~ /^\s*</) {
			@cmds = read_common_config($block);
		}
		else {
			@cmds = split /\n\n+/, $block;
		}
		foreach my $cmd (@cmds) {
			my $cref;
			my $unprompted;
			my $subcode;
			my $mainparam;
			my ($command, $prompt);
			if(ref $cmd) {
				$cref = $cmd;
				$cmd = '';
			}
			else {
				$cmd = substitute($cmd);
				$cmd =~ s/\\\n//g;
				$cref = {};
				my $prompt;
				($command, $prompt) = split /\n/, $cmd, 2;
				if($prompt =~ s/^\s*(\w+\s*=[^\n]*|{\s*\w+\s*=.*})\s*\n//s) {
					my $extra = $1;
#debug("Found command mods: $extra");
					my $ref = get_option_hash($extra);
#debug("Command mods: " . uneval($ref));
					if (ref $ref) {
						for (keys %$ref) {
							$cref->{$_} = $ref->{$_};
						}
					}
					else {
						warn "Unsuccessful command option parse: $extra\n";
					}
				}
				$cref->{help}   = $prompt if ! $cref->{help};
			}
			if($cref->{window_indicator}) {
				$wref ||= $Window{$cref->{name}};
				for(keys %$cref) {
					$wref->{$_} = $cref->{$_};
				}
				next;
			}
			$cref->{widget} = 'yesno' if ! $cref->{widget};
			$command = $cref->{command} if ! $command;
			$command =~ s/^\s+//;
			$command =~ s/\s+$//;
			$command =~ s/^!// and $> != 0 and $cref->{unprompted} = 1;
			delete $wref->{conditional}
				if  $wref->{conditional} eq '0'
				and $pre_post;
			
			if($command =~ s/{\s*([A-Z0-9]+)(\s*\S.*?)?\s*}\s*//) {
				$mainparam = lc $1;
				my $test = $2;
				$test =~	s{(['"]?)__MVC_([A-Z0-9]+)__\1}
							 {'\$Conf{' . lc $2 . '}'   }eg;
				$subcode = <<EOF;
 sub {
	my \$status;
#debug("conditional checking param=$mainparam testing=$test Value=\$Conf{$mainparam}");
	if(\$Conf{$mainparam} $test) {
		\$status = 1;
	}
	else {
		\$status = 0;
	}
#debug("conditional routine returning \$status");
	return \$status;
 }
EOF
			}
			elsif ( $cref->{conditional} ) {
				$cref->{conditional} =~ s/^[A-Z0-9a-z]+$/__MVC_\U${1}__/;
				$cref->{conditional} =~ s{(['"]?)__MVC_([A-Z0-9]+)__\1}
										 {'\$Conf{' . lc $2 . '}'   }eg;
				# Make vi happy: } }
				$subcode = delete $cref->{conditional};
			}

#debug("read_commands:  sub=$subcode");
			if($subcode) {
				$subcode = "sub {\n" . $cref->{conditional} . "}"
					unless $subcode =~ /^\s*sub\s+{/;
				my $sub = eval $subcode;
				if($@) {
debug("read_commands: Problem evaluating sub: $subcode");
					undef $sub;
				}
				$cref->{conditional} = $sub;
			}

			$cref->{command} = $command;
			$cref->{label}   = $command if ! $cref->{label};
			$cref->{name}    = $cmd_num++ unless $cref->{name};
			my $name = $cref->{name};
			$Content{$name} = $cref;
			if(my $gname = $cref->{group}) {
				$Window{$gname}->{contents} ||= [];
				push @{$Window{$gname}->{contents}}, $name;
			}
			else {
				push @{$wref->{contents}}, $name;
			}
		}
	}
	if($pre_post) {
		return ($Window{precopy_commands}, $Window{postcopy_commands});
	}
	else {
		return $wref;
	}
}


# Validate a field against:
#
#   check_regex -- a regular expression which must succeeed
#   check_blank -- Just needs a non-blank value
#   check_routine -- a subroutine which can return -1, 0, 1
#   check_message -- a template (from errmsg) which can be used
#
# If the return value is -1, then the error message is assumed
# to have been handled by the check_routine and is not returned.
#
sub validate {
	my ($val, $parm) = @_;
	my $thing = $Content{$parm};
	if(! $parm or ! $thing) {
		return (0, errmsg('blank'));
	}

	my $status;
	my $message = $thing->{check_message};
	my $errmsg;

	if($thing->{check_regex}) {
		$errmsg = errmsg('blank');
		$status = length($val) ? 1 : 0;
	}
	elsif($thing->{check_regex}) {
		my $regex = qr/$thing->{check_regex}/;
		$status = $val =~ $regex;
	}
	elsif($thing->{check_routine}) {
		($status, $errmsg) = $thing->{check_routine}->($val, $parm);
	}
	else {
		$status = 1;
	}

	## This allows directly returning error and no confirm screen
	return $status if abs($status);
	$message = "%s (value '%s'): failed validation"
		if ! $message;
	my $lab = label($parm) || $parm;
	$message = errmsg($message, $lab, $val, $parm);
	return($status, $message);
}

sub prefix {
	my ($parm, $nodefault, $override) = @_;
	$parm = lc $parm;
	if($Alias{$parm} and $Conf{$parm}) {
		$Conf{$parm} = $Alias{$parm}{$Conf{$parm}};
	}
	return $Conf{$parm} if $Conf{$parm};
	return $ENV{"MVC_\U$parm"} if $ENV{"MVC_\U$parm"};
	return undef if $nodefault;
	my $thing = $Content{$parm}{prefix} || $Prefix{$parm};
	if(ref $thing eq 'CODE') { 
		return $thing->();
	}
	elsif(ref $thing eq 'ARRAY') { 
		return $thing->[0];
	}
	else {
		return $thing;
	}
}

%Special_sub= (
	cryptpw => sub {
		my $pw = shift;
		return $pw if $Conf{alreadycrypt};
		my @letters = ('A' .. 'Z', 'a' .. 'z');
		my $salt = $letters[ int rand(scalar @letters) ];
		$salt .= $letters[ int rand(scalar @letters) ];
		return crypt($pw, $salt);
	},
);

sub substitute {
	my($parm) = @_;
	if($parm !~ /^\w+$/) {
		$parm =~ s/__MVC_([A-Z0-9]+)__/$Conf{lc $1}/eg;
	}
	elsif (defined $ENV{"MVC_$parm"}) {
		$parm = $ENV{"MVC_$parm"};
	}
	elsif (my $sub = $Special_sub{lc $parm}) {
		if(ref $sub) {
			$parm = $sub->($Conf{lc $parm});
		}
		else {
			$parm = $sub;
			$parm =~ s/__MVC_([A-Z0-9]+)__/$Conf{lc $1}/eg;
		}
	}
	else {
		$parm = $Conf{lc $parm};
	}
	$parm = '' unless defined $parm;
	return $parm;
}

sub sum_it {
	my ($file) = @_;
	open(IT, "<$file")
		or return undef;
	my $data = '';
	$data .= $_ while (<IT>);
	close IT;
	return unpack("%32c*", $data);
}

sub strip_na {
	my $val = shift;
	return '' if lc($val) eq 'n/a';
	return $val;
}


sub directory_process {
    my $dir = shift;
    $dir =~ s:[/\s]+$::;
    if($Conf{catuser} and $dir =~ /^~/) {
        my $userdir = ( getpwnam( $Conf{catuser} ) )[7];
		$dir =~ s/^~/$userdir/ if $userdir;
    }
    return $dir;
}

sub strip_trailing_slash {
	my $url = shift;
	$url =~ s:[/\s]+$::;
	return $url;
}


sub inet_host {
	return scalar find_inet_info('h');
}

sub inet_port {
	return scalar find_inet_info('p');
}

sub find_inet_info {
	my $type = shift;
	my (@hosts);
	my (@ports);
	my $prog = "$Conf{relocate}$Conf{vendroot}/src/tlink";
	my $the_one = sum_it($prog);
	my $defport = '7786';
	my $defhost = '127.0.0.1';

	my @poss = glob("$Conf{relocate}$Conf{vendroot}/src/tlink.*.*");
	for (@poss) {
		my $name = $_;
		/tlink\.(.*)\.(\d+)$/
			or next;
		my ($h, $p) = ($1, $2);
		push @hosts, $h;
		push @ports, $p;
		my $one = sum_it($_);
		next unless $one eq $the_one;
		$defhost = $h;
		$defport = $p;
	}

	if(! $type) {
		my %seen;
		@ports = grep !$seen{$_}++, @ports;
		%seen = ();
		@hosts = grep !$seen{$_}++, @hosts;
		return (\@hosts, \@ports);
	}
	elsif ($type =~ /^h/i) {
		return $defhost;
	}
	elsif ($type =~ /^p/i) {
		return $defport;
	}
}

sub applicable_directive {
	my ($direc, $routine) = @_;
	$direc = lc($direc);
	if($routine) {
		return undef if ! $routine->($direc);
	}
	return $direc if ! defined $IfRoot{$direc};
	return undef if $Conf{asroot} xor $IfRoot{$direc};
	return $direc;
}


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

sub history {
	my $parm = shift;
	$parm = lc $parm;
	return unless defined $History{$parm};
	my @things = $History{$parm}->(@_);
	return wantarray ? @things : \@things;
}

sub error_message {
	my($parm) = @_;
	$parm = lc $parm;
	return defined $Validate{$parm} ? $Validate{$parm} : '';
}

sub label {
	my($parm) = @_;
	return defined $Label{lc $parm} ? $Label{lc $parm} : '';
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
 
sub set_owner {
	return unless $> == 0;
	my($file) = @_;
	resolve_owner()
		unless $Conf{interchangeuid};
	
	my ($user, $group) = ($Conf{interchangeuid}, $Conf{interchangegid});
	die errmsg("Can't find info: %s", 'interchangeuid')
		unless $Conf{interchangeuid};
	
	if($Conf{permtype} =~ /^m/i) {
		$user = $Conf{catuseruid};
		$group = $Conf{catusergid};
	}
	elsif($Conf{permtype} =~ /^g/i) {
		$group = $Conf{catusergid};
	}
	chown($user, $group, $file)
		or die errmsg(
				"Couldn't set ownership to UID=%s GID=%s for %s: %s", 
				$user,
				$group,
				$file,
				$!,
			);
}

sub install_file {
	my ($srcdir, $targdir, $filename, $opt) = @_;
	$opt = {} unless $opt;
	my $save_umask;
	if($opt->{umask} ) {
		$save_umask = umask $opt->{umask};
		local($SIG{__DIE__}) = sub { umask $save_umask; warn @_; exit 1 };
	}

	my $scale;
	if($scale = $opt->{scale_call}) {
		$scale->( 'start', $opt->{scale}, $opt->{message});
	}

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
		File::Path::mkpath($mkdir, undef, $opt->{dmode} || 0777)
			or die "Couldn't make directory $mkdir: $!\n";
		chmod($opt->{dmode}, $mkdir) if $opt->{dmode};
		set_owner($mkdir);
	}

	if (! -f $srcfile) {
		die "Source file $srcfile missing.\n";
	}
	elsif (
		$opt->{perm_hash}
			and $opt->{perm_hash}->{$filename}
		)
	{
		$perms = $opt->{perm_hash}->{$filename};
	}
	elsif ($opt->{fmode}) {
		$perms = $opt->{fmode};
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

	if( ! $Global::Win32 and -f $targfile and ! compare_file($srcfile, $targfile) ) {
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
			open(SOURCE, "< $bak")
				or die errmsg("%s %s: %s\n", errmsg("open"), $bak, $!);
			open(TARGET, ">$targfile")
				or die errmsg("%s %s: %s\n", errmsg("create"), $bak, $!);
			local($/) = undef;
			my $page = <SOURCE>; close SOURCE;

			$page =~ s/^#>>(.*)(__MVR_(\w+)__.*)\n\1.*/#>>$1$2/mg;
			$page =~ s/^#>>(.*__MVR_(\w+)__.*)/#>>$1\n$1/mg;
			1 while $page =~ s/^([^#].*)__MVR_(.*)/$1__MVC_$2/mg;
			$page =~ s/__MV[CS]_([A-Z0-9]+)__/$opt->{Substitute}{lc $1}/g;

			print TARGET $page				or die "print $targfile: $!\n";
			close TARGET					or die "close $targfile: $!\n";
			unlink $bak						or die "unlink $bak: $!\n";
	}

	chmod $perms, $targfile;
	$scale->('end') if $scale;
	umask $save_umask if $save_umask;
	return 1;
}

sub debug {
	for(@_) {
		print DEBUG "$_\n";
	}
	return;
}

sub copy_current_to_dir {
	my($target_dir, $exclude_pattern) = @_;
	return copy_dir('.', $target_dir, $exclude_pattern);
}

sub copy_dir {
	my($source_dir, $target_dir, $exclude_pattern, $opt) = @_;
	return undef unless -d $source_dir;
	$opt = {} unless $opt;
	my $scale;
	if($scale = $opt->{scale_call}) {
		$scale->('start', $opt->{scale}, $opt->{message});
	}
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

	$term = new Term::ReadLine 'Interchange Configuration';
	die "No Term::ReadLine" unless defined $term;

	readline::rl_set('CompleteAddsuffix', 'Off');
	readline::rl_set('TcshCompleteMode', 'On');
	$Prompt_sub = sub {
		my ($prompt, $default) = @_;
		if($Force) {
			print "$prompt SET TO --> $default\n";
			return $default;
		}
		$prompt =~ s/^\s*(\n+)/print $1/ge;
		$prompt =~ s/\n+//g;
		readline::rl_bind('C-x', 'catch-cancel');
		readline::rl_bind('C-b', 'catch-backward');
		readline::rl_bind('C-y', 'catch-help');
		readline::rl_bind('C-f', 'catch-forward');
		if(! $Conf{vi_edit_mode}) {
			readline::rl_bind('"\M-\OP"', 'catch-help');
			readline::rl_bind('"\M-[20"', 'catch-backward');
			readline::rl_bind('"\M-[21"', 'catch-forward');
			#readline::rl_bind('"\M-[1"', 'catch-cancel');
			readline::rl_bind('"\M-[5"', 'catch-backward');
			readline::rl_bind('"\M-[6"', 'catch-forward');
		}
		my $out = $term->readline($prompt, $default);
		return "\cB" if ! defined $out;
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
	return $History_add->(@_);
}

sub sethistory {
	return '' unless defined $History_set;
	return $History_set->(@_);
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
	my ($file, $directive, $configname, $value) = @_;
	if(! $file) {
		$file = "$Conf{relocate}$Global::ConfigFile";
	}
	$configname = $Conf{catalogname} if ! $configname;
	$directive  = 'Catalog'          if ! $directive;
	if (! $value) {
		$value = "$Conf{catalogname} $Conf{catroot} $Conf{cgiurl}";
		$value .= " $Conf{aliases}" if $Conf{aliases};
	}
	my ($newcfgline, $mark, @out);
	my ($tmpfile) = "$file.$$";
	if (-f $file) {
		rename ($file, $tmpfile)
			or die "Couldn't rename $file: $!\n";
	}
	else {
		File::Copy::copy("$file.dist", $tmpfile)
			or die errmsg("Couldn't find interchange.cfg");
	}
	open(CFG, "< $tmpfile")
		or die "Couldn't open $tmpfile: $!\n";
	$newcfgline = sprintf "%-19s %s\n", $directive, $value;
	while(<CFG>) {
		$mark = $. if /^#?\s*catalog\s+/i;
debug("\nDeleting old configuration $configname.\n") if s/^(\s*$directive\s+$configname\s+)/#$1/io;
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
	close NEWCFG || die errmsg("%s %s: %s\n", 'close', $file, $!);
	unlink $tmpfile;
}

sub server_running {
	local ($/);
debug("in server_running, pid file=$Global::PIDfile");
	open(PID, "+< $Global::PIDfile")
		or return undef;
debug("opened PID file");
	if(Vend::Util::lockfile(\*PID, 1, 0)) {
debug("PID file not locked");
		## Daemon not running;
		close PID;
		return undef;
	}
	my $pid = <PID>;
debug("PID=$pid");
	$pid =~ /(\d+)/;
	$pid = $1;
	return $pid;
}

sub run_catalog {
	my ($file, $directive, $configname, $value) = @_;
	$Conf{relocate}
		and die errmsg("Can't add catalog to running server when relocating.");
 
	if(! $file) {
		my $fn = 'restart';
		$file  = "$Global::RunDir/$fn";
	}

	$configname = $Conf{catalogname} if ! $configname;
	$directive  = 'Catalog'          if ! $directive;
	if (! $value) {
		$value = "$Conf{catalogname} $Conf{catroot} $Conf{cgiurl}";
		$value .= " $Conf{aliases}" if $Conf{aliases};
	}
	my $pid = server_running();
	if(! defined $pid) {
		die errmsg("Can't add %s to server: not running", $configname);
	}

	open(RESTART, "<+$file")
		or open(RESTART, ">>$file")
			or die errmsg("%s %s: %s\n", errmsg("write"), $file, $!);
	Vend::Util::lockfile(\*RESTART, 1, 1)
			or die errmsg("%s %s: %s\n", errmsg("lock"), $file, $!);
	printf RESTART "%-19s %s\n", $directive, $value;
	Vend::Util::unlockfile(\*RESTART) 
		or die errmsg("%s %s: %s\n", errmsg("unlock"), $file, $!);
	close RESTART;
	set_owner($file);
	kill 'HUP', $pid;
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

	
	if($data =~ s/^\s*resourceconfig\s+("?)(.*)\1//i) {
		$newfile = $2;
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
					((?s:.)*?)
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
			$servname = Sys::Hostname::hostname() unless $servname;
			$servname =~ s/\s+$//;
			$main = $servname;
			$servers->{$servname} = {} if ! $servers->{$servname};
			$servers->{$servname}{Master} = 1;
		}
		next unless $servname;

		my $ref = $servers->{$servname};

		$ref->{servername} = $servname;

		foreach my $line (@data) {
			$line =~ s/^\s+//;
			$line =~ s/\s+$//;
			my ($key, $val);
			my ($directive,$param) = split /\s+/, $line, 2;
			$directive = lc $directive;
			if(defined $Http_hash{$directive}) {
				$ref->{$directive} = {}
					unless defined $ref->{$directive};
				my ($key,$val) = split /\s+/, $param, 2;
				$val =~ s/^\s*"// and $val =~ s/"\s*$//;
				if (defined $Http_process{$directive}) {
					$key = $Http_process{$directive}->('key', $key);
					$val = $Http_process{$directive}->('value', $val);
				}
				$ref->{$directive}{$key} = $val;
			}
			elsif(defined $Http_scalar{$directive}) {
				$param =~ s/^"// and $param =~ s/"\s*$//;
				if (defined $ref->{$directive}) {
					undef $ref;
					$Error = "$directive defined twice in $servname, only allowed once.";
					return undef;
				}
				if (defined $Http_process{$directive}) {
					$param = $Http_process{$directive}->($param);
				}
				$ref->{$directive} = $param;
			}
		}
	}
			
	return $servers;
}

sub substitute_cryptpw {
	my $pw = $Conf{cryptpw};
	return unless $pw;
	return if $Conf{alreadycrypt}++;
	my @letters = ('A' .. 'Z', 'a' .. 'z');
	my $salt = $letters[ int rand(scalar @letters) ];
	$salt .= $letters[ int rand(scalar @letters) ];
	$Conf{cryptpw} = crypt($pw, $salt);
}

sub unique_ary {
	my %seen;
	%seen = ();
	return ( grep !$seen{$_}++, @_ );
}

sub resolve_owner {
	my $cref = shift || \%Conf;
	die errmsg("Usage: %s", "resolve_owner({ })")
		unless ref $cref eq 'HASH';
	return unless $> == 0 || $cref->{asroot};
	my @things = qw/interchangeuser interchangegroup catuser catgroup/;
	my ($icu, $icg, $catu, $catg) = @$cref{@things};

	$catu = $icu if ! $catu;
	
	# Default groups
	my $icd;
	my $catd;

	my($icu_uid, $catu_uid, $icg_gid, $catg_gid);
	$icu_uid = getpwnam($icu)
		or die errmsg("User does not exist: %s\n", $icu);
	$catu_uid = getpwnam($catu)
		or die errmsg("User does not exist: %s\n", $catu);

	if($cref->{permtype} =~ /^\s*m/i) {
		$icg_gid = (getpwnam($catu))[3] if ! $icg;
		$catg_gid = (getpwnam($catu))[3];
	}
	elsif($cref->{permtype} =~ /^\s*g/i) {
		$icg_gid = (getpwnam($icu))[3] if ! $icg;
		$catg_gid = (getpwnam($icu))[3];
	}
	else {
		$icg_gid = (getpwnam($catu))[3] if ! $icg;
		$catg_gid = (getpwnam($catu))[3];
	}
	$icg_gid = (getpwnam($icu))[3] if ! $icg_gid;
	$catg_gid = (getpwnam($catu))[3] if ! $catg_gid;

	@$cref{qw/
			interchangeuid
			interchangegid
			catuid
			catgid
			/} = ($icu_uid, $icg_gid, $catu_uid, $catg_gid);
	return $cref;
}

sub hammer_symlinks {
	my $dir = shift;
	File::Find::find(
					sub {
						return if ! -l $_;
						unlink $_
							or die "couldn't unlink $File::Find::name: $!\n";
					},
					$dir,
	 );
	 return 1;
}



sub check_root_execute { 
	my $dir = shift;
	return undef if ! -d $dir;
	my @disc;
	my $wanted = sub {
		my @stat = stat($_);
		my $type = -d _ ? 'directory' : 'file';
		push @disc, [ $type, $File::Find::name, l('not owned by root')]
			if $stat[4] != 0;
		push @disc, [ $type, $File::Find::name, l('world writable')   ]
			if (07777 & $stat[2] & 02);
		push @disc, [ $type, $File::Find::name, l('group writable')   ]
			if (07777 & $stat[2] & 020);
	};

	File::Find::find($wanted, $dir);
	return 1 if ! @disc;
	my $out = "";
	for (@disc) {
		$_->[1] =~ s!^$dir/!!;
		$out .= errmsg("  %s %s is %s\n", @$_);
	}
	return $out;
}

sub compile_link {
	my $cref = shift || \%Conf;
	for( qw/linkmode cgiurl vendroot cgidir cgiurl/) {
		die errmsg("improper reference passed, missing: %s", $_)
			if ! $cref->{$_};
	}
	return 1 if $cref->{linkmode} =~ /^\s*n/i;
	my @args;
	my $cginame = $cref->{cgiurl};
	$cginame =~ s:.*/::;
	$cref->{cgifile} = $cginame = "$cref->{relocate}$cref->{cgidir}/$cginame";
	die errmsg("%s %s: %s", 'target file', $cref->{cgifile}, 'is a directory')
		if -e $cref->{cgifile};
	my $exec = "$cref->{relocate}$cref->{vendroot}/bin/compile_link";
	die errmsg("%s %s: %s", 'executable file', $exec, 'not executable')
		if ! -x $exec;
	push @args, (
			$cref->{linkmode} =~ /^\s*u/i 
			? '--unixmode'
			: '--inetmode'
		);
	push @args, "--source=$cref->{relocate}$cref->{vendroot}/src";
	push @args, "--outputfile=$cref->{relocate}$cref->{cgifile}";
	push @args, "--port=$cref->{linkport}"
		if $cref->{linkport};
	push @args, "--host=$cref->{linkhost}"
		if $cref->{linkhost};
	push @args, "--nosuid"
		if $cref->{cgiwrap};
	push @args, "--nosuid"
		if $cref->{cgiwrap};
	for (@args) {
		die errmsg("Improper argument: %s", $_)
			if /"/;
		$_ = qq{"$_"};
	}
	my $dir = $ENV{TMP} || '/tmp';
	my $bdir    = "$dir/compile_link.$$";
	my $outfile = "$bdir/build.out";
	my $errfile = "$bdir/build.err";
	File::Path::mkpath($bdir);
	push @args, "--build=$bdir";
	
	system join " ",
			   $exec,
			   @args,
			   "2>$errfile",
			   ">$outfile";
	
	if($?) {
		my $msg = `cat $errfile`;
		die errmsg("Failed to compile and copy link:\n\n%s", $msg);
	}
	File::Path::rmtree($bdir);
	unlink $errfile;
	unlink $outfile;
	return 1;
}

my @Action;

sub evaluate_action {
	my $act = shift;
	ref($act) eq 'HASH' or die "usage: evaluate_action(\%action)";
	my $orig_dir;
	my $error;
	eval {
		if($act->{chdir}) {
			$orig_dir = cwd();
			my $dir = $act->{chdir};
			$dir = substitute($dir) if $dir =~ /__MVC_/;
			chdir $dir
				or die errmsg("Unable to change directory to %s.", $dir) . "\n";
		}
		if($act->{from_dir} and $act->{to_dir}) {
			if($Conf{relocate}) {
				$act->{to_dir} = "$Conf{relocate}$act->{to_dir}";
				$act->{from_dir} = "$Conf{relocate}$act->{from_dir}";
			}
			copy_dir($act->{from_dir}, $act->{to_dir}, undef, $act);
			if($act->{delete_from}) {
				File::Path::rmtree($act->{from_dir});
			}
		}
		if(my $sub = $act->{sub}) {
			my $args = $act->{args} || [];
			$sub->(@$args);
		}
		if(my $cmd = $act->{command}) {
			$cmd = substitute($cmd) if $cmd =~ /__MVC_/;
			system $cmd;
			if($?) {
				my $status = $? >> 8;
				die errmsg(
						"Command %s returned status %s: %s",
						$cmd,
						$status,
						$!,
					) . "\n";
			}
		}
	};
	$error = $@ if $@;
	chdir $orig_dir if $orig_dir;
	die $error if $error;
	return;
}

sub build_cat {
	my ($scale, $die, $warn, $opt) = @_;
debug("build_cat called scalesub=$scale");
	
	$opt ||= {};
	(
		$scale  && ! ref $scale eq 'CODE'
			or
		$die    && ! ref $die   eq 'CODE'
			or
		$warn   && ! ref $warn  eq 'CODE'
			or
		$opt    && ! ref $opt   eq 'HASH'
	) and die errmsg("usage: %s", 'build_cat(\&scale,\&die,\&warn,$hashref)');

	$die  = sub { die  errmsg(@_) . "\n"; } if ! $die;
	$warn = sub { die  errmsg(@_) . "\n"; } if ! $die;

	my $cref = $opt->{configuration} || \%Conf;

	my @action;

#	Here we create an array of hashes. The elements:
#	structure is:
#		
#		from_dir       =>  directory to copy from (done before sub)
#		to_dir         =>  directory to copy to
#		delete_from    =>  delete from_dir when finished
#		sub		       =>  subroutine to run
#		args           =>  subroutine args
#		message        =>  message for scale routine
#		scale          =>  value to be added to scale when done
#		error          =>  Error message if fails
#		error_ok       =>  Ignore error if it occurs
#		error_warn     =>  Issue conditional warning if error
#                          (dies if in batch mode)
#
#   If "action_ref" option key is provided, it is used instead. (Unlikely
#   ever to be used, obviously.)

	CREATEACTION: {
		if($opt->{action_ref}) {
			@action = @{$opt->{action_ref}};
			last CREATEACTION;
		}

		push @action, {
					sub => \&substitute_cryptpw,
					message => errmsg('Encrypting passwords'),
					scale => 1,
				};

		push @action, {
					sub => \&compile_link,
					args => [ $cref ],
					message => errmsg('Compiling link programs'),
					scale => 4,
				};

		push @action, { 
				sub => sub {
					hammer_symlinks("$Conf{relocate}$Conf{catroot}"),
				},
				message => errmsg("Cleaning up catalog directory"),
				scale => 1,
		} if -d "$Conf{relocate}$Conf{catroot}";

		if(my $wref = $Window{precopy_commands}) {
			$wref->{contents} ||= [];
			for(@{$wref->{contents}}) {
				my $cref = $Content{$_};
				$cref->{scale} = 1 unless defined $cref->{scale};
				$cref->{message} = "Running $cref->{command}"
					unless $cref->{message};
				$cref->{error_warn} = 1
					unless $cref->{error_ok};
				if(! $cref->{conditional} or $cref->{conditional}->()) {
					push @action, $cref;
				}
			}
		}
		push @action, {
					from_dir	=> "$Conf{vendroot}/$Conf{demotype}",
					to_dir		=>  $Conf{catroot},
					dmode		=>  02770,
					fmode		=>  0660,
					Substitute  =>  \%Conf,
					error 		=>  $Build_error{demotype},
					message		=>  errmsg("Copying base demo skeleton"),
					scale		=>  3,
				};

		push @action, {
					delete_from =>  1,
					dmode		=>  0775,
					error 		=>  $Build_error{demotype},
					fmode		=>  0664,
					from_dir	=>  "$Conf{catroot}/html",
					message		=>  errmsg("Copying public HTML files"),
					scale		=>  1,
					to_dir		=>  $Conf{samplehtml},
				};

		push @action, {
					delete_from =>  1,
					dmode		=>  0775,
					error 		=>  $Build_error{demotype},
					fmode		=>  0664,
					from_dir	=>  "$Conf{catroot}/images",
					message		=>  errmsg("Copying image files"),
					scale		=>  2,
					symlink_to  =>  1,
					to_dir		=>  $Conf{imagedir},
				};

		if(my $wref = $Window{postcopy_commands}) {
			$wref->{contents} ||= [];
			for(@{$wref->{contents}}) {
				my $cref = $Content{$_};
				$cref->{scale} = 1 unless defined $cref->{scale};
				$cref->{chdir} = $Conf{catroot} unless $cref->{chdir};
				$cref->{message} = "Running $cref->{command}"
					unless $cref->{message};
				$cref->{error_warn} = 1
					unless $cref->{error_ok};
				if(! $cref->{conditional} or $cref->{conditional}->()) {
					push @action, $cref;
				}
			}
		}

		push @action, {
				sub => \&add_catalog,
				message		=>  errmsg("Adding catalog to interchange.cfg"),
				scale => 1,
		} if $cref->{add_catalog};
debug("run_catalog=$cref->{run_catalog} server_running=" . server_running());
		push @action, {
				sub => \&run_catalog,
				message		=>  errmsg("Running catalog"),
				scale => 1,
		} if $cref->{run_catalog} and server_running();
	}
	my $total_scale = 0;
	foreach my $act (@action) {
		$total_scale += $act->{scale};
	}

debug("total scale amount=$total_scale scalesub=$scale");
	## install_scale returns a closure implementing whatever scale
	## there is....
	my $msg = errmsg("Installing catalog: %s", $Conf{catalogname});
	my $scale_call;
debug("scale_call=$scale_call");
	if(! $opt->{event_driven}) {
		$scale_call = $scale->($total_scale, $msg)
			if $scale;
		foreach my $act (@action) {
debug("action: " . uneval($act));
			$scale_call->('start', $act->{scale}, errmsg($act->{message}))
				if $scale_call;
			#select(undef,undef,undef, .75);
			my $orig_dir;
			eval {
				evaluate_action($act);
			};
			if(! $@) {
				$scale_call->('end')
					if $scale_call;
			}
			elsif($act->{error_ok}) {
debug("action error_ok: $@");
				my $msg = errmsg($act->{message}) . "..." . errmsg('failed') . ".";
				$scale_call->('end', undef, $msg)
					if $scale_call;;
			}
			elsif($act->{error_warn}) {
debug("action error_warn: $@");
				my $msg = $@;
				$warn->($msg) 
					or do {
						$die->($msg);
						return undef;
					};
			}
			else {
debug("action fatal_error: $@");
				$die->( errmsg("Error installing catalog %s: %s"));
				return undef;
			}
			chdir $orig_dir if $orig_dir;
		}
		$scale_call->('finish')
			if $scale_call;
	}
	elsif($scale) {
		eval {
			$scale->($total_scale, $msg, \&evaluate_action, @action);
		};
		if($@) {
debug("action fatal_error: $@");
			$die->( errmsg("Error installing catalog %s: %s"));
			return undef;
		}
	}
	else {
		die "Must have scale subroutine call if event-driven\n";
	}

}

package readline;

use vars qw/$AcceptLine/;

sub discard_ReadKey {
	return unless $Term::ReadKey::VERSION;
	my $timeout = shift || '-1';
	local($^W);
	eval {
			Term::ReadKey::ReadKey(-1, $readline::term_IN);
	};
}

sub F_CatchHelp {
		$AcceptLine = "\cY";
}

sub F_CatchCancel {
		$AcceptLine = "\cX";
		discard_ReadKey(1);
}

sub F_CatchBackward {
		$AcceptLine = "\cB";
		discard_ReadKey(1);
}

sub F_CatchForward {
		$AcceptLine = "\cF";
		discard_ReadKey(1);
}

1;
__END__
