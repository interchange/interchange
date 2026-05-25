# Vend::SessionDB - Stores Interchange session information in a database table
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
use Vend::Util::Compress qw(compress uncompress);

use vars qw($VERSION);
$VERSION = '2.11';

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

	# SQLite doesn't support the necessary row-level locking to work
	die 'SQLite has no row-level locking required for SessionType DBI - try MySQL or PostgreSQL'
		if $self->{DBH}->get_info(17) eq 'SQLite';

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
	my $dbh = $self->{DBH};

	return $self->{SESSION_VALUE}{$key}
		if $self->{SESSION_VALUE}{$key};

	my $q_table = $dbh->quote_identifier($self->{TABLE});
	my $q_session = $dbh->quote_identifier('session');

	my $retries = 0;
	DEADLOCK: {
		_handle_transaction($self, $dbh);
		my $sth = $self->{FETCH} ||= $self->{DBH}->prepare(
								"select $q_session from $q_table where code = ? for update"
							);
		local $@;
		eval {
			$rc = $sth->execute($key);
		};

		if (my $err = $@) {
			## Session fetch error
			if ($err =~ /deadlock/i && $retries < 3) {
				::logError("Deadlock encountered fetching session $key - retry attempt %d", ++$retries);
				$dbh->rollback;
				redo DEADLOCK;
			}
			else {
				::logError("DBI error fetching session $key: $err");
				return undef;
			}
		}

		my $ary = $sth->fetchrow_arrayref
			or return undef;

		defined $ary->[0]
			or return undef;

		my $fetch = \$ary->[0];
		if (my $c_type = $Vend::Cfg->{SessionDBCompression}) {
			my ($ref, $time, $alert) = uncompress($fetch, $c_type);
			::logError("$c_type uncompression response alert: $alert")
				if $alert;
			::logDebug('%s time to uncompress: %fs', $c_type, $time);
			$fetch = $ref;
		}

		return $self->{SESSION_VALUE}{$key} = $$fetch;
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
	return @pair;
}

sub NEXTKEY {
	my $self = shift;
	my @pair = $self->{DB}->each_record();
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
	my $dbh = $self->{DBH};
	my $q_table = $dbh->quote_identifier($self->{TABLE});
	$self->{DELHANDLE} ||= $dbh->prepare(
								"delete from $q_table where code = ?",
								);
	my $rv = $self->{DELHANDLE}->execute($key);
	$dbh->commit unless $dbh->{AutoCommit};
	return $rv;
}

sub STORE {
	my($self, $key, $val) = @_;

	my $dbh = $self->{DBH};
	my $in_trans = !$dbh->{AutoCommit};
	my $q_table = $dbh->quote_identifier($self->{TABLE});
	my $q_session = $dbh->quote_identifier('session');

	my $store = \$val;
	if (my $c_type = $Vend::Cfg->{SessionDBCompression}) {
		my ($ref, $before, $after, $time, $alert) = compress($store, $c_type);
		::logError("$c_type compression response alert: $alert")
			if $alert;
		::logDebug('%s compression impact - before: %dB; after: %dB; %%reduced: %s', $c_type, $before, $after, $before ? sprintf ('%.2f', (1-$after/$before)*100) : 'undefined');
		::logDebug('%s time to compress: %fs', $c_type, $time);
		$store = $ref;
	}

    my %attr = _get_bind_attr();
	local $@;
	eval {
		my $upd = $dbh->prepare("update $q_table set $q_session = ? where code = ?");
		$upd->bind_param(1, $$store, \%attr);
		$upd->bind_param(2, $key);
		$upd->execute;

		# Fallback to insert
		if ($upd->rows == 0) {
			my $ins = $dbh->prepare("insert into $q_table (code, $q_session) values (?,?)");
			$ins->bind_param(1, $key);
			$ins->bind_param(2, $$store, \%attr);
			$ins->execute;
		}
	};

	if (my $err = $@) {
		::logError("DBI error storing session $key - CRITICAL: $err");
		$dbh->rollback if $in_trans;
	}
	elsif ($in_trans) {
		$dbh->commit;
	}

	$self->{SESSION_VALUE}{$key} = $val;
	return 1;
}

sub _get_bind_attr {
    local $@;
    my %hsh = eval { ( pg_type => DBD::Pg->PG_BYTEA ) };
    return %hsh;
}

sub _handle_transaction {
	my ($self, $dbh) = @_;
	my $q_table = $dbh->quote_identifier($self->{TABLE});
	my $once = 0;
	LOOP: {
		local $@;
		eval {
			# Trying to back out of any cached cxn in open transaction
			unless ($dbh->{AutoCommit}) {
				$dbh->rollback;
				$dbh->{AutoCommit} = 1;
			}
			# Issue no-op select in autocommit to try to refresh the cxn
			$dbh->selectrow_array("select 1 from $q_table where 2 = 1");
			$dbh->begin_work;
		};

		if (my $err = $@) {
			::logError('_handle_transaction() produced an error: %s', $err);
			unless ($once++) {
				::logError('Attempting to clone DBI handle and retry _handle_transaction() ...');
				local $@;
				eval {
					$dbh = $self->{DBH} = $self->{DB}->ref->[$Vend::Table::DBI::DBI] = $dbh->clone({});
				};
				if (my $err = $@) {
					::logError('Error on call to clone: %s', $err);
				}
				redo LOOP;
			}
		}
	}
	return;
}

1;
__END__
