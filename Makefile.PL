use ExtUtils::MakeMaker;
require ExtUtils::Install;

BEGIN {
	eval {
		require FindBin;
		chdir $FindBin::RealBin;
	};
}

use Config;

use File::Copy;
use File::Path;
use File::Basename;
use File::Find;
use Data::Dumper;
use Cwd;
require 5.005;

use strict;

use vars (qw($VERSION $DOWARN));

my $TermRead;
my $Prompt_sub;
my @mods_to_get;
my @remove_old;
my $Lock_troubles;

$VERSION = '5.3.0';

my @os_hints;
eval {
	# gets package 'mvhints'
	require 'hints.pl';
	@os_hints = mvhints::get_hints();
};

my @chown_files = qw/
						error.log
						etc
					/;

# Now we can use the libraries
use lib './lib';


my $origdir = cwd();

# See if we have Term::ReadLine::Perl
eval {
		require Term::ReadLine;
		require Term::ReadLine::Perl;
		require Term::ReadKey;
		$TermRead = 1;
};
unless($@) {
	$ENV{PERL_RL} = 'Perl';
}

if(! $ENV{MINIVEND_FORCE_THREADS} and $Config{usethreads} || $Config{useithreads} || $Config{use5005threads}) {
	die "Interchange will not work with a thread-enabled perl.\n";
}

my $term;
if($TermRead) {
	eval {
		$term = new Term::ReadLine 'MakeFile';
	};

	! $@ and $Prompt_sub = sub {
		my($prompt, $default) = @_;
		$prompt .= "[$default] "
			if defined $default && !$ENV{PERL_RL};
		return $term->readline($prompt, $default);
	};
}

sub compare_file {
	my($first,$second) = @_;
	return 0 unless -s $first == -s $second;
	local $/;
	open(FIRST, $first) or return undef;
	open(SECOND, $second) or (close FIRST and return undef);
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

sub get_rename {
	my ($bn, $extra) = @_;
	$bn =~ s:(.*/)::;
	my $dn = $1;
	$extra = '~' if ! $extra;
	return $dn . "/.$extra." . $bn;
}

sub install_file {
	my ($srcdir, $targdir, $filename) = @_;
	my $srcfile  = $srcdir . '/' . $filename;
	my $targfile = $targdir . '/' . $filename;
	my $mkdir = File::Basename::dirname($targfile);
	my $extra;
	my $perms;

	if(! -d $mkdir) {
		File::Path::mkpath($mkdir)
			or die "Couldn't make directory $mkdir: $!\n";
	}

	if (! -f $srcfile) {
		die "Source file $srcfile missing.\n";
	}
	else {
		$perms = (stat(_))[2] & 0777;
	}

	if( -f $targfile and ! compare_file($srcfile, $targfile) ) {
		open (GETVER, $targfile)
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
			push @remove_old, $rename;
			$extra .= '~';
			$rename = get_rename($targfile, $extra);
		}
		push @remove_old, $rename;
		rename $targfile, $rename
			or die "Couldn't rename $targfile to $rename: $!\n";
	}

	File::Copy::copy($srcfile, $targfile)
		or die "Copy of $srcfile to $targfile failed: $!\n";
	chmod $perms, $targfile;

}

sub copyright_prompt {

	print <<EOF;

 Interchange V$VERSION
 
 Copyright (C) 2002-2004 Interchange Development Group.
 Copyright (C) 1996-2002 Red Hat, Inc.
 Interchange is free under the terms of the GNU General Public License.

 http://www.icdevgroup.org/

EOF
}

sub my_prompt {
    return $_[1] if $MV::Default{force};
    return &$Prompt_sub(@_)
        if defined $Prompt_sub;
    my($pr) = shift || '? ';
    my($def) = shift;
    my($ans);

    print $pr;
    print "[$def] " if $def;
    chomp($ans = <STDIN>);
    $ans ? $ans : $def;
}


