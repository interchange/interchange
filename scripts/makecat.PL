#!/usr/bin/perl
##!~_~perlpath~_~
#
# Interchange catalog configurator
#
# $Id: makecat.PL,v 2.24 2004-05-09 20:56:21 mheins Exp $
#
# Copyright (C) 2002-2003 Interchange Development Group
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
# Software Foundation, Inc., 59 Temple Place, Suite 330, Boston,
# MA  02111-1307  USA.

use lib '/usr/local/interchange/lib';
#use lib '~_~INSTALLPRIVLIB~_~';
use lib '/usr/local/interchange';
#use lib '~_~INSTALLARCHLIB~_~';

#use strict;
use Config;
use File::Find;
use File::Copy;
use File::Path;
use Sys::Hostname;
use Vend::MakeCat;
use Vend::Util;
use Getopt::Long;
use IniConf;
use Cwd;
use vars qw/$CGIwrap/;

Getopt::Long::config(qw/permute/);
#Getopt::Long::config(qw/debug/);

BEGIN {

	($Global::VendRoot = $ENV{MINIVEND_ROOT})
		if defined $ENV{MINIVEND_ROOT};
	$Global::VendRoot = $Global::VendRoot || '/usr/local/interchange';
#	$Global::VendRoot = $Global::VendRoot || '~_~INSTALLARCHLIB~_~';

	$Global::ProgRoot = '/usr/local/interchange';
#	$Global::ProgRoot = '~_~INSTALLARCHLIB~_~';

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

}

### END CONFIGURATION VARIABLES

$| = 1; select STDERR; 
$| = 1; select STDOUT; 

my $Removeconfig;
my $Reconfigure = 0;
my $Configfile;
my $Cfg;
my $Logfile = 'makecat.log';
my $catalog_name;
use vars qw( %Conf );
my $Inetmode;
my $Windows;
my $pid;
$Windows = 1 if $Config{osname} =~ /win32/i;


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
    --demotype=template        The template catalog (standard is the default)
    --mailorderto=email        Email address to send orders

    Optional:
    --catalogconf=file         Specify separate configuration file for catalogs
    --catuser=username         The user files should be owned by (if root)
    --sharedir=directory       The directory where shared admin images go
    --shareurl=url             The URL to prefix shared admin images with
    --imagedir=directory       The directory where template images go
    --imageurl=url             The URL to prefix images with
    --linkmode=mode            UNIX or INET (link program vlink or tlink)
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

EOF

if (scalar @ARGV > 1) {
	my %optctl = (
	    'F'                 => \$Vend::MakeCat::Force,
	    'aliases'           => \$Conf{aliases},
	    'basedir'           => \$Conf{basedir},
	    'catalogconf'       => \$Conf{catalogconf},
	    'catalogname'       => \$catalog_name,
	    'catroot'           => \$Conf{catroot},
	    'catuser'           => \$Conf{catuser},
	    'cgibase'           => \$Conf{cgibase},
	    'cgidir'            => \$Conf{cgidir},
	    'cgiurl'            => \$Conf{cgiurl},
	    'configfile'        => \$Global::ConfigFile,
	    'demotype'          => \$Conf{demotype},
	    'documentroot'      => \$Conf{documentroot},
	    'c'                 => \$Configfile,
	    'homedir'           => \$Conf{homedir},
	    'imagedir'          => \$Conf{imagedir},
	    'imageurl'          => \$Conf{imageurl},
	    'l'                 => \$Logfile,
	    'linkmode'          => \$Conf{linkmode},
	    'linkhost'          => \$Conf{linkhost},
	    'linkport'          => \$Conf{linkport},
	    'linkprogram'       => \$Conf{linkprogram},
	    'mailorderto'       => \$Conf{mailorderto},
	    'interchangegroup'  => \$Conf{interchangegroup},
	    'interchangeuser'   => \$Conf{interchangeuser},
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
	    'linkfile'          => \$Conf{linkfile},
	    'vendroot'          => \$Conf{vendroot},
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
	    aliases=s
	    basedir|base=s
	    catalogconf=s		
	    catalogname|name=s
	    catroot|dir=s
	    catuser|user=s
	    cgibase=s
	    cgidir=s
	    cgiurl|script=s
	    configfile=s
	    demotype|template=s
	    documentroot=s
	    c=s
	    homedir=s
	    imagedir=s
	    imageurl=s
	    l=s
	    linkmode=s
	    linkfile=s
	    linkhost=s
	    linkport=s
	    linkprogram=s
	    mailorderto=s
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
	    <>
	/);

	GetOptions(\%optctl, @options)			or die "\n$USAGE\n";
}
elsif ($ARGV[0] =~ /^(--help|-h(elp)?)$/i) {
	die "\n$USAGE\n";
}

$catalog_name = shift unless $catalog_name;
if(@ARGV) {
	die <<EOF . "\n";
Extra command line arguments were found. (Did you specify
both --catalogname=name and one on the command line?)

$USAGE
EOF
}

unless($catalog_name) {
	die "$USAGE\n" if $Vend::MakeCat::Force;
	print <<EOF;

Select a short, mnemonic name for the catalog. This will be
used to set the defaults for naming the catalog, executable,
and directory, so you will have to type in this name frequently.

NOTE: This will be the name of 'vlink' or 'tlink', the link CGI
program. Depending on your CGI setup, it may also have the 
extension .cgi added.

Only the characters [-a-zA-Z0-9_] are allowed, and it is strongly suggested
that the catalog name be all lower case.

If you are doing the demo for the first time, you might use "standard".

EOF
   $catalog_name = prompt ("Catalog name? ");
}

die "$catalog_name -- $USAGE\n" unless $catalog_name =~ /^[-\w]+$/;

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
	$Logfile = $Windows ?  'nul:'	: '/dev/null';
}

if ($Vend::MakeCat::Force) {
	my $file = $Logfile || 'makecat.log';
	open(LOGOUT, ">>$file") or die "write $file: $!\n";
	select LOGOUT;
}

$Configfile = "$Global::VendRoot/etc/makecat.cfg" unless $Configfile;
my $Servername;
my $Servers;
my $Done_defaults;

print <<EOF;
makecat -- Interchange catalog installation program.

*** We will be making a catalog named '$catalog_name'. ***

EOF

READCONFIG: {
	my $cfgfile = "etc/$catalog_name.makecat.cfg";

	last READCONFIG unless -f $cfgfile;
	open(READCONFIG, "< $cfgfile") or die "read $cfgfile: $!\n";

	while(<READCONFIG>) {
			next unless /^\s*[A-Z]\w*\s+\S/;
			chomp;
			($var, $val) = split " ", $_, 2;
			$ENV{"MVC_$var"} = $val;
	}
	close READCONFIG;
}

my $CgiDefault		= prefix('CGIDIR')			|| undef;
my $DocrootDefault	= prefix('DOCUMENTROOT')	|| undef;

if ($Windows) {
	$ENV{HOME}		= $ENV{HOME} || $ENV{MINIVEND_ROOT}
						|| prefix('VENDROOT') || '';
	$CgiDefault		=  prefix('CGIDIR') || 'c:/webshare/scripts';
	$CgiUrlDefault	=  prefix('CGIURL')  || '/scripts';
	$DocrootDefault =  prefix('DOCUMENTROOT') || 'c:/webshare/wwwroot';
}

$ENV{MVC_ENCRYPTOR} = prefix('ENCRYPTOR') || 'none';

FINDDOCROOT: {
	last FINDDOCROOT if defined $DocrootDefault;
	for(qw/www html web web-public public_html public-html htdocs/) {
		-d "$ENV{HOME}/$_" and -w _
			and $DocrootDefault = "$ENV{HOME}/$_"
		and last FINDDOCROOT;
	}

	for(	glob("$ENV{HOME}/*html*"),
			glob("$ENV{HOME}/*www*"),
			glob("$ENV{HOME}/*web*")
		)
	{
		-d $_ and -w _
			and $DocrootDefault = $_
		and last FINDDOCROOT;
	}

	for(
		 '/home/httpd/html',
		 '/var/www/html',
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
		and last FINDDOCROOT;
	}

	$DocrootDefault = '';
}

FINDCGIDIR: {
	last FINDCGIDIR if defined $CgiDefault;
	for(qw/cgi-bin cgi cgibin web-scripts scripts cgiwrap cgi-wrap/) {
		-d "$ENV{HOME}/$_" and -w _
			and $CgiDefault = "$ENV{HOME}/$_"
			and $CgiUrlDefault = "/$_"
		and last FINDCGIDIR;
	}

	for( glob("$ENV{HOME}/*cgi*"), glob("$ENV{HOME}/*scripts*") ) {
		-d $_ and -w _
			and $CgiDefault = $_
			and ($CgiUrlDefault = $_) =~ s:.*/:/:
		and last FINDCGIDIR;
	}

	for(
			 '/home/httpd/cgi-bin',
			 '/var/www/cgi-bin',
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
		and last FINDCGIDIR;
	}

	$CgiDefault = $CgiUrlDefault = '';
}

my $isroot = 0;
if ($< == 0) {
	$isroot = 1 unless $Windows or $Conf{relocate};
}

$Conf{catalogname} = $catalog_name;

my %Initial;

my %IfRoot = (qw( permtype 1 interchangeuser 1 interchangegroup 1 catuser 1 linkmode 1));

