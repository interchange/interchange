#!/usr/bin/perl
##!~_~perlpath~_~
#
# Interchange catalog configurator with curses
#
# $Id: newcat.PL,v 2.6 2002-06-27 18:55:50 jon Exp $
#
# Copyright (C) 1996-2002 Red Hat, Inc. <interchange@redhat.com>
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

use lib '/work/interchange/lib';
#use lib '~_~INSTALLPRIVLIB~_~';
use lib '/work/interchange';
#use lib '~_~INSTALLARCHLIB~_~';

use Config;
use File::Find;
use File::Copy;
use File::Path;
use Sys::Hostname;
use Vend::MakeCat;
use Vend::Util;
use Vend::Config;
use Getopt::Long;
use IniConf;
use Cwd;
use vars qw/$CGIwrap/;
use strict;

Getopt::Long::config(qw/permute/);
#Getopt::Long::config(qw/debug/);

BEGIN {

	($Global::VendRoot = $ENV{MINIVEND_ROOT})
		if defined $ENV{MINIVEND_ROOT};
	$Global::VendRoot = $Global::VendRoot || '/work/interchange';
#	$Global::VendRoot = $Global::VendRoot || '~_~INSTALLARCHLIB~_~';

	$Global::ProgRoot = $Global::ProgRoot || '/work/interchange';
#	$Global::ProgRoot = $Global::ProgRoot || '~_~INSTALLARCHLIB~_~';

	if(-f "$Global::VendRoot/interchange.cfg") {
		$Global::ExeName = 'interchange';
		$Global::ConfigFile = 'interchange.cfg';
	}
	elsif(-f "$Global::VendRoot/minivend.cfg") {
		$Global::ExeName = 'minivend';
		$Global::ConfigFile = 'minivend.cfg';
	}
	else {
		$Global::ExeName = 'interchange';
		$Global::ConfigFile = 'interchange.cfg';
	}
	$Global::Win32 = 1 if $Config{osname} =~ /win32|cygwin/i;
}

BEGIN: {
	eval {
		use Newt qw/:keys :exits
					NEWT_ANCHOR_LEFT
					NEWT_ANCHOR_RIGHT
					NEWT_FLAG_SCROLL
					NEWT_FLAG_RETURNEXIT
					NEWT_FLAG_WRAP
				/;
		$Vend::Newt = 1;
	};
}

### END CONFIGURATION VARIABLES

$| = 1; select STDERR; 
$| = 1; select STDOUT; 


# Package lexicals for state
my $Beginner;
my $BgColor = '#990000';				# Background color for Gtk
my $CgiDefault;
my $CgiUrlDefault;
my $Configfile;
my $Debug = $ENV{INTERCHANGE_DEBUG};
my $DistDemo = 'foundation';
my $Displaymode;
my $DocrootDefault;
my $Expert;
my $Gtk_result;
my $Help;
my $Logfile = 'makecat.log';
my $Logo;
my $Water;
my $WaterFile = "$Global::VendRoot/share/pixmaps/shadowman-48.xpm";
my $LogoFile = "$Global::VendRoot/share/pixmaps/shadowman-64.xpm";
my $No_curses;
my $Reconfigure;
my $Removeconfig;
my $Servers = {};
my $Tilde;

# The initial windows
my @Windows;

# Additional windows, usually from install template additional_fields
my @Additional;

# Final windows, before install
my @Final;

# Messages that we want to display in a window...
my @Messages;

my $USAGE = <<EOF;
usage: $0 [options] [catalogname]
 
options:
 
    -F    Force make of catalog with defaults
    -c    Configuration file (default is etc/makecat.cfg)
    -l    File to log to (default makecat.log)
    -r    Reconfigure defaults
 
    [catalogname] must contain alphanumerics and hyphens only.
 
    Defaults:
    --basedir=directory        Base directory for catalogs
    --cgibase=url_fragment     Base URL for link programs
    --documentroot=directory   The directory where HTML is based
    --interchangegroup=group   The default group files should be owned by
    --interchangeuser=username The user ID which runs Interchange
    --serverconf=filename      Location of httpd.conf
    --vendroot=filename        Location of Interchange software
    --homedir=directory        Use instead of \$HOME to set defaults
 
    Required:
    --catroot=directory        Directory where Interchange catalog files go
    --cgidir=directory         The directory the CGI link should go to
    --servername=server        Name of server (www.whatever.domain)
    --cgiurl=url_fragment      The path to the CGI link (no server name)
    --demotype=template        The template catalog (foundation is the default)
    --mailorderto=email        Email address to send orders
 
    Optional:
    --asroot                   Run program as if we are root
    --catuser=username         The user files should be owned by (if root)
    --expert                   Dispense with help messages
    --sharedir=directory       The directory where shared admin images go
    --shareurl=url             The URL to prefix shared admin images with
    --imagedir=directory       The directory where template images go
    --imageurl=url             The URL to prefix images with
    --linkmode=mode            UNIX, INET, or NONE (vlink or tlink, default UNIX)
    --linkhost=host            INET link target host
    --linkport=port            INET link target port
    --linkprogram=file         Use file as link program instead of vlink/tlink
    --nocfg                    Don't add to $Global::ConfigFile
    --nocopy                   Don't actually copy the files, just test
    --norunning                Don't add to running server
    --noumask                  Don't set umask
    --permtype=[M|G|U]         Set permission type (Multi, Group, User)
    --reference                Return hash of config as string
                               (sets -F, no write)
    --relocate=dir             Directory to relocate files to (for RPM and such)
    --samplehtml=directory     The directory where template HTML goes
    --sampleurl=url            URL to access HTML for catalog
    --vi                       Use vi key bindings (if you have vi as VISUAL)
 
In addition, any option can be passed with OPTION=value with no leading hyphen
(-). This allows setting options found in the catalog template definition.
EOF

my %optctl = (
	'F'                 => \$Vend::MakeCat::Force,
	'asroot'            => \$Conf{asroot},
	'aliases'           => \$Conf{aliases},
	'novice'            => \$Beginner,
	'basedir'           => \$Conf{basedir},
	'catalogname'       => \$Conf{catalogname},
	'catroot'           => \$Conf{catroot},
	'catuser'           => \$Conf{catuser},
	'cgibase'           => \$Conf{cgibase},
	'cgidir'            => \$Conf{cgidir},
	'cgiurl'            => \$Conf{cgiurl},
	'debug'	            => \$Debug,
	'demotype'          => \$Conf{demotype},
	'documentroot'      => \$Conf{documentroot},
	'c'                 => \$Configfile,
	'help'              => \$Help,
	'displaymode'       => \$Displaymode,
	'expert'			=> \$Expert,
	'homedir'           => \$Conf{homedir},
	'imagedir'          => \$Conf{imagedir},
	'imageurl'          => \$Conf{imageurl},
	'l'                 => \$Logfile,
	'linkmode'          => \$Conf{linkmode},
	'linkhost'          => \$Conf{linkhost},
	'linkport'          => \$Conf{linkport},
	'linkprogram'       => \$Conf{linkprogram},
	'mailorderto'       => \$Conf{mailorderto},
	'icconfig'          => \$Global::ConfigFile,
	'interchangegroup'  => \$Conf{interchangegroup},
	'interchangeuser'   => \$Conf{interchangeuser},
	'nocurses'          => \$No_curses,
	'nocfg'             => \$Conf{nocfg},
	'nocopy'            => \$Conf{nocopy},
	'norunning'         => \$Conf{norunning},
	'noumask'           => \$Conf{noumask},
	'permtype'          => \$Conf{permtype},
	'r'                 => \$Reconfigure,
	'reference'         => \$Conf{reference},
	'relocate'          => \$Conf{relocate},
	'samplehtml'        => \$Conf{samplehtml},
	'sampleurl'         => \$Conf{sampleurl},
	'sharedir'          => \$Conf{sharedir},
	'shareurl'          => \$Conf{shareurl},
	'serverconf'        => \$Conf{serverconf},
	'servername'        => \$Conf{servername},
	'vendroot'          => \$Conf{vendroot},
	'vi'          		=> \$Conf{vi_edit_mode},
	'<>'                => sub {
						my $arg = shift;
						return unless $arg =~ /=/;
						my ($opt, $val) = split /=/, $arg, 2;
						$opt = lc $opt;
						die "Can't set \U$opt\E twice.\n$USAGE\n"
							if defined $Conf{$opt};
						$Conf{$opt} = $val;
						return;
						},
);

my @options = ( qw/
	F
	asroot
	aliases=s
	basedir|base=s
	catalogname|name=s
	catroot|dir=s
	catuser|user=s
	cgibase=s
	cgidir=s
	cgiurl|script=s
	demotype|template=s
	debug
	documentroot=s
	c=s
	displaymode|dm=s
	expert
	help|h
	homedir=s
	iconfig=s
	imagedir=s
	imageurl=s
	l=s
	linkmode=s
	linkhost=s
	linkport=s
	linkprogram=s
	mailorderto=s
	nocurses
	novice
	interchangegroup|minivendgroup|group=s
	interchangeuser|minivenduser|mvuser=s
	nocfg
	nocopy
	norunning
	permtype=s
	r
	reference
	relocate=s
	samplehtml|html=s
	sampleurl=s
	serverconf|conf=s
	servername|server=s
	sharedir=s
	shareurl:s
	vendroot|mvdir=s
	vi
	<>
/);

$Conf{vendroot} = $Global::VendRoot;

GetOptions(\%optctl, @options)			or die "\n$USAGE\n";

for(keys %Conf) {
	$Commandline{$_} = $Conf{$_};
}

if($Help) {
	print "\n$USAGE\n";
	exit 2;
}

$Vend::Gtk = undef;

if(! $Displaymode or $Displaymode =~ /^\s*g/i) {
	undef $Displaymode;
	eval {
		eval "use Gtk";
		die if $@;
		eval "use Gnome";
		die if $@;
		$Vend::Gtk = 1;
		$Displaymode = 'gtk';
	};
}

if(! $Displaymode or $Displaymode =~ /^\s*n/i) {
	undef $Displaymode;
	$Displaymode = 'newt' if $Vend::Newt;
	$Vend::Newt = 1;
}

$Displaymode = 'tty' unless $Displaymode =~ /^(gtk|newt)$/;

$Vend::ExternalProgram = 1;

if(! -f $Global::ConfigFile) {
	for( "$Global::VendRoot/interchange.cfg", "/etc/interchange.cfg") {
		next unless -f $_ and -r _;
		$Global::ConfigFile = $_;
	}
}

eval {
	Vend::Config::global_config();
};

## If it fails, probably because never configured.
if($@) {
print "Config parse failed. $@\n";
	$Global::ConfigFile = "$Global::VendRoot/interchange.cfg";
}

$Conf{catalogname} = shift unless $Conf{catalogname};

if($Debug) {
	open (Vend::MakeCat::DEBUG, ">>/tmp/newt.debug");
	my $save = select Vend::MakeCat::DEBUG;
	$| = 1;
	select $save;
}

if(@ARGV) {
	die <<EOF . "\n";
Extra command line arguments were found. (Did you specify
both --catalogname=name and one on the command line?)

$USAGE
EOF
}

if($Conf{homedir}) {
	die "Directory set with --homedir=$Conf{homedir} is not a directory.\n"
		unless -d $Conf{homedir};
	$ENV{HOME} = $Conf{homedir};
}