sub extra_libs {

	my ($realdir) = @_;
	# Do the extra library checks

	my @extra_lib_dirs;
	my @extra_lib_files;

	eval {
		require IniConf;
	};
	if ($@) {
		push @extra_lib_files, 'IniConf.pm';
	}

	eval {
		require HTML::Entities;
	};
	if ($@) {
		push @extra_lib_dirs, 'HTML';
		push @extra_lib_files, 'HTML/Entities.pm';
	}

	eval {
		require Business::UPS;
	};
	if ($@) {
		push @extra_lib_dirs, 'Business';
		push @extra_lib_files, 'Business/UPS.pm';
	}

	eval {
		require Tie::ShadowHash;
	};
	if ($@) {
		push @extra_lib_dirs, 'Tie';
		push @extra_lib_files, 'Tie/ShadowHash.pm';
	}

	eval {
		require Business::Fedex;
	};
	if ($@) {
		push @extra_lib_dirs, 'Business';
		push @extra_lib_files, 'Business/Fedex.pm';
	}

	eval {
		require Storable;
	};
	unless ($@) {
		my $def = 's';
        print <<EOF if $MV::Default{storable};

You appear to have Raphael Manfredi's Storable module installed.
This module will significantly improve your DBM storage and fetch times.

You can reply one of:

	n -- Don't use Storable
	s -- Use for sessions only, won't break existing databases
	y -- Use for both sessions and databases

It is recommended that all installations reply S unless there is a need for
improved performance in Interchange DBM databases.

If you reply YES and you use any GDBM or DB_File databases they will
NEED TO BE REMADE for ALL CATALOGS using this Interchange server instance.
EOF

		if($ENV{MINIVEND_STORABLE_DB} || -f "$realdir/_db_storable" || -f "_db_storable") {
			$def = 'y';
		}
		elsif($ENV{MINIVEND_STORABLE} || -f "$realdir/_session_storable" || -f "_session_storable") {
			$def = 's';
		}
		my $ask;
		$ask = $def;
		$ask = my_prompt("Use Storable module? (y/n/s) ", $def) 
			if $MV::Default{storable};
		if ($ask =~ /^\s*(y|d)/i) {
			open(TSTORABLE, ">_db_storable")
				or die "creat _db_storable: $!\n";
			print TSTORABLE "REMOVE THIS FILE TO STOP USING Storable\n";
			close TSTORABLE;
		}
		if ($ask =~ /^\s*(y|s)/i) {
			open(TSTORABLE, ">_session_storable")
				or die "creat _session_storable: $!\n";
			print TSTORABLE "REMOVE THIS FILE TO STOP USING Storable\n";
			close TSTORABLE;
		}
	}

	COPYEXTRA: {
		my $cpdir = '.';
		mkdir $cpdir, 0777 unless -d $cpdir;
		mkdir "$cpdir/lib", 0777 unless -d "$cpdir/lib";
		for(@extra_lib_dirs) {
			next if -d "$cpdir/lib/$_";
			mkdir "$cpdir/lib/$_", 0777 or die "mkdir $cpdir/lib/$_: $!\n";
		}
		for(@extra_lib_files) {
			File::Copy::copy ("extra/$_", "lib/$_")
				or die "Couldn't copy $_: $!\n";
		}
	}
}

sub mk_initp {
	my ($ref) = @_;
	local($Data::Dumper::Terse);
	$Data::Dumper::Terse = 1;
	open (INITP, ">scripts/initp.pl")
		or die "Can't write initp.pl: $!\n";
	print INITP '$MV::Self = ';
	print INITP Dumper($ref);
	print INITP ";\n1;";
	close INITP;
}

