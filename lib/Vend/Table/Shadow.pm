# Vend::Table::Shadow - Access a virtual "Shadow" table
#
# $Id: Shadow.pm,v 1.3 2002-05-27 12:52:43 racke Exp $
#
# Copyright (C) 2002 Stefan Hornburg (Racke) <racke@linuxia.de>
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

package Vend::Table::Shadow;
$VERSION = substr(q$Revision: 1.3 $, 10);

# TODO
#
# Config.pm:
# - check MAP to avoid mapping the key

use strict;

use vars qw($CONFIG $TABLE $KEY $NAME $TYPE $OBJ);
($CONFIG, $TABLE, $KEY, $NAME, $TYPE, $OBJ) = (0 .. 5);

sub config {
	my ($s, $key, $value) = @_;
	$s = $s->import_db() if ! defined $s->[$OBJ];
	return $s->[$CONFIG]{$key} unless defined $value;
	$s->[$CONFIG]{$key} = $value;
}

sub import_db {
	my($s) = @_;
	my $db = Vend::Data::import_database($s->[0], 1);
	return undef if ! $db;
	$Vend::Database{$s->[0]{name}} = $db;
	Vend::Data::update_productbase($s->[0]{name});
	return $db;
}

sub create {
	# create the real table we put the shadow around
	my ($class, $config, $columns, $tablename) = @_;
	my $obj;
	
	no strict 'refs';
	$obj = &{"Vend::Table::$config->{OrigClass}::create"}('',$config,$columns,$tablename);
	my $s = [$config, $tablename, undef, $columns, undef, $obj];
	bless $s, $class;
	
	return $s;
}

sub new {
	my ($class, $obj) = @_;
	bless [$obj], $class;
}

sub open_table {
	my ($class, $config, $tablename) = @_;
	my $obj;
	
	no strict 'refs';
	$obj = &{"Vend::Table::$config->{OrigClass}::open_table"}("Vend::Table::$config->{OrigClass}",$config,$tablename);
	my $s = [$config, $tablename, undef, undef, undef, $obj];
	bless $s, $class;
	
	return $s;
}

sub close_table {
	my $s = shift;
	$s->[$OBJ]->close_table();
}

sub columns {
	my ($s) = shift;
	$s = $s->import_db() unless defined $s->[$OBJ];
	return $s->[$OBJ]->columns();
}

sub field {
	my ($s, $key, $column) = @_;
	my ($map, $locale);
	
	$s = $s->import_db() unless defined $s->[$OBJ];
	$locale = $::Scratch->{mv_locale} || 'default';
	if (exists $s->[$CONFIG]->{MAP}->{$column}->{$locale}) {
		$column = $s->[$CONFIG]->{MAP}->{$column}->{$locale};
	}
	$s->[$OBJ]->field($key, $column);
}

sub ref {
	return $_[0] if defined $_[0]->[$OBJ];
	return $_[0]->import_db();
}

sub record_exists {
	my ($s, $key) = @_;
	$s = $s->import_db() unless defined $s->[$OBJ];
	$s->[$OBJ]->record_exists($key);
}

sub each_nokey {
	my ($s, $qual) = @_;
	$s = $s->import_db() unless defined $s->[$OBJ];
	::logDebug('COLUMNS: ' . $s->columns());
	return $s->[$OBJ]->each_nokey($qual);
}

1;