if($Conf{'reference'}) {
	$Vend::MakeCat::Force =
	$Conf{nocopy}         =
	$Conf{norunning}      =
	$Conf{nocfg}          = 1;
	$Logfile = $Global::Win32 ?  'nul:'	: '/dev/null';
}

if ($Vend::MakeCat::Force) {
	undef $Vend::Newt;
	my $file = $Logfile || 'makecat.log';
	open(LOGOUT, ">>$file") or die "write $file: $!\n";
	select LOGOUT;
}

my @routines = qw(
	cancel_question
	close_display
	continue_question
	display_it
	fatal_question
	install_scale
	help_message
	init_display
	root_message
);

sub set_display_routines {
	my $tag = shift;
	$tag .= "_";
	no strict 'refs';
	for(@routines) {
		*{$_} = \&{"$tag$_"};
		if(! defined &{$_}) {
			*{$_} = sub { 1 };
		}
	}
}

set_display_routines($Displaymode);

$Configfile = "$Global::VendRoot/etc/makecat.cfg" unless $Configfile;

my @baseparms = qw/
		basedir
		cgibase
		cgidir
		documentroot
		interchangegroup
		interchangeuser
		linkmode
		serverconf
		servername
		sharedir
		shareurl
		vendroot
/;

my $Cfg;
my $isroot;

if ($> == 0) {
	$Conf{asroot} = 1;
	$isroot = 1;
}

%IfRoot = (qw( permtype 1 interchangeuser 1 interchangegroup 1 catuser 1));

%Prefix = (
	aliases      =>  sub { return "/$Conf{catalogname}" },
	basedir      =>  sub {
							return prefix('basedir', 1) if prefix('basedir', 1);
							return "$Conf{vendroot}/catalogs"
								if $Global::Win32;
							return "$ENV{HOME}/catalogs"
								unless $Conf{asroot};
							return "~/catalogs";
							},
	catalogname  =>   $Conf{catalogname},
	catroot      =>   sub {
							my $dir = prefix('basedir') . "/" . $Conf{catalogname};
							return $dir if $Global::Win32;
							my $userdir = (getpwnam($Conf{catuser}))[7];
							$dir =~ s/^\~/$userdir/;
							return $dir;
							},
    catuser      =>  sub {
							$ENV{MVC_CATUSER} ||
							($Conf{asroot} ? '' : $Conf{'interchangeuser'})
						},
	cgibase      =>  sub { find_cgidir(); return $CgiUrlDefault},
	cgidir       =>  sub { find_cgidir() },
	cgiurl       =>  sub {
							return $ENV{MVC_CGIURL} if $ENV{MVC_CGIURL};
							my $url = '';
							if ($Conf{cgibase} eq '') {
								$url =	$Tilde if defined $Tilde;
								$url .=	'/' .
										$Conf{catalogname} .
										'.cgi';
							}
							else {
								$url .= $Conf{cgibase} . '/' . $Conf{catalogname};
							}
							$url;
						  },
	demotype     =>  $ENV{MVC_DEMOTYPE} || 'foundation',
    documentroot =>  sub { find_docroot() },
	imagedir     => sub {
							return $ENV{MVC_IMAGEDIR} if $ENV{MVC_IMAGEDIR};
				 			return prefix('samplehtml') . '/' . 'images'
						},
	imageurl     => sub {
							my $url = '';
							return $ENV{MVC_IMAGEURL} if $ENV{MVC_IMAGEURL};
	                        if(defined $Tilde) {
								$url = $Tilde;
							}
							$url .= '/' . $Conf{catalogname} . '/' . 'images';
							$url;
						},
	interchangeuser =>  sub {  return 'everybody' if $Global::Win32; get_id(); },
	interchangegroup=>  '',
    linkhost     =>  sub {
							my $lm = $Conf{linkmode} || $Commandline{linkmode};
							return 'n/a' if ! $lm;
							return 'n/a' if $lm !~ /^i/i;
							return $Commandline{linkhost} || inet_host();
							},
    linkmode     =>  'UNIX',
    linkport     =>  sub {
							my $lm = $Conf{linkmode} || $Commandline{linkmode};
							return 'n/a' if ! $lm;
							return 'n/a' if $lm !~ /^i/i;
							return $Commandline{linkport} || inet_port();
						},
    mailorderto  => sub {  return 'webmaster' if $Global::Win32;
							if($Conf{servername} =~ s:(/~[^/]+)$:: ) {
								$Tilde = $1;
							}
    						$Conf{catuser} },
	serverconf   =>  sub {
							return
								$Conf{servconflist}
								||
								($History{serverconf}->())[0];
						},
    servername => sub {
						set_serverconf($Conf{serverconf});
						if($Servers) {
							return $Servers->{$Conf{serverlist}}{servername}
									if $Servers->{$Conf{serverlist}};
							for(keys %$Servers) {
								return $Servers->{$_}{servername}
									if $Servers->{$_}{Master}
							}
						}
						return Sys::Hostname::hostname() || $Config{myhostname};
					},
	samplehtml   =>  sub {
						return $ENV{MVC_SAMPLEHTML} if $ENV{MVC_SAMPLEHTML};
						$Conf{documentroot} . '/' . $Conf{catalogname};
						},
	sharedir	 => sub {
							return $ENV{MVC_SHAREDIR} if $ENV{MVC_SHAREDIR};
							return prefix('documentroot');
						},
	shareurl	 => sub {
							return $ENV{MVC_SHAREURL} if $ENV{MVC_SHAREURL};
							my $url = '';
							$url = $Tilde if defined $Tilde;
							return $url;
						},
	vendroot     =>  $Global::VendRoot,

);

%Postprocess = (

	cgibase			=> \&strip_trailing_slash,
	basedir			=> \&strip_trailing_slash,
	documentroot	=> \&directory_process,
	imagedir		=> \&directory_process,
	samplehtml		=> \&directory_process,
	catroot			=> \&directory_process,
	relocate		=> \&strip_trailing_slash,
	shareurl		=> \&strip_trailing_slash,
	linkhost		=> \&strip_na,
	linkport		=> \&strip_na,
	serverconf		=> sub {
							my $val = shift;
							$val = strip_trailing_slash($val);
							if("\L$val" eq 'linux') {
								$val = '/etc/httpd/conf/httpd.conf';
							}
							set_serverconf($val);
							return $val,
						},

);

%History = (

	catuser  =>   sub {
						my (@return) = history('interchangeuser');
						my $catu = prefix('catuser');
						unshift(@return, $catu) if $catu;
						return @return;
					},

	cgibase      =>  sub {
						if(defined $Servers->{$Conf{servername}}) {
							my $ref = $Servers->{$Conf{servername}}{scriptalias};
							return @_ unless defined $ref;
							if($Conf{cgidir}) {
								my ($k,$v);
								for (keys %$ref) {
									$k = $_;
									$v = $ref->{$_};
									$v =~ s:[/\s]+$::;
									next unless $v eq $Conf{cgidir};
									$k =~ s:[/\s]+$::;
									return $k;
								}
							}
							else {
								return keys %$ref;
							}
						}
						return (@_);
					},

	cgidir       =>  sub {
						if(	defined $Servers->{$Conf{servername}} and
							$Servers->{$Conf{servername}}->{scriptalias}
							 ) {
							my @return;
							@return = values %{$Servers->{$Conf{servername}}{scriptalias}};
							unshift @return, $ENV{MVC_CGIDIR} if $ENV{MVC_CGIDIR};
							return @return;
						}
						return (@_);
					},

	imagedir     =>   sub {
						my (@return) = @_;
						if(defined $Servers->{$Conf{servername}}) {
							push (@return,
								values %{$Servers->{$Conf{servername}}->{alias}})
							 if defined $Servers->{$Conf{servername}}->{alias};
						}
						return unique_ary(@return);
					},

	imageurl     =>   sub {
						my (@return) = @_;
						if(defined $Servers->{$Conf{servername}}) {
							push (@return,
								keys %{$Servers->{$Conf{servername}}->{alias}})
							 if defined $Servers->{$Conf{servername}}->{alias};
						}
						return @return;
					},
	interchangegroup  =>   sub {
						return 'nogroup' if $Global::Win32;
						my (@return) = @_;
						my $u;
						my $nogood;
						if(defined $Servers->{$Conf{servername}}) {
							$nogood = $Servers->{$Conf{servername}}->{'group'}
							 if defined $Servers->{$Conf{servername}}->{'group'};
						}
						my @out;
						setgrent;
						while($u = getgrent) {
							next if $u eq 'root';
							next if $u eq $nogood;
							push(@out, $u);
						}
						my $gr = prefix('interchangegroup');
						if($gr = prefix('interchangegroup') ) {
							unshift @return, $gr;
						}
						elsif (
							$gr = ( getpwnam( prefix('interchangeuser') ) )[3] ) {
							$gr = getgrgid($gr);
							unshift @return, $gr;
						}
						return unique_ary(@return, sort @out);
					},

	interchangeuser  =>   sub {
						return 'everybody' if $Global::Win32;
						my @return = (@_);
						my $u;
						my $nogood;
						if(defined $Servers->{$Conf{servername}}) {
							$nogood = $Servers->{$Conf{servername}}->{'user'}
							 if defined $Servers->{$Conf{servername}}->{'user'};
						}
						my @out;
						my @u;
						setpwent;
						while($u = getpwent) {
							next if $u eq 'root';
							next if $u eq $nogood;
							push(@out, $u);
						}
						unshift @return, prefix('interchangeuser');
						return unique_ary(@return, sort @out);
					},

	linkmode => sub { return ('UNIX', 'INET', 'none') },

	permtype     =>   sub {
						my (@return) = @_;
						push(@return, 'G', 'M', 'U');
						return @return;
					},

	serverconf => sub {
						findexe('locate') or return ();
						my @files = findfiles('httpd.conf');
						@files = grep /httpd.conf$/, @files;
						@files = grep length($_) < 50, @files;
						@files = sort {
										-M $a <=> -M $b
										} @files;
						$History{serverconf} = sub { return  @files };
						return @files;
					},

	sharedir	 =>	  sub {
						my (@return) = @_;
						if(defined $Servers->{$Conf{servername}}) {
							push (@return,
								values %{$Servers->{$Conf{servername}}->{alias}})
							 if defined $Servers->{$Conf{servername}}->{alias};
						}
						return @return;
					},

	shareurl     =>   sub {
						my (@return) = @_;
						if(defined $Servers->{$Conf{servername}}) {
							push (@return,
								keys %{$Servers->{$Conf{servername}}->{alias}})
							 if defined $Servers->{$Conf{servername}}->{alias};
						}
						return @return;
					},

    demotype =>  sub {
						my $dir = $Conf{vendroot};
						my @dir =  glob("$dir/*/catalog.cfg");
						for(@dir) {
							s:(.*)/.*:$1:;
							s:.*/(.*):$1:;
						} 
						@dir = sort @dir;
						unshift(@dir, $DistDemo)
								if  -f "$dir/$DistDemo/catalog.cfg";
						for(@dir) {
							unshift(@dir, $_)
								if  $Conf{catalogname} =~ /^$_/;
						}
						return unique_ary(@dir);
					},

    documentroot =>  sub {
						if(defined $Servers->{$Conf{servername}}) {
							return $Servers->{$Conf{servername}}->{documentroot}
							 if defined $Servers->{$Conf{servername}}->{documentroot};
						}
						else {
							return (@_);
						}
					},

    mailorderto  =>	 sub {
						my(@return) = @_;
						if(defined $Servers->{$Conf{servername}}) {
							push(@return, $Servers->{$Conf{servername}}->{serveradmin})
							 if defined $Servers->{$Conf{servername}}->{serveradmin};
						}
						return @return;
					},

);
## The window definitions. 
## 
## Labels and help messages are defined in Vend::MakeCat via the 
## exported description() and label() routines, which allow for
## localization.
## 
## The window need not exist -- if not listed, and there is a Content
## entry, a window will autovivify with one item.
## 