my %Prefix = (
	vendroot     =>  $Global::VendRoot,
	basedir      =>  sub {
							return prefix('basedir', 1) if prefix('basedir', 1);
							return "$Conf{vendroot}/catalogs"
								if $Windows;
							return "$ENV{HOME}/catalogs"
								unless $isroot;
							return "~/catalogs";
							},
	interchangeuser =>  sub {  return 'everybody' if $Windows;
							get_id(); },
	interchangegroup=>  '',
    servername => sub {
						return Sys::Hostname::hostname() || $Config{myhostname};
					},
    linkmode     =>  'UNIX',
    documentroot =>  $ENV{MVC_DOCUMENTROOT} || $DocrootDefault,
	cgidir       =>  $ENV{MVC_CGIDIR} || $CgiDefault,
	cgibase      =>  $ENV{MVC_CGIBASE} || $CgiUrlDefault,
	demotype     =>  $ENV{MVC_DEMOTYPE} || 'standard',
    catuser      =>  sub {
							$ENV{MVC_CATUSER} ||
							($isroot ? '' : $Conf{'interchangeuser'})
						},
    mailorderto  => 
						sub {  return 'webmaster' if $Windows;
							if($Conf{servername} =~ s:(/~[^/]+)$:: ) {
								$Tilde = $1;
							}
    						$Conf{catuser} },
	catroot      =>   sub {
							my $dir = prefix('basedir') . "/" . $catalog_name;
							return $dir if $Windows;
							my $userdir = (getpwnam($Conf{catuser}))[7];
							$dir =~ s/^\~/$userdir/;
							return $dir;
							},
	cgiurl       =>  sub {
							return $ENV{MVC_CGIURL} if $ENV{MVC_CGIURL};
							my $url = '';
							if ($Conf{cgibase} eq '') {
								$url =	$Tilde if defined $Tilde;
								$url .=	'/' .
										$catalog_name .
										'.cgi';
							}
							else {
								$url .= $Conf{cgibase} . '/' . $catalog_name;
							}
							$url;
						  },
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
							$url .= '/' . $catalog_name . '/' . 'images';
							$url;
						},
	samplehtml   =>  sub {
						return $ENV{MVC_SAMPLEHTML} if $ENV{MVC_SAMPLEHTML};
						$Conf{documentroot} . '/' . $catalog_name;
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

);

sub strip_trailing_slash {
	my $url = shift;
	$url =~ s:[/\s]+$::;
	return $url;
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

my %Postprocess = (

	cgibase			=> \&strip_trailing_slash,
	cgidir			=> \&strip_trailing_slash,
	basedir			=> \&strip_trailing_slash,
	documentroot	=> \&directory_process,
	imagedir		=> \&directory_process,
	samplehtml		=> \&directory_process,
	catroot			=> \&directory_process,
	relocate		=> \&strip_trailing_slash,
	shareurl		=> \&strip_trailing_slash,
	sharedir		=> \&strip_trailing_slash,

);

sub sum_it {
	my ($file) = @_;
	open(IT, "<$file")
		or return undef;
	my $data = '';
	$data .= $_ while (<IT>);
	close IT;
	return unpack("%32c*", $data);
}

sub prefix {
	my ($parm, $nodefault) = @_;
	$parm = lc $parm;
	return $Conf{$parm} if $Conf{$parm};
	return $ENV{"MVC_\U$parm"} if $ENV{"MVC_\U$parm"};
	return undef if $nodefault;
	if(ref $Prefix{$parm}) { 
		return &{ $Prefix{$parm} };
	}
	else {
		return $Prefix{$parm};
	}
}

my %History = (
    demotype =>  sub {
						my @dir; 
						@dir = sort map { s:(.*)/.*:$1:; $_ } glob("*/catalog.cfg");
						@dir = grep $_ ne 'standard', @dir;
						unshift(@dir, 'standard') if -f 'standard/catalog.cfg';
						unshift(@dir, 'foundation')
							if  -f 'foundation/catalog.cfg'
							and $catalog_name =~ /^foundation/;
						unshift(@dir, 'construct')
							if  -f 'construct/catalog.cfg'
							and $catalog_name =~ /^construct/;
						unshift(@dir, 'barry')
							if  -f 'barry/catalog.cfg'
							and $catalog_name =~ /^barry/;
						unshift(@dir, 'art')
							if  -f 'art/catalog.cfg'
							and $catalog_name =~ /^art/;
						my %seen;
						@dir = grep !$seen{$_}++, @dir;
						return @dir;
					},

	linkmode => sub { return ('UNIX', 'INET') },
    documentroot =>  sub {
						if(defined $Servers->{$Servername}) {
							return $Servers->{$Servername}->{documentroot}
							 if defined $Servers->{$Servername}->{documentroot};
						}
						else {
							return (@_);
						}
					},

	cgidir       =>  sub {
						if(	defined $Servers->{$Servername} and
							$Servers->{$Servername}->{scriptalias}
							 ) {
							my @return;
							@return = values %{$Servers->{$Servername}{scriptalias}};
							unshift @return, $ENV{MVC_CGIDIR} if $ENV{MVC_CGIDIR};
							return @return;
						}
						return (@_);
					},

	cgibase      =>  sub {
						if(defined $Servers->{$Servername}) {
							my $ref = $Servers->{$Servername}{scriptalias};
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
    mailorderto  =>	 sub {
						my(@return) = @_;
						if(defined $Servers->{$Servername}) {
							push(@return, $Servers->{$Servername}->{serveradmin})
							 if defined $Servers->{$Servername}->{serveradmin};
						}
						return @return;
					},

	sharedir	 =>	  sub {
						my (@return) = @_;
						if(defined $Servers->{$Servername}) {
							push (@return,
								values %{$Servers->{$Servername}->{alias}})
							 if defined $Servers->{$Servername}->{alias};
						}
						return @return;
					},

	shareurl     =>   sub {
						my (@return) = @_;
						if(defined $Servers->{$Servername}) {
							push (@return,
								keys %{$Servers->{$Servername}->{alias}})
							 if defined $Servers->{$Servername}->{alias};
						}
						return @return;
					},

	imagedir     =>   sub {
						my (@return) = @_;
						if(defined $Servers->{$Servername}) {
							push (@return,
								values %{$Servers->{$Servername}->{alias}})
							 if defined $Servers->{$Servername}->{alias};
						}
						return @return;
					},

	permtype     =>   sub {
						my (@return) = @_;
						push(@return, 'G', 'M', 'U');
						return @return;
					},

	imageurl     =>   sub {
						my (@return) = @_;
						if(defined $Servers->{$Servername}) {
							push (@return,
								keys %{$Servers->{$Servername}->{alias}})
							 if defined $Servers->{$Servername}->{alias};
						}
						return @return;
					},

	catuser  =>   sub {
						return 'everybody' if $Windows;
						my @return = (@_);
						my $u;
						if(defined $Servers->{$Servername}) {
							$nogood = $Servers->{$Servername}->{'user'}
							 if defined $Servers->{$Servername}->{'user'};
						}
						my @out;
						while($u = getpwent) {
							next if $u eq 'root';
							next if $u eq $nogood;
							push(@out, $u);
						}
						return (@return, sort @out);
					},

	interchangeuser  =>   sub {
						return 'everybody' if $Windows;
						my @return = (@_);
						my $u;
						if(defined $Servers->{$Servername}) {
							$nogood = $Servers->{$Servername}->{'user'}
							 if defined $Servers->{$Servername}->{'user'};
						}
						my @out;
						while($u = getpwent) {
							next if $u eq 'root';
							next if $u eq $nogood;
							push(@out, $u);
						}
						return (@return, sort @out);
					},

	interchangegroup  =>   sub {
						return 'nogroup' if $Windows;
						my (@return) = @_;
						my $u;
						if(defined $Servers->{$Servername}) {
							$nogood = $Servers->{$Servername}->{'group'}
							 if defined $Servers->{$Servername}->{'group'};
						}
						my @out;
						while($u = getgrent) {
							next if $u eq 'root';
							next if $u eq $nogood;
							push(@out, $u);
						}
						return (@return, sort @out);
					},

);

unless($isroot) {
	@Prefix{qw(interchangeuser interchangegroup)} = get_ids();
	$Prefix{catuser} = $Prefix{interchangeuser};
	$Prefix{basedir} = "$ENV{HOME}/catalogs";
}

my($ask,$param);

unless (-f $Configfile) {
	$Removeconfig = 1 if prefix('nocopy');
	open(CFGFILE, ">$Configfile")	or die "Can't write $Configfile: $!\n";
	while(<DATA>) {
		print CFGFILE $_;
	}
	close(CFGFILE)					or die "Can't close $Configfile: $!\n";
	print "\nNew configuration file '$Configfile'\n" ;
	$Reconfigure = 1;
}

$Cfg = new IniConf -file => $Configfile;
unless ($Cfg) {
	if (@IniConf::errors) {
		print join("\n", @IniConf::errors, '');
	}
	die "Can't parse config file $Configfile\n";
}

my @parms;

unless($Reconfigure or $Cfg->val('base', 'vendroot')) {
	$Reconfigure = 1;
}

CHECKEXIST: {

	if(grep /^catalog $catalog_name$/i, $Cfg->Sections()) {
		@parms = $Cfg->Parameters("catalog $catalog_name");
	}
	else {
		@parms = ();
	}
	unless(@parms) {
		@parms = $Cfg->Parameters('legalconfig');
		undef $Cfg;
		my $user_time = "run by ";
		$user_time .= scalar getpwuid($>);
		$user_time .= " at ";
		$user_time .= scalar localtime();

		open(CFGFILE, ">>$Configfile")	or die "Can't write $Configfile: $!\n";
		print CFGFILE <<EOF;

# New catalog definition '$catalog_name' written by makecat
# $user_time
[catalog $catalog_name]
EOF
		for(@parms) {
			printf CFGFILE "%-19s =\n", $_;
		}
		close(CFGFILE)					or die "Can't close $Configfile: $!\n";
		$Cfg = new IniConf -file => $Configfile;
		die "Can't read config file $Configfile: $!\n" unless defined $Cfg;
		redo CHECKEXIST;
	}
		
}

my @conf;
my @Servers;

FINDCONF: {

	last FINDCONF if $Windows;
	last FINDCONF if $Vend::MakeCat::Force;
	last FINDCONF if $ENV{MVC_SERVERNAME};
	my $httpdconf;
	if($param = prefix('serverconf') || $Cfg->val('base', 'serverconf')) {
		last FINDCONF if $param =~ /^none$/i;
		@conf = split /\s+/, $param;
	}
	print <<EOF unless @conf;

If you are using the Apache or NCSA web server, Interchange can set
some of the default parameters for you by reading the file.

If you use the Netscape Enterprise server or other non-NCSA HTTP server,
enter 'none' -- the information, if any, will not be useful.

EOF
	if (defined $Vend::MakeCat::Prompt_sub) {
		print <<EOF;

Try using the UP arrow at some of the prompts -- you have the
Term::ReadLine module installed, and Interchange may find some
default values in your HTTP server configuration file.  You can
cycle among them with the UP and DOWN arrows.

EOF
	}
	else {
		print <<EOF unless @conf;

This information may not be that useful to you, since you don't
have the Term::ReadLine module installed. If the default setting
presented is not correct, you will have to know the information.
C'est la vie.

EOF
	}

	my $not_set;
	if(! scalar @conf) {
		$not_set = 1;
		if(findexe('locate')) {
			@conf = findfiles('httpd.conf');
		}
		else {
			print <<EOF;

Interchange can look for Apache or NCSA HTTP server configuration
files for you by a slow method (using the system find
command). This may take as many as several minutes.

EOF
			$ask = prompt("Find httpd.conf files? ", 'y');
			@conf = findfiles('httpd.conf') if $ask =~ /^\s*y/i;
		}
	}

	sethistory(@conf);
	if ($not_set) {
		$httpdconf = prompt("Enter path to httpd.conf file: ", $conf[0]);
		$Cfg->setval('base', 'serverconf', $httpdconf);
	}
	else {
		$httpdconf = shift @conf;
	}
	last FINDCONF if $httpdconf =~ /^none$/i;

	if($httpdconf) {
		$Servers = conf_parse_http($httpdconf);
		unless (defined $Servers) {
			print <<EOF;

The file '$httpdconf' was not parsed properly.

Error: $Vend::MakeCat::Error

You can edit the file and try again if you wish. (Don't worry if it
didn't work, you will have the opportunity to enter all of the proper
information manually.)

EOF
			$ask = prompt("Try again? ", 'y');
			last FINDCONF if $ask =~ /^\s*n/i;
			redo FINDCONF;
		}
		else {
			@Servers = sort keys %{$Servers};
		}
	}
}

##############
SETDEFAULTS: {
	last SETDEFAULTS if $Done_defaults;
	$Done_defaults = 1;
	unless ($Reconfigure) {
		my @parms = $Cfg->Parameters('base');
		for(@parms) {
			next if $Conf{$_} = prefix($_, 1);
			$Conf{$_} = $Cfg->val('base', $_) || undef;
		}
		last SETDEFAULTS;
	}

	PERMS: {

		unless ($isroot) {
			print <<EOF unless $Windows;

This demo configuration sometimes requires root permissions,
depending on your ISP. It needs to copy a few files to the CGI
and HTML directories.

You must either have your own CGI directory, or be able to run
a CGI with an extension like '.cgi'.

If you will be operating only on directories owned by the
user you are running this as, you will be able to do
everything.

EOF

		}
		else {
			last PERMS if prefix('permtype', 1);
			print <<EOF;

You are the super-user. You can set the permissions to GROUP, MULTIPLE
GROUP, or USER mode for catalogs on this server.

MULTIPLE GROUP or GROUP is appropriate when multiple users will be running
catalogs on the same server.

MULTIPLE GROUP is the best way. Put each user in their own group, and
place the Interchange user in that group. In this mode, only the user of
each catalog and the Interchange server may read database and error files --
files that may contain sensitive information. If the user's default UMASK
is 2 on a UNIX system, then this the most troublefree mode of operation.

GROUP mode causes all files to be owned by the Interchange user, with group
ownership set to the group the user belongs to. This allows the Interchange
user and each individual user to read and write the files associated with
a catalog, but others in that group may read files from a catalog. This
may not be secure, and may cause problems when the user creates new
files that must be read/write to the Interchange user.

USER mode is appropriate when only one user owns all catalogs running
on this server, and the Interchange daemon is run by the same user.

  M) MULTIPLE GROUP
  G) GROUP
  U) USER

EOF
			sethistory("MULTIPLE GROUP", "GROUP", "USER");
			$Conf{permtype} = prompt("Permission Mode? ", "M");
			unless($Conf{permtype} =~ s/^\s*([mgu]).*/uc $1/ie) {
				print "Must be one of M(ULTIPLE), G(ROUP), or U(SER).\n";
				redo PERMS;
			}
			$Cfg->setval('base', 'permtype', $Conf{permtype});

		}

	} # END PERMS

	print <<EOF;

Since there was no master configuration file, we will ask
some questions to help set initial defaults for making this
and future catalogs.

EOF


	##############
	DEFSERVER: {

	last DEFSERVER unless @Servers;

	print <<EOF if defined $Vend::MakeCat::Prompt_sub;

Interchange can set many of the defaults for you if it knows the server
name that is going to be used.

Enter the default server that should be used. This is only a default, to
determine the *first* one that will be looked at -- you will be given
a choice of all available servers.

There is a "history" mechanism that will allow you to use the up
and down arrows on your terminal (assuming you have a standard terminal)
to cycle between possible choices. This should contain the available
servers.

EOF

	sethistory(@Servers);
	$Conf{servername} = prompt('Default server? ', $Servers[0]);
	$Servername = $Conf{servername};
	$Cfg->setval('base', 'servername', $Servername);

	}
	############

	my @ask = $Cfg->val('global', 'askbase');

	for('cgidir') {
		next if $Conf{$_};
		print <<EOF;


We need to know if all of your CGI programs are run as a file ending
in .cgi or some other extension, or whether you have your own personal
CGI directory.

EOF
		$ask = prompt ("Do you have a CGI directory? ", 'y');
		last if is_yes($ask);
		$Prefix{cgidir} = prefix('documentroot');
	}

	my ($p, $i);

	for ($i = 0; $i < scalar @ask; $i++) {
		$p = $ask[$i];
		my $hval;
		$hval = prefix($p);
		if (defined $History{$p}) {
			@history = &{$History{$p}}(prefix($p));
			$hval = $history[0];
			sethistory(@history);
		}
		$val = prefix($p, 1) || $Cfg->val("base", $p) || $hval;
		if (! $isroot and defined $IfRoot{$p}) {
			$Conf{$p} = $val;
			next;
		}
		print "\n";
		print description($p);
		print "\n\n";
		my $msg = pretty($p) . "? ";
		$Conf{$p} = prompt ($msg, $val);
		if($Conf{$p} eq '@') {
			$i--;
			$i = 0 if $i < 0;
			redo;
		}
		if(defined $Postprocess{$p}) {
			$Conf{$p} = $Postprocess{$p}->($Conf{$p});
		}
	}

	for(@ask) {
		$Cfg->setval('base', $_, $Conf{$_});
	}

	$Cfg->WriteConfig("$Configfile.new")
		and File::Copy::copy "$Configfile.new", $Configfile;

	print "#########     END BASE CONFIGURATION      #########\n\n";

}
#############

	my $serv = prefix('servername') || 'www.yourdomain'; 

