# Static.pm - Interchange static page routines
# 
# $Id: Static.pm,v 1.4.6.2 2001-01-20 20:02:30 heins Exp $
#
# Copyright (C) 1996-2000 Akopia, Inc. <info@akopia.com>
#
# This program was originally based on Vend 0.2
# Copyright 1995 by Andrew M. Wilcox <awilcox@world.std.com>
#
# Portions from Vend 0.3
# Copyright 1995 by Andrew M. Wilcox <awilcox@world.std.com>
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

package Vend::Misc::Static;

use strict;
use Vend::Util;
use Vend::Data;
use Vend::Scan;
use Vend::Interpolate;
use Vend::Page;
require File::Path;

# does message for page build
sub do_msg {
	my ($msg, $size) = @_;
	$size = 60 unless defined $size;
	my $len = length $msg;

	return "$msg.." if ($len + 2) >= $size;
	$msg .= '.' x ($size - $len);
	return $msg;
}

sub fake_scan {
	my($path) = @_;
	my ($key,$page);
	my $c = { mv_search_immediate => 1 };
	find_search_params($c,$path);
	return undef if $c->{mv_more_matches};
	::perform_search($c);
	$page = readin($CGI::values{mv_nextpage} || ::find_special_page('results'));
	return ::interpolate_html($page, 1);
}