%Window = (
	win_addcatalog	=> {
	#### The catalog information that is NOT path-oriented
		contents => [qw(
						add_catalog
						run_catalog
						)],
	},

	win_catinfo	=> {
	#### The catalog information that is NOT path-oriented
		contents => [qw(
						interchangeuser
						interchangegroup
						permtype
						catuser
						catroot
						demotype
						)],
		postamble => sub {
						while(my ($k, $v) = each %Content) {
							delete $Content{$k} if $v->{_additional};
						}
						while(my ($k, $v) = each %Window) {
							next unless $v->{_additional};
							$v->{gtk_page}->destroy()
								if $v->{gtk_page};
							delete $Window{$k};
						}
						@Additional = read_additional();
					},
	},

	win_greeting	=> {
	#### Initial screen, including catalog name
		control_buttons => \&next_cancel_button,
		contents => [qw(
						catalogname
					)],
	},

	win_linkinfo	=> {
	#### Link program information. Recognize mod_interchange?
		contents => [qw(
						linkmode
						linkhost
						linkport
						)],
	},

	win_server	=> {
	#### Ask for HTTP server info
		contents => [qw(
						servername
						documentroot
						cgidir
						sharedir
						cgibase
						shareurl
						)],
	},

	win_serverconf => {
	#### Display possible HTTP server configurations
		contents => [ 'servconflist', 'serverconf',],
		conditional => sub {
							return 1 unless $Conf{serverconf};
							my $v = prefix('serverconf');
							$Conf{serverconf} = $Postprocess{serverconf}->($v);
							return 0 if -f $Conf{serverconf};
							return 1;
						},
	},

	win_servername => {
	#### Ask for server found in Apache httpd.conf
		preamble => sub { set_serverconf($Conf{serverconf}) },
		conditional => sub {
							my @hosts = keys %$Servers;
							return scalar(@hosts);
						},
		contents => [ 'serverlist'],
	},

	win_urls	=> {
	#### The catalog information that is path-oriented
		contents => [qw(
						samplehtml
						imagedir
						imageurl
						cgiurl
						aliases
						)],
	},

);

## The individual fields to use. 
## 
## Labels and help messages are defined in Vend::MakeCat via the 
## exported description() and label() routines, which allow for
## localization.
## 
## The field need not exist -- if not listed, and it has a label
## or help message, it will autovivify with a "text" widget of
## length 30.
## 
%Content = (
	add_catalog => {
		widget => 'yesno',
	},

	basedir => {
		check_routine => \&dir_check,
		length => 50,
	},

	catalogname => {
		length => 12,
		check_regex => '^[a-zA-Z](?:[-\w]*[a-zA-Z])?$',
		check_routine => sub {
							my $val = shift;
							if($Global::Catalog{$val}) {
								my $msg = errmsg("Catalog %s already exists", $val);
								continue_question($msg);
							}
						},
	},

	catroot => {
		check_routine => \&dir_warn,
		length => 50,
	},

	catuser => {
		widget => 'select',
		options => sub { return [ history('catuser') ] },
		check_routine => sub { scalar getpwnam(shift @_) },
		check_message => "%s %s (%s): not a valid user",
	},

	cgidir => {
		length => 50,
		check_routine => \&dir_check,
	},

	cgiurl => {
		check_routine => sub {
							my ($url, $parm) = @_;
							unless ($url =~ m{^$Conf{cgibase}}) {
								return continue_question(
									errmsg(
										"%s (%s) not subsidiary to %s",
										$url,
										label('cgiurl'),
										$Conf{cgibase},
									),
								);
							}
							return 1;
						},
	},

	demotype => {
		widget => 'select',
		returnexit => 1,
		orientation => 'v',
		options => sub { return [ $History{demotype}->() ] },
		postamble => sub { @Additional = read_additional(); },
		check_routine => sub {
			my $dt = shift;
			return 1 if $> != 0;
			$dt = "$Conf{relocate}$Conf{vendroot}/$dt";
			my $status = check_root_execute($dt);
			return $status if $status == 1;
			my @msg = split /\n/, error_message('demotype') . "\n\n$status";
			if(@msg > 9) {
				splice(@msg, 9);
				$msg[8] = "  [" . l('truncated') . "]";
			}
			return fatal_question(join "\n", @msg);
		},
	},

	documentroot => {
		check_routine => \&dir_check,
		length => 50,
	},

	imagedir => {
		check_routine => \&dir_warn,
		length => 50,
	},

	imageurl => {
		check_blank => 1,
	},

	interchangeuser => {
		widget => 'select',
		options => sub { return [ history('interchangeuser') ] },
		check_routine => sub { scalar getpwnam(shift @_) },
		check_message => "%s %s (%s): not a valid user",
	},

	interchangegroup => {
		widget => 'select',
		options => sub { return [ history('interchangegroup') ] },
		check_routine => sub { scalar getgrnam(shift @_) },
		check_message => "%s %s (%s): not a valid group",
	},

	linkmode => {
		widget => 'radio',
		orientation => 'v',
		callback => [ 'linkhost', 'linkport' ],
		height => 3,
		options => [ 'UNIX', 'INET', 'NONE' ],
	},

	permtype => {
		orientation => 'v',
		widget => 'radio',
		returnexit => 1,
		options => ['Multi', 'Group', 'User'],
	},

	run_catalog => {
		widget => 'noyes',
	},

	samplehtml => {
		check_routine => \&dir_warn,
		length => 50,
	},

	servconflist => {
		conditional => sub {
							return 0 if -f $Conf{serverconf};
							return 1;
						},
		widget => 'select',
		options => [ $History{serverconf}->() ],
		callback => [ 'serverconf' ],
	},

	serverconf => {
		length => 50,
		check_routine => sub {
			my ($fn, $parm) = @_;
			if(! $fn or ! -f $fn or ! -r _) {
				return continue_question(
						errmsg(
							"It is very helpful to have this file to set defaults.",
						)
				);
			}
			else {
				return 1;
			}
		},
	},

	serverlist => {
		widget => 'select',
		height => -5,
		returnexit => 1,
		options => sub { return [sort(keys %$Servers), ''] },
	},

	servername => {
		check_regex => '^(?:\d+\.\d+\.\d+\.\d+|(?:[-\w+]\.)+\w+)(/~\w+)?$',
	},

	servername => {
		length => 50,
		callback => [ qw/
						documentroot
						cgidir
						cgibase
						cgiurl
						sampledir
						samplehtml
						sharedir
						imagedir
						imageurl
					/],
	},

	sharedir => {
		check_routine => \&dir_check,
		length => 50,
	},

);

## These are the content items, some of which will autovivify by virtue
## of having a label() or description() response from Vend::MakeCat.
my @All = (
	qw/
	aliases			
	basedir			
	catuser			
	cgibase			
	cgidir			
	cgiurl			
	demotype		
	documentroot	
	imagedir		
	imageurl		
	mailorderto		
	interchangeuser	
	interchangegroup
	samplehtml		
	sampledir		
	sampleurl		
	servername		
	sharedir		
	shareurl		
	catroot			
	vendroot		
	linkmode
	linkhost
	linkport
	/
);

VIVIFY: {
	@All = unique_ary(@All, keys %Content, keys %Window);
}

## The windows for novice mode
my @beginner = (
	qw/
	catalogname
	servconflist
	servconf
	serverlist
	servername
	demotype
	catroot
	catuser
	documentroot
	sharedir
	shareurl
	interchangeuser
	interchangegroup
	cgibase
	mailorderto
	samplehtml
	imagedir
	imageurl
	cgidir
	cgiurl
	aliases
	linkmode
	linkhost
	linkport
	/
);

## Here we get the help and labels for windows....
for my $one (keys %Window) {
	my $ref = $Window{$one};
	if(! $ref->{message}) {
		my $help = description($one);
		$help =~ s/^# ?//mg;
		$ref->{message} = $help;
	}
	if(! $ref->{label}) {
		$ref->{label} = label($one);
	}
	if(! $ref->{banner}) {
		$ref->{banner} = label($one);
	}
}

if (-f $Configfile) {
	 $Cfg = readconfig();
}
else {
	$Removeconfig = 1 if prefix('nocopy');
	open(CFGFILE, ">$Configfile")	or die "Can't write $Configfile: $!\n";
	for(@baseparms) {
		my $val = prefix($_);
		print CFGFILE "$_=$val\n";
	}
	print CFGFILE "\n";
	close(CFGFILE)					or die "Can't close $Configfile: $!\n";
	push @Messages, "New base configuration file '$Configfile'" ;
	$Reconfigure = 1;
}

## Here we get the help and labels for content items....
for(@All) {
	my $lab = label($_);
	$Content{$_}{label} = $lab if $lab;
	$Content{$_}{label} = pretty($_) if ! $Content{$_}{label};
	if (! $Content{$_}{help}) {
		my $help = description($_);
		$help =~ s/^# ?//mg;
		$Content{$_}{help} = $help;
	}
}

$Ever{catalogname} = $Conf{catalogname};
$Conf{vendroot}    = prefix('vendroot');

unless($Conf{asroot}) {
	@Prefix{qw(interchangeuser interchangegroup)} = get_ids();
	$Prefix{catuser} = $Prefix{interchangeuser};
	$Prefix{basedir} = "$ENV{HOME}/catalogs";
}

my $gtk_win;
my $gtk_top;
my $druid;
my $druid_start;
my $druid_end;

sub gtk_init_display {
	$SIG{__DIE__} = sub { Gtk::main_quit(); warn @_; exit 1; };
	Gnome->init('newcat', 0.1);
	$Logo = load_image Gtk::Gdk::ImlibImage($LogoFile);
	$Water = load_image Gtk::Gdk::ImlibImage($WaterFile);
	$gtk_win = new Gtk::Window('toplevel');
	$gtk_win->signal_connect( "destroy", \&Gtk::main_quit );
	$gtk_top = new Gtk::VBox( 0, 2 );
	$gtk_win->add($gtk_top);
    $gtk_top->show;
}

my ($screen_width, $screen_height);
sub newt_init_display {
	$SIG{__DIE__} = sub { Newt::Cls(); Newt::Finished(); warn @_; exit 1; };
	$SIG{TERM} = sub { Newt::Cls(); Newt::Finished(); exit 0; };
	Newt::Init();
	Newt::Cls();
	($screen_width, $screen_height) = Newt::GetScreenSize();
}

sub tty_init_display {
	readline::rl_set('EditingMode', 'emacs')
		if $Displaymode eq 'tty' and ! $Conf{vi_edit_mode};
	system 'clear' unless $Debug;
}

