# Vend::Control - Routines that alter the running Interchange daemon
# 
# $Id: Control.pm,v 2.16 2007-08-09 21:53:02 racke Exp $
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

package Vend::Control;

require Exporter;
@ISA = qw/ Exporter /;
@EXPORT = qw/
				signal_reconfig
				signal_add
				signal_jobs
				signal_remove
				control_interchange
				change_catalog_directive
				change_global_directive
				remove_catalog
				add_catalog
/;

use strict;
use Vend::Util;

sub signal_reconfig {
	my (@cats) = @_;
	for(@cats) {
		my $ref = $Global::Catalog{$_}
			or die errmsg("Unknown catalog '%s'. Stopping.\n", $_);
		Vend::Util::writefile("$Global::RunDir/reconfig", "$ref->{script}\n");
	}
}

sub signal_jobs {
	shift;
	$Vend::mode = 'jobs';
	my $arg = shift;
	my ($cat, $job, $delay) = split /\s*=\s*/, $arg, 3;
	my (@parms, $parmsstr);
	
	$Vend::JobsCat = $cat;
	if ($delay =~ /^(\d+)$/) {
		$delay += time;
	} else {
		$delay = 0;
	}

	if ($Vend::JobsEmail) {
		push (@parms, "email=$Vend::JobsEmail");
	}
	
#::logGlobal("signal_jobs: called cat=$cat job=$job");
	$job = join ",", $job, $Vend::JobsJob;
	$job =~ s/^,+//;
	$job =~ s/,+$//;
	$Vend::JobsJob = $job;

	if (@parms) {
		$parmsstr = ' '. join (' ', @parms);
	}
	
	Vend::Util::writefile("$Global::RunDir/jobsqueue", "jobs $cat $delay $job$parmsstr\n");
#::logGlobal("signal_jobs: wrote file, ready to control_interchange");
	control_interchange('jobs', 'HUP');
}

sub signal_remove {
	shift;
	$Vend::mode = 'reconfig';
	my $cat = shift;
	Vend::Util::writefile("$Global::RunDir/restart", "remove catalog $cat\n");
	control_interchange('remove', 'HUP');
}

sub signal_add {
	$Vend::mode = 'reconfig';
	Vend::Util::writefile("$Global::RunDir/restart", <>);
	control_interchange('add', 'HUP');
}

sub control_interchange {
	my ($mode, $sig, $restart) = @_;

	$Vend::ControllingInterchange = 1;
	unless(-f $Global::PIDfile) {
		warn errmsg(
			"The Interchange server was not running (%s).\n",
			$Global::PIDfile,
			) unless $Vend::Quiet;
		exit 1 unless $restart;
		return;
	}
	my $pidh = Vend::Server::open_pid()
		or die errmsg(
				"Couldn't open PID file %s: %s\n",
				$Global::PIDfile,
				$!,
				);
	my $pid = Vend::Server::grab_pid($pidh);
	if(! $pid) {
		warn errmsg(<<EOF);
The previous Interchange server was not running and probably
terminated with an error.
EOF
		exit 1 unless $restart;
		return;
	}
	if(! $sig) {
		$sig = $mode ne 'kill' ? 'TERM' : 'KILL';
	}
	my $msg;
	if($mode eq 'jobs') {
		$msg = errmsg(
					"Dispatching jobs=%s for cat %s to Interchange server %s with %s.\n",
					$Vend::JobsJob,
					$Vend::JobsCat,
					$pid,
					$sig,
				);
	}
	else {
		$msg = errmsg(
					"Killing Interchange server %s with %s.\n",
					$pid,
					$sig,
				);
	} 

	print $msg unless $Vend::Quiet;

	kill $sig, $pid
		or die errmsg("Interchange server would not stop.\n");
	exit 0 unless $restart;
}

sub remove_catalog {
	my($name) = @_;
	my $g = $Global::Catalog{$name};
	my @aliases;

	unless(defined $g) {
		logGlobal( {level => 'error'}, "Attempt to remove non-existant catalog %s." , $name );
		return undef;
	}

	if($g->{alias}) {
		@aliases = @{$g->{alias}};
	}

	my $c = delete $Global::Selector{$g->{script}};
	delete $Global::Catalog{$name};

	for(@aliases) {
		delete $Global::Selector{$_};
		delete $Global::SelectorAlias{$_};
	}

	if($c) {
		my $sfile = "status.$name";
		my $status_dir = -f "$c->{RunDir}/$sfile"
					   ? $c->{RunDir} 
					   : $c->{ConfDir};
		for( "$Global::RunDir/$sfile", "$status_dir/$sfile") {
			unlink $_ 
				or ::logGlobal("Error removing status file %s: %s", $_, $!);
		}
	}
	
	logGlobal("Removed catalog %s (%s)", $name, $g->{script});
}

sub add_catalog {
	my($line) = @_;
	$line =~ s/^\s+//;
	my ($var, $name, $val) = split /\s+/, $line, 3;
	Vend::Config::parse_catalog($var,"$name $val")
		or die "Bad catalog line '$line'\n";

	my $g = $Global::Catalog{$name}
				or die "Catalog '$name' not parsed.\n";

	my $c = $Global::Selector{$g->{script}}			||
			$Global::SelectorAlias{$g->{script}}	||
			{};

	$c->{CatalogName} = $name;

	my $dir = $g->{'dir'};
	my $script = $g->{'script'};

	if(defined $g->{'alias'}) {
		for(@{$g->{alias}}) {
			if (exists $Global::Selector{$_}
				and $Global::SelectorAlias{$_} ne $g->{'script'})
			{
				logGlobal({level => 'notice'}, "Catalog ScriptAlias %s used a second time, skipping.", $_);
				next;
			}
			elsif (m![^-\w_\~:#/.]!) {
				logGlobal( "Bad alias %s, skipping.", $_,);
			}
			$Global::Selector{$_} = $c;
			$Global::SelectorAlias{$_} = $g->{'script'};
		}
	}

	Vend::Util::writefile("$Global::RunDir/reconfig", "$script\n");
	my $msg = <<EOF;
Added/changed catalog %s:

 Directory: %s
 Script:    %s
EOF
	
	logGlobal({level => 'notice'},  $msg, $name, $dir, $script);

	$Global::Selector{$g->{script}} = $c;
}

sub change_catalog_directive {
	my($cat, $line) = @_;
	$line =~ s/^\s+//;
	my($dir,$val) = split /\s+/, $line, 2;
	my $ref = Vend::Config::set_directive($dir,$val);
	die "Bad directive '$line'.\n" unless defined $ref;
	$cat->{$ref->[0]} = $ref->[1];
	return 1;
}

sub change_global_directive {
	my($line) = @_;
	chomp $line;
	$line =~ s/^\s+//;
	my($dir,$val) = split /\s+/, $line, 2;
	my $ref = Vend::Config::set_directive($dir,$val,1);
	die "Bad directive '$line'.\n" unless defined $ref;
	no strict 'refs';
	${"Global::" . $ref->[0]} = $ref->[1];
	$Global::Structure->{$ref->[0]} = $ref->[1]
		if $Global::DumpStructure;

	dump_structure($Global::Structure, "$Global::RunDir/$Global::ExeName")
		if $Global::DumpStructure;
	return 1;
}

1;
