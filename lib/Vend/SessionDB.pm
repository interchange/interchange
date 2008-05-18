# Vend::SessionDB - Stores Interchange session information in a database table
#
# $Id: SessionDB.pm,v 2.11 2007-10-09 13:56:46 jon Exp $
#
# Copyright (C) 2002-2007 Interchange Development Group
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
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA  02110-1301  USA.

package Vend::SessionDB;
require Tie::Hash;
@ISA = qw(Tie::Hash);

use strict;
use Vend::Util;

use vars qw($VERSION);
$VERSION = substr(q$Revision: 2.11 $, 10);

sub TIEHASH {
	my($class, $db) = @_;
	$db = Vend::Data::database_exists_ref($db)
		or die "Vend::SessionDB: bad database $db\n";
	my $self = {
		DB => $db,
		DBH => $db->dbh(),
		TABLE => $db->name(),
		LOCK_VALUE => {},
	};

	bless $self, $class;
}

sub UNTIE {
	my $self = shift;
	%$self = ();
}

sub FETCH {
	my($self, $key) = @_;
#::logDebug("$self fetch: $key (pid=$$)");
	my $rc;

    if($key =~ /^LOCK_/) {

		return $self->{LOCK_VALUE}{$key}
			if $self->{LOCK_VALUE}{$key};

		my $val = time() . ":$$";

		$self->{DOLOCK} ||=
			$self->{DBH}->prepare(
					"insert into $self->{TABLE} (code,sessionlock) values(?,?)",
				);

		eval {
			$rc = $self->{DOLOCK}->execute($key, $val);
		};
		if($@ or $rc < 1) {
			if($@) {
				::logDebug("Error on session execute: $@");
			}
			else {
				::logDebug("Session insert returned rc=$rc");
			}
			## Session exists
			my $sth;

			eval {
				$sth = $self->{DBH}->prepare(
						"select code,sessionlock from $self->{TABLE} where code = ?",
					);
			};
			if($@) {
				my $msg = errmsg("Session lock fetch prepare failed: %s", $@);
				::logDebug($msg);
				::logGlobal($msg);
			}

			eval {
				$sth->execute($key)
					or do {
						logError("DBI query error when fetching session lock $key");
						return undef;
					};
			};
			if($@) {
				my $msg = errmsg("Session lock fetch execute failed: %s", $@);
				::logDebug($msg);
				::logGlobal($msg);
			}

			my $ary = $sth->fetchrow_arrayref
				or return undef;
			return $ary->[1];
		}
		else {
			## No session there already
			$self->{LOCK_VALUE}{$key} = $val;
			return undef;
		}
	}
	else {
		return $self->{SESSION_VALUE}{$key}
			if $self->{SESSION_VALUE}{$key};
		my $sth = $self->{FETCH} ||= $self->{DBH}->prepare(
								"select session from $self->{TABLE} where code = ?"
							);
		eval {
			$rc = $sth->execute($key);
		};

		if($@) {
			## Session fetch error
			logError("DBI error fetching session $key");
			undef $@;
			return undef;
		}

		my $ary = $sth->fetchrow_arrayref
			or return undef;
		return $self->{SESSION_VALUE}{$key} = $ary->[0];
	}
}

sub FIRSTKEY {
	my $self = shift;
	my $tmp = pop @{$self->{DB}};
	eval {
		$self->{DB}->config('DELIMITER');
	};
	push @{$self->{DB}}, $tmp if $@;
	my @pair = $self->{DB}->each_record();
	while($pair[0] =~ /^LOCK_/) {
		@pair = $self->{DB}->each_record();
	}
	return @pair;
}

sub NEXTKEY {
	my $self = shift;
	my @pair = $self->{DB}->each_record();
	while($pair[0] =~ /^LOCK_/) {
		@pair = $self->{DB}->each_record();
	}
	return @pair;
}

sub EXISTS {
	my($self,$key) = @_;
#::logDebug("$self EXISTS check: $key");
	return undef unless $self->{DB}->record_exists($key);
	1;
}

sub DELETE {
	my($self,$key) = @_;
#::logDebug("$self delete: $key");
	$self->{DELHANDLE} ||= $self->{DBH}->prepare(
								"delete from $self->{TABLE} where code = ?",
								);
	$self->{DELHANDLE}->execute($key);
}

sub STORE {
	my($self, $key, $val) = @_;
	if( $key =~ s/^LOCK_//) {
		return $self->{LOCK_VALUE}{$key};
	}
	else {
		$self->{DB}->set_field( $key, 'session', $val);
		undef $self->{SESSION_VALUE}{$key};
		return 1;
	}
}
	
1;
__END__
