# Vend::SessionDB - Stores Interchange session information in files
#
# $Id: SessionDB.pm,v 2.3 2003-11-13 16:07:26 mheins Exp $
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

package Vend::SessionDB;
require Tie::Hash;
@ISA = qw(Tie::Hash);

use strict;
use Vend::Util;

use vars qw($VERSION);
$VERSION = substr(q$Revision: 2.3 $, 10);

sub TIEHASH {
	my($self, $db) = @_;
	$db = Vend::Data::database_exists_ref($db);
	$db = $db->ref();
#::logDebug("$self: tied");
	die "Vend::SessionDB: bad database\n"
		unless $db;
	
	bless { DB => $db }, $self;
}

sub FETCH {
	my($self, $key) = @_;
#::logDebug("$self fetch: $key");
	return undef unless $self->{DB}->record_exists($key);
#::logDebug("$self exists: $key");
	return $self->{DB}->field($key, 'sessionlock') if $key =~ s/^LOCK_//;
#::logDebug("$self complex fetch: $key");
	my $data = $self->{DB}->field($key, 'session');
	return undef unless $data;
	return $data;
}

sub FIRSTKEY {
	my $self = shift;
	my $tmp = pop @{$self->{DB}};
	eval {
		$self->{DB}->config('DELIMITER');
	};
	push @{$self->{DB}}, $tmp if $@;
	return $self->{DB}->each_record();
}

sub NEXTKEY {
	return $_[0]->{DB}->each_record();
}

sub EXISTS {
	my($self,$key) = @_;
#::logDebug("$self EXISTS check: $key");
	if ($key =~ s/^LOCK_//) {
		return undef unless $self->{DB}->record_exists($key);
		return undef unless $self->{DB}->field($key, 'sessionlock');
		return 1;
	}
	return undef unless $self->{DB}->record_exists($key);
	1;
}

sub DELETE {
	my($self,$key) = @_;
#::logDebug("$self delete: $key");
	if($key =~ s/^LOCK_// ) {
		return undef unless $self->{DB}->record_exists($key);
		$self->{DB}->set_field($key,'sessionlock','');
		return 1;
	}
	$self->{DB}->delete_record($key);
}

sub STORE {
	my($self, $key, $val) = @_;
	my $locking = $key =~ s/^LOCK_//;
	$self->{DB}->set_row($key) unless $self->{DB}->record_exists($key);
	return $self->{DB}->set_field($key, 'sessionlock', $val) if $locking;
	$self->{DB}->set_field( $key, 'session', $val);
	return 1;
}
	
1;
__END__