# STATICPAGE
sub build_page {
	my($name,$dir,$check,$scan) = @_;
	my($base,$page);
	my $status = 1;

	Vend::Interpolate::reset_calc();
	eval {
		unless($scan) {
			$page = readin($name);
			# Try for on-the-fly if not there
			if(! defined $page) {
				$page = Vend::Interpolate::fly_page($name);
			}
		}
		else {
			$name =~ s!^$Vend::Cfg->{StaticPath}/!!;
			$page = readfile("$dir/$name", 0);
			my $string = $Vend::Cfg->{VendURL} . "/scan/" ;
			return 0 unless $page =~ m!$string!;
			$name =~ s!$Vend::Cfg->{StaticSuffix}$!!;
			$Vend::ForceBuild = 1;
		}

	    if (defined $page) {

			unless($check) {
			  open(BUILDPAGE, ">$dir/$name$Vend::Cfg->{StaticSuffix}")
				or die "Couldn't create file $dir/$name" .
						$Vend::Cfg->{StaticSuffix} . ": $!\n";
			}

			$page = cache_html($page) unless defined $scan;
			unless (defined $Vend::CachePage or defined $Vend::ForceBuild) {
				print "\cH" x 22 . "skipping, dynamic elements.\n";
				$status = 0;
			}
			elsif(! $check) {
				my @post = ();
				my $count = 0;
				my($search, $file, $newpage);
				my $string = $Vend::Cfg->{VendURL} . "/scan/" ;
				while($page =~ s!$string([^?"]+)[^"]*"!"__POST_" . $count++ . "__" . '"'!e) {
					undef $Vend::CachePage;
					undef $Vend::ForceBuild;
					$search = $1;
					print do_msg "\n>> found search $search", 61;
					push @post, $string . $search;
					if(defined $Vend::Found_scan{$search}) {
						pop @post;
						push @post, $Vend::Found_scan{$search};
						print "cached.";
					}
					elsif ($newpage = fake_scan($search) ) {
						$file = "scan" . ++$Vend::ScanCount .
										$Vend::Cfg->{StaticSuffix};
						pop @post;
						$Vend::Found_scan{$search}			=
										"$Vend::Cfg->{StaticPath}/$file";
						$Vend::Cfg->{StaticPage}{"scan/$search"} = $file;
						$Vend::Cfg->{StaticPage}{"scan/$search"}
							=~ s/$Vend::Cfg->{StaticSuffix}$//o;
						push @post, $Vend::Found_scan{$search};
						Vend::Util::writefile(">$dir/$file", $$newpage)
							or die "Couldn't write $dir/$file: $!\n";
						if($Vend::ScanName) {
							eval {
									$Vend::ScanName = "$dir/$Vend::ScanName" .
											$Vend::Cfg->{StaticSuffix}
										unless index($Vend::ScanName, '/') == 0;
									die "Not a symlink"
										unless ! -e $Vend::ScanName
											or -l $Vend::ScanName;
									unlink $Vend::ScanName;
									symlink "$dir/$file", "$Vend::ScanName";
							};
							if($@) {
								::logError ("Symlink problem $dir/$file --> $Vend::ScanName: $@");
							}
							else {
								print "\b\b\b\b\b\b\b\b\b\blinked....";
							}
							undef $Vend::ScanName;
						}
						print "save.";
					}
					else {
						print "skip.";
					}

				}
				if(@post) {
					$page =~ s/__POST_(\d+)__/$post[$1]/g;
					print "\n";
				}
			}
			undef $Vend::CachePage;
			undef $Vend::ForceBuild;

			return $status if $check;
	    	print BUILDPAGE $page;
			close BUILDPAGE;
	    }
		else {
			print "\cH" x 20 . "skipping, page not found.\n";
			$status = 0;
		}
	};
	if($@) {
		$status = 0;
		::logError("build_page died: $@");
	}
	return $status;

}

# Build a static page tree from the database
# The session is faked, but all other operations
# should work the same.
sub build_all {
	my($catalog,$outdir) = @_;
	my ($g, $sub, $p, $spec, $key, $val);

	print "doing static page build\n" unless $Vend::Quiet;
	undef %Vend::Found_scan;
	$Vend::ScanCount = 0;

	$Vend::BuildingPages = 1;

	if ($@) {
		my $msg = $@;
		print "\n$msg\n\a$g->{'name'}: error building pages. Skipping.\n";
		::logGlobal( { level => 'debug' }, <<EOF);
$g->{'name'}: Page build error. Skipping.
$msg
EOF
	}
	my(@files);
	for(keys %Global::Catalog) {
		next unless $Global::Catalog{$_}->{'name'} eq $catalog;
		$g = $Global::Catalog{$_}->{'script'};
	}
	die "$catalog: no such catalog!\n"
		unless defined $g;
	$Vend::Cfg = $Global::Selector{$g};

	unless($Vend::Cfg->{StaticDir}) {
		print <<EOF;

Skipping static page build for $catalog, StaticDir not set.
EOF
		return;
	}
		
	my %build;
	my $build_list = 0;

	$::Variable = $Vend::Cfg->{Variable};
	chdir $Vend::Cfg->{VendRoot} 
		or die "Couldn't change to $Vend::Cfg{VendRoot}: $!\n";
	$Vend::Cfg->{ReadPermission} = 'world';
	::set_file_permissions();
	umask $Vend::Cfg->{Umask};

	$spec = $Vend::BuildSpec || $Vend::Cfg->{StaticPattern} || '';
	CHECKSPEC: {
		my $test = 'NevVAIRBbe';
		eval { $test =~ s:^/tmp/whatever/$spec::; };
		die "Bad -files spec '$spec'\n" if $@;
	}
	@Vend::BuildSpec = keys %{$Vend::Cfg->{StaticPage}};
	if(@Vend::BuildSpec) {
		%build = map { ($_,1) } @Vend::BuildSpec;
		$build_list = 1;
	}

	my $all = $Vend::Cfg->{StaticAll};
	$build_list = 0 if $all;

	my $basedir = $Vend::Cfg->{PageDir};

	my @build_file;

	BUILDFILE: {
	if(-f "$basedir/.build" and -s _) {
		print "Building from files listed in .build file.\n";
		$build_list = 1;
		$all = 0;
		open(BUILD, "< $basedir/.build")
			or die "Couldn't open build spec $basedir/.build: $!\n";
		my $suf = $Vend::Cfg->{StaticSuffix};
		while(<BUILD>) {
			next if /^\s*#/;
			chomp;
			print;
			$_ .= $suf unless /$suf$/;
			unless (-f "$basedir/$_") {
				print "...flypage?...";
			}
			s/($suf)?\s*$//o;
			$build{$_} = 1;
			push @build_file, $_;
			print "...accepted.\n";
		}
		close BUILD;
	}
	elsif ( -f "$basedir/.build_spec" and -s _) {
		require File::Copy;
		File::Copy::copy("$basedir/.build_spec","$basedir/.build");
		redo BUILDFILE;
	}
	}

	return unless ($all or $build_list or scalar keys %{$Vend::Cfg->{StaticPage}});

	# do some basic checks to make sure we don't clobber
	# anything with a value of '/', and have an
	# absolute file path
	$outdir = $outdir || $Vend::Cfg->{StaticDir} || 'static';

	$outdir =~ s:/+$::;
	die "No output directory specified.\n" unless $outdir;
	$outdir = "$Vend::Cfg->{VendRoot}/$outdir"
		unless $outdir =~ m:^/:;

	if($Vend::Cfg->{ClearCache}) {
		print do_msg("Clearing output directory $outdir");
		-d $outdir && File::Path::rmtree($outdir)
			or die "Couldn't clear output directory $outdir: $!\n";
		print "done.\n"
	}

	unless(-d $outdir) {
		! -f $outdir
			or die "Output directory '$outdir' is a file. Abort.\n";
		print do_msg("Making output directory $outdir");
		File::Path::mkpath ($outdir)
			or die "Couldn't make output directory $outdir: $!\n";
		print "done.\n"
	}

	open_database(1);
	$Vend::SessionID = 'BUILD';
	$Vend::SessionName = 'BUILD:localhost';
	Vend::Session::init_session();
	if($Vend::Cfg->{StaticDBM}) {
		for(glob("$Vend::Cfg->{StaticDBM}.gdbm $Vend::Cfg->{StaticDBM}.db")) {
			unlink $_;
		}
	}
	unlink "$basedir/.static" if $Vend::Cfg->{StaticDBM};
	$CGI::cookie = $Vend::Cookie = "MV_SESSION_ID=building:local.host";
	require File::Find or die "No standard Perl library File::Find!\n";
	$sub = sub {
					my $name = $File::Find::name;
					die "Bad file name $name\n"
						unless $name =~ s:^$basedir/?::;

					if ($spec) {
						return unless $name =~ m!^$spec!o;
					}

					if (-d $File::Find::name) {
						die "$outdir/$name is a file, not a dir.\n"
							if -f "$outdir/$name";
						($File::Find::prune = 1, return)
							if defined $Vend::Cfg->{NoCache}->{$name};
						return if -d "$outdir/$name";
						mkdir ("$outdir/$name", 0777)
							or die "Couldn't make dir $outdir/$name: $!\n";
						return;
					}
					return unless $name =~ s/$Vend::Cfg->{StaticSuffix}$//o;
					return if defined $Vend::Cfg->{NoCache}->{$name};

					if ($build_list) {
						return unless defined $build{$name};
					}

					push @files, $name;
			};
	# Don't find recursive if listed in file

	unless (@build_file) {
		print do_msg("Finding files...");
		File::Find::find($sub, $Vend::Cfg->{PageDir});
		print "done.\n";
	}
	else {
		@files = @build_file;
		$all = 1;
	}
	
	chdir $Vend::Cfg->{VendRoot} 
		or die "Couldn't change to $Vend::Cfg->{VendRoot}: $!\n";

	$Vend::Session->{pageCount} = -1;
	local($^W) = 0;

	my $static;

	foreach $key (@files) {
		print do_msg("Checking page $key ...");
		$Vend::Cfg->{StaticPage}->{$key} = '' if $all;
		$static = build_page($key,$outdir, 1);
		unless ($static) {
			$build{$key} = delete $Vend::Cfg->{StaticPage}->{$key};
			$key = '';
			next;
		}
		print "done.\n";
	}

	FLYCHECK: {
		last FLYCHECK unless $Vend::Cfg->{StaticFly};
		last FLYCHECK if @build_file;
	  foreach $p (@Vend::Productbase) {
		$p = database_ref($p);
		while( ($key,$val) = $p->each_record() ) {
			next if $build_list && ! defined $build{$key};
			next unless $key =~ m{^$spec}o;
			$Vend::Cfg->{StaticPage}->{$key} = '' if $all;
			print do_msg("Checking part number $key");
			build_page($key,$outdir, 1)
				or (delete($Vend::Cfg->{StaticPage}->{$key}), next);
			print "done.\n";
		}
	  }
	}

	foreach $key (@files) {
		next unless $key;
		print do_msg("Building page $key ...");
		build_page($key,$outdir)
			or ( delete($Vend::Cfg->{StaticPage}->{$key}), next);
		delete $build{$key} if defined $build{$key};
		$Vend::Session->{pageCount} = -1;
		print "done.\n";
	}

	FLY: {
	  last FLY unless $Vend::Cfg->{StaticFly};
	  last FLY if @build_file;
	  foreach $p (@Vend::Productbase) {
		$p = database_ref($p);
		while( ($key,$val) = $p->each_record() ) {
			next unless defined $Vend::Cfg->{StaticPage}->{$key};
			print do_msg("Building part number $key");
			build_page($key,$outdir)
				or ( print "skipped.\n" and delete($Vend::Cfg->{StaticPage}->{$key}), next);
			$Vend::Session->{pageCount} = -1;
			print "done.\n";
		}
	  }
	}
	open STATICPAGE, ">$basedir/.static"
		or die "Couldn't write static page file: $!\n";

	::tie_static_dbm(1) if $Vend::Cfg->{StaticDBM};

	for(sort keys %{$Vend::Cfg->{StaticPage}}) {
		print STATICPAGE "$_\t$Vend::Cfg->{StaticPage}{$_}\n";
		$Vend::StaticDBM{$_} = $Vend::Cfg->{StaticPage}{$_}
			 if $Vend::Cfg->{StaticDBM};
	}
	close STATICPAGE;

	open UNBUILT, ">$basedir/.unbuilt"
		or die "Couldn't write build exception file: $!\n";
	for(sort keys %build) {
		print UNBUILT "$_\n";
	}
	close UNBUILT;
	unlink "$basedir/.build" if @build_file;
	unlink "$basedir/.static" if $Vend::Cfg->{StaticDBM};

	# Second level of search, no more than 1 is recommended, but
	# can be set by StaticDepth
	my $i;
	STATICDEPTH: 
	for ($i = 0; $i < $Vend::Cfg->{StaticDepth}; $i++) {
		my $num = scalar keys %Vend::Found_scan;
		for(values %Vend::Found_scan) {

			print do_msg("Re-checking $_");
			my $status = build_page($_, $outdir, 0, 1);
			$status = $status ? "done.\n" : "none.\n";
			print $status;
		}
		last STATICDEPTH if $num >= scalar keys %Vend::Found_scan;
	}
}

1;

# END STATICPAGE