sub tty_install_scale {
	my ($total_scale, $main_message) = @_;
debug("called tty_install_scale with tot=$total_scale msg=$main_message");
	print "##### $main_message #####\n\n";
	my $message;
	return sub {
		my($function, $increment, $newmsg, $opt) = @_;
		if($function eq 'start') {
			$message = $newmsg;
			print do_msg($message);
			return;
		}
		elsif($function eq 'end') {
			print errmsg('done') . ".\n";
		}
	};
}

sub gtk_install_scale {
	my ($total_scale, $main_message, $sub, @actions) = @_;
debug("called gtk_install_scale with tot=$total_scale msg=$main_message");
	$main_message = errmsg("Installing %s", $Conf{catalogname})
		if ! $main_message;

	my ($dpage, $tab) = gtk_std_page($main_message, 3, '');
	my $prev_dpage;

	for(reverse @Final, reverse @Additional, reverse @Windows) {
		next unless $Window{$_}{gtk_active};
		last if $prev_dpage = $Window{$_}{gtk_page};
	}
	$druid->insert_page($prev_dpage, $dpage);
	$druid->set_buttons_sensitive(0,0,0);

	my $label = new Gtk::Label(errmsg('Starting installation' . '...'));
	$tab->set_homogeneous(1);

	my $hb1 = new Gtk::HBox;
	$hb1->pack_start($label, "expand", "expand", 5);

	
	my $message;
	my $i = 0;
	$total_scale += int ($total_scale / 100 * 5);
	# Create a Adjustment object to hold the range of the progress bar
	my $adj = new Gtk::Adjustment( 0, $i, $total_scale, 0, 0, 0 );

	my $pbar = new_with_adjustment Gtk::ProgressBar( $adj );
	$pbar->set_format_string( "%p%%" );
	$pbar->set_show_text(1);
	$pbar->set_bar_style('continuous');
	$pbar->set_value($i);

	my $hb2 = new Gtk::HBox;
	$hb2->pack_start($pbar, "expand", "expand", 5);

	$tab->attach($hb1, 0,2, 1,2, "expand", "expand", 5,5 );
	$tab->attach($hb2, 0,2, 2,3, "expand", "expand", 5,5 );

	$tab->show_all;
	$dpage->show;
	$druid->set_page($dpage);
	$gtk_win->show_all;

	my $timer = Gtk->timeout_add(500, \&Gtk::main_quit);
debug("ready to run Gtk main, timer=$timer");
	Gtk->main;
	Gtk->timeout_remove($timer);
debug("returned from Gtk main_iteration");

	return sub {
		my($function, $increment, $newmsg, $opt) = @_;
		if($function eq 'start') {
			$message = $newmsg;
			$label->set($message);
			$pbar->set_value($i);
			$i += $increment;
			$gtk_win->show_all;
			my $timer = Gtk->timeout_add(100, \&Gtk::main_quit);
debug("ready to run Gtk main, timer=$timer");
			Gtk->main;
			Gtk->timeout_remove($timer);
		}
		elsif($function eq 'finish') {
			$label->set($main_message . '.....' . errmsg('done'));
			$pbar->set_value($total_scale);
			$gtk_win->show_all;
			my $timer = Gtk->timeout_add(500, \&Gtk::main_quit);
debug("ready to run Gtk main, timer=$timer");
			Gtk->main;
			Gtk->timeout_remove($timer);
		}
	};

}

sub newt_install_scale {
	my ($total_scale, $main_message) = @_;
debug("called install_scale with tot=$total_scale msg=$main_message");
	$main_message = errmsg("Installing %s", $Conf{catalogname})
		if ! $main_message;
	Newt::Cls();
	Newt::DrawRootText(0, 0, $main_message);

	my $i = 1;
	my $label = Newt::Label(errmsg('Starting installation' . '...'));
	my $scale = Newt::Scale(60, $total_scale);
	my $started;
	my $message;
	my $main = Newt::Panel(1,2, errmsg('Installation'))
		  ->Add(0, 0, $label, NEWT_ANCHOR_LEFT, 0, 0, 0, 1)
		  ->Add(0, 1, $scale)
		  ->Draw();
	Newt::Refresh();
	return sub {
		my($function, $increment, $newmsg, $opt) = @_;
		if($function eq 'start') {
			$message = $newmsg;
			$label->Set($message);
			$scale->Set($i);
			$main->Draw();
			Newt::Refresh();
			$i += $increment;
			select(undef,undef,undef,.2);
			return;
		}
		elsif ($function eq 'finish') {
			$main->Hide();
			undef $main;
		}
	};
}

sub tty_cancel_question {
	my $q = shift;
	print "\n##### " . errmsg("Cancel") . "! #####\n\n";
	print "$q\n\n";
	my $yes = errmsg('Yes');
	my $no  = errmsg('No'); 
	my $yes_regex = substr($yes, 0, 1);
	$yes_regex = qr/$yes_regex/i;
	sethistory($yes, $no);
	my $ans = prompt(
				errmsg("Cancel") . "? ",
				errmsg("Yes"),
				);
	if($ans =~ $yes_regex) {
		return 1;
	}
	else {
		return 0;
	}
}

sub newt_cancel_question {
	my $q = shift;
	my $res = Newt::newtWinChoice(
				errmsg("Cancel"),
				errmsg("Yes"),
				errmsg("No"),
				$q,
			  );
	if($res eq '2') {
		return 0;
	}
	else {
		return 1;
	}
}

sub tty_continue_question {
	my $q = shift;
	print "\n\n##### " . errmsg("Warning") . "! #####\n\n";
	print "$q\n\n";
	my $yes = errmsg('Yes');
	my $no  = errmsg('No'); 
	my $yes_regex = substr($yes, 0, 1);
	$yes_regex = qr/$yes_regex/i;
	sethistory($yes, $no);
	my $ans = prompt(
				errmsg("Continue anyway") . "? ",
				errmsg("no"),
				);
	if($ans =~ $yes_regex) {
		return 1;
	}
	else {
		return -1;
	}
}

sub newt_continue_question {
	my $q = shift;
	my $res = Newt::newtWinChoice(
				errmsg("Warning"),
				errmsg("Change"),
				errmsg("Continue anyway"),
				$q,
				);
	if($res eq '2') {
		return 1;
	}
	else {
		return -1;
	}
}
sub gtk_continue_question {
	my $q = shift;
	my $win = new Gtk::Window(-toplevel);
	$win->set_modal(1);
	my $frame = new Gtk::Frame(errmsg('Warning'));
	my $tab = new Gtk::Table(2,2,0);
	$frame->add($tab);
	$win->add($frame);
	my $lab = new Gtk::Label($q);
	$lab->set_line_wrap(1);

	$lab->show;
	$tab->attach($lab, 0,2 , 0,1, "expand", "expand", 25, 25);

	my $but1 = new Gtk::Button(errmsg('Change'));
	$but1->border_width(5);
	$but1->show;
	my $but2 = new Gtk::Button(errmsg('Continue anyway'));
	$but2->border_width(5);
	$but2->show;

	my $res;
	$but1->signal_connect('clicked', sub { $res = 1 ; Gtk->main_quit; return });
	$but2->signal_connect('clicked', sub { $res = 2 ; Gtk->main_quit; return });
	$tab->attach_defaults($but1, 0,1 , 1,2);
	$tab->attach_defaults($but2, 1,2 , 1,2);
	$tab->show_all;
	$frame->show_all;
	$win->show_all;
	main Gtk;
	$win->destroy();
	if($res eq '2') {
		return 1;
	}
	else {
		return -1;
	}
}

sub gtk_fatal_question {
	my $q = shift;
	my $win = new Gtk::Window(-toplevel);
	$win->set_modal(1);
	my $frame = new Gtk::Frame(errmsg('Warning'));
	$win->add($frame);
	my $tab = new Gtk::Table(2,2,1);
	$frame->add($tab);
	my $lab = new Gtk::Label($q);
	$lab->set_justify('left');

	$tab->attach($lab, 0,2 , 0,1, "expand", "expand", 25, 25);

	my $but1 = new Gtk::Button(errmsg('Close'));

	my $res;
	$but1->signal_connect('clicked', sub { $res = -1 ; &Gtk::main_quit; return });
	$tab->attach_defaults($but1, 0,1 , 1,2);

	$lab->show;
	$but1->show;
	$tab->show;
	$frame->show;
	$win->show;
	main Gtk;
	$win->destroy();
	return -1;
}

sub tty_fatal_question {
	my $q = shift;
	print "##### " . errmsg("Error") . "! #####\n\n";
	print "$q\n\n";
	my $ans = prompt(
				errmsg("Press any key to continue..."),
				errmsg("Continue"),
				);
	return -1;
}

sub newt_fatal_question {
	my $q = shift;
	my $res = Newt::newtWinMessage(
				errmsg("Error"),
				errmsg("Close"),
				$q,
			);
	return -1;
}

sub dir_warn {
	my ($dir, $parm, $types) = @_;
	$types = '!e !w' unless $types;
	return dir_check($dir, $parm, $types);
}

sub dir_check {
	my ($dir, $parm, $types) = @_;
	return 1 if "\L$dir" eq 'none';
	$dir = $Conf{$dir} if $dir !~ m{/};
	return 0 unless $dir;
	my @msg;
	$types = 'd w' if ! $types;
	my @types = split /\s+/, $types;
	my %condition;
	foreach my $test (@types) {
		if($test eq '!e') {
			push @msg, 'w', errmsg("Directory %s %s", $dir, errmsg('exists'))
				if -e $dir;
		}
		elsif ($test eq 'd') {
			push @msg, 'e', errmsg("Directory %s %s", $dir, errmsg('does not exist'))
				unless -d $dir;
		}
		elsif($test eq 'w') {
			push @msg, 'e', errmsg("Directory %s %s", $dir, errmsg('not writable'))
				unless -w $dir;
		}
		elsif($test eq '!w') {
			push @msg, 'e', errmsg("Directory %s %s", $dir, errmsg('not writable'))
				if -d $dir and ! -w _;
		}
	}
	my $result = 1;
	while(@msg) {
		my $t = shift @msg;
		my $q = shift @msg;
		if($t eq 'w') {
			$result = continue_question($q);
		}
		else {
			$result = fatal_question($q);
		}
		last if $result <= 0;
	}
	return $result;
}

sub set_serverconf {
	my $s = conf_parse_http(shift)
		or return undef;
	$Servers = $s;
}

sub find_docroot {
	my $s;
	$s = $Servers->{$Conf{servername}};
	
	if($s and $s->{documentroot}) {
		$DocrootDefault = $s->{documentroot};
	}
	return $DocrootDefault if $DocrootDefault;
	if(! $Conf{asroot}) {
		for(qw/www html web web-public public_html public-html htdocs/) {
			-d "$ENV{HOME}/$_" and -w _
				and $DocrootDefault = "$ENV{HOME}/$_"
			and return $DocrootDefault;
		}

		for(	glob("$ENV{HOME}/*html*"),
				glob("$ENV{HOME}/*www*"),
				glob("$ENV{HOME}/*web*")
			)
		{
			-d $_ and -w _
				and $DocrootDefault = $_
			and return $DocrootDefault;
		}
	}

	for(
		 '/var/www/html',
		 '/home/httpd/html',
		 '/usr/local/etc/httpd/htdocs',
		 '/usr/local/apache/htdocs',
		 '/home/httpd/htdocs',
		 glob("/*/httpd/*docs"),
		 glob("/*web*/*docs"),
		 glob("/*/ns-home/docs"),
		 glob("/export/*/ns-home/http*/docs"),
		 glob("/usr/*/ns-home/http*/docs"),
		 glob("/home/*/ns-home/http*/docs")
		)
	{
		-d $_ and -w _
			and $DocrootDefault = $_
		and return $DocrootDefault;
	}

	$DocrootDefault = '';
}

