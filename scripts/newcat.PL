my $base = $ARGV[0] || '/work/interchange';
$self = {
	INSTALLARCHLIB => $base,
	INSTALLBIN     => "$base/bin",
	INSTALLDIRS    => 'perl',
	INSTALLMAN1DIR => "$base/doc",
	INSTALLMAN3DIR => "$base/doc",
	INSTALLPRIVLIB => "$base/lib",
	INSTALLSCRIPT  => "$base/bin",
};

my %Special;

use Config;

eval {
	require 'scripts/initp.pl';
};

if(! $MV::Self ) {
	$MV::Self = $self;
	$Special{perlpath} = $Config{perlpath};
	$Special{perlpath} .= <<EOF;


eval 'exec $Config{perlpath} -S \$0 \${1+"\$@"}'
    if 0; # not running under some shell
    [catalogname] must contain alphanumerics and hyphens only.

EOF
	$Special{perlpath} =~ s/\s+$//;
}


sub doit {
	my ($key) = @_;
	my $val;
	if ($MV::Self->{RPMBUILDDIR} and $val = $MV::Self->{$key}) {
		$val =~ s!^$MV::Self->{RPMBUILDDIR}/!/!; 
		return $val;
	}
	return $MV::Self->{$key} unless $key =~ /[a-z]/;
	return $Special{$key} if defined $Special{$key};
	$Config{$key};
}

