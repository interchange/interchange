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

$VERSION = '4.5.8';

# See if we have the CPAN module
my $Cpan = 0;
my $CpanInit;
eval { 	
		die if $^O =~ /win32/i;
		unless( -f ".cpan.tried") {
			open TMP, ">.cpan.tried" and close TMP;
			require CPAN::Config;
			require CPAN;
			import CPAN;
		}
		unlink ".cpan.tried";
};
unless($@) {
	$Cpan = 1;
}

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
elsif ($Cpan) {
	push @mods_to_get, 'Term::ReadKey', 'Term::ReadLine::Perl';
}

my $term;
if($TermRead) {
	$term = new Term::ReadLine 'MakeFile';
	$Prompt_sub = sub {
		my($prompt, $default) = @_;
		$prompt .= "[$default] "
			if defined $default && !$ENV{PERL_RL};
		return $term->readline($prompt, $default);
	};
}

my $Windows = $^O =~ /win32/i ? 1 : 0;

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
 
  Copyright (C) 1996-2000 Akopia, Inc. <info\@akopia.com>

 Interchange is free under the terms of the GNU General Public License.

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

sub cpan_get {
	my($module, $libdir, $prompt) = @_;
	
	print <<EOF unless defined $CpanInit;

Since you have the CPAN module installed and initialized,
we can go and get optional modules that help Interchange work a
bit better and faster. At least we can if you are connected
to the Internet and have one of the following on your machine:

		Perl LWP libraries
		Perl Net::FTP library
		ncftp (a nice FTP program)
		lynx  (the text-based web browser)

In case you were wondering, CPAN is a worldwide network of
over 40 FTP sites which maintain the latest Perl software.
If you don't know a URL to use, you can try:

	ftp://ftp.freesoftware.com/pub/perl/CPAN
	ftp://ftp.funet.fi/pub/languages/perl/CPAN

If you have never used CPAN before, you may want to reply NO.
Interchange should work anyway -- it just won't be quite as easy
to build the demo catalogs.

If you have errors during the process, don't worry. Either
just continue on or stop the program and try again, replying
No when prompted for CPAN.

EOF
	$prompt = "Get $module module? [yes]" unless defined $prompt;
	my $ask = my_prompt($prompt);
	return undef if $ask =~ /^\s*n/i;
	
	return undef unless defined $CPAN::Config;
	$CPAN::Config->{makepl_arg} = "INSTALLPRIVLIB=$libdir/lib INSTALLARCHLIB=$libdir/lib INSTALLSITELIB=$libdir/lib INSTALLMAN1DIR=none INSTALLMAN3DIR=none INSTALLSITEARCH=$libdir/lib INSTALLDIRS=perl";
	$CPAN::Config->{keep_source_where} = "$libdir/src"
		unless -w $CPAN::Config->{keep_source_where};
	$CPAN::Config->{cpan_home} = "$libdir/src"
		unless -w $CPAN::Config->{cpan_home};
	$CPAN::Config->{build_dir} = "$libdir/src"
		unless -w $CPAN::Config->{build_dir};
	return CPAN::install($module);
}