sub find_cgidir {
	my $s;
	$s = $Servers->{$Conf{servername}};
	
	if($s and $s->{scriptalias}) {
		for my $each (keys %{$s->{scriptalias}}) {
			$CgiDefault = strip_trailing_slash($s->{scriptalias}{$each});
			$CgiUrlDefault = strip_trailing_slash($each);
			last;
		}
	}
	return $CgiDefault if defined $CgiDefault;
	if(! $Conf{asroot}) {
		for(qw/cgi-bin cgi cgibin web-scripts scripts cgiwrap cgi-wrap/) {
			-d "$ENV{HOME}/$_" and -w _
				and $CgiDefault = "$ENV{HOME}/$_"
				and $CgiUrlDefault = "/$_"
			and return $CgiDefault;
		}

		for( glob("$ENV{HOME}/*cgi*"), glob("$ENV{HOME}/*scripts*") ) {
			-d $_ and -w _
				and $CgiDefault = $_
				and ($CgiUrlDefault = $_) =~ s:.*/:/:
			and return $CgiDefault;
		}
	}

	for(
			 '/var/www/cgi-bin',
			 '/home/httpd/cgi-bin',
			 '/usr/local/etc/httpd/cgi-bin',
			 '/usr/local/apache/cgi-bin',
			 glob("/*web*/cgi*"),
			 glob("/*/ns-home/cgi*"),
			 glob("/export/*/ns-home/http*/cgi*"),
			 glob("/usr/*/ns-home/http*/cgi*"),
			 glob("/home/*/ns-home/http*/cgi*"),
		)
	{
		-d $_ and -w _
			and $CgiDefault = $_
			and ($CgiUrlDefault = $_) =~ s:.*/:/:
		and return $CgiDefault;
	}

	$CgiDefault = $CgiUrlDefault = '';
}

sub tty_help_message {
	my ($msg) = @_;
	$msg = '' if ! defined $msg;
	if ($msg eq 1) {
		print <<'EOF';
We will configure and build a new Interchange catalog during this
process.
EOF
		print <<'EOF' if defined $Vend::MakeCat::Prompt_sub;

You are not using full-screen display, but there are still a few
shortcuts available.

There is a "history" mechanism that will allow you to use the up
and down arrows on your terminal (assuming you have a standard
terminal) to cycle between possible choices. This should contain
the available servers.

Try using the UP arrow at some of the prompts -- you have the
Term::ReadLine module installed, and Interchange may find some default
values in your HTTP server configuration file. You can cycle among them
with the UP and DOWN arrows.
EOF

	}
	else {
			print "$msg\n";
	}
}

sub newt_help_message {
	my ($msg) = @_;
	return 1;
	$msg = '' if ! defined $msg;
	if ($msg eq 1) {
			my @helps = (
				'<Tab>/<Alt-Tab> between elements',
			);
			@helps = map { errmsg($_) } @helps;
			$msg = join " | ", @helps;
	}
	$msg = ' ' x int(($screen_width - length($msg)) / 2) . $msg;
	Newt::PushHelpLine($msg);
}

sub next_back_cancel_button {
        my $nextb = Newt::Button('Next')->Tag('Next');
        my $backb = Newt::Button('Back')->Tag('Back');
        my $cancelb = Newt::Button('Cancel')->Tag('Cancel');

        Newt::Panel(3, 1)
                ->Add(0, 0, $nextb, NEWT_ANCHOR_RIGHT, 0, 1, 0, 0)
                ->Add(1, 0, $backb, NEWT_ANCHOR_RIGHT, 1, 1, 0, 0)
                ->Add(2, 0, $cancelb, NEWT_ANCHOR_LEFT, 1, 1, 0, 0);
}

sub next_cancel_button {
        my $nextb = Newt::Button('Next')->Tag('Next');
        my $cancelb = Newt::Button('Cancel')->Tag('Cancel');

        Newt::Panel(2, 1)
                ->Add(0, 0, $nextb, NEWT_ANCHOR_RIGHT, 0, 1, 0, 0)
                ->Add(1, 0, $cancelb, NEWT_ANCHOR_LEFT, 1, 1, 0, 0);
}

sub finish_back_cancel_button {
        my $nextb = Newt::Button('Finish')->Tag('Next');
        my $backb = Newt::Button('Back')->Tag('Back');
        my $cancelb = Newt::Button('Cancel')->Tag('Cancel');

        Newt::Panel(3, 1)
                ->Add(0, 0, $nextb, NEWT_ANCHOR_RIGHT, 0, 1, 0, 0)
                ->Add(1, 0, $backb, NEWT_ANCHOR_RIGHT, 1, 1, 0, 0)
                ->Add(2, 0, $cancelb, NEWT_ANCHOR_LEFT, 1, 1, 0, 0);
}

sub newt_get_field {
        my ($entry, $name, $content) = @_;
        $content = $Content{$name} if ! $content;
        my $wid = $content->{widget} || 'text';
        my $value;
        if ($wid eq 'radio') {
                my $opts        = $content->{options} || ['Yes', 'No'];
                my $idx = $entry->Get();
                $value = $opts->[$idx];
        }
        elsif ($wid eq 'yesno') {
                my $idx = $entry->Get();
                return $idx ? 0 : 1;
        }
        elsif ($wid eq 'noyes') {
                my $idx = $entry->Get();
                return $idx ? 0 : 1;
        }
        elsif ($wid eq 'select') {
                my @items = $entry->Get();
                $value = $items[0];
        }
        else {
                $value = $entry->Get();
        }
        return $value;
}

sub gtk_add_field {
	my ($field, $name, $default) = @_;
	my $content = $Content{$name} || return;

	my $wid = $content->{widget} || 'text';

	my $opts;
	my $yn;
	if($wid eq 'yesno') {
		$wid = 'radio';
		$opts = [ errmsg('Yes'), errmsg('No')];
		if(! length($default)) {
			$default = errmsg('Yes');
		}
		elsif( $default eq errmsg('Yes') or is_yes($default) ) {
			$default = errmsg('Yes');
		}
		else {
			$default = errmsg('No');
		}
	}
	elsif($wid eq 'noyes') {
		$wid = 'radio';
		$opts = [ errmsg('Yes'), errmsg('No')];
		if(! length($default)) {
			$default = errmsg('No');
		}
		elsif( $default eq errmsg('Yes') or is_yes($default) ) {
			$default = errmsg('Yes');
		}
		else {
			$default = errmsg('No');
		}
	}
	elsif( ! $content->{options} ) {
		# Do nothing
	}
	elsif( ref $content->{options} eq 'CODE') {
		$opts = $content->{options}->();
	}
	elsif( ref $content->{options} eq 'ARRAY') {
		$opts = $content->{options};
	}

	my $entry;
	my $box;
	if ($wid eq 'radio') {
		my $orientation = $content->{orientation} || 'horizontal';
		return undef unless ref $opts eq 'ARRAY';
		if($orientation =~ /^v/i) {
			$box = new Gtk::VButtonBox;
		}
		else {
			$box = new Gtk::HButtonBox;
		}
		$box->set_layout_default('start');
		my $but;
		my $do_def = 1;
		for(@$opts) {
			if($but) {
				$but = new Gtk::RadioButton($_, $but);
			}
			else {
				$but = new Gtk::RadioButton($_);
				$entry = $but;
			}
			$but->set_active(1), undef $do_def if $_ eq $default;
			$box->add($but);
		}
		$entry->set_active(1) if $do_def;
		$entry->signal_connect('clicked', $field->{callback})
			if $field->{callback};
	}
	elsif ($wid eq 'select') {
		$opts = [] unless ref $opts eq 'ARRAY';
		my $height = defined $content->{height} ? $content->{height} : 0;
		if($height < 0) {
			$height = abs($height);
			$height = scalar(@$opts) < $height ? undef : $height;
		}

		my $sbox;
		$default = $opts->[0] if ! length $default;
		$entry = new Gtk::List;
		for(@$opts) {
			my $item = new Gtk::ListItem();
			my $l = new Gtk::Label($_);
			$item->add($l);
			$l->show;
			$entry->add( $item );
			$item->show;
			$item->select if $_ eq $default;
		}
		$entry->signal_connect('select_child', $field->{callback})
			if $field->{callback};

		$box = new Gtk::VBox(0,2);
		$sbox = new Gtk::ScrolledWindow(undef, undef);
		$sbox->add_with_viewport($entry);
		$sbox->set_policy(-automatic, -automatic);
		if($height and $height < @$opts) {
			$height *= 15;
			$sbox->set_usize(250, $height);
		}
		else {
			$sbox->set_usize(300, 50);
		}
		$box->add($sbox);
		$sbox->show;
	}
	else  {
debug("unknown widget type '$wid'") if $wid ne 'text';
		my $width = $content->{length} || $content->{width} || 30;
		$entry = new Gtk::Entry($content->{maxlength});
		$box = new Gtk::HBox (0,0);
		if($width) {
			$entry->set_usize(6 * $width, 0);
		}
		$entry->set_text($default);
		$entry->signal_connect('focus_out_event', $field->{callback})
			if $field->{callback};
		$box->pack_start($entry, 0,0,5);
		$box->show;
	}

	$entry->signal_connect('focus_in_event', $field->{onenter})
		if $field->{onenter};
	$field->{widget_object} = $entry;
	$field->{bounding_box} = $box;
#debug("box=$box entry=$entry");
	return ($entry, $box);
}

sub gtk_get_field {
        my ($field, $name) = @_;
        my $content = $Content{$name} || return;

        my $wid = $content->{widget} || 'text';
		my $entry = $field->{widget_object}
			or return undef;

		my $yes;
		if($wid eq 'yesno') {
			$wid = 'radio';
			$yes = errmsg('Yes');
		}
		elsif($wid eq 'noyes') {
			$wid = 'radio';
			$yes = errmsg('Yes');
		}

		my $val;
        if ($wid eq 'radio') {
			for($entry->group()) {
				next unless $_->get_active();
				$val = $_->child->get();
			}
			if($yes) {
				$val = $val eq $yes ? 1 : 0;
			}
        }
        elsif ($wid eq 'select') {
			my @sel = $entry->selection();
			my $count = scalar @sel;
debug("sel count=$count items: @sel");
			if(! @sel) {
				# Do nothing
			}
			elsif(@sel > 1) {
				my @out;
				for(@sel) {
					push @out, $_->child->get();
				}
				$val = \@out;
			}
			else {
				$val = $sel[0]->child->get();
			}
        }
        else  {
			$val = $entry->get_text();
        }

        return $val;
}

