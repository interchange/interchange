#!/usr/bin/perl
##!~_~perlpath~_~
#
# Interchange cron editor
#
# Copyright (C) 2005-2009 Interchange Development Group
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

use lib '/usr/local/interchange/lib';
#use lib '~_~INSTALLPRIVLIB~_~';
use lib '/usr/local/interchange';
#use lib '~_~INSTALLARCHLIB~_~';

BEGIN {

	($Global::VendRoot = $ENV{MINIVEND_ROOT})
		if defined $ENV{MINIVEND_ROOT};
	$Global::VendRoot = $Global::VendRoot || '/usr/local/interchange';
#	$Global::VendRoot = $Global::VendRoot || '~_~INSTALLARCHLIB~_~';

	if(-f "$Global::VendRoot/interchange.cfg") {
		$Global::ExeName = 'interchange';
		$Global::ConfigFile = 'interchange.cfg';
	}
	else {
		$Global::ExeName = 'interchange';
		$Global::ConfigFile = 'interchange.cfg';
	}

}

### END CONFIGURATION VARIABLES

use POSIX qw/tmpnam/;
use Vend::Cron;

my $prospect = tmpnam();

use File::Copy;
use Term::ReadLine;
use FindBin;

my $term = new Term::ReadLine 'Simple';

use Safe;
my $safe = new Safe;

my $configstring = `$FindBin::Bin/interchange -globalconfig`;

chdir $Global::VendRoot
	or die "Unable to chdir to $Global::VendRoot: $!\n";

my $Global = $safe->reval($configstring)
	or die "Unable to read configuration via $FindBin::Bin/interchange.\n";


my $hupit = 1;

if(! $Global->{HouseKeepingCron}) {
	warn "No HouseKeepingCron is defined, this will do nothing.\n";
	warn "Add:\n\n\tHouseKeepingCron <crontab\n\nto interchange.cfg to activate.\n";
	undef $hupit;
}

$Vend::Quiet = 1;

my $file = "$Global->{ConfigDir}/crontab";

#warn "Cron file is $file\n";

if(-f $file) {
	File::Copy::copy($file, $prospect);
}

my $ed = $ENV{VISUAL} || $ENV{EDITOR} || 'vi';

my @needed = qw/
	:restart
	:reconfig
	:jobs
/;

EDCRON: {
	system "$ed $prospect";

	my $status = `diff $prospect $file`;

	unless($?) {
		warn "Crontab unchanged.\n";
		exit;
	}

	open NEWCRON, "< $prospect"
		or die "Cannot open prospective cron file: $!\n";

	local($/);

	my $lines = <NEWCRON>;
	close NEWCRON;

#warn "Read lines (" . length($lines) . " bytes)\n";

	my $obj;
	eval {
		$obj = Vend::Cron::read_cron($lines);
	};

	if(! $obj or $@) {
		print "Cron file problem: $@\n";
		my $prompt = "Retry? [y]";
		my $ans = $term->readline($prompt);
		if($ans =~ /^\s*n/) {
			last EDCRON;
		}
		else {
			redo EDCRON;
		}
	}

    my %wanted = qw/ :reconfig 1 :jobs 1 /;
    for(@$obj) {
        my $things = $_->{things};
        for(@$things) {
            next unless $wanted{$_};
            delete $wanted{$_};
        }
    }

	my @errmsg;
    for(keys %wanted) {
        push @errmsg, sprintf("WARNING: suggested cron entry '%s' not present.", $_);
    }

	if(@errmsg) {
		print join "\n", @errmsg, '';
		my $prompt = "Retry? [y]";
		my $ans = $term->readline($prompt);
		unless ($ans =~ /^\s*n/) {
			redo EDCRON;
		}
	}


#warn "read_cron returned $obj.\n";

	File::Copy::copy($prospect, $file);
	print "Wrote crontab file $file.\n";
#warn "copied $prospect to $file\n";

	unlink $prospect;
	if($hupit) {

		open CRON, "< $file"
			or die "Can't read cron file $file: $!\n";
		my $lines = <CRON>;
		close CRON;

		my $rsfile = "$Global->{RunDir}/restart";
		open RESTART, ">> $rsfile"
			or die "Cannot write restart file: $!\n";
		print RESTART "HouseKeepingCron <<EndOfCrontab\n";
		print RESTART $lines;
		print RESTART "\nEndOfCrontab\n";
		close RESTART;
#warn "created restart file\n";

		my $pidfile = $Global->{PIDfile};
		unless (-f $pidfile) {
			warn "Interchange not running, cannot tell to reread ($pidfile).\n";
		}
		open PID, "< $pidfile"
			or die "Cannot read PID file $pidfile: $!\n";

		my $pid = <PID>;
		close PID;
		$pid =~ s/\s+.*//s;
		$pid =~ s/\D+//g;
#warn "Found pid=$pid\n";
		chomp $pid;
		if ($pid) {
			kill 'HUP', $pid;
			print "Sent HUP signal to Interchange server at $pid.\n";
		}
		else {
			die "Unable to find pid at $pidfile.\n";
		}
	}
}

