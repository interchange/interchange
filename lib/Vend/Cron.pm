# Vend::Cron - Determine tasks to run based on time
#
# $Id: Cron.pm,v 2.6 2007-08-09 13:40:53 pajamian Exp $
#
# Copyright (C) 2002-2007 Interchange Development Group
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

package Vend::Cron;

use vars qw($VERSION);
$VERSION = substr(q$Revision: 2.6 $, 10);

use POSIX qw(strftime);
use Vend::Util;
use Text::ParseWords;
use strict;

no warnings qw(uninitialized);

BEGIN {
  eval {
	require Set::Crontab;
	import Set::Crontab;
	$Vend::Cron::Loaded = 1;
  };
}

my @periods = (
	[0 .. 59],
	[0 .. 59],
	[0 .. 23],
	[1 .. 31],
	[1 .. 12],
	[0 .. 7],
);

sub read_cron {
	my $lines = shift;
#::logDebug("read_cron reading $lines") unless $Vend::Quiet;
	my @lines = grep /\w/, split /\n/, $lines;
	@lines = grep $_ !~ /^\s*#/, @lines;

	my @cronobj;
	for(@lines) {
		s/\s+$//;
		my @ary = split /\s+/, $_, 7;

		if(scalar(@ary) < 7) {
			die "Bad cron entry '$_', not right number of time specifications.";
		}

		my $thing = pop @ary;
		if($thing !~ /[a-zA-Z]/) {
			die "Bad cron entry '$_', no job specification.";
		}
		my @times;
		for(my $i = 0; $i < @ary; $i++) {
			$times[$i] = Set::Crontab->new($ary[$i], $periods[$i]);
		}
		push @cronobj, {
			times => \@times,
			things => [ split /\s*;\s*/, $thing ],
			original => $_,
		};
	}

	my %wanted = qw/ :reconfig 1 :jobs 1 /;
	for(@cronobj) {
		my $things = $_->{things};
		for(@$things) {
			next unless $wanted{$_};
			delete $wanted{$_};
		}
	}

	for(keys %wanted) {
		::logGlobal("WARNING: suggested cron entry '%s' not present.", $_)
			unless $Vend::Quiet;
	}
	my $obj = \@cronobj;
#::logDebug("read_cron returning $obj") unless $Vend::Quiet;
	return $obj;
}

sub cron {
	my $jobspec = shift;
	my $time = shift || time;

	my @todo;

	my $from;

	## We initialize this baby to make sure run for every second
	if( ref($jobspec->[-1]) ) {
		push @$jobspec, $time;
	}

	$from = $jobspec->[-1];
	$jobspec->[-1] = $time + 1;

#::logDebug("doing run for $from .. $time");
	for my $runtime ($from .. $time) {
		my @made_cut = @$jobspec;
		pop @made_cut;
		my @t = localtime($runtime);
		$t[4]++;
		splice @t, 5, 1;

		for my $n (0 .. 5) {
			my @try = splice @made_cut;
			for(@try) {
				$_->{times}->[$n]->contains($t[$n])
					and push @made_cut, $_;
			}
			last unless @made_cut;
		}
		push @todo, @made_cut;
	}

	my %do;
	my @do_before;
	my @do_after;
	my @cronjobs;

	my $date = POSIX::strftime("time=%H:%M:%S", localtime($time));
	for my $obj (@todo) {
		for(@{$obj->{things}}) {
#::logDebug("$date spawns $_ from $obj->{original}");
			my $j = $_;
			if($j =~ s/^://) {
				$do{$j} = 1;
			}
			elsif($j =~  s/^=//) {
				push @cronjobs, $j;
			}
			elsif($j =~  s/^>//) {
				push @do_after, $j;
			}
			else {
				$j =~ s/^<//;
				push @do_before, $j;
			}
		}
	}

	my @out = \%do;
	push @out, (scalar(@do_before) ? \@do_before : undef);
	push @out, (scalar(@do_after) ? \@do_after : undef);
	push @out, (scalar(@cronjobs) ? \@cronjobs : undef);
	return @out;
}

sub housekeeping {
	return cron($Global::HouseKeepingCron, shift(@_));
}

1;
__END__