sub initialize {
#warn "Got to initialize\n";
	my @scripts = map { "scripts/$_" } qw(
		compile_link
		config_prog
		configdump
		dump
		expire
		expireall
		findtags
		ic_mod_perl
		interchange
		localize
		makecat
		offline
		restart
		update
	);
	my %X;
	$X{INSTALLDIRS}	= "perl";
	$X{EXE_FILES}	= [ @scripts ];
	$X{PL_FILES}	= { 'relocate.pl' => [ @scripts ] };

	$MV::Default{LSB} ||= $MV::Default{RPM};

	if(! $MV::Default{force} and ! $MV::Default{PREFIX}) {
		if($> == 0) {
			$MV::Default{PREFIX} = '/usr/local/interchange';
		}
		else {
			$MV::Default{PREFIX} = "$ENV{HOME}/interchange";
		}
	}
	if($MV::Default{LSB}) {
		if($> != 0) {
			die "Cannot install LSB (RPM-style) unless root.\n";
		}
		unlink '_uid';
		$MV::Default{PREFIX} = '/usr/lib/interchange';
		$MV::Default{INTERCHANGE_USER} = 'interch';
	}

	if($MV::Default{rpmbuilddir} or $MV::Default{RPMBUILDDIR}) {
		$X{RPMBUILDDIR} = $MV::Default{rpmbuilddir} || $MV::Default{RPMBUILDDIR};
		$MV::Default{RPMBUILDDIR} = $X{RPMBUILDDIR};
	}

	return \%X if $MV::Default{nocopy};

    my $uid = $MV::Default{INTERCHANGE_USER};
    if(-f "_uid") {
        open UID, '_uid'
            or die "Cannot read _uid file: $!\n";
        chomp($uid = <UID>);
        close UID;
    }

#warn "Got past open UID file , uid=$uid user=$>\n";

	GETUID: {
		if($> == 0 and ! $MV::Default{INTERCHANGE_USER}) {
			$uid = my_prompt(
				qq{Interchange cannot be run as root. Which user should run Interchange? },
				($uid || 'interch'),
			);
			my $name = getpwnam($uid);
			if(! $name) {
				my $ans = my_prompt("User name $uid doesn't exist. Use anyway? ", 'n');
				last GETUID if $ans =~ /^\s*y/i;
				redo GETUID;
			}
		}
		elsif ($uid = $MV::Default{INTERCHANGE_USER}) {
			# do nothing
		}
		else {
			eval {
				$uid = scalar getpwuid($>);
			};
		}
	}
#warn "Got past GETUID\n" ; #if $X{RPMBUILDDIR};
    if($uid) {
        open(UID, ">_uid")
            or die "Can't write uid file: $!\n";
        print UID "$uid";
        close UID;
    }

	for(@Config{
				  qw/
					  archlib
					  archlibexp
					  privlib
					  privlibexp
					  sitearch
					  sitearchexp
					  sitelib
					  sitelibexp
				  /
		})
	{
		die "Can't install in Perl library!\n" if $MV::Default{PREFIX} eq $_;
	}

	my $realdir;

	$origdir =~ s:[\\/]\s*$::;
	$origdir =~ s:^\s*::;

	if(! $MV::Default{final}) {
		&copyright_prompt();

		# don't suggest install target same as software source directory
		$MV::Default{PREFIX} = '' if
			$MV::Default{PREFIX} eq $origdir;

		PROMPTDIR: {
			if($MV::Default{LSB}) {
				$realdir = $MV::Default{PREFIX};
			}
			else {
				$realdir = my_prompt(
									"Where is your Interchange to be installed? ",
									$MV::Default{PREFIX},
									);
				$realdir =~ s:[\\/]\s*$::;
				$realdir =~ s:^\s*::;
				if ($realdir eq $origdir) {
					warn "Can't install in software source directory!\n";
					redo;
				}
			}
			print "\n";
		}
	}
	else {
		$MV::Default{final} =~ s:[\\/]\s*$::;
		$MV::Default{final} =~ s:^\s*::;
		$realdir = $MV::Default{final};
	}

	die "Can't install in software source directory!\n" if
		! $MV::Default{force} && $realdir eq $origdir;

#warn "Got past realdir prompt\n" ; #if $X{RPMBUILDDIR};

	$X{INSTALLSCRIPT}	= "$realdir/bin";
	$X{INSTALLBIN}		= "$realdir/bin";
	$X{INSTALLARCHLIB}	= "$realdir";
	$X{INSTALLPRIVLIB}	= "$realdir/lib";
	if(! $MV::Default{final}) {
		$X{INSTALLMAN1DIR}	= "$realdir/man"
			if ! $MV::Default{INSTALLMAN1DIR};
		$X{INSTALLMAN3DIR}	= "$realdir/man"
			if ! $MV::Default{INSTALLMAN3DIR};
	}

	my @re_link = qw();
	my @re_dir  = qw();
	my @re_copy = qw();

	my $upgrade;
	if($MV::Default{final}) {
		$^W = 0;
		for(glob "_*") {
			File::Copy::copy($_, $realdir);
		}
		open(MANI, "MANIFEST")
			or die "No MANIFEST?\n";
		my (@files) = <MANI>;
		close MANI;

#warn "Got past open MANIFEST\n" ; #if $X{RPMBUILDDIR};

		# install share/ files from MANIFEST
		chomp(my @sharefiles = grep m:^share/:, @files);
		install_file('.', $realdir, $_) for @sharefiles;
		# install code/ files from MANIFEST
		chomp(my @codefiles = grep m:^code/:, @files);
		install_file('.', $realdir, $_) for @codefiles;
		# create symbolic links for images used for
		# other languages either not yet translated
		# or without embedded text
		my @imgfiles = grep m:^share/interchange-5/en_US/:, @sharefiles;
		my @loc;
		@loc = map { s:.*/::; s/\.cfg$//; $_ } glob('dist/lib/UI/locales/*_*.cfg');
		my $cwd = cwd();
		my ($locale, $imgfile, $fname);
		chdir("$realdir/share/interchange-5")
			|| die "Couldn't enter directory $realdir/share/interchange-5: $!\n";

		for $locale (@loc) {
			unless (-d $locale) {
				mkdir ($locale, 0777)
					|| die "Couldn't create directory $realdir/share/interchange-5/$locale: $!\n";
			}
			for $imgfile (@imgfiles) {
				$fname = basename($imgfile);
				next if -f "$locale/$fname";
				symlink ("../en_US/$fname", "$locale/$fname")
					|| die "Couldn't create symlink $realdir/share/interchange-5/$locale/$fname: $!\n";
			}
		}
		chdir($cwd)
			|| die "Couldn't enter directory $cwd: $!\n";

#warn "Got past install SHAREFILES\n" ; #if $X{RPMBUILDDIR};

		# install dist/ files from MANIFEST
		print "Installing dist/ files\n";
		@files = grep m:^dist/:, @files;
		chomp(@files);
		@files = map { s:^dist/::; $_} @files;

		# New install_file routine
		chdir 'dist';
		for (@re_dir) {
			mkdir $_, 0777
				or @re_copy = ();
		}
		while ($_ = shift @re_copy ) {
			my $from = $_;
			my $to = shift @re_copy;
			push @files, $to;
			File::Copy::copy($from, $to);
		}
		for (@files) {
			$upgrade ||= -f "$realdir/$_";
			install_file('.', $realdir, $_);
		}
		chdir '..';

#warn "Got past install all files\n" ; #if $X{RPMBUILDDIR};

		for(@os_hints) {
			my ($condition, $routine) = @$_;
			unless (ref($condition) =~ /CODE/ and ref($routine) =~ /CODE/) {
				warn <<EOF;
OS hint condititon and routine must be code reference, is

	condition: $condition
	routine:   $routine

Skipping.
EOF
				next;
			}
			next unless $condition->();
			my $odir = cwd();
			chdir $realdir
				or die "Cannot chdir to $realdir: $!\n";
			$routine->();

		}
		while ($_ = shift @re_link ) {
			my $from = $_;
			my $to = shift @re_link;
			push @files, $to;
			my $odir = cwd();
			chdir $realdir
				or die "Cannot chdir to $realdir: $!\n";
			eval {
				symlink($from, $to);
			};
			chdir $odir;
		}
		if(-f "$realdir/_uid" and $> == 0) {
			open(UID, "$realdir/_uid")
				or die "Can't open uid file: $!\n";
			my $uid = <UID>;
			close UID;
			$MV::Default{INTERCHANGE_UID} = getpwnam($uid);
			$MV::Default{INTERCHANGE_GID} = getgrnam($uid);
			for(@chown_files) {
				chown	$MV::Default{INTERCHANGE_UID},
						$MV::Default{INTERCHANGE_GID},
						"$realdir/$_";
			}
		}
		if($MV::Default{LSB}) {
			my $d = cwd();
			print "Doing LSB install...\n";
			do './install_lsb.pl';
			print "Done with LSB install.\n";
		}
		if(@remove_old) {
			if($MV::Default{UNLINK}) {
				print "Removing old files....";
				my $odir = cwd();
				chdir $realdir
					or die "Cannot chdir to $realdir: $!\n";
print "Changed dir to realdir=$realdir.\n";
				unlink @remove_old;
				print "done.\n";
				chdir $odir
					or die "Cannot chdir to $odir: $!\n";
print "Changed dir to odir=$odir.\n";
			}
			else {
				my $msg = <<EOF;
The following old files were found, different from the installed versions.
You should check and remove them at the earliest opportunity.

EOF
				$msg .= join "\n\t", '', @remove_old;
				$msg .= <<EOF;


If you have not modified any Interchange usertags, software programs, or
libraries, it is usually safe to remove them, but you might copy them somewhere
just in case you forgot something you changed.
EOF
				print $msg;
			}
		}

		chdir '..';

		print <<EOF;

Your Interchange main software installation appears to have been successful.
EOF
		FINCHECK: {
			@mods_to_get = ();
			eval {
					require Digest::MD5;
				};
			push(@mods_to_get, 'Digest::MD5') if $@;
			eval {
					require Safe::Hole;
				};
			push(@mods_to_get, 'Safe::Hole') if $@;
			eval {
					require MIME::Base64;
				};
			push(@mods_to_get, 'MIME::Base64') if $@;
			eval {
					require Storable;
				};
			push(@mods_to_get, 'Storable') if $@;
			eval {
					require URI::URL;
				};
			push(@mods_to_get, 'URI::URL') if $@;
		}
		if(@mods_to_get) {
			my $mods = join "\n\t", @mods_to_get;
			
			if ($MV::Default{nocpaninstall}) {
				print <<EOF;
You do not appear to have all the required modules installed. You are missing:

	$mods

Please run src/cpan_local_install to install them.
EOF
  				exit ($MV::Default{force} ? 0 : 1);
			} else {
				print <<EOF;
You do not appear to have all the required modules installed. You are missing:

	$mods

Trying to install now.
EOF
			}

			chdir $realdir
				or die "Couldn't change directory to $realdir: $!\n";
			system $^X, 'src/cpan_local_install';
			eval {
				require Storable;
				open JUNK, ">_session_storable"
					and close JUNK;
			};
			eval {
				require Business::UPS;
			};
			if($@) {
				print "Retrying a couple of modules, just a sec...\n\n";
				require HTML::Tagset
					or
					system $^X, 'src/cpan_local_install', '-c', 'HTML::Tagset';
				require HTML::Parser
					or
					system $^X, 'src/cpan_local_install', '-c', 'HTML::Parser';
				system $^X, 'src/cpan_local_install', '-c', 'LWP::Simple';
				system $^X, 'src/cpan_local_install', '-c', 'Business::UPS';
			}
			system $^X, 'src/cpan_local_install', '-c';
		}
		if($upgrade) {
		print <<EOF;

Since this was an update, you are now ready to restart and ensure
your catalogs run as expected. You do NOT need to re-run makecat,
though you can always do that to make a new catalog. Never run
makecat on an existing catalog.

EOF
		}
		else {
		print <<EOF;

You are now ready to cd to $realdir and run 'bin/makecat'
to set up your first catalog.

EOF
		}
		exit;

	}

	# Check for extra needed libraries
	extra_libs($realdir);

	mk_initp(\%X);
	delete $X{RPMBUILDDIR};
    return \%X;
}

sub regularize {
	for (@_) {
		s/[\\]\n//g;
		s/\n\s+/ /g;
		s/\s+$//g;
	}
	wantarray ? @_ : $_[0];
}

sub MY::install {

	my $self = shift;
	local *install;
	sub dont_warn {
		\*install;
	}

	my $uidparm;

	if (-f "_uid") {
		if (open UID, '_uid') {
			chomp (my $uid = <UID>);
			close UID;
			$uidparm = "INTERCHANGE_USER=$uid";
		}
	}

	my @args = (
			'force',
			'nocpaninstall=$(NOCPANINSTALL)',
		);
	my @extra_args = ( qw/INTERCHANGE_USER LSB RPM UNLINK/ );
	for(@extra_args) {
		next unless $MV::Default{$_};
		push @args, "$_=$MV::Default{$_}";
	}
	push @args, 'final=$(INSTALLARCHLIB)';

	my $argstring = join " ", @args;

	my $new = <<EOF;
VERBINST=0

mv_install ::
			\$(PERL) Makefile.PL $argstring

install :: all pure_install mv_install

EOF
	$new .= <<EOF;
rpm_move ::
		\$(PERL) Makefile.PL force=1 rpmbuilddir=$MV::Default{RPMBUILDDIR} final=\$(INSTALLARCHLIB)

rpm_build :: all pure_install rpm_move

EOF
	$_ = $self->MM::install;
	s/\ninstall :.*/$new/;
	$_;
}

sub MY::postamble {
	return <<'EOF';
UIDIR=dist/lib/UI
UILCDIR=$(UIDIR)/locales
UIMENUDIR=$(UIDIR)/pages/include/menus

localefiles:
	@for langfile in $(UILCDIR)/*_*.cfg; do \
		lang=`basename $$langfile .cfg`; \
		mv $$langfile $$langfile.old; \
		cat $(UILCDIR)/default.cfg >> $$langfile.old; \
		if ! $(INSTALLBIN)/localize -n -s -m $$langfile.old -u $(UIMENUDIR) -l $$lang `find $(UIDIR) -type f -not -empty -not -name '.#*'` > $$langfile; then \
		echo "Failed to generate locale file $$langfile"; \
		mv $$langfile.old $$langfile; \
		fi; \
	done
EOF
}

my %mv_specific = qw/
	FINAL            1
	FORCE            1
	INTERCHANGE_USER 1
	LSB              1
	PREFIX           1
	RPM              1
	RPMBUILDDIR      1
	STORABLE         1
	UNLINK           1
/;
my %delete;
use Getopt::Long;
my @saveargs = @ARGV;
my %optctl = (
	'junk'			=> sub { 1 },
	'<>'			=> sub {
							my ($arg) = @_;
	#warn "checking option $arg\n";
							my ($opt, $val);
							if($arg !~ /=/) {
								$opt = $arg;
								$val = 1;
							}
							else {
								($opt, $val) = split /=/, $arg, 2;
							}

							$delete{$arg} = 1 if $mv_specific{uc $opt};

							$MV::Default{$opt} = $val;
							return;
						},
);

my @options = ( qw/
	junk
	<>
/ );

Getopt::Long::config(qw/permute/);
GetOptions(\%optctl, @options)
	or die "Bad option get\n";

#use Data::Dumper;
#$Data::Dumper::Terse = $Data::Dumper::Indent = 2;
#print "ARGV: " . Dumper(\@ARGV);
#print "OPT: " . Dumper(\%MV::Default);

@ARGV = grep ! $delete{$_}, @saveargs;

WriteMakefile(
	NAME     => "Interchange",
	DISTNAME => "interchange",
	clean    => {
				FILES => "lib/IniConf.pm _uid _db_storable _session_storable lib/File/CounterFile.pm scripts/initp.pl scripts/compile_link scripts/config_prog scripts/configdump scripts/dump scripts/expire scripts/localize scripts/expireall scripts/makecat scripts/ic_mod_perl scripts/interchange scripts/offline scripts/restart scripts/update",
			   },

	dist     => {
					CI => "ci -l -t-Initial",
					SUFFIX   => ".gz",
					DIST_DEFAULT => 'all tardist',
					COMPRESS => "gzip -9f",
					ZIP_FLAGS => '-pr9',
				},
	VERSION_FROM => "scripts/interchange.PL",
	EXE_FILES  => [],
	CONFIGURE  => \&initialize,
);