# Set server

print "######### BEGINNING CATALOG CONFIGURATION #########\n";
print <<EOF if defined $Vend::MakeCat::Prompt_sub;

During many of the following operations, defaults are placed in
a buffer for you. You may use the up and down arrows to toggle
between the defaults.

If you made a mistake on a *previous* entry and realize that
in a later one, if you enter ONLY an @ sign and press return you
should be returned to the previous step.

EOF
SETSERVER: {
	sethistory(@Servers);
	print description('servername');
 	$Servername = prefix('servername', 1)  			|| 
				  $Cfg->val('base', 'servername')	||
				  prefix('servername');
	$Servername =
		$Conf{servername} =
			prompt("Server name? ", ($Servername || $Servers[0]));
	$Cfg->setval("catalog $catalog_name", 'servername', $Conf{servername});
}

	@ask = $Cfg->val('global', 'askconfig');

	my $redid;
	my $next_force;
	for ($i = 0; $i < scalar @ask; $i++) {
		$p = $ask[$i];
		if ($redid) {
#print("###redo###\n");
			# Handle the &-d option, don't want to force first time
			if (defined $next_force and ! $next_force) {
#print("###force next###\n");
				$next_force = 1;
			}
			$val = $Conf{$p};
		}
		elsif (defined $History{$p}) {
			@history = &{$History{$p}}(prefix($p));
			sethistory(@history);
			$val =	prefix($p,1)							||
					$Cfg->val("catalog $catalog_name", $p)	||
					$history[0]								||
					prefix($p);
		}
		else {
			$val =	prefix($p,1)							||
					$Cfg->val("catalog $catalog_name", $p)	||
					prefix($p);
		}
		if (! $isroot and defined $IfRoot{$p}) {
			$Conf{$p} = $val;
			next;
		}
		print "\n";

		unless($redid) {
			print description($p);
			print "\n\n";
		}
		else {
			undef $redid;
		}

		my $msg = pretty($p) . "? ";
		$Conf{$p} = prompt ($msg, $val);
#print("###force=$Vend::MakeCat::Force###\n");
		if(defined $Postprocess{$p}) {
			$Conf{$p} = $Postprocess{$p}->($Conf{$p});
		}
		if($Conf{$p} eq '@') {
			$Conf{$p} = $val;
			$redid = 1;
			$next_force = 0 if $next_force;
			$i--;
			$i = 0 if $i < 0;
			redo;
		}
		elsif ($Conf{$p} eq '&-d') {
			print "OK, I will run with defaults after this prompt.\n";
			$Conf{$p} = $val;
			$redid = 1;
			$next_force = 0;
			redo;
		}

		if ($next_force) {
#print("###force now###\n");
			$Vend::MakeCat::Force = 1;
		}

		$Cfg->setval("catalog $catalog_name", $p, $Conf{$p});
	}