sub gtk_set_field {
        my ($field, $name, $val) = @_;
        my $content = $Content{$name} || return;

        my $wid = $content->{widget} || 'text';
		my $entry = $field->{widget_object}
			or return undef;

		my $yes;
		if($wid eq 'yesno' or $wid eq 'yesno') {
			$yes = ($val == 1 or errmsg('Yes') eq $val);
			$yes = $yes ? errmsg('Yes') : errmsg('No');
		}

        if ($wid eq 'radio') {
			for($entry->group()) {
				next unless $yes eq $_->child->get();
				$_->set_active(1);
			}
        }
        elsif ($wid eq 'select') {
			for($entry->children()) {
				next unless $val eq $_->get();
				$_->select(1);
			}
        }
        else  {
			$entry->set_text($val);
        }

        return $val;
}

sub newt_add_field {
        my ($panel, $row, $content, $name, $default) = @_;
        $content = $Content{$name} if ! $content;

        my $wid = $content->{widget} || 'text';
debug("adding field wid=$wid");
        my $label = $content->{label} || $name;
        $label = substitute($label);
        my $entry_flags;

        $panel->Add(0, $row, Newt::Label($label), NEWT_ANCHOR_RIGHT, 0, 0);

        my $entry;
        if($wid eq 'text') {
                my $width = $content->{length} || $content->{width} || 30;
                $entry = Newt::Entry($width, $entry_flags, $default);
        }
        elsif ($wid eq 'yesno') {
                my $orientation = $content->{orientation} || 'horizontal';
                my $opts        = [ errmsg('Yes'), errmsg('No')];
                $opts = $content->{options}->() if ref $opts eq 'CODE';
                if($orientation =~ /^v/i) {
                        $entry = Newt::VRadiogroup(@$opts);
                }
                else {
                        $entry = Newt::HRadiogroup(@$opts);
                }
				if( ! length($default)) {
					$entry->Select(0);
				}
				elsif ($default eq $opts->[1] ) {
					$entry->Select(1);
				}
				elsif ($default eq $opts->[0] ) {
					$entry->Select(0);
				}
				elsif (is_no($default) ) {
					$entry->Select(1);
				}
				else {
					$entry->Select(0);
				}
        }
        elsif ($wid eq 'noyes') {
                my $orientation = $content->{orientation} || 'horizontal';
                my $opts        = [ errmsg('Yes'), errmsg('No')];
                $opts = $content->{options}->() if ref $opts eq 'CODE';
                if($orientation =~ /^v/i) {
                        $entry = Newt::VRadiogroup(@$opts);
                }
                else {
                        $entry = Newt::HRadiogroup(@$opts);
                }
				if( ! length($default)) {
debug("noyes select: setting 1/No by default (no length on default)");
					$entry->Select(1);
				}
				elsif ($default eq $opts->[1] ) {
debug("noyes select: default=$default opts1=$opts->[1], setting 1");
					$entry->Select(1);
				}
				elsif ($default eq $opts->[0] ) {
debug("noyes select: default=$default opts0=$opts->[0], setting 0");
					$entry->Select(0);
				}
				elsif (is_yes($default) ) {
debug("noyes select: is_yes($default), setting 0/yes");
					$entry->Select(0);
				}
				else {
debug("noyes select: setting 1/No by default=$default");
					$entry->Select(1);
				}
        }
        elsif ($wid eq 'radio') {
                my $orientation = $content->{orientation} || 'horizontal';
                my $opts        = $content->{options} || ['Yes', 'No'];
                $opts = $content->{options}->() if ref $opts eq 'CODE';
                if($orientation =~ /^v/i) {
                        $entry = Newt::VRadiogroup(@$opts);
                }
                else {
                        $entry = Newt::HRadiogroup(@$opts);
                }
debug("adding radio");
				for(my $i = 0; $i < @$opts; $i++) {
debug("checking i=$i entry=$opts->[$i] vs. default=$default");
					next if $opts->[$i] ne $default;
					$entry->Select($i);
debug("selecting i=$i entry=$opts->[$i]");
					last;
				}
        }
        elsif ($wid eq 'select') {
                my $opts        = $content->{options} || ['Yes', 'No'];
                $opts = $content->{options}->() if ref $opts eq 'CODE';
                my $height = $content->{height} || 1;
				if($height < 0) {
					$height = abs($height);
					$height = scalar(@$opts) < $height ? scalar @$opts : $height;
				}
                my $return = $content->{returnexit} ? NEWT_FLAG_RETURNEXIT : 0;
                $entry = Newt::Listbox($height, NEWT_FLAG_SCROLL | $return);
                $entry->Add(@$opts);
                if($default) {
					$entry->Select($default);
					for(my $i = 0; $i < @$opts; $i++) {
						next if $opts->[$i] ne $default;
						$entry->SetCurrent($i);
						last;
					}
                }
        }
        else  {
debug("unknown widget type '$wid'") if $wid ne 'text';
                my $width = $content->{length} || $content->{width} || 30;
                $entry = Newt::Entry($width, $entry_flags, $default);
        }
        $panel->Add(1, $row, $entry, NEWT_ANCHOR_LEFT, 1, 0);
        return $entry;
}

