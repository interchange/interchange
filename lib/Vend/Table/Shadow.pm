# Vend::Table::Shadow - Access a virtual "Shadow" table
#
# $Id: Shadow.pm,v 1.9 2002-09-26 11:51:06 racke Exp $
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
$VERSION = substr(q$Revision: 1.9 $, 10);

# TODO
#
# Config.pm:
# - check MAP to avoid mapping the key

use strict;

use vars qw($CONFIG $TABLE $KEY $NAME $TYPE $OBJ $PENDING);
($CONFIG, $TABLE, $KEY, $NAME, $TYPE, $OBJ, $PENDING) = (0 .. 6);

sub config {
	my ($s, $key, $value) = @_;
	$s = $s->import_db() if ! defined $s->[$OBJ];
	return $s->[$CONFIG]{$key} unless defined $value;
	$s->[$CONFIG]{$key} = $value;
}

sub import_db {
	my ($s) = @_;
	my ($db);

	if ($s->[$PENDING]) {
		die "Recursive call to Vend:Table::Shadow::import_db detected (database $s->[0]->{name})\n";
	}
	
	$s->[$PENDING] = 1;
	$db = Vend::Data::import_database($s->[0], 1);
	$s->[$PENDING] = 0;

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
#::logDebug ("CLASS: $class CONFIG: " . ::Vend::Util::uneval($config));	
	no strict 'refs';
	$obj = &{"Vend::Table::$config->{OrigClass}::open_table"}("Vend::Table::$config->{OrigClass}",$config,$tablename);
	my $s = [$config, $tablename, undef, undef, undef, $obj];
	bless $s, $class;
	
	return $s;
}

sub close_table {
	my $s = shift;
	return 1 unless defined $s->[$OBJ];
	$s->[$OBJ]->close_table();
}

sub columns {
	my ($s) = shift;
	$s = $s->import_db() unless defined $s->[$OBJ];
	return $s->[$OBJ]->columns();
}

sub test_column {
	my ($s, $column) = @_;
	$s = $s->import_db() unless defined $s->[$OBJ];
	return $s->[$OBJ]->test_column($column);
}

sub quote {
	my ($s, $value, $field) = @_;
	$s = $s->import_db() unless defined $s->[$OBJ];
	return $s->[$OBJ]->quote($value, $field);
}

sub numeric {
	my ($s, $column) = @_;
	my ($map, $locale);

	$s = $s->import_db() if ! defined $s->[$OBJ];
	$locale = $::Scratch->{mv_locale} || 'default';
	if (exists $s->[$CONFIG]->{MAP}->{$column}->{$locale}) {
		$column = $s->[$CONFIG]->{MAP}->{$column}->{$locale};
	}
	
	return $s->numeric($column);
}

sub column_index {
	my ($s, $column) = @_;
	$s = $s->import_db() unless defined $s->[$OBJ];
	return $s->[$OBJ]->column_index($column);
}

sub column_exists {
    my ($s, $column) = @_;
	my ($locale);
	
	$s = $s->import_db() if ! defined $s->[$OBJ];
	$locale = $::Scratch->{mv_locale} || 'default';
	if (exists $s->[$CONFIG]->{MAP}->{$column}->{$locale}) {
		$column = $s->[$CONFIG]->{MAP}->{$column}->{$locale};
	}
	
	return defined($s->[$CONFIG]{COLUMN_INDEX}{lc $column});
}

sub set_row {
	my ($s, @fields) = @_;

	if ($s->[$PENDING]) {
		no strict 'refs';
		return &{"Vend::Table::$s->[0]->{OrigClass}::set_row"}($s, @fields);
	}
		
	$s = $s->import_db() if ! defined $s->[$OBJ];
	$s->[$OBJ]->set_row(@fields);
}

sub row {
	my ($s, $key) = @_;
	my ($column, $locale);
	
	$s = $s->import_db() if ! defined $s->[$OBJ];
	$locale = $::Scratch->{mv_locale} || 'default';
	
	my @row = $s->[$OBJ]->row($key);
	if (@row) {
		my @cols = $s->columns();
		for (my $i = 0; $i < @cols; $i++) {
			$column = $cols[$i];
			if (exists $s->[$CONFIG]->{MAP}->{$column}->{$locale}) {
				$row[$i] = $s->field($key, $column);
			}
		}
	}
	return @row;
}

sub row_hash {
	my ($s, $key) = @_;
	my ($ref, $column, $locale);
	
	$s = $s->import_db() unless defined $s->[$OBJ];
	$locale = $::Scratch->{mv_locale} || 'default';
	$ref = $s->[$OBJ]->row_hash($key);
	if ($ref) {
		my @cols = $s->columns();
		for (my $i = 0; $i < @cols; $i++) {
			$column = $cols[$i];
			if (exists $s->[$CONFIG]->{MAP}->{$column}->{$locale}) {
				$ref->{$cols[$i]} = $s->field($key, $column);
			}
		}
	}
	return $ref;
}

sub field {
	my ($s, $key, $column) = @_;
	my ($map, $locale, $db);
	
	$s = $s->import_db() unless defined $s->[$OBJ];
	$locale = $::Scratch->{mv_locale} || 'default';
	if (exists $s->[$CONFIG]->{MAP}->{$column}->{$locale}) {
		$map = $s->[$CONFIG]->{MAP}->{$column}->{$locale};
		if (exists $map->{table}) {
			$db = Vend::Data::database_exists_ref($map->{table})
				or die "unknown table $map->{table} in mapping for column $column of $s->[$TABLE] for locale $locale";
			return unless $db->record_exists($key);
			return $db->field($key, $map->{column});
		} else {
			$column = $map->{column};
		}
	}
	$s->[$OBJ]->field($key, $column);
}

sub ref {
	return $_[0] if defined $_[0]->[$OBJ];
	return $_[0]->import_db();
}

sub test_record {
	1;
}

sub record_exists {
	my ($s, $key) = @_;
	$s = $s->import_db() unless defined $s->[$OBJ];
	$s->[$OBJ]->record_exists($key);
}

sub each_nokey {
	my ($s, $qual) = @_;
	$s = $s->import_db() unless defined $s->[$OBJ];
	return $s->[$OBJ]->each_nokey($qual);
}

sub reset {
	my ($s, $key) = @_;
	$s = $s->import_db() unless defined $s->[$OBJ];
	$s->[$OBJ]->reset();
}

1;