if($Removeconfig) {
	unlink $Configfile;
}
elsif ( ! prefix('nocopy') ) {
	$Cfg->WriteConfig("$Configfile.new")
		and File::Copy::copy "$Configfile.new", $Configfile;
}

undef $Cfg;

# Try and get the URL we will use to access the catalog
GUESS: {

 	if( $Conf{samplehtml} =~ /^\s*none\s*$/i ) {
		$Conf{sampleurl} = 'NONE';
		last GUESS;
	}

	my $tempurl;
    $guessdir = $Conf{samplehtml};

    unless( $guessdir =~ s/^$Conf{documentroot}// ) {
        print <<EOF;

The specified HTML directory, $Conf{samplehtml},
is not a subdirectory of DocumentRoot. This will make it
hard for us to guess the URL needed to access pages from
the catalog. Please re-specify your HTML document root.

# The base directory for HTML for the catalog, the DocumentRoot.
# This is a file name, not a URL.

EOF
        $val = '';
		my $msg = pretty('documentroot');
        $Conf{documentroot} = prompt ("\n$msg? ", '');
        redo GUESS;
    }

    $guessdir =~ s:^/+::;
    $guessdir = "$Tilde/$guessdir" if defined $Tilde;
    $guessdir =~ s:^/+::;
    $tempurl = "http://$Conf{servername}/$guessdir";
    if (defined $Conf{sampleurl} and $Conf{sampleurl} ne $tempurl) {
		print <<EOF;

We were given a previous value for the URL that will run the catalog
(from the catalog configuration file $Configfile):

    $Conf{sampleurl}

This conflicts with what we guess from what you have just
entered:

   	$tempurl

EOF

		if ($Vend::MakeCat::Force) {
			$tempurl = $Conf{sampleurl};
		} else {
			$tempurl  = prompt ("\nPlease re-enter or confirm: ",
						"http://$Conf{servername}/$guessdir");
		}
	}

	$Conf{sampleurl} = $tempurl;

}

if ($Windows) {
	$mvuid = $catuid = 'everybody';
	$mvgid = $catgid = 'nogroup';
}
elsif ($Conf{relocate}) {
	$mvuid = $catuid = $mvgid = $catgid = 'nobody';
}
else {
	$mvuid = (getpwnam($Conf{interchangeuser}))[2];
	die "$Conf{interchangeuser} is not a valid user name on this machine.\n"
		unless defined $mvuid;

	if ($Conf{interchangegroup}) {
		$mvgid = getgrnam($Conf{interchangegroup});
		die "$Conf{interchangegroup} is not a valid group name on this machine.\n"
			unless defined $mvgid;
	}
	else {
		$mvgid = (getpwnam($Conf{interchangeuser}))[3];
		$Conf{interchangegroup} = getgrgid($mvgid)
	}

	($catuid, $catgid) = (getpwnam($Conf{catuser}))[2,3];
	die "$Conf{catuser} is not a valid user name on this machine.\n"
		unless defined $catuid;
}

if($isroot) {
	chown ($mvuid, $mvgid, $Configfile)
		or warn "\nCouldn't set ownership of $Configfile: $!\n";
	if(! $Conf{permtype} or $Conf{permtype} =~ /^[MUmu]/) {
		$Conf{catgroup} = getgrgid($catgid);
	}
	else {
		$Conf{catgroup} = getgrgid($mvgid);
	}
}

# Final substitution
for(keys %Conf) {
	next unless $Conf{$_} =~ /__MVC_/;
	$Conf{$_} =~ s/__MVC_([A-Z]+)__/$Conf{lc $1}/g;
}

# Find the perl path
$Conf{'perl'} = $Config{perlpath};

# Now change to the directory defined as Global::VendRoot
chdir "$Conf{relocate}$Conf{vendroot}"
	or die "Couldn't change directory to $Conf{relocate}$Conf{vendroot}: $!\n";

$warn = 0;
$msg = q# supposed to be a directory, not a file. Can't continue.#;
for ( $Conf{catroot}, $Conf{documentroot}, $Conf{basedir},
	$Conf{samplehtml}, $Conf{imagedir} ) {
	next unless -f "$Conf{relocate}$_";
	print "$_ $msg\n";
	$warn++;
}
die "\n" if $warn;

my $prog;
my ($lh, $lp);

SETLINKMODE: {
	if($prog = prefix('linkprogram')) {
		last SETLINKMODE;
	}
	if ($Windows) {
		$Conf{linkmode} = 'INET';
		$prog = "$Conf{relocate}$Conf{vendroot}/src/tlink.pl";
		last SETLINKMODE;
	}
	print <<EOF;

Interchange can use either UNIX- or internet-domain sockets.
Most ISPs would prefer UNIX mode, and it is more secure.

If you already have a program there, or use a common program
and the FullURL directive, select NONE. You will then need
to copy the program by hand or otherwise ensure its presence.

EOF
	print "(You can use the up/down arrows to toggle).\n"
		if $Vend::MakeCat::Prompt_sub;

	sethistory("NONE", "UNIX", "INET");

	unless ( $default = prefix('linkmode') ) {
		$default = ($Config{osname} =~ /bsd/i and $Config{osvers} gt '3')
				? 'INET' : 'UNIX';
	}
	
	$ask = prompt("INET or UNIX mode? ", $default);

	$prog = "$Conf{relocate}$Conf{vendroot}/src/vlink";

	if($ask =~ /^\s*i/i) {
		$lm = "i";
		$Conf{linkmode} = 'INET';
		$Inetmode = 1;

		my $defport;
		my $defhost;

	  INETASK: {
		my (@hosts);
		my (@ports);
		$prog = "$Conf{relocate}$Conf{vendroot}/src/tlink";
		my $the_one = sum_it($prog);

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

		my %seen;
		sethistory(grep !$seen{$_}++, @ports);
		$default = $defport || $Conf{linkport} || 7786;
		$lp = $lh = '';
		while(! $lp) {
			$lp = prompt("TCP socket to use? ", $default);
			redo INETASK if $lp eq '@';
			if($lp !~ /^\d+$/ or $lp < 1024) {
				print "Looking for an integer number > 1024 here.\n";
				undef $lp;
			}
		}

		sethistory(grep !$seen{$_}++, @hosts);
		$default = $defhost || $Conf{linkhost} || '127.0.0.1';
		while(! $lh) {
			$lh = prompt("Link host? ", $default);
			redo INETASK if $lh eq '@';
		}
		$Conf{linkport} = $lp;
		$Conf{linkhost} = $lh;
		unlink $prog unless $lh eq $defhost && $lp eq $defport;
	  } # END INETASK
	}
	elsif($ask =~ /^\s*n/i) {
		$Conf{linkmode} = $prog = "NONE";
	}
	else {
		$lm = 'u';
		$Conf{linkmode} = "UNIX";
		my $def = -u '/usr/bin/suexec' ? 'y' : 'n';
		$ask = prompt("Do you use CGIWRAP or SUEXEC? ", $def);
		$Conf{cgiwrap} = $CGIwrap = $ask =~ /^\s*y/i;
	}

}

my $tried_compile;

FINDPROG: {
	last FINDPROG if $prog eq 'NONE';
	unless (-x $prog and -f _) {
		if(! $tried_compile) {
			my $cmd = 'bin/compile_link ';
			$cmd .= "-$lm " if $lm;
			$cmd .= "-s $Conf{linkfile} " if $Conf{linkfile};
			$cmd .= "-p $lp " if $lp;
			$cmd .= "-h $lh " if $lh;
			if ($Conf{relocate}) { 
                        	$cmd .= "--source $Conf{relocate}/$Conf{vendroot}/src ";
            		}
			system $cmd;
			$tried_compile = 1;
			redo FINDPROG;
		}
		my @history = ();
		$prog =~ s:.*src/::;
		print <<EOF;
	Couldn't find the executable file '$prog'.

	Please give the complete path to the link program.

EOF
		if($Config{osname} =~ /win32/i) {
			# do nothing
		}
		elsif (@history = glob("$Global::VendRoot/src/?link.???*")) {
			# do nothing
		}
		elsif (@history = glob("$Global::ProgRoot/src/?link.???*")) {
			# do nothing
		}
		elsif(findexe('locate')) {
			@history = findfiles($prog);
		}
		else {
			@history = `find . -name \*[vt]link\* -print`;
			chomp @history;
		}
		sethistory(@history);
		$prog = prompt("Link program? ", $history[0]);
	}
}

umask(022) unless $Conf{noumask};

$warn = 0;
print do_msg("Checking directories");

$msg = q#directory exists!#;
for($Conf{catroot}, $Conf{samplehtml}) {
	next unless -d $_;
	print "\n$_: $msg\n";
	$warn++;
}

if($warn) {
	$ask = prompt "The above directories already exist. Overwrite files? ", 'n';
	unless($Vend::MakeCat::Force) {
		exit 2 unless is_yes($ask);
	}
}

$warn = 0;
for($Conf{documentroot}, $Conf{basedir}) {
	next if /^\s*none\s*$/i;
	next if -d $_;
	$warn++;
}

for($Conf{catroot}, $Conf{samplehtml}, $Conf{imagedir}) {
	next if /^\s*none\s*$/i;
	next if -d $_;
	$warn++;
}