sub extra_libs {

	my ($realdir) = @_;
	# Do the extra library checks

	my @extra_lib_dirs;
	my @extra_lib_files;
	# We will use our own version of File::CounterFile always
	push @extra_lib_dirs, 'File';
	push @extra_lib_files, 'File/CounterFile.pm';

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
		require Storable;
	};
	unless ($@) {
				my $def = 's';
		        print <<EOF;

You appear to have Raphael Manfredi's Storable module installed.

This module will significantly improve your DBM storage and
fetch times.

You can reply one of:

		n -- Don't use Storable
		s -- Use for sessions only, won't break existing databases
		y -- Use for both sessions and databases

It is recommended that all installations reply S unless there is a need for
improved performance in Interchange DBM databases.

If you reply YES and you use any GDBM or DB_File databases
they will NEED TO BE REMADE for ALL CATALOGS using this
Interchange server instance.
EOF

		if($ENV{MINIVEND_STORABLE_DB} || -f "$realdir/_db_storable" || -f "_db_storable") {
			$def = 'y';
		}
		elsif($ENV{MINIVEND_STORABLE} || -f "$realdir/_session_storable" || -f "_session_storable") {
			$def = 's';
		}
		my $ask = my_prompt("Use Storable module? (y/n/s) ", $def);
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
    my %X;
#warn "Got to initialize\n";
    $X{INSTALLDIRS}     = "perl";
	$X{EXE_FILES}  = [qw(
							scripts/compile_link
							scripts/config_prog
							scripts/configdump
							scripts/dump
							scripts/expire
							scripts/expireall
							scripts/localize
							scripts/makecat
							scripts/interchange
							scripts/offline
							scripts/restart
							scripts/update
						)];
	$X{PL_FILES}  = {qw(
							scripts/compile_link.PL scripts/compile_link
							scripts/config_prog.PL scripts/config_prog
							scripts/configdump.PL  scripts/configdump
							scripts/dump.PL        scripts/dump
							scripts/expire.PL      scripts/expire
							scripts/expireall.PL   scripts/expireall
							scripts/localize.PL    scripts/localize
							scripts/makecat.PL     scripts/makecat
							scripts/interchange.PL    scripts/interchange
							scripts/offline.PL     scripts/offline
							scripts/restart.PL     scripts/restart
							scripts/update.PL      scripts/update
						)};

	if(! $MV::Default{force} and ! $MV::Default{PREFIX}) {
		if($> == 0) {
			$MV::Default{PREFIX} = '/usr/local/interchange';
		}
		else {
			$MV::Default{PREFIX} = "$ENV{HOME}/interchange";
		}
	}
	if($MV::Default{rpmbuilddir} or $MV::Default{RPMBUILDDIR}) {
		$X{RPMBUILDDIR} = $MV::Default{rpmbuilddir} || $MV::Default{RPMBUILDDIR};
		$MV::Default{RPMBUILDDIR} = $X{RPMBUILDDIR};
	}

	return %X if $MV::Default{nocopy};

    my $uid = $MV::Default{INTERCHANGE_USER};
    if(-f "_uid") {
        open UID, '_uid'
            or die "Cannot read _uid file: $!\n";
        chomp($uid = <UID>);
        close UID;
    }

#warn "Got past open UID file , uid=$uid user=$> Windows=$Windows\n";

	GETUID: {
		if($> == 0 and ! $MV::Default{INTERCHANGE_USER} and ! $Windows) {
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
		elsif (! $Windows) {
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

	if(! $MV::Default{final}) {
		&copyright_prompt();

		# don't suggest install target same as software source directory
		$MV::Default{PREFIX} = '' if
			$MV::Default{PREFIX} =~ /^\Q$origdir/;

		{
			$realdir = my_prompt(
								"Where is your Interchange to be installed? ",
								$MV::Default{PREFIX},
								);
			if ($realdir =~ /^\s*\Q$origdir/) {
				warn "Can't install in software source directory $realdir,$origdir!\n";
				redo;
			}
		}
		print "\n";
		$realdir =~ s:[\\/]\s*$::;
		$realdir =~ s:^\s*::;
		$MV::Default{final} = $realdir if $Windows;
	}
	else {
		$MV::Default{final} =~ s:[\\/]\s*$::;
		$MV::Default{final} =~ s:^\s*::;
		$realdir = $MV::Default{final};
	}

	die "Can't install in software source directory! $realdir,$origdir,$'\n" if
		! $MV::Default{force} && $realdir =~ /^\Q$origdir/;

#warn "Got past realdir prompt\n" ; #if $X{RPMBUILDDIR};

	$X{INSTALLSCRIPT}	= "$realdir/bin";
	$X{INSTALLBIN}		= "$realdir/bin";
	$X{INSTALLARCHLIB}	= "$realdir";
	$X{INSTALLPRIVLIB}	= "$realdir/lib";
	if(! $MV::Default{final}) {
		$X{INSTALLMAN1DIR}	= "$realdir/doc"
			if ! $MV::Default{INSTALLMAN1DIR};
		$X{INSTALLMAN3DIR}	= "$realdir/doc"
			if ! $MV::Default{INSTALLMAN3DIR};
	}

	if (! -f 'pod/mvtags.pod') {
		chdir 'lib'
			or die "Cannot chdir to ./lib: $!\n";
		system("$^X Vend/Tagref.pm > ../pod/mvtags.pod");
		chdir '..'
			or die "Cannot chdir back to ..: $!\n";
	}
	my @re_link  = qw( interchange bin/minivend );
	my @re_dir  = qw( simple/download );
	my @re_copy = qw(	
						../pod/mvtags.pod simple/download/mvtags.pod
						../pod/mvdocs.pod simple/download/mvdocs.pod
						../pod/mvfaq.pod simple/download/mvfaq.pod
						);

#warn "Got past mvtags build\n" ; #if $X{RPMBUILDDIR};

	if($Windows) {
		mk_initp(\%X);
		my ($in, $out);
		my $ref = delete $X{PL_FILES};
		if(! -d 'bin') {
			File::Path::mkpath('bin');
		}
		my (@f);
		while ( ($in, $out) = each %$ref) {
			system "$^X $in";
			if($?) {
				die "Error making $in into $out: $!\n";
			}
			my $targ = $out;
			$targ =~ s:.*/::;
			File::Copy::copy($out, 'bin');
			push @f, "bin/$targ";
			system "pl2bat.bat $out";
			if($?) {
				warn "PL2BAT did not succeed for $out.\n";
			}
			else {
				File::Copy::copy("$out.bat", 'bin');
				push @f, "bin/$targ.bat";
			}
		}
		# Check for extra needed libraries
		extra_libs($realdir);
		my $wanted = sub {
				return unless -f $_;
				push @f, $File::Find::name;
		};
		File::Find::find($wanted, 'lib');
		for (@f) {
			install_file('.', $realdir, $_);
		}
	}
#warn "Got past Windows stuff\n" ; #if $X{RPMBUILDDIR};
	if($MV::Default{final}) {
		$ = 0;
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

#warn "Got past install SHAREFILES\n" ; #if $X{RPMBUILDDIR};

		# build context-sensitive admin help files
		my $sourcedir = cwd();
		BUILD_HELP_HTML: {
			chdir "$realdir/share/akopia/ui/help" or last BUILD_HELP_HTML;
			local $/;
			open HELP_MAKE, "help_make.pl" or
				warn("Unimportant: Unable to open help_make.pl\n"), last BUILD_HELP_HTML;
			my $help_make = <HELP_MAKE>;
			close HELP_MAKE;
			print "Generating admin help HTML\n";
			eval $help_make;
			warn("Unimportant: Error generating admin help HTML\n") if $@;
		}
		chdir $sourcedir;

#warn "Got past install Helpfiles\n" ; #if $X{RPMBUILDDIR};

		# install dist/ files from MANIFEST
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
		chdir '..';
		if(@remove_old) {
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

		print <<EOF;

Your Interchange main software installation appears to have been successful.
You are now ready to cd to $realdir and run 'bin/makecat'
to set up your first catalog.

EOF
		exit;

	}


	MODCHECK: {
		eval {
				require Digest::MD5;
			};
		push(@mods_to_get, 'Digest::MD5') if $@ and $Cpan;
		eval {
				require SQL::Statement;
			};
		push(@mods_to_get, 'SQL::Statement') if $@ and $Cpan;
		eval {
				require Safe::Hole;
			};
		push(@mods_to_get, 'Safe::Hole') if $@ and $Cpan;
		eval {
				require MIME::Base64;
			};
		push(@mods_to_get, 'MIME::Base64') if $@ and $Cpan;
		eval {
				require URI::URL;
			};
		push(@mods_to_get, 'URI::URL') if $@ and $Cpan;
	}

	local($);
	$ = 0;

	MODGET: {
		last MODGET unless $Cpan;
		my $odir = cwd();
		unless (-d 'build') {
			mkdir('build', 0777)
				or die "Couldn't make build directory for CPAN: $!\n";
		}
		chdir 'build'
			or die "Couldn't chdir to build directory for CPAN: $!\n";
		my $mod;
		foreach $mod (@mods_to_get) {
			my $ok = eval { cpan_get($mod, $realdir)};
			if (! $@) {
				$CpanInit = 1;
				print "\n\n";
			}
			else {
				print "\a\n$mod get failed.\n\n";
			}
		}
		chdir $odir
			or die "Couldn't return to original dir $odir: $!\n";
	}

	# Check for extra needed libraries
	extra_libs($realdir);

	my @msgs;
	for(@mods_to_get) {
		eval {
			eval "require $_"
				or die "No $_ module available.";
		};
		if($@) {
			push @msgs, $@;
		}
	}
	if(@msgs) {
		die join "\n", @msgs, '', <<EOF;
These modules must be installed to run Interchange. Try:

	perl -MCPAN -e 'install Bundle::Interchange'

or use normal Perl procedures to install them.
EOF
	}
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

	my $new = <<'EOF';
VERBINST=0

mv_install ::
			$(PERL) Makefile.PL force final=$(INSTALLARCHLIB)

install :: all pure_install doc_install mv_install

EOF
	$new .= <<EOF;
rpm_move ::
		\$(PERL) Makefile.PL force=1 rpmbuilddir=$MV::Default{RPMBUILDDIR} final=\$(INSTALLARCHLIB)

rpm_build :: all pure_install doc_install rpm_move

EOF
	$_ = $self->MM::install;
	s/\ninstall :.*/$new/;
	$_;
}

	my %mv_specific = qw/
						PREFIX 1 FORCE 1 FINAL 1 RPMBUILDDIR 1 INTERCHANGE_USER 1
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

#	use Data::Dumper;
#	$Data::Dumper::Terse = $Data::Dumper::Indent = 2;
#	print "ARGV: " . Dumper(\@ARGV);
#	print "OPT: " . Dumper(\%MV::Default);

	@ARGV = grep ! $delete{$_}, @saveargs;

if($Windows) {
	&initialize;
}
else {
	WriteMakefile(
		NAME       => "Interchange",
		MAN3PODS => {
						'pod/mvdocs.pod' => 'blib/man3/mvdocs.8',
						'pod/mvtags.pod' => 'blib/man3/mvtags.8',
						'pod/mvfaq.pod' => 'blib/man3/mvfaq.8',
						},
		DISTNAME => "interchange",
		clean    => {
					FILES=> "lib/IniConf.pm _uid _db_storable _session_storable lib/File/CounterFile.pm scripts/initp.pl scripts/compile_link scripts/config_prog scripts/configdump scripts/dump scripts/expire scripts/localize scripts/expireall scripts/makecat scripts/interchange scripts/offline scripts/restart scripts/update dist/simple/download/mvdocs.pod dist/simple/download/mvtags.pod dist/simple/download/mvfaq.pod pod/mvtags.pod",
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
}