DOIT: {
	local ($/);
	local($_) = <<'_EoP_';
#!/usr/bin/perl
##!~_~perlpath~_~
#
# Interchange catalog configurator with curses
#
# $Id: newcat.PL,v 2.1 2001-08-20 21:02:21 heins Exp $
#
# Copyright (C) 1996-2001 Red Hat, Inc. <interchange@redhat.com>
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

### END CONFIGURATION VARIABLES

$| = 1; select STDERR; 
$| = 1; select STDOUT; 

BEGIN {
	eval {
		require Newt;
		$Vend::Newt = 1;
		import Newt qw/:keys :exits
				NEWT_ANCHOR_LEFT
				NEWT_ANCHOR_RIGHT
				NEWT_FLAG_SCROLL
				NEWT_FLAG_RETURNEXIT
				NEWT_FLAG_WRAP
			/;
	};
}

# Package lexicals for state
my $Beginner;
my $CgiDefault;
my $CgiUrlDefault;
my $Configfile;
my $Debug = $ENV{INTERCHANGE_DEBUG};
my $DistDemo = 'foundation';
my $DocrootDefault;
my $Expert;
my $Help;
my $Logfile = 'makecat.log';
my $No_curses;
my $Reconfigure;
my $Removeconfig;
my $Servers = {};
my $Tilde;

# Additional windows, usually from catalog template additional_fields
my @Additional;
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

$Vend::ExternalProgram = 1;

if(! -f $Global::ConfigFile) {
	for( "$Global::VendRoot/interchange.cfg", "/etc/interchange.cfg") {
		$Global::ConfigFile = $_ if -f $_;
	}
}

eval {
	Vend::Config::global_config();
};

## If it fails, probably because never configured.
if($@) {
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

if($No_curses or ! $Vend::Newt) {
	undef $Vend::Newt;
	readline::rl_set('EditingMode', 'emacs')
		unless $Conf{vi_edit_mode};
	set_display_routines('tty');
}
else {
	set_display_routines('newt');
}

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
							return 'n/a' if ! $Conf{linkmode};
							return 'n/a' if $Conf{linkmode} !~ /^i/i;
							return $Commandline{linkhost} || inet_host();
							},
    linkmode     =>  'UNIX',
    linkport     =>  sub {
							return 'n/a' if ! $Conf{linkmode};
							return 'n/a' if $Conf{linkmode} !~ /^i/i;
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
						my $host = `hostname`;
						chomp $host;
						return $host || $Config{myhostname};
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
							delete $Window{$k} if $v->{_additional};
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
		widget => 'select',
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

sub tty_install_scale {
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
			return;
		}
		elsif($function eq 'end') {
			$label->Set($message . '.....' . errmsg('done'));
			$main->Draw();
			Newt::Refresh();
			select(undef,undef,undef,.5);
		}
		elsif ($function eq 'finish') {
			$main->Hide();
			undef $main;
		}
	};
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


my ($screen_width, $screen_height);
sub newt_init_display {
	$SIG{__DIE__} = sub { Newt::Cls(); Newt::Finished(); warn @_; exit 1; };
	Newt::Init();
	Newt::Cls();
	($screen_width, $screen_height) = Newt::GetScreenSize();
}

sub tty_init_display { system 'cls'; }

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
				'<Space> selects',
				'<F9> previous screen',
				'<F10> next screen',
			);
			#@helps = map { errmsg($_) } @helps;
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
                return ! $idx;
        }
        elsif ($wid eq 'noyes') {
                my $idx = $entry->Get();
                return $idx;
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

sub newt_add_field {
        my ($panel, $row, $content, $name, $default) = @_;
        $content = $Content{$name} if ! $content;

        my $wid = $content->{widget} || 'text';
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
        }
        elsif ($wid eq 'noyes') {
                my $orientation = $content->{orientation} || 'horizontal';
                my $opts        = [ errmsg('No'), errmsg('Yes')];
                $opts = $content->{options}->() if ref $opts eq 'CODE';
                if($orientation =~ /^v/i) {
                        $entry = Newt::VRadiogroup(@$opts);
                }
                else {
                        $entry = Newt::HRadiogroup(@$opts);
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
                if($Conf{$name}) {
					$entry->Select($Conf{$name});
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
        my ($tref, $screen) = @_;

        my @windows = @$tref;

        my (@screenstack, $result);

        if(! $screen) {
			$screen;
		}
		else {
			@screenstack = (0 .. $screen - 1);
		}

        while ($screen < @windows) {

debug("### running screen=$screen window=$windows[$screen]");

                my $skip;
                my $prospect;
                my $win_name = $windows[$screen];

          WINLOOP: {
                my $win = $Window{$win_name} || $Content{$win_name};

                if( ! $win) {
die("no window!?!");
                        $result = 'Next';
                        last WINLOOP;
                }

                if ($win->{conditional} ) {
                        my $prospect = $win->{conditional}->();
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
                        $result = $result || 'Next';
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
                $result = display_it($win_name) || '';
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

sub newt_display_it {
        my $name = shift;
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
			$Conf{$one} = '' unless $Ever{$one};
			my $default;
			$default = prefix($one);
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
        my $name = shift;
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
root_message('Red Hat Interchange Catalog Configurator');

#
# go through screens
#

debug("\n##### Start catalog_name=$Conf{catalogname} " . scalar localtime);
#debug("conf=" . uneval(\%Conf) ."\n");

my @windows = qw/
	win_greeting
	win_serverconf
	win_servername
	win_server
	win_catinfo
	win_urls
	win_linkinfo
/;

if($Beginner) {
        @windows = grep applicable_directive($_), @beginner;
}

my @final = qw/
	win_addcatalog
/;


my $ptr = 0;
my $result;
my $Cancel_result = errmsg('Cancel');
my $Back_result = errmsg('Back');
DOALL: {
        $result = run_screens(\@windows, $ptr);
        last DOALL if $result eq $Cancel_result;

	DOADD: {
        $result = run_screens(\@Additional, $ptr);
		last DOALL if $result eq $Cancel_result;
		if($result eq $Back_result) {
				$ptr = $#windows;
				redo DOALL;
		}

		$result = run_screens(\@final);
		last DOALL if $result eq $Cancel_result;
		if($result eq $Back_result) {
				$ptr = $#Additional;
				redo DOADD;
		}
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

	Vend::MakeCat::build_cat(\&install_scale, \&fatal_question, \&continue_question);

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
_EoP_
	s{.*\n(#(.*)~_~(\w+)~_~(.*))}{$2 . doit($3) . "$4\n$1"}eg;
	my $file = $0;
	$file =~ s/\.PL$//;
	open(OUT, ">$file") 
		or die "Create $file: $!\n";
	print OUT $_;
}