if($warn) {
	for(qw(catroot samplehtml imagedir)) {
		$dir = "$Conf{relocate}$Conf{$_}";
#print "doing dir=$dir\n";
		# Allow nocopy
		next if $dir =~ /^\s*none\s*$/i;

		(warn "\n$_ is empty, skipping.\n", next)
			unless $dir =~ /\S/;
		unless(-d $dir or prefix('nocopy') ) {
			File::Path::mkpath([$dir], 1, 0775)
				or die "Couldn't make directory $dir: $!\n";
		}
	}
}

for(qw(catroot samplehtml imagedir)) {
    my $userdir;
    if($dir =~ /^~/ and $userdir = (getpwnam($Conf{catuser}))[7] ) {
		$dir =~ s/^~/$userdir/;
    }
	$dir = "$Conf{relocate}$Conf{$_}";

	# Allow nocopy
	next if $dir =~ /^\s*none\s*$/i;

	if (prefix('nocopy')) {
		next if -w $dir;
		my $parent = $dir;
		do {
			$parent =~ s:/[^/]+$::;
		} until $parent !~ m{/} or -d $parent;
		warn "Directory $dir (or parents) not writable, could be problems.\n"
			unless -w $dir || -w $parent;
		next;
	}

	die "Directory $dir not writable, can't continue.\n"
		unless -w $dir or $dir =~ /^\s*none\s*$/i;
	set_owner($dir);
}
print "done.\n";

# Now change to the directory defined as Global::VendRoot if the checks
# have left us elsewhere
chdir "$Conf{relocate}$Conf{vendroot}"
		or die "Couldn't change directory to $Conf{relocate}$Conf{vendroot}: $!\n";

print do_msg("Copying demo files");
unless (-d "$Conf{relocate}$Conf{vendroot}/$Conf{demotype}") {
	print "No $Conf{relocate}$Conf{vendroot}/$Conf{demotype} directory is present,\n";
	$dir = prompt("where should the files come from? ", "$Conf{relocate}$Conf{catroot}");
}
else {
	$dir = "$Conf{relocate}$Conf{vendroot}/$Conf{demotype}";
}

# Do some additional configuration if the additional_fields
# file is found

ADDITIONAL: {
	last ADDITIONAL unless -f "$dir/config/additional_fields";
	open(ADDL, "< $dir/config/additional_fields") 
		or last ADDITIONAL;
	my %help;
	local ($/) = "";
	if(open(ADDLHELP, "< $dir/config/additional_help") ) {
		while(<ADDLHELP>) {
			my($parm,$help) = split /\n/, $_, 2;
			$help =~ s/\s*$/\n\n/;
			$help =~ s/^[.\t ]+$//mg;
			$help{uc $parm} = $help;
		}
		close ADDLHELP;
	}
	my $said = 0;
	my $redid;
	my $next_force;
	while(<ADDL>) {
		my $noprompt = '';
		my $grp;
		s/\s+$//;
		s/__MVC_([A-Z0-9]+)(__)?/substitute($1,$2)/eg;
		my ($var, $prompt, $default) = split /\n/, $_, 3;
		$var =~ s/\t(.*)//;
		next unless $var;
		$grp = $1 || $var;

		if ($redid) {
#print("###redo###\n");
			# Handle the &-d option, don't want to force first time
			if (defined $next_force and ! $next_force) {
#print("###force next###\n");
				$next_force = 1;
			}
			$val = $Conf{$p};
		}
		if($var =~ s/{\s*([A-Z0-9]+)(\s*\S.*?)?\s*}\s*//) {
			my $param = $1;
			my $test = $2;
			my $v = $Conf{lc $param};
			$v = "q{$v}";
			my $true;
			eval {
				$true = eval "$v$test";
			};
			next unless $true;
		}
		$var =~ s/\s+//g;
		$var =~ s:^!::
			and $noprompt = 1;
		$var = lc $var;
		my $ucvar = uc $var;
		if($default =~ /\t/) {
			my (@history);
			(@history)  = split /\t/, $default;
			$default = $history[0];
			sethistory(@history);
		}
		unless ($noprompt) {
			if (defined $help{$ucvar} and ! $redid) {
				$help{$ucvar} =~ s/__MVC_([A-Z0-9]+)(__)?/substitute($1,$2)/eg;
				print $help{$ucvar};
			}
			print "found more to ask.\n\n" unless $said++;
			$Conf{$var} = prompt(
							do_msg("$prompt: ", 50),
									 ( delete $ENV{"MVC_$ucvar"}
										|| $Conf{$var}
										|| $default)
									);
			if ($Conf{$var} eq '&-d') {
				print "OK, I will run with defaults after this prompt.\n";
				$Conf{$var} = $default;
				$redid = 1;
				$next_force = 0;
				redo;
			}
		}
		else {
			$Conf{$var} = delete $ENV{"MVC_$ucvar"} || $Conf{$var} || $default;
		}

		if ($next_force) {
#print("###force now###\n");
			$Vend::MakeCat::Force = 1;
		}

	}
	close ADDL;
}

CRYPTPW: {
	my $pw = substitute('CRYPTPW', '__');
	last CRYPTPW unless $pw;
	last CRYPTPW if substitute('ALREADYCRYPT', '__');
	my @letters = ('A' .. 'Z', 'a' .. 'z');
	my $salt = $letters[ int rand(scalar @letters) ];
	$salt .= $letters[ int rand(scalar @letters) ];
	$ENV{MVC_CRYPTPW} = crypt($pw, $salt);
}

PRECMD: {
	last PRECMD unless -f "$dir/config/precopy_commands";
	open(ADDL, "< $dir/config/precopy_commands") 
		or last PRECMD;
	print "\nFound system commands to run.\n\n";
	local ($/) = "";
	while(<ADDL>) {
		my $unprompted;
		s/\s+$//;
		s/__MVC_([A-Z0-9]+)(__)?/substitute($1,$2)/eg;
		my ($command, $prompt) = split /\n/, $_, 2;
		$command =~ s/^\s+//;
		$command =~ s/\s+$//;
		$command =~ s/^!// and $unprompted = 1;
		if($command =~ s/{\s*([A-Z0-9]+)(\s*\S.*?)?\s*}\s*//) {
			my $param = $1;
			my $test = $2;
			my $v = $Conf{lc $param};
			$v = "q{$v}";
			my $true;
			eval {
				$true = eval "$v$test";
			};
			next unless $true;
		}
		print "$prompt\n\n";
		print "Running: $command\n" if $unprompted;
		my $ans = $unprompted ? 'y' : prompt( qq{run "$command"? }, 'y' );
		if($ans =~ /^\s*y/i) {
			system $command;
			if($?) {
				print "\nCommand returned error code " . ($? >> 8) . ": $!\n";
			}
		}
		else {
			print "\nskipping '$command'\n";
		}
	}
	close ADDL;
}

