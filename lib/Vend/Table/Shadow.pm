# Vend::Table::Shadow - Access a virtual "Shadow" table
#
# $Id: Shadow.pm,v 1.54 2008-05-26 02:30:04 markj Exp $
#
# Copyright (C) 2002-2006 Stefan Hornburg (Racke) <racke@linuxia.de>
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

package Vend::Table::Shadow;
$VERSION = substr(q$Revision: 1.54 $, 10);

# CREDITS
#
# Thanks to Andreas Jacob <wabi@gmx.net> for initial funding
# and continuous bug reports.

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

sub dbh {
	my ($s) = shift;
	$s = $s->import_db() unless defined $s->[$OBJ];
	if ($s->[$OBJ]->can('dbh')) {
		return $s->[$OBJ]->dbh();
	}
}

sub name {
	my ($s) = shift;
	$s = $s->import_db() unless defined $s->[$OBJ];
	return $s->[$OBJ]->name();
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

sub inc_field {
	my ($s, $key, $column, $value) = @_;
	$s = $s->import_db() unless defined $s->[$OBJ];
	return $s->[$OBJ]->inc_field($key, $column, $value);
}

sub commit {
	my ($s) = @_;
	$s = $s->import_db() unless defined $s->[$OBJ];
	return $s->[$OBJ]->commit();
}

sub rollback {
	my ($s) = @_;
	$s = $s->import_db() unless defined $s->[$OBJ];
	return $s->[$OBJ]->rollback();
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

sub get_slice {
	my ($s, $key, $fary) = @_;
	my ($db, $col);

	$s = $s->import_db() if ! defined $s->[$OBJ];
	if (ref $fary ne 'ARRAY') {
		shift; shift;
		$fary = [ @_ ];
	}

	for (my $i = 0; $i < @$fary; $i++) {
		($db, $col) = $s->_map_field($fary->[$i]);
		$fary->[$i] = $col;
	}
	
	$s->[$OBJ]->get_slice($key, $fary);
}

sub set_slice {
	my $s = shift;

	$s = $s->import_db() if ! defined $s->[$OBJ];
	$s->[$OBJ]->set_slice(@_);
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
	$locale = $::Scratch->{mv_locale} || $Vend::Cfg->{DefaultLocale};
	
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

	$s = $s->import_db() unless defined $s->[$OBJ];
	$s->_map_column($key, $column);
}

sub set_field {
	my ($s, $key, $column, $value) = @_;

	$s = $s->import_db() unless defined $s->[$OBJ];

	# usually we want to operate on the original table
	$s->[$OBJ]->set_field($key, $column, $value);
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

sub delete_record {
	my ($s, $key) = @_;
	$s = $s->import_db() unless defined $s->[$OBJ];
	$s->[$OBJ]->delete_record($key);
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
	my $record;
	
	$s = $s->import_db() unless defined $s->[$OBJ];
	if ($record = $s->[$OBJ]->each_nokey($qual)) {
		return $s->_map_array ($record);
	}
}

sub query {
	my($s, $opt, $text, @arg) = @_;

	if (! CORE::ref($opt)) {
		unshift @arg, $text if defined $text;
		$text = $opt;
		$opt = {};
	}
	$opt->{query} = $opt->{sql} || $text if ! $opt->{query};

	if($opt->{type}) {
		$opt->{$opt->{type}} = 1 unless defined $opt->{$opt->{type}};
	}

	$s = $s->import_db() unless defined $s->[$OBJ];
	
	if ($opt->{query}) {
		# we try to analyse the query
		my $qref = $s->_parse_sql($opt->{query});

		if (@{$qref->{tables}} > 1) {
			die ::errmsg("Vend::Table::Shadow::query can handle only one table");
		}

		my $table = $qref->{tables}->[0];
		my $db;
		
		if ($table ne $s->[$CONFIG]->{name}) {
			# pass query to other table, but preserve the query info
			$opt->{queryinfo} = $qref;
			unless ($db = Vend::Data::database_exists_ref($table)) {
				die ::errmsg(qq{Table %s not found for query "%s"}, $table, $opt->{query});
			}
			return $db->query($opt, $text, @arg);
		} elsif ($qref->{command} ne 'SELECT') {
			return $s->[$OBJ]->query($opt, $text, @arg);
		} else {
			# check if one of the queried fields is shadowed
			my (@map_matches, @map_entries, $colref);

			# handle "select * ..." queries
			$colref = $qref->{columns};
			if (@$colref == 1 && $colref->[0] eq '*') {
				$colref = [$s->columns()];
			} else {
				# SQL parser returns columns in lowercase, replace
				# with correct case if needed
				my $pos;
				my @cols = $s->columns();

				for (my $i = 0; $i < @$colref; $i++) {
					if ($pos = $s->[$OBJ]->column_index($colref->[$i])) {
						$colref->[$i] = $cols[$pos];
					} elsif ($colref->[$i] eq lc($s->[$OBJ]->config('KEY'))) {
						$colref->[$i] = $s->[$OBJ]->config('KEY');
					}
				}
			}

			unless (@map_matches = $s->_map_entries($colref, \@map_entries)) {
				return $s->[$OBJ]->query($opt, $text, @arg);				
			}

			if (@$colref == 1 && $qref->{distinct}->[0]) {
				# workaround for queries like
				# "select distinct category from products order by category"
				my ($dt, $dc) = $s->_map_field($colref->[0]);

				$opt->{query} = "select distinct $dc from " . $dt->config('name');
				if (@{$qref->{order}}) {
					$opt->{query} .= " ORDER BY " . join(',', @{$qref->{order}});
				}
				
				return $s->[$OBJ]->query($opt, $text, @arg);
			}
			
			# scan columns for key field
			my $keyname = $s->[$OBJ]->config('KEY');
			my $keypos;
			for (my $i = 0; $i < @$colref; $i++) {
				if ($keyname eq $colref->[$i]) {
					$keypos = $i;
					last;
				}
			}
			unless (defined $keypos) {
				die "key $keyname not in query $opt->{query}, cannot handle";
			}
			# replace shadowed fields
			my ($pos, $name, $row, $map_entry, $list, @qa, $result);
			if ($list = $opt->{list}) {
				$opt->{list} = 0;
				@qa = $s->[$OBJ]->query($opt, $text, @arg);
				$result = $qa[0];
			} else {
				$result = $s->[$OBJ]->query($opt, $text, @arg);
			}

			if ($opt->{hashref}) {
				for $row (@$result) {
					for $pos (@map_matches) {
						($name, $map_entry) = @{$map_entries[$pos]};
						$row->{$colref->[$pos]} = $s->_map_column($row->{$colref->[$keypos]}, $name, 1, $row->{$colref->[$pos]}, $map_entry);
					}
				}
			} else {
				for $row (@$result) {
					for $pos (@map_matches) {
						($name, $map_entry) = @{$map_entries[$pos]};
						$row->[$pos] = $s->_map_column($row->[$keypos], $name, 1, $row->[$pos], $map_entry);
					}
				}
			}

			if($opt->{search_label}) {
				$::Instance->{SearchObject}{$opt->{search_label}} = {
					mv_results => $result,
					mv_field_names => $qa[2],
				};
			}

			if ($list) {
				$opt->{list} = 1;
				return Vend::Interpolate::tag_sql_list($text, $result, $qa[1], $opt, $qa[2]);
			} else {
				return $result;
			}
		}
	}
}

sub reset {
	my ($s, $key) = @_;
	$s = $s->import_db() unless defined $s->[$OBJ];
	$s->[$OBJ]->reset();
}

sub _parse_config_line {
	my ($d, $p, $val) = @_;
	my @f = split(/\s+/, $val);
	my %parms;
	my %map_options = (fallback => 1);
	my ($map_table, $map_column);

	if (@f < 2) {
		Vend::Config::config_error("At least two parameters needed for $p.");
	}
	
	if ($p eq 'MAP_OPTIONS') {
		@f = split(/\s+/, $val, 3);
		if ($f[0] eq 'share') {
			if (@f != 3) {
				Vend::Config::config_error("Two parameters needed for MAP option share");
			}
			$d->{MAP_OPTIONS}->{share}->{$f[1]} = $f[2];
		} else {
			Vend::Config::config_error("Unknown MAP option $f[0]");
		}
	} elsif ($p ne 'MAP') {
		Vend::Config::config_error("Unknown MAP directive $p");
	}
	
	my $field = shift @f;

	if (@f % 2) {
		Vend::Config::config_error("Incomplete parameter list for MAP.");
	}

	# now we have a valid configuration and change the database type
	# if necessary

	unless ($d->{type} eq 10) {
		$d->{OrigClass} = $d->{Class};
		$d->{Class} = 'SHADOW';
		$d->{type} = 10;
	}

	while (@f) {
		my $map_key = shift @f;
		my $map_value = shift @f;

		if (exists $map_options{$map_key}) {
			# option like fallback
			$d->{MAP}->{$field}->{$map_key} = $map_value;
		} else {
			# mapping direction
			if ($map_value =~ m%^((.*?)::(.*?)/)?(.*?)::(.*)%) {
				if ($1) {
					$d->{MAP}->{$field}->{$map_key} = {lookup_table => $2,
													   lookup_column => $3,
													   table => $4,
													   column => $5}
				} else {
					$d->{MAP}->{$field}->{$map_key} = {table => $4,
													   column => $5};
				}
			} else {
				$d->{MAP}->{$field}->{$map_key} = {column => $map_value};
			}
		}
	}
}

sub _parse_sql {
	my ($s, $query) = @_;
	my (%sqlinfo);
	
	my ($stmt);
	
	eval {
		$stmt = Vend::SQL_Parser->new($query);
	};
	
	if ($@) {
		die ::errmsg("Bad SQL statement: %s\nQuery was: %s", $@, $query);
	}

	$sqlinfo{command} = $stmt->command();
	
	for ($stmt->tables()) {
		push (@{$sqlinfo{tables}}, $_->name());
	}
	for ($stmt->columns()) {
		push (@{$sqlinfo{columns}}, $_->name());
		push (@{$sqlinfo{distinct}}, $_->distinct());
	}
	for ($stmt->order()) {
		push (@{$sqlinfo{order}}, $_->column() . ($_->desc ? ' DESC' : ''));
	}
	
	\%sqlinfo;		   
}

sub _map_entries {
	my ($s, $colsref, $entriesref) = @_;
	my @matches;
	my $locale = $::Scratch->{mv_locale} || $Vend::Cfg->{DefaultLocale};
	
	for (my $i = 0; $i < @$colsref; $i++) {
		if (exists $s->[$CONFIG]->{MAP}->{$colsref->[$i]}->{$locale}) {
			$entriesref->[$i] = [$colsref->[$i], $s->[$CONFIG]->{MAP}->{$colsref->[$i]}];
			push (@matches, $i);
		}
	}
	return @matches;
}

# _map_field returns the shadowed database and column for a given field
sub _map_field {
	my ($s, $column) = @_;
	my ($db, $sdb, $scol);
	
	my $locale = $::Scratch->{mv_locale} || $Vend::Cfg->{DefaultLocale};

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

sub _map_array {
	my ($s, $aref) = @_;
	my (@cols) = $s->columns();
	my $key = $aref->[0];
	
	for (my $i = 1; $i < @cols; $i++) {
		$aref->[$i] = $s->_map_column ($key, $cols[$i], 1, $aref->[$i]);
	}

	$aref;
}

sub _map_column {
	my ($s, $key, $column, $done, $orig, $mapentry) = @_;
	my ($map, $db, $value);

	my $locale = $::Scratch->{mv_locale} || $Vend::Cfg->{DefaultLocale};

	if (! $mapentry && ! $::Scratch->{mv_shadowpass}
		&& exists $s->[$CONFIG]->{MAP}->{$column}->{$locale}) {
		$mapentry = $s->[$CONFIG]->{MAP}->{$column};
	}

	if ($mapentry) {
		$map = $mapentry->{$locale};
		if (exists $map->{lookup_table}) {
			my ($db_lookup, $lookup_key);
#::logDebug ("Lookup $column with key $key in $map->{lookup_table}");
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

sub _shared_databases {
	my ($s) = @_;
	
	if ($s->[$CONFIG]->{MAP_OPTIONS}->{share}) {
		my $tables = $s->[$CONFIG]->{MAP_OPTIONS}->{share}->{$::Scratch->{mv_locale} || $Vend::Cfg->{DefaultLocale}};
		return split(/[\s,]+/, $tables);
	}
}

*autonumber = \&Vend::Table::Common::autonumber;

1;