sub run_screens {
        my ($tref, $screen, $pref) = @_;

        my @windows = @$tref;

        my (@screenstack, $result);

        if($screen) {
			@screenstack = (0 .. $screen - 1);
		}

        while ($screen < @windows) {

debug("### running screen=$screen window=$windows[$screen]");

			my $skip;
			my $prospect;
			my $win_name = $windows[$screen];
			my $prev_page = $screen == 0 ? $pref->[$#$pref] : $windows[$screen - 1];

          WINLOOP: {
                my $win = $Window{$win_name} || $Content{$win_name};

                if( ! $win) {
die("no window!?!");
                        $result = 'Next';
                        last WINLOOP;
                }

                if ($win->{conditional} ) {
debug("checking window $win_name conditional=$win->{conditional} subcode=$::Subcode{$win_name}");
					my $prospect = $win->{conditional}->();
debug("window $win_name conditional prospect=$prospect");
					if (ref $prospect eq 'CODE') {
						$prospect->($win_name);
					}
					elsif ($prospect and $Window{$prospect}) {
						$win_name = $prospect;
						redo WINLOOP;
					}
					$skip = 1 unless $prospect;
                }

                if($skip) {
debug("skipping window $win_name");
					$result = $result || 'Next';
					display_it($win_name, $prev_page, 'dummy');
					next;
                }

                if(my $over = $win->{override}) {
					foreach my $new (keys %$over) {
debug("window $win_name overriding $new");
						$Content{$new} = $over->{$new};
					}
					if(my $addl = $win->{additional}) {
debug("window $win_name additional: " . join(",", @$addl));
						splice @windows, $screen + 1, 0, @$addl;
					}
                }

debug("window=$win_name");
                $result = display_it($win_name, $prev_page) || '';
#debug("window=$win_name result=$result");
          }
			last if $result eq 'Cancel';

			my $nextscreen = '';
			$nextscreen = $screen + 1
				if $result eq 'Next'
				or $result eq 'Skip'
				or ! $result;
			if ($result eq 'Back') {
				last if $screen == 0;
				$nextscreen = pop @screenstack;
			}
			push @screenstack, $screen if $result eq 'Next';
			$screen = $nextscreen;
        }
        return $result;
}

sub gtk_get_druid {
	return $druid if $druid;
	$druid = new Gnome::Druid;
	$druid->signal_connect("cancel", \&Gtk::main_quit);
	$gtk_top->pack_start($druid,1,1,0);
	$druid_start = new Gnome::DruidPageStart();
	$druid_start->set_title(errmsg("Makecat -- Interchange Catalog Configurator"));
	$druid_start->set_bg_color(Gtk::Gdk::Color->parse_color($BgColor));
	$druid_start->set_logo_bg_color(Gtk::Gdk::Color->parse_color($BgColor));
	$druid_start->set_logo($Logo);
	$druid_start->set_text(errmsg(<<EOF));
Welcome to Interchange!

We will configure and build a new Interchange catalog during this process.
EOF
	$druid_start->set_watermark($Water);
	$druid_start->signal_connect('back', \&gtk_result, 'Cancel');
	$druid_start->signal_connect('next', \&gtk_result, 'Next');
	$druid_start->signal_connect('cancel', \&gtk_result, 'Cancel');
	$druid_start->show;
	$druid->append_page($druid_start);
	$druid->append_page(gtk_end_druid());
	return $druid;
}

sub gtk_result {
	shift;
	my $result = shift;
	$Gtk_result = $result;
debug("Gtk_result=$result");
	Gtk::main_quit();
	return $result;
}

sub gtk_std_page {
	my($title, $rows, $text) = @_;
debug("std_page=$title");
	my $druid_std = new Gnome::DruidPageStandard();
	$druid_std->set_title($title);
	$druid_std->set_bg_color(Gtk::Gdk::Color->parse_color($BgColor));
	$druid_std->set_logo_bg_color(Gtk::Gdk::Color->parse_color($BgColor));
	$druid_std->set_logo($Logo);
	$druid_std->signal_connect("cancel", \&gtk_result, 'Cancel');
	$druid_std->signal_connect("next", \&gtk_result, 'Next');
	$druid_std->signal_connect("back", \&gtk_result, 'Back');

	my $msg;
	$rows++;
	$text =~ s/\n\n/~~NEWLINE~~/g;
	$text =~ s/\n/ /g;
	$text =~ s/~~NEWLINE~~/\n\n/g;
	$msg = new Gtk::Label($text || '');
	$msg->set_line_wrap(1);
	my $tbox = $druid_std->vbox();
	$tbox->set_border_width(15);
	my $sframe = new Gtk::Frame($Conf{catalogname} || errmsg('(unnamed catalog)'));
	my $sbox = new Gtk::ScrolledWindow;
	$sbox->set_policy('automatic', 'automatic');
	$sframe->add($sbox);
	$tbox->pack_start($sframe, 1, 1, 0);
	$sframe->show;
	$tbox->show;
	my $tab = new Gtk::Table($rows,2,0);
	$sbox->add_with_viewport($tab);
	$tab->attach_defaults($msg,0,2,0,1);
	$sbox->show;
	$tab->show;
	return ($druid_std, $tab);
}


sub gtk_end_druid {
	my ($title, $text) = @_;
	$druid_end = new Gnome::DruidPageFinish();
	$druid_end->set_title($title);
	$druid_end->set_watermark($Water);
	$druid_end->set_bg_color(Gtk::Gdk::Color->parse_color($BgColor));
	$druid_end->set_logo_bg_color(Gtk::Gdk::Color->parse_color($BgColor));
	$druid_end->set_logo($Logo);
	$druid_end->signal_connect("cancel", \&Gtk::main_quit);
	$druid_end->signal_connect("finish", \&Gtk::main_quit);
	return $druid_end;
}


sub gtk_field_label {
	my $msg = shift;
	my $lbox = new Gtk::HBox;
	my $lab = new Gtk::Label($msg);
	$lab->set_justify('right');
	$lab->set_line_wrap(1);
	$lab->show;
	$lbox->pack_end($lab, 0,0,5);
	$lbox->show;
	return $lbox;
}

sub gtk_display_it {
        my ($name, $prev_page, $dummy) = @_;
#debug("running window=$name");
        my $return;
        my $indiv_mode;

        my $win = $Window{$name};

        my $winlab;
        my $winmsg;
        my $winitems;

        my $msgflags = 0;

        if(! $win) {
			$indiv_mode = 1;
			$win = $Content{$name}
				or die "No content item for fallback in indiv_mode";
        }
        else {
			$winitems = $win->{contents};
        }

        $winitems = [ $name ] if ! $winitems;

        $winmsg = substitute($win->{message} || $win->{help});
        $winlab = $win->{banner} || $win->{label} || $name;
        $winlab = substitute($winlab);

        if($win->{preamble}) {
                $win->{preamble}->();
        }

		my $not_show = ! $druid;

		gtk_get_druid() if $not_show;

        my $lines = $winmsg =~ tr/\n/\n/;
        $lines = 6 if $lines < 6;

		my $current;         # Tag of current componet set by OnEnter
		my $focused;         # If we are to focus, set this to tag.
		my $first_field = 1; # Use to run callback for first_field always

  RUNIT: {

        my @things = grep $Content{$_}, @$winitems;

		my $prev_dpage;
		if ($Window{$prev_page}) {
			$prev_dpage = $Window{$prev_page}->{gtk_page};
		}
		else {
			$prev_dpage = $druid_start;
		}

        @things = grep applicable_directive($_, $Content{$_}->{conditional}), @things
                if @things > 1;
        my ($dpage, $tab) = gtk_std_page($winlab, scalar @things, $winmsg);
		if($win->{gtk_page}) {
			$win->{gtk_page}->destroy();
		}
		$win->{gtk_active} = 0;
		$win->{gtk_page} = $dpage;
		$win->{gtk_table} = $tab;

		$druid->insert_page($prev_dpage, $dpage);

        return 'Skip' if $dummy;
        return 'Skip' unless @things;
		$druid->set_buttons_sensitive(1,1,1);

		$win->{gtk_active} = 1;

        my $field   = {};

        for( my $i = 0; $i < @things; $i++) {
			my $one = $things[$i];
			my $row = $i + 1;
			my $content = $Content{$one};
			my $default;
			$default = prefix($one);
			$Conf{$one} = '' unless $Ever{$one};
			$field->{$one} = {};
			$content->{widget} = 'text' unless $content->{widget};
			my $cb = $content->{callback};
			my $sub;
			if (ref $cb eq 'ARRAY') {
				$sub = sub {
					my $val = gtk_get_field($field->{$one}, $one);
					my ($status, $error) = validate($val, $one);
					return if $status <= 0;
					$Conf{$one} = $val;
					$Conf{$one} = $Postprocess{$one}->($Conf{$one})
							if defined $Postprocess{$one};
					foreach my $item (@$cb) {
						next unless defined $field->{$item};
						delete $Conf{$item};
						my $val = prefix($item);
						gtk_set_field($field->{$item}, $item, $val);
					}
				};
			}
			elsif (ref $cb eq 'CODE') {
				$sub = sub {
					$cb->(gtk_get_field($field->{$one}, $one), $one);
				};
			}
			elsif ($cb) {
			}
			$field->{$one}{content} = $content;
			$field->{$one}{callback} = $sub if $sub;
			$field->{$one}{onenter} = sub {
											$current = $one;
										};
			my $lbox = gtk_field_label(substitute($content->{label} || $one));
			$tab->attach_defaults($lbox, 0,1 , $row,$row + 1);
			my ($entry, $bbox) = gtk_add_field(
										$field->{$one},
										$one,
										$default,
									);
			$tab->attach_defaults($bbox,  1,2 , $row,$row + 1);

			# Run the callback for the first field always, like Newt
			$sub->() if $first_field and $sub;
			undef $first_field;
		}

		$gtk_win->show_all;
		if($not_show) {
			my $result = main Gtk;
			return 'Cancel' if $Gtk_result eq 'Cancel';
		}
        while (1) {
			$druid->set_page($dpage);
			my $return = main Gtk;
			$return = $Gtk_result;
			if ($return eq 'Cancel' or $return eq 'Back') {
				return $return;
			}
			my @errors;
			my $transparent_error;
			foreach my $f (@things) {
				my $val = gtk_get_field($field->{$f}, $f);
				$val = $Postprocess{$f}->($val)
						if defined $Postprocess{$f};
				my ($status, $error) = validate($val, $f);
				if(! $status) {
					my $hlp = $Content{$f}->{help};
					$error .= "\n\n" . substitute($hlp)	if $hlp;
					$focused = $f unless $focused;
					push @errors, $error;
					$field->{$f}{value} = $val;
					next;
				}
				elsif ($status < 0) {
					$transparent_error = 1;
				}
debug("setting $f=$val");
				$Conf{$f} = $val;
			}
			if(@errors) {
				gtk_fatal_question(
						join("\n\n", @errors),
				);
				redo;
			}
			redo RUNIT if $transparent_error;
			last;
        }

        for(@things) {
			$Ever{$_} = 1;
        }

        if($win->{postamble}) {
			$win->{postamble}->();
        }

  }

		$druid->set_buttons_sensitive(0,0,0);
        return 'Next';
}

sub newt_display_it {
        my ($name, $prev_page, $dummy) = @_;
		return if $dummy;
#debug("running window=$name");
        my $return;
        my $indiv_mode;

        my $win = $Window{$name};
##debug("$name: Window=$win");

        my $winlab;
        my $winmsg;
        my $winitems;

        my $msgflags = 0;

        if(! $win) {
                $indiv_mode = 1;
                $win = $Content{$name} || die "No content item for fallback in indiv_mode";
        }
        else {
                $winitems = $win->{contents};
        }

        $winitems = [ $name ] if ! $winitems;

        $winmsg = substitute($win->{message} || $win->{help});
        $winlab = $win->{banner} || $win->{label} || $name;
        $winlab = substitute($winlab);

        if($win->{preamble}) {
                $win->{preamble}->();
        }

        my $lines = $winmsg =~ tr/\n/\n/;
        $lines = 6 if $lines < 6;

		my $current;         # Tag of current componet set by OnEnter
		my $focused;         # If we are to focus, set this to tag.

  RUNIT: {
        Newt::Cls();
        my $panel = Newt::Panel(1, 3, $winlab);
		my $msgbox = Newt::Textbox(75, $lines, $msgflags, $winmsg);
        $panel->Add(0, 0, $msgbox);
		$panel->AddHotKey(NEWT_KEY_F1);
		$panel->AddHotKey(NEWT_KEY_F2);
		$panel->AddHotKey(NEWT_KEY_F5);
		$panel->AddHotKey(NEWT_KEY_F7);
		$panel->AddHotKey(NEWT_KEY_F8);
		$panel->AddHotKey(NEWT_KEY_F9);
		$panel->AddHotKey(NEWT_KEY_F10);

        my @things = grep $Content{$_}, @$winitems;

        @things = grep applicable_directive($_, $Content{$_}->{conditional}), @things
                if @things > 1;
        return 'Skip' unless @things;
        my $subpanel = Newt::Panel(2, scalar @things);

        my $field   = {};
        my $hist_ptr = {};

        for( my $i = 0; $i < @things; $i++) {
			my $one = $things[$i];
			my $content = $Content{$one};
			#next unless applicable_directive($one, $content->{conditional});
			my $default;
			$default = prefix($one);
			$Conf{$one} = '' unless $Ever{$one};
			$field->{$one} = newt_add_field(
								$subpanel,
								$i,
								$content,
								$one,
								$default,
							);
			$content->{widget} = 'text' unless $content->{widget};
			if( $content->{widget} eq 'text') {
				$field->{$one}->SetFilter(
					sub {
						my ($proposed_char, $pos) = @_;
						my $untab = NEWT_KEY_UNTAB;

						my $ord = ord($proposed_char);

						if($ord == ord("\cU") ) {
							$field->{$one}->Set('');
							return 0;
						}
						return $ord;
					}
				);

			}
			$field->{$one}->OnEnter(
				sub {
					$current = $one;
				} );
			my $cb = $content->{callback};
			my $sub;
			if (ref $cb eq 'ARRAY') {
				$sub = sub {
					my $val = newt_get_field($field->{$one}, $one);
					my ($status, $error) = validate($val, $one);
					return if $status <= 0;
					$Conf{$one} = $val;
					$Conf{$one} = $Postprocess{$one}->($Conf{$one})
							if defined $Postprocess{$one};
					foreach my $item (@$cb) {
						next unless defined $field->{$item};
						delete $Conf{$item};
						my $val = prefix($item);
						$field->{$item}->Set($val);
					}
				};
			}
			elsif (ref $cb eq 'CODE') {
				$sub = sub {
					$cb->(newt_get_field($field->{$one}), $one);
				};
			}
			elsif ($cb) {
				eval {
					$sub = sub {
						my $pres = newt_get_field($field->{$one}, $one);
						$Ever{$one} = $Conf{$one};
						$focused = $one;
						if ($Conf{$one} ne $pres) {
							$pres = $Postprocess{$one}->($pres)
								if $Postprocess{$one};
							$Ever{$one} = $Conf{$one} = $pres;
							redo RUNIT;
						}
					};
				};
				if ($@) {
						debug("sub creation error: $@");
						undef $sub;
				}
				else {
						debug("GOTO sub created for $one: $sub");
				}
			}
			eval {
				$field->{$one}->AddCallback($sub) if $sub;
			};
		}
                
        $panel->Add(0, 1, $subpanel, 0, 0, 1);
        my $csub = $win->{control_buttons} || \&next_back_cancel_button;
        $panel->Add(0, 2, $csub->());
		$panel->Focus($field->{$focused}) if $focused;
		undef $focused;

        while (1) {
			my ($reason, $data) = $panel->Run();
			if($reason eq NEWT_EXIT_COMPONENT) {
				$return = $data->Tag();
				if ($return eq 'Cancel' or $return eq 'Back') {
					$panel->Hide();
					undef $subpanel;
					undef $panel;
					return $return;
				}
			}
			elsif ($reason eq NEWT_EXIT_HOTKEY) {

				### Individual component help
				if($data eq NEWT_KEY_F1) {
					#my $item = $determine_focus->($panel->GetCurrent());
					my $item = $current
						or redo;
					my $thing = $Content{$item};
					my $hlp = "$thing->{label}:\n\n";
					$hlp .= $thing->{help} || 'No help for this item.';
					Newt::newtWinMessage(
						errmsg("Help"),
						errmsg("Close"),
						$hlp,
					);
					redo;
				}
				### All helps
				elsif($data eq NEWT_KEY_F2) {
					my @helps;
					for(@things) {
						my $thing = $Content{$_};
						my $hlp = "$thing->{label}:\n\n";
						$hlp .= $thing->{help} || 'No help for this item.';
						push @helps, $hlp;
					}
					Newt::newtWinMessage(
						errmsg("Help"),
						errmsg("Close"),
						join("\n\n", @helps),
					);
					redo;
				}
				elsif($data eq NEWT_KEY_F5) {
					cancel_question(errmsg("Exit the program"))
						and return 'Cancel';
					redo;
				}
				### Text component history
				elsif($data eq NEWT_KEY_F7 or $data eq NEWT_KEY_F8) {
					my $item = $current
						or redo;
					my $h = $Content{$item}{history} || $History{$item}
						or redo;
					my $hist;
					if(ref $h eq 'ARRAY') {
						$hist = [ map { substitute($_) } @$h ];
					}
					elsif(ref $h eq 'CODE') {
						my @h = $h->();
						$hist = \@h;
					}
					redo unless $hist;
					push @$hist, prefix($item);
					push @$hist, $Conf{$item};
					my $ptr  = $hist_ptr->{$item};

					if(defined $ptr) {
						if   ($data eq NEWT_KEY_F7)	{ $ptr-- }
						else 						{ $ptr++ }
					}
					elsif ($data eq NEWT_KEY_F7) {
						$ptr = $#$hist;
					}
					else {
						$ptr = 1;
					}

					$ptr = $#$hist if $ptr < 0;
					$ptr = 0      if $ptr > $#$hist;
					$hist_ptr->{$item} = $ptr;

					redo unless defined $hist->[$ptr];
					redo unless length  $hist->[$ptr];
					$field->{$item}->Set( $hist->[$ptr] );
					redo;
				}
				### Go back immediately
				elsif($data eq NEWT_KEY_F9) {
						$panel->Hide();
						undef $subpanel;
						undef $panel;
						return 'Back';
				}
				### Go forward immediately
				elsif($data eq NEWT_KEY_F10) {
						$return = 'Next';
				}
			}
			my @errors;
			my $transparent_error;
			foreach my $f (@things) {
				my $val = newt_get_field($field->{$f}, $f);
				$val = $Postprocess{$f}->($val)
						if defined $Postprocess{$f};
				my ($status, $error) = validate($val, $f);
				if(! $status) {
					my $hlp = $Content{$f}->{help};
					$error .= "\n\n" . substitute($hlp)	if $hlp;
					$focused = $f unless $focused;
					push @errors, $error;
					$field->{$f}->Set('');
					next;
				}
				elsif ($status < 0) {
					$transparent_error = 1;
				}
				$Conf{$f} = $val;
			}
			if(@errors) {
				Newt::newtWinMessage(
						errmsg("Error"),
						errmsg("Close"),
						join("\n\n", @errors),
				);
				redo RUNIT;
			}
			redo RUNIT if $transparent_error;
			last;
        }

        $panel->Hide();
        undef $panel;

        for(@things) {
			$Ever{$_} = 1;
        }

        if($win->{postamble}) {
			$win->{postamble}->();
        }

  }

        return 'Next';
}

sub tty_display_it {
        my ($name, $prev_page, $dummy) = @_;
		return if $dummy;
        my $return;
        my $indiv_mode;

        my $win = $Window{$name};

        my $winlab;
        my $winmsg;
        my $winitems;

        if(! $win) {
                $indiv_mode = 1;
                $win = $Content{$name} || die "No content item for fallback in indiv_mode";
        }
        else {
                $winitems = $win->{contents};
        }

        $winitems = [ $name ] if ! $winitems;

        $winmsg = substitute($win->{message} || $win->{help});
        $winlab = $win->{banner} || $win->{label} || $name;
        $winlab = substitute($winlab) if $winlab =~ /__MVC_/;

        if($win->{preamble}) {
                $win->{preamble}->();
        }

        my $lines = $winmsg =~ tr/\n/\n/;
        $lines = 6 if $lines < 6;

  RUNIT: {
        print "\n\n##### $winlab #####\n\n";;

        print "$winmsg\n";

        my @things = grep $Content{$_}, @$winitems;

        @things = grep applicable_directive($_, $Content{$_}->{conditional}), @things
                if @things > 1;
        return 'Skip' unless @things;

        my $field = {};

        for( my $i = 0; $i < @things; $i++) {
                my $one = $things[$i];
                my $content = $Content{$one};
                #next unless applicable_directive($one, $content->{conditional});
                $Conf{$one} = '' unless $Ever{$one};
                my $default = prefix($one);
                $field->{$one} = {
                                   content => $content,
                                   name => $one,
								   default => $default,
								   value => $default,
                                 };
                my $cb = $content->{callback};
                my $sub;
                if (ref $cb eq 'ARRAY') {
                        $sub = sub {
                                my $val = $field->{$one}->{value};
								my ($status, $error) = validate($val, $one);
								return if ! $status;
                                $Conf{$one} = $val;
                                $Conf{$one} = $Postprocess{$one}->($Conf{$one})
                                        if defined $Postprocess{$one};
                                foreach my $item (@$cb) {
                                        next unless defined $field->{$item};
                                        delete $Conf{$item};
                                        my $val = prefix($item);
                                        $field->{$item}->{value} = $val;
                                }
                        };
                }
                elsif (ref $cb eq 'CODE') {
                        $sub = sub {
                                $cb->($one, $field->{$one});
                        };
                }
                elsif ($cb) {
                        eval {
							$sub = sub {
								my $pres = $field->{$one}{value};
								$Ever{$one} = $Conf{$one};
								if ($Conf{$one} ne $pres) {
										$pres = $Postprocess{$one}->($pres)
											if $Postprocess{$one};
										$Ever{$one} = $Conf{$one} = $pres;
										goto RUNIT;
								}
							};
                        };
                        if ($@) {
							debug("sub creation error: $@");
							undef $sub;
                        }
                        else {
							debug("GOTO sub created for $one: $sub");
                        }
                }
				$field->{$one}->{callback_sub} = $sub if $sub;
        }
                
        while (1) {
			foreach my $one (@things) {
				my $f = $field->{$one};
				my $c = $f->{content};
				if($c->{options}) {
					my @opt;
					my $o = $c->{options};
					if (ref $o eq 'CODE') {
						$o = $c->{options}->();
					}

					if(ref $o) {
						@opt = @$o;
					}
					else {
						@opt = $o;
					}

					for(@opt) {
						$_ = substitute($_) if /\s|__MVC_/;
					}

					$f->{value} = shift @opt;
					@opt = reverse @opt;
					unshift @opt, $f->{value};

					sethistory(@opt);
				}
				elsif ($History{$one}) {
					sethistory($History{$one}->());
				}
				else {
					sethistory();
				}
				if (! $Expert and $c->{help}) {
					my $hlp = $c->{help};
					$hlp =~ s/\s+$/\n\n/;
					print $hlp;
				}
				my $prompt = substitute($c->{label});
				$prompt .= "? " unless $prompt =~ /\?/;
				my $ans = prompt(do_msg($prompt, 32), $f->{value} || $f->{default});
				if($ans eq "\cY") {
					my $hlp = $c->{help};
					print "\n\n";
					print "#### " . errmsg("Help for %s", $one) . " ####\n\n";
					print "$hlp\n";
					redo;
				}
				elsif($ans eq "\cF") {
					last;
				}
				elsif($ans eq "\cX") {
					cancel_question(errmsg("Exit the program"))
						and return 'Cancel';
					redo;
				}
				elsif($ans eq "\cB" or $ans =~ /^\s*\@\s*$/) {
					return 'Back';
				}
				else {
					$f->{value} = $ans;
					$f->{callback_sub}->() if $f->{callback_sub};
				}
				print "\n";
			}
			my @errors;
			my $transparent_error;
			for(@things) {
				my $val = $field->{$_}->{value};
				$val = $Postprocess{$_}->($val)
						if defined $Postprocess{$_};
				my ($status, $error) = validate($val, $_);
				if(! $status) {
					if(my $hlp = $Content{$_}->{help}) {
						$error .= "\n\n$hlp";
					}
					push @errors, $error;
					$field->{$_}->{value} = '';
					next;
				}
				elsif($status < 0) {
					$transparent_error++;
				}
				$Conf{$_} = $val;
			}
			if(@errors) {
					print "#### ERROR:\n\n", join("\n\n", @errors) . "\n\n";
					print do_msg("Press any key to continue");
					my $junk = <STDIN>;
					redo RUNIT;
			}
			redo RUNIT if $transparent_error;
			last;
        }

        for(@things) {
                $Ever{$_} = 1;
        }

        if($win->{postamble}) {
                $win->{postamble}->();
        }

  }

        return 'Next';
}

sub tty_root_message {
        my ($text) = @_;
        print "#####\n\t$text\n#####\n\n";
}

sub newt_root_message {
        my ($text, $left, $top) = @_;
        $left = int(($screen_width - length($text)) / 2) unless defined $left;
        $top ||= 0;
        Newt::DrawRootText($left, $top, $text);
}

sub newt_close_display {
		delete $SIG{__DIE__};
        Newt::Finished();
}

sub tty_close_display {
}

#####  MAIN CODE

init_display();
help_message(1);
root_message('Interchange Catalog Configurator');

#
# go through screens
#

debug("\n##### Start catalog_name=$Conf{catalogname} " . scalar localtime);
#debug("conf=" . uneval(\%Conf) ."\n");

@Windows = qw/
	win_greeting
	win_serverconf
	win_servername
	win_server
	win_catinfo
	win_urls
	win_linkinfo
/;

if($Beginner) {
        @Windows = grep applicable_directive($_), @beginner;
}

@Final = qw/
	win_addcatalog
/;


my $ptr = 0;
my $result;
my $Cancel_result = errmsg('Cancel');
my $Back_result = errmsg('Back');
DOALL: {
        $result = run_screens(\@Windows, $ptr);
        last DOALL if $result eq $Cancel_result;

	DOADD: {
        $result = run_screens(\@Additional, $ptr, \@Windows);
		last DOALL if $result eq $Cancel_result;
		if($result eq $Back_result) {
				$ptr = $#Windows;
				redo DOALL;
		}

		$result = run_screens(\@Final, undef, \@Additional);
		last DOALL if $result eq $Cancel_result;
		if($result eq $Back_result) {
				$ptr = $#Additional;
				redo DOADD;
		}
	}
	if($result eq 'Redo') {
		$ptr = 0;
		redo DOALL;
	}
}

BUILD: {
	last BUILD if $result eq $Cancel_result;
	if($> == 0) {
		my $status = check_root_execute("$Conf{vendroot}/$Conf{demotype}");
		if($status != 1) {
			fatal_question(<<EOF);
Improper file security on catalog template.

Some files were writable by UIDs other than root, which is not
secure for reading installation scripts. Please verify the demo
catalog skeleton and make sure no files are world-writable or
are owned by a non-root user.

$status
EOF
			close_display();
			exit;
		}
	}
	Vend::MakeCat::read_commands();

	debug( "Pre-build: ");
	debug(uneval($Window{precopy_commands}));
	my $cont;
	if($cont = $Window{precopy_commands}{contents}) {
		for(@$cont) {
			debug("$_: ");
			debug(uneval($Content{$_}));
		}
	}

	debug( "Post-build: ");
	debug( uneval($Window{postcopy_commands}));
	if($cont = $Window{postcopy_commands}{contents}) {
		for(@$cont) {
			debug("$_: ");
			debug(uneval($Content{$_}));
		}
	}

	Vend::MakeCat::build_cat(
		\&install_scale,
		\&fatal_question,
		\&continue_question,
	);

	#
	# all done
	#

	my $conffile = "/tmp/newcat.cfg";
	unless ($result eq 'Cancel') {
			open CONF, ">$conffile" or
					die "Unable to write configuration file '$conffile': $!\n";
			chmod 0600, $conffile;
			for (sort keys %Conf) {
					$Conf{$_} = '' if ! defined $Conf{$_};
					print CONF "$_=$Conf{$_}\n";
			}
			close CONF or
					die "Error closing configuration file '$conffile': $!\n";
	}

}

close_display();