# Here we actually do the file copy unless --nocopy is set
DOCOPY: {

	if (prefix('nocopy')) {
		print "not copying.\n";
		last DOCOPY;
	}

	chdir $dir || die "Couldn't change directory to $dir: $!\n";


	# This is what we used to do
	#system "tar -cf - * | (cd $Conf{catroot}; tar -xf -)";

	umask(07) unless $Conf{noumask};

	# remove any existing symbolic links in target directory
	File::Find::find( sub {
								return if ! -l $_;
								unlink $_
									or die "couldn't unlink $File::Find::name: $!\n";
							},
					 "$Conf{relocate}$Conf{catroot}",
					 );

	eval {
		copy_current_to_dir("$Conf{relocate}$Conf{catroot}");
	};

	umask(022) unless $Conf{noumask};

	if($@) {
		die <<EOF . "\n";
There were errors in copying the demo files.  Cannot
continue.  Check to see if permissions are correct.
The problem was:

	$@
EOF
	}

	unless($prog eq 'NONE') {
		File::Copy::copy( $prog, "$Conf{relocate}$Conf{catroot}/executable")
			or die "Couldn't copy link program from $prog: $!\n";
	}

	print "done.\n";

chdir "$Conf{relocate}$Conf{catroot}"
 	|| die "Couldn't change directory to $Conf{relocate}$Conf{catroot}: $!\n";

my ($umode, $gmode);

if($Conf{permtype} =~ /^[mg]/i) {
	$umode = 0; $gmode = 1;
}
else {
	$umode = 1; $gmode = 0;
}


%MacroString = qw(

    __MVC_CGIURL        cgiurl
    __MVC_CGIDIR        cgidir
    __MVC_MAILORDERTO   mailorderto
    __MVC_IMAGEURL      imageurl
    __MVC_SAMPLEURL     sampleurl
    __MVC_SERVERNAME    servername

);

sub set_owner {
	return unless $> == 0;
	my($file) = @_;
	my ($user, $group) = ($mvuid, $mvgid);
	if($Conf{permtype} =~ /^m/i) { $user = $catuid; $group = $catgid; }
	elsif($Conf{permtype} =~ /^g/i) { $group = $catgid; }
	chown($user, $group, $file)
		or die "Couldn't set ownership to UID=$user GID=$group for $file: $!\n";
}

sub substitute {
	my($parm,$new) = @_;

	return $ENV{"MVC_$parm"} if defined $ENV{"MVC_$parm"};

	if($new) {
		return $Conf{lc $parm} || '';
	}
	else {
		return $Conf{$MacroString{"__MVC_$parm"}}
			if defined $MacroString{"__MVC_$parm"};
	}
	return "__MVC_${parm}__";
}

sub wanted {

	my ($mode,$file);
	$file = $_;
	my $name = $File::Find::name;
	EDIT: {
     	return if        (-l $file);

		# Ugly, but necessary on BSDI
		$File::Find::prune = 1 if -f _;

        last EDIT unless (-f _);
        last EDIT unless (-T _);
  
		open(IN, "< $file") or die "Couldn't open $name: $!\n";
		open(OUT, ">$file.new") or die "Couldn't create $name.new: $!\n";
		while(<IN>) {
			( (print OUT $_), next) unless /__MV[CR]/;
            s/^#>>(.*)(__MVR_(\w+)__.*)\n\1.*/#>>$1$2/g;
            s/^#>>(.*__MVR_(\w+)__.*)/#>>$1\n$1/g;
            1 while s/\n([^#].*)__MVR_(.*)/\n$1__MVC_$2/g;
            s/__MVC_([A-Z0-9]+)(__)?/substitute($1,$2)/eg;
            print OUT $_;
		}
		close OUT;
		close IN;
		unlink ($file)
			or die "Couldn't unlink $name: $!\n";
		rename ("$file.new", $file)
			or die "Couldn't rename $name.new to $name: $!\n";
	}
	my %Xfile;
	if($Windows) {
		# None of this stuff applies for Windows, I don't think.
		# Put Win-specific stuff here.
	}
	else {
		set_owner($file);
		$mode = (stat($file))[2];
		if ($Xfile{$file}) {
			$mode |= 0550;
		}
		else {
			$mode |= 060 if $gmode;
			$mode |= 02010 if $gmode and -d $file;
		}
		chmod ($mode, $file)
			or die "\nCouldn't set permissions on $name: $!\n";
	}
}
	
	$File::Find::dont_use_nlink = 1;
	set_owner("$Conf{relocate}$Conf{catroot}");
	File::Find::find(\&wanted, "$Conf{relocate}$Conf{catroot}");

	$cginame = $Conf{cgiurl};
	$cginame =~ s:.*/::;
	$Conf{cgifile} = $cginame = "$Conf{relocate}$Conf{cgidir}/$cginame";
	
	umask(022) unless $Conf{noumask};

	unless ($prog eq 'NONE') {
		my $ask_cgi = 'y';
		if(-f $cginame) {
            $ask_cgi = prompt (
                            do_msg("Moving link, $cginame exists, overwrite? "),
                            'n',
                            );
        }
        else {
            print do_msg("Moving link program to $cginame");
        }

		if(is_yes($ask_cgi)) {
			File::Copy::copy("$Conf{relocate}$Conf{catroot}/executable", $cginame)
				or die
				"\nCouldn't copy link executable from $prog to $cginame: $!\n";
			chmod 0755, $cginame   
					or die "\nCouldn't make $cginame executable: $!\n";
			unlink "$Conf{relocate}$Conf{catroot}/executable";
		}

		if($isroot) {
			chown ($mvuid, $mvgid, $cginame)
				or die "\nCouldn't set ownership of $cginame: $!\n";
		}

		unless ($Windows or $Inetmode or $CGIwrap) {
			unless ($isroot or can_do_suid()) {
				print <<EOF;

My test indicates you can't change vlink to SUID mode.
This will cause big problems -- you can make Interchange work anyway
by changing the ReadPermission and WritePermission directives in
all of your catalogs to 'world', but this is not secure. If you can,
you should run this as root, or su to root and do:

	chmod 4755 $cginame

EOF
				$ask = prompt("Continue? ", 'n');
				unless($Vend::MakeCat::Force) {
					exit 2 unless is_yes($ask);
				}
			}

			chmod 04755, $cginame
				or warn "\nCouldn't set permissions on $cginame: $!\n";
		}

		print "done.\n";

		if($CGIwrap and $isroot) {
			print <<EOF;
Since you selected the SUEXEC/CGIwrap option and are root, we aren't sure
which user and group you intended to own the link program. We have selected
the catalog user's UID/GID ($catuid/$catgid), but this may not match your
server definition. If you get a server error, change the ownership to its
proper value and ensure that the SUID bit is turned off on the link
program ($cginame).

EOF
			chown($catuid, $catgid, $cginame) or die "\nchown $cginame: $!\n";
			prompt("Press <ENTER> to continue....");
		}
	}

	my $chg_to_catuser = sub {
							next if -l $_;
							$File::Find::prune = 1 if -f _;
							my $mode = (stat(_))[2];
							$mode |= 044;
							$mode |= 011 if -d $_;
							chmod( $mode, $_)
								or die "\nchmod $_ to $mode: $!\n";
							chown($catuid, $catgid, $_)
								or die "\nchown $_: $!\n";
							
						 };

	unless ($Conf{sharedir} eq 'NONE') {
		print do_msg("Copying share/ files to $Conf{relocate}$Conf{sharedir}");
		my $oldpwd = cwd();
		my @sharedirs;
		eval {
			chdir "$Conf{relocate}$Conf{vendroot}"
				or die "\nchdir $Conf{relocate}$Conf{vendroot}: $!\n";
			# remember directories so we can chown below
			chdir "share" or die "error.\nchdir 'share': $!\n";
			map { push @sharedirs, $_ if -d $_ } glob('*');
			chdir "..";
			copy_dir("share", "$Conf{relocate}$Conf{sharedir}") or die;
		};
		if (! @sharedirs) {
			print "none found.\n";
		}
		elsif ($@) {
			print "error.\nError installing share/ files: $@\n";
		} else {
			File::Find::find(
				$chg_to_catuser,
				map { "$Conf{relocate}$Conf{sharedir}/$_" } @sharedirs
			) if $isroot;
			print "done.\n";
		}
		chdir $oldpwd;
	}

	my $ok = 0;
	unless($Conf{samplehtml} eq 'NONE') {
		print do_msg("Moving HTML files to $Conf{samplehtml}");
		eval {
			chdir 'html' or ++$ok and die "\nchdir html: $!\n";
			copy_current_to_dir("$Conf{relocate}$Conf{samplehtml}");
			chdir '..';
			File::Path::rmtree('html'); 
		};

		if($@ and !$ok) {
			die "\nCouldn't move HTML files to $Conf{relocate}$Conf{samplehtml}: $@\n";
		}
		elsif ($ok) {
			warn "\nHTML dir copy error: $!\nTrying to continue.\n";
		}
		else {
			File::Find::find( $chg_to_catuser, "$Conf{relocate}$Conf{samplehtml}")
				if $isroot;
		}

		print "done.\n";
	}

	$ok = 0;
	unless($Conf{imagedir} eq 'NONE') {
		print do_msg("Moving image files to $Conf{imagedir}");
		eval {
			chdir 'images' or ++$ok and die "chdir images: $!\n";
			copy_current_to_dir("$Conf{relocate}$Conf{imagedir}");
			chdir '..';
			File::Path::rmtree('images');
		};
			
		if($@ and !$ok) {
			die "\nCouldn't move image files $Conf{relocate}$Conf{imagedir}: $@\n";
		}   
		elsif ($ok) {
			warn "\nImage dir copy error: $!\nTrying to continue.\n";
		}
		else {
			File::Find::find($chg_to_catuser, "$Conf{relocate}$Conf{imagedir}")
				if $isroot;
		}
 
		print "done.\n";
	}

	chdir "$Conf{relocate}$Conf{vendroot}"
		or die "\nCouldn't change directory to $Conf{relocate}$Conf{vendroot}: $!\n";

	my $pidfile;
	for(qw! etc/interchange.pid etc/minivend.pid etc/interchange.pid !) {
		$pidfile = $_;
		last if -f $_;
	}

	PID: {
		local ($/);
		open(PID,"+<$pidfile") or last PID;

		# If we get lock we are not running
		unless($Windows) {
			lockfile(\*PID,1,0)  and last PID;
		}
		
		$pid = <PID>;
		$pid =~ /(\d+)/;
		$pid = $1;
	}

}

POSTCMD: {
	last POSTCMD unless -f "$dir/config/postcopy_commands";
	open(ADDL, "< $dir/config/postcopy_commands") 
		or last POSTCMD;
	print "\nFound additional system commands to run.\n\n";
	local ($/) = "";
	while(<ADDL>) {
		my $unprompted;
		s/\s+$//;
		s/__MVC_([A-Z0-9]+)(__)?/substitute($1,$2)/eg;
		my ($command, $prompt) = split /\n/, $_, 2;
		$command =~ s/^\s+//;
		$command =~ s/\s+$//;
		$command =~ s/^!// and $unprompted = 1;
		if($command =~ s/{\s*([A-Z0-9]+)(\s*\S.*?)?\s*}\s*//) {
			my $param = $1;
			my $test = $2;
			my $v = $Conf{lc $param};
			$v = "q{$v}";
			my $true;
			eval {
				$true = eval "$v$test";
			};
			next unless $true;
		}
		print "$prompt\n\n";
		print "Running: $command\n" if $unprompted;
		my $ans = $unprompted ? 'y' : prompt( qq{run "$command"? }, 'y' );
		if($ans =~ /^\s*y/i) {
			system $command;
			if($?) {
				print "\nCommand returned error code " . ($? >> 8) . ": $!\n";
			}
		}
		else {
			print "\nskipping '$command'\n";
		}
	}
	close ADDL;
}
	my $add;
	my $add_tcp;
	my $add_inet;

	umask(07) unless $Conf{noumask};

	$add = prefix('nocfg') ? 'n' : 'y';
	if ($Conf{catalogconf}) {
		$yes = prompt "Add catalog to $Conf{catalogconf}? ", $add;
	} else {
		$yes = prompt "Add catalog to $Global::ConfigFile? ", $add;
	}
	$add = prefix('norunning') ? 'n' : 'y';

	if($yes and $Inetmode) {
		$add_tcp = prompt "Add port $lp to TcpMap in interchange.cfg if necessary? ", $add;
		$add_tcp = is_yes($add_tcp);
		$add_inet = prompt "Set Interchange to run in INET mode if necessary? ", $add;
		$add_inet = is_yes($add_inet);
	}

	if($pid) {
		$add_to_running = prompt "Add catalog to server running on PID $pid? ", $add;
		$add_to_running = is_yes($add_to_running);
	}

	my $full = '';
	my $newcfgline;
	my $tcpmark;

	$newcfgline = sprintf "%-10s %s %s %s %s\n", 'Catalog',
				$catalog_name, $Conf{catroot}, $full . $Conf{cgiurl}, $Conf{aliases};

	if( is_yes($yes) ) {
		my ($newcfgline, $mark, @out);
		my $tmpfile;

		if ($Conf{catalogconf}) {
			$tmpfile = "$Conf{catalogconf}.$$";
			File::Copy::copy ($Conf{catalogconf}, $tmpfile)
					or die "\nCouldn't copy $Conf{catalogconf}: $!\n";
        } else {
        	$tmpfile= "$Global::ConfigFile.$$";
			if (-f $Global::ConfigFile) {
				File::Copy::copy ($Global::ConfigFile, $tmpfile)
					or die "\nCouldn't copy $Global::ConfigFile: $!\n";
			}	
			else {
				my @cf = ("$Global::ConfigFile.dist", "$Global::VendRoot/interchange.cfg.dist");
				my $cf;
				for(@cf) {
					$cf = $_ if -f $_;
				}

				File::Copy::copy($cf, $tmpfile)
					or die "\nCouldn't copy $cf: $!\n";
			}	
		}

		open(CFG, "< $tmpfile")
			or die "\nCouldn't open $tmpfile: $!\n";
		while(<CFG>) {
			$mark = $. if /^#?catalog\s+/i;
			print "\nDeleting old configuration $catalog_name.\n"
				if s/^(catalog\s+$catalog_name\s+)/#$1/io;
			$full = is_yes($1)
				if /^\s*fullurl\s+(.*)/i;
			if ($add_tcp and /^tcpmap\s+/i and $_ !~ /\b$lh:$lp\b/) {
				$tcpmark = /^tcpmap\s+[^<]+$/i ? $. : $. + 1;
				$tcpmark-- if $mark;
			}
			push @out, $_;
		}
		close CFG;

		if($full) {
			$full = $Conf{servername};
		}

		if ($Conf{catalogconf}) {
			open(NEWCFG, ">$Conf{catalogconf}")
				or die "\nCouldn't write $Conf{catalogconf}: $!\n";
		} else {
			open(NEWCFG, ">$Global::ConfigFile")
				or die "\nCouldn't write $Global::ConfigFile: $!\n";
		}

		$newcfgline = sprintf "%-13s %s %s %s %s\n", 'Catalog',
				$catalog_name, $Conf{catroot}, $full . $Conf{cgiurl}, $Conf{aliases};

		if($tcpmark) {
			$out[$tcpmark] =~ s/\s*$/ $lh:$lp -\n/;
		}

		if($add_inet) {
			my $found_inetmode;
			for(@out) {
				next unless /^\s*inet_mode\s+/i;
				$_ = "Inet_Mode Yes\n";
				$found_inetmode = 1;
				last;
			}
			if(! $found_inetmode) {
				push @out, "Inet_Mode Yes\n";
			}
		}

		if (defined $mark) {
			print NEWCFG @out[0..$mark-1];
			print NEWCFG $newcfgline;
			print NEWCFG @out[$mark..$#out];
		}
		else { 
			$newconfig = 1;
			print "\nNo catalog previously defined. Adding $catalog_name at top.\n";
			print NEWCFG $newcfgline;
			print NEWCFG @out;
		}

		close NEWCFG || die "close: $!\n";
		unlink $tmpfile;
		if($isroot) {
			chown ($mvuid, $mvgid, $Global::ConfigFile)
				or warn "Couldn't set ownership of '$Global::ConfigFile': $!\n";
		}
	}
	else {
		print <<EOF;
You will need to add the following line to your $Global::ConfigFile file
to activate the catalog.

$newcfgline

EOF
	}

	$newcfgline = sprintf "%-13s %s %s %s %s\n", 'Catalog',
				$catalog_name, $Conf{catroot}, $full . $Conf{cgiurl}, $Conf{aliases};

	if($add_to_running) {
		my $fn = 'etc/restart';
		open(RESTART, ">>$fn") or
				die "Couldn't write $fn to add catalog: $!\n";
		Vend::Util::lockfile(\*RESTART, 1, 1) 	or die "lock $fn: $!\n";
		printf RESTART $newcfgline;
		Vend::Util::unlockfile(\*RESTART) 		or die "unlock $fn: $!\n";
		close RESTART;
		if($isroot) {
			chown ($mvuid, $mvgid, $fn)
				or warn "\nCouldn't set ownership of $fn: $!\n";
		}
		unless ($Windows) {
			kill 'HUP', $pid;
			sleep 1;
		}
		$fn = 'etc/reconfig';
		open(RESTART, ">>$fn") or
				die "Couldn't write $fn to add catalog: $!\n";
		Vend::Util::lockfile(\*RESTART, 1, 1) 	or die "lock $fn: $!\n";
		printf RESTART $full . $Conf{cgiurl} . "\n";
		if($isroot) {
			chown ($mvuid, $mvgid, $fn)
				or warn "\nCouldn't set ownership of $fn: $!\n";
		}
		Vend::Util::unlockfile(\*RESTART) 		or die "unlock $fn: $!\n";
		close RESTART;
		unless ($Windows) {
			kill 'HUP', $pid;
		}
	}
	
    my $start_string = $> == 0
				? qq(su -c "$Conf{vendroot}/bin/interchange -r" $Conf{interchangeuser})
				: "$Conf{vendroot}/bin/interchange -r";

	print <<EOF;

Done with installation. If my reading of your input is correct, you
should be able to access the demo catalog with the following URL:

	$Conf{sampleurl}

In any case, you should get direct access at:

	http://$Conf{servername}$Conf{cgiurl}

That is, after you START or RESTART the Interchange server.  8-)
It is best done with:

	$start_string

EOF
	CHECKEXPIRE: {
		my $dbm;
		my $message;
		eval { require GDBM_File; $dbm = 1; };
		eval { require DB_File;   $dbm = 1; };

		if(! $Windows and $dbm) {

			print <<EOF;
For session expiration, you might want to place a line like this in your
crontab:

44 4 * * * $Conf{vendroot}/bin/expireall -r

It will prevent the session databases from getting too large.

EOF

		}
		else {
			print <<EOF;
Remember to expire your session databases on a regular basis (see
the documentation for details).

EOF
		}
	}

	print "Good luck with Interchange!\n" if defined $newconfig;

	if($Conf{'reference'}) {
		$Data::Dumper::Terse = 1;
		$Data::Dumper::Indent = 3;
		print STDOUT Vend::Util::uneval(\%Conf);
	}

=head1 NAME

makecat - Build an Interchange catalog from a template

=head1 SYNOPSIS

makecat [--options] name

=head1 VERSION

# $Id: makecat.PL,v 2.24 2004-05-09 20:56:21 mheins Exp $

=head1 INTRODUCTION

The makecat program builds a Interchange catalog from a template based on your
server configuration.  It interrogates for parameters like the directories to
use, URL to base the catalog in, HTTP server definitions, and file ownership.
It is self-documenting in that it asks verbose questions and gives relevant
examples.

On UNIX, if you want to check on something during the process you can
usually hit <CTRL-Z> to suspend the program and do something and then
type C<fg> to return to <makecat>. Also, if your input begins with
an exclamation mark (C<!>), it will be interpreted as a shell command.
An exclamation mark (C<!>) alone should drop you into a shell.

If you have the C<Term::ReadLine::Perl> and C<Term::ReadKey> modules
installed, the <UP> and <DOWN> arrows will cycle between suggested defaults;
and the following features will be in place:

    TAB       Completes file name
    <UP>      Cycle suggestion up
    <DOWN>    Cycle suggestion down
    <CTRL-P>  Cycle suggestion up
    <CTRL-N>  Cycle suggestion down
    <CTRL-B>  Go back one question (if possible)
    <CTRL-U>  Erase line
    <LEFT>    Command-line editing left
    <RIGHT>   Command-line editing left

Also, if you make a mistake at some stage of the interrogation, you can
often hit the <CTRL-B> key to return to the previous query. If you don't
have Term::ReadLine installed, then you can enter an at sign (C<@>) by
itself on the line.

=head1 OPTIONS 

usage: makecat [options] [catalogname]

The makecat program can build a catalog based completely on a command line
description. An example is in eg/makecat.sh.

There are just a few flag-based options:

=over 4

=item C<-F>

Force make of catalog with defaults supplied on command line.

=item C<-c>

Configuration file -- default is makecat.cfg in Interchange Confdir (etc) directory.

=item C<-l>

File to log to (default makecat.log)

=item C<-r>

Reconfigure defaults normally set in makecat.cfg; this is done automatically
the first time the program is run.
 
=back

The remainder of the options are supplied on the command line as named
parameters followed by an C<=> sign, followed by the value, i.e.

  --parameter=value

Normally, if C<makecat> supplies a default you might guess at that. It
is fairly intelligent if you have an Apache server and it has found the
httpd.conf file. If you are on a Netscape or other web server, it is
less likely to be right.

The options set at reconfig time, i.e. the first time the program is run:

=over 4

=item --basedir=directory

Base directory for catalogs. This defaults to C<catalogs> in the home
directory of the catalog user.

=item --cgibase=url_fragment

Base URL for link programs. This is normally either blank (your programs
are made with .cgi extension) or C</cgi-bin> (you have a CGI directory).

=item --documentroot=directory

The directory where HTML is based. This is the root directory of the
web server, i.e. DocumentRoot.

=item --interchangegroup=group

The default group files should be owned by.

=item --interchangeuser=username

The user ID which runs Interchange.

=item --serverconf=filename

Location of httpd.conf; you will be queried otherwise.

=item --vendroot=filename

Location of Interchange software.

=item --homedir=directory

Use instead of \$HOME to set defaults

=back

These are options which are required to be set for any catalog; the
default will often be correct if you have set the above options correctly.

=over 4

=item --catroot=directory

Directory where Interchange catalog files go. This is the base directory
for this catalog.

=item --cgidir=directory

The directory the CGI link should go to. This is the CGI directory; if
your CGI programs all end in C<.cgi> then this would normally be the same
as C<documentroot>; if you have a C<cgi bin> directory it should be used.

=item --servername=server

Name of server (www.whatever.domain). You can supply a port:

    www.foo.com:8080

or a username:

    www.foo.com/~bar

For testing on your local machine, just use C<localhost>.

=item --cgiurl=url_fragment

The path to the CGI link (no server name). For a catalog named
C<standard>, this would normally be one of:

    --cgiurl=/cgi-bin/standard

or 

    --cgiurl=/standard.cgi


=item --demotype=template

The template catalog. The default is <standard>.

=item --mailorderto=email

Email address to send orders

=item --catuser=username

The user files should be owned by (option only operative if C<root>).

=back

The rest of the parameters need not be supplied on the
command line as intelligent defaults can be derived from
the above parameters.

=over 4

=item --samplehtml=directory

The directory where template HTML goes.

=item --imagedir=directory

The directory where template images go.

=item --imageurl=url

The URL to prefix images with.

=item --sharedir=directory

The directory where shared admin images go.

=item --shareurl=url

The URL to prefix shared admin images with.

=item --nocfg

Don't add to interchange.cfg.

=item --nocopy

Don't actually copy the files, just test.

=item --norunning

Don't add to running server.

=item --reference

Return hash of config as string (sets C<-F>, no write). This is for
passing back to the makecat program in a autobuild environment.

=item --linkprogram=file

Use file as link program instead of vlink/tlink.

=item --linkmode=mode

UNIX or INET (link program vlink or tlink).

=item --sampleurl=url

URL to access HTML for catalog.

=item --noumask

Don't set umask to the value implied by mode.

=item --catalogconf=file

Use file as configuration file for catalog definitions. This option
has been designed for the use with Debian installations.

=back

=head1 DESCRIPTION

C<makecat> needs a template catalog to operate on. The I<Foundation
Store> demo template is distributed with Interchange. You can
also look for additional demo catalogs (mostly for ideas) at
http://www.icdevgroup.org/

B<IMPORTANT NOTE:> You only make a catalog once. All further configuration
is done by editing the files within the I<catalog directory>.

A catalog template contains an image of a configured catalog. The best
way to see what the makecat program does is to configure the 'standard'
demo and then run a recursive C<diff> on the template and configured
catalog directories:

  diff -r interchange/standard catalogs/standard

You will see that the files are mostly the same, except that certain
macro strings have been replaced with the answers you gave to the script.
For example, if you answered C<www.mydomain.com> at the prompt
for server name, then you would see this difference in the catalog.cfg file:

    # template
    Variable SERVER_NAME  __MVC_SERVERNAME__

    # configured catalog
    Variable SERVER_NAME  www.mydomain.com

The macro string __MVC_SERVERNAME__ was substituted with the answer to
the question about server name.  In the same way, other variables are
substituted, and include (at least):

    MVC_BASEDIR      MVC_IMAGEDIR
    MVC_CATROOT      MVC_IMAGEURL
    MVC_CATUSER      MVC_MAILORDERTO
    MVC_CGIBASE      MVC_MINIVENDGROUP
    MVC_CGIDIR       MVC_MINIVENDUSER
    MVC_CGIURL       MVC_SAMPLEHTML
    MVC_DEMOTYPE     MVC_SAMPLEURL
    MVC_DOCUMENTROOT MVC_VENDROOT
    MVC_ENCRYPTOR

(Not all of these are present in the standard template, and
quite a few more may be defined.)  In fact, any environment variable that
is set and begins with MVC_ will be substituted for by the C<makecat>
script. So if you wanted to set up a configurable parameter to customize
the COMPANY variable in catalog.cfg, you could run a pre-qualifying
script that set the environment variable MVC_COMPANY and then place in
the catalog.cfg file:

    Variable   COMPANY   __MVC_COMPANY__

All files within a template directory are substituted for macros,
not just the catalog.cfg file. There are two special directories
named C<html> and C<images>. These will be recursively copied to
the directories defined as SampleHTML and ImageDir.

B<IMPORTANT NOTE:> The template directory is located in the Interchange
software directory, i.e. where C<interchange.cfg> resides. You normally do
not edit files in the template directory.  If you want to try creating
your own template, it is recommended that you name it something besides
standard and copy the C<standard> demo directory to it as a starting point.
Templates are normally placed in the Interchange base directory, but can
be located anywhere -- the script will prompt you for location if it
cannot find a template.

In addition to the standard parameters prompted for by Interchange, and
the standard catalog creation procedure, you may define four other
files in the C<config> directory of the template:

    additional_fields  -- file with more parameters for macro substitution
    additional_help    -- extended description for the additional_fields
    precopy_commands   -- commands passed to the system prior to catalog copy
    postcopy_commands  -- commands passed to the system after catalog copy

All files are paragraph-based; in other words, a blank line (with no spaces)
terminates the individual setting.

The I<additional_fields> file contains:

    PARAM
    The prompt. Set PARAM to?
    The default value of PARAM

This would cause a question during makecat:

    The prompt. Set PARAM to?.....[The default value of PARAM]

If the I<additional_help> file is present, you can give additional
instructions for PARAM.

    PARAM
    These are additional instructions for PARAM, and they
    may span multiple lines up to the first blank line.

The prompt would now be:

    These are additional instructions for PARAM, and they
    may span multiple lines up to the first blank line.

    The prompt. Set PARAM to?.....[The default value of PARAM]

If the file I<config/precopy_commands> exists, it will be read as
a command followed by the prompt/help value.

    mysqladmin create __MVC_CATALOGNAME__
    We need to create an SQL database for your Interchange
    database tables.
     
This will cause the prompt:

    We need to create an SQL database for your Interchange
    database tables.
     
    Run command "mysqladmin create test_standard"?

If the response is "y" or "yes", then the command will be run
by passing it through the Perl system() function. As with any
of the additional configuration files, MVC_PARAM macro substitution
is done on the command and help. Obviously you must have proper
permissions for the command.

The file I<config/postcopy_commands> is exactly the same as I<precopy_commands>
except you are prompted I<after> the catalog files are copied and
macro substitution is performed on all files.

=head1 ABOUT INTERCHANGE IN GENERAL

Interchange has many, many, functions and features; they are too numerous
to describe in this venue. Complete information can be found at
its web site:

        http://www.icdevgroup.org/

Interchange requires Perl 5.6.0 or higher; more information on Perl can
be seen at:

        http://www.perl.com/

=head1 SEE ALSO

interchange(1)

=head1 LICENSE

Interchange comes with ABSOLUTELY NO WARRANTY. This is free software, and
you are welcome to redistribute and modify it under the terms of the
GNU General Public License.

=head1 COPYRIGHT

Copyright 2002-2003 Interchange Development Group.
Copyright 1995-2002, Red Hat, Inc.
All rights reserved except as in the license.

=cut

=head1 AUTHOR

Mike Heins, <mike@perusion.com>. Please do not contact the author for
direct help with the system. Use the Interchange mail list:

    interchange-users

Information on subscribing to the list, and general information and
documentation for Interchange is at:

    http://www.icdevgroup.org/

=cut

__END__

[catalog standard]
basedir         =
catroot         =
catuser         =
cgibase         =
cgibin          =
cgidir          =
cgiurl          =
demotype        = standard
documentroot    =
imagedir        =
imageurl        =
mailorderto     =
interchangegroup=
interchangeuser =
samplehtml      =
sampleurl       =
servername      =
vendroot        =

[base]
permtype=
basedir=
cgidir=
cgibase=
documentroot=
sharedir=
shareurl=
interchangegroup=
interchangeuser=
serverconf=
servername=
vendroot=
linkmode=

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#
# DO NOT EDIT BELOW HERE
#
# These are global parameters used by the program
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

[global]
# 
# All params allowed
#
params=<<EOF
aliases
basedir
catroot
catuser
cgibase
cgibin
cgidir
cgiurl
demotype
documentroot
imagedir
imageurl
linkmode
mailorderto
interchangegroup
interchangeuser
samplehtml
sampleurl
serverconf
servername
sharedir
shareurl
vendroot
EOF

catparams=<<EOF
aliases
catroot
catuser
cgidir
cgiurl
demotype
documentroot
imagedir
imageurl
mailorderto
interchangegroup
interchangeuser
samplehtml
sampleurl
servername
EOF

# 
# Default (base) parameters to ask about, in order
#
askbase=<<EOF
cgidir
cgibase
documentroot
sharedir
shareurl
vendroot
basedir
interchangeuser
linkmode
EOF

# 
# Catalog parameters to ask about, in order
#
askconfig=<<EOF
demotype
permtype
interchangeuser
catuser
interchangegroup
mailorderto
catroot
cgidir
cgiurl
aliases
documentroot
samplehtml
imagedir
imageurl
EOF

######## END GLOBAL SECTION ########

# Simple test to make sure legal for config file
[legalconfig]
aliases=1
cgidir=1
cgiurl=1
catuser=1
demotype=1
imagedir=1
imageurl=1
mailorderto=1
interchangeuser=1
interchangegroup=1
permtype=1
samplehtml=1
sampleurl=1
servername=1
catroot=1

# Simple test to make sure legal for base file
[legalbase]
basedir=1
cgidir=1
cgibase=1
documentroot=1
interchangegroup=1
interchangeuser=1
serverconf=1
servername=1
sharedir=1
shareurl=1
vendroot=1
linkmode=1
