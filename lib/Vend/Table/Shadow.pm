# Vend::Table::Shadow - Access a virtual "Shadow" table
#
# $Id: Shadow.pm,v 1.22 2003-02-17 12:18:16 racke Exp $
#
# Copyright (C) 2002-2003 Stefan Hornburg (Racke) <racke@linuxia.de>
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
$VERSION = substr(q$Revision: 1.22 $, 10);

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
	# during an import the object has the wrong class, so we fix it here
	bless $obj, "Vend::Table::$config->{OrigClass}";

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
	$s = $s->import_db() unless defined $s->[$OBJ];
	my ($orig_db, $orig_col) = $s->_map_field($column);
	return $orig_db->numeric($orig_col);
}

sub column_index {
	my ($s, $column) = @_;
	$s = $s->import_db() unless defined $s->[$OBJ];
	return $s->[$OBJ]->column_index($column);
}

sub column_exists {
    my ($s, $column) = @_;
	
	$s = $s->import_db() if ! defined $s->[$OBJ];
	my ($orig_db, $orig_col) = $s->_map_field($column);
	return $orig_db->column_exists($orig_col);
}

sub set_slice {
	my ($s, $key, $fary, $vary) = @_;

	$s = $s->import_db() if ! defined $s->[$OBJ];
	$s->[$OBJ]->set_slice($key, $fary, $vary);
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
	my ($ref, $map, $column, $locale, $db, $value);
	
	$s = $s->import_db() unless defined $s->[$OBJ];
	$ref = $s->[$OBJ]->row_hash($key);
	if ($ref) {
		$s->_map_hash($key, $ref);
	}
	return $ref;
}

sub foreign {
	my ($s, $key, $foreign) = @_;

	$s = $s->import_db() unless defined $s->[$OBJ];	
	$s->[$OBJ]->foreign($key, $foreign);
}

sub field {
	my ($s, $key, $column) = @_;
	my ($map, $locale, $db);

	$s = $s->import_db() unless defined $s->[$OBJ];
	$s->_map_column($key, $column);
}

sub ref {
	return $_[0] if defined $_[0]->[$OBJ];
	return $_[0]->import_db();
}

sub test_record {
	my ($s, $key) = @_;
	$s = $s->import_db() unless defined $s->[$OBJ];
	$s->[$OBJ]->test_record($key);
}

sub record_exists {
	my ($s, $key) = @_;
	$s = $s->import_db() unless defined $s->[$OBJ];
	$s->[$OBJ]->record_exists($key);
}

sub touch {
	my ($s) = @_;
	$s = $s->import_db() unless defined $s->[$OBJ];
	$s->[$OBJ]->touch();
}

sub sort_each {
	my ($s, @args) = @_;
	$s = $s->import_db() unless defined $s->[$OBJ];
	return $s->[$OBJ]->sort_each(@args);
}

sub each_record {
	my ($s, $qual) = @_;
	$s = $s->import_db() unless defined $s->[$OBJ];
	return $s->[$OBJ]->each_record($qual);
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

# _map_field returns the shadowed database and column for a given field
sub _map_field {
	my ($s, $column) = @_;
	my ($db, $sdb, $scol);
	
	my $locale = $::Scratch->{mv_locale} || 'default';

	if (exists $s->[$CONFIG]->{MAP}->{$column}->{$locale}) {
		my $map = $s->[$CONFIG]->{MAP}->{$column}->{$locale};

		if (exists $map->{table}) {
			$db = Vend::Data::database_exists_ref($map->{table})
					   or die "unknown table $map->{table} in mapping for column $column of $s->[$TABLE] for locale $locale";
			$sdb = $db;
		} else {
			$sdb = $s->[$OBJ];
		}
		$scol = $map->{column};
	} else {
		$sdb = $s->[$OBJ];
		$scol = $column;
	}
	return ($sdb, $scol);
}
	
sub _map_hash {
	my ($s, $key, $href) = @_;

    for (keys %$href) {
		$href->{$_} = $s->_map_column($key, $_, 1, $href->{$_});
	}

	$href;
}

sub _map_column {
	my ($s, $key, $column, $done, $orig) = @_;
	my ($map, $mapentry, $db, $value);

	my $locale = $::Scratch->{mv_locale} || 'default';

	if (exists $s->[$CONFIG]->{MAP}->{$column}->{$locale}) {
		$mapentry = $s->[$CONFIG]->{MAP}->{$column};
		$map = $mapentry->{$locale};
		if (exists $map->{lookup_table}) {
			my ($db_lookup, $lookup_key);
			::logDebug ("Lookup $column with key $key in $map->{lookup_table}");
			$db_lookup = Vend::Data::database_exists_ref($map->{lookup_table})
				or die "unknown lookup table $map->{lookup_table} in mapping for column $column of $s->[$TABLE] for locale $locale";
			$db = Vend::Data::database_exists_ref($map->{table})
				or die "unknown table $map->{table} in mapping for column $column of $s->[$TABLE] for locale $locale";

			# retrieve original value
			$value = $s->[$OBJ]->field($key,$column);

			# now map original value to lookup table
			if ($lookup_key = $db_lookup->foreign($value,$map->{lookup_column})) {
				my $final = $db->field($lookup_key,$map->{column});
				return $final if $final;
			}
			
			if ($mapentry->{fallback}) {
				return $value;
			}

			return '';
		}
		if (exists $map->{table}) {
			$db = Vend::Data::database_exists_ref($map->{table})
					   or die "unknown table $map->{table} in mapping for column $column of $s->[$TABLE] for locale $locale";
			if ($db->record_exists($key)) {
			    $value = $db->field($key, $map->{column});
			} else {
				$value = '';
			}
		} else {
			$value = $s->[$OBJ]->field($key, $map->{column});
		}
		if (! $value && $mapentry->{fallback}) {
			# nothing found, so we fallback to the original entry
			if ($done) {
				$value = $orig;
			} else {
				$value = $s->[$OBJ]->field($key, $column);
			}
		}
	} elsif ($done) {
		# column lookup already took place
		$value = $orig;
	} else {
		$value = $s->[$OBJ]->field($key, $column);
	}

	return $value;
}

1;
