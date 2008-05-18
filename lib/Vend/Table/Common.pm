# Vend::Table::Common - Common access methods for Interchange databases
#
# $Id: Common.pm,v 2.50 2008-05-06 20:42:59 markj Exp $
#
# Copyright (C) 2002-2008 Interchange Development Group
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

$VERSION = substr(q$Revision: 2.50 $, 10);
use strict;

package Vend::Table::Common;
require Vend::DbSearch;
require Vend::TextSearch;
require Vend::CounterFile;
no warnings qw(uninitialized numeric);
use Symbol;
use Vend::Util;

use Exporter;
use vars qw($Storable $VERSION @EXPORT @EXPORT_OK);
@EXPORT = qw(create_columns import_ascii_delimited import_csv config columns);
@EXPORT_OK = qw(import_quoted read_quoted_fields);

use vars qw($FILENAME
			$COLUMN_NAMES
			$COLUMN_INDEX
			$KEY_INDEX
			$TIE_HASH
			$DBM
			$EACH
			$CONFIG);
(
	$CONFIG,
	$FILENAME,
	$COLUMN_NAMES,
	$COLUMN_INDEX,
	$KEY_INDEX,
	$TIE_HASH,
	$DBM,
	$EACH,
	) = (0 .. 7);

# See if we can do Storable
BEGIN {
	eval {
		die unless $ENV{MINIVEND_STORABLE_DB};
		require Storable;
		$Storable = 1;
	};
}

my @Hex_string;
{
    my $i;
    foreach $i (0..255) {
        $Hex_string[$i] = sprintf("%%%02X", $i);
    }
}

sub create_columns {
	my ($columns, $config) = @_;
	$config = {} unless $config;
    my $column_index = {};
	my $key;
#::logDebug("create_columns: " . ::uneval($config));

	if($config->{KEY}) {
		$key = $config->{KEY};
	}
	elsif (! defined $config->{KEY_INDEX}) {
		$config->{KEY_INDEX} = 0;
		$config->{KEY} = $columns->[0];
	}
    my $i;
	my $alias = $config->{FIELD_ALIAS} || {};
#::logDebug("field_alias: " . ::uneval($alias)) if $config->{FIELD_ALIAS};
    for ($i = 0;  $i < @$columns;  ++$i) {
        $column_index->{$columns->[$i]} = $i;
		defined $alias->{$columns->[$i]}
			and $column_index->{ $alias->{ $columns->[$i] } } = $i;
		next unless defined $key and $key eq $columns->[$i];
		$config->{KEY_INDEX} = $i;
		undef $key;
#::logDebug("set KEY_INDEX to $i: " . ::uneval($config));
    }

    die errmsg(
			"Cannot find key column %s in %s (%s): %s",
			$config->{KEY},
			$config->{name},
			$config->{file},
			$!,
	    ) unless defined $config->{KEY_INDEX};

	return $column_index;
}

sub separate_definitions {
	my ($options, $fields) = @_;
	for(@$fields) {
#::logDebug("separating '$_'");
		next unless s/\s+(.*)//;
#::logDebug("needed separation: '$_'");
		my $def = $1;
		my $fn = $_;
		unless(defined $options->{COLUMN_DEF}{$fn}) {
			$options->{COLUMN_DEF}{$fn} = $def;
		}
	}
	return;
}

sub clear_lock {
	my $s = shift;
	return unless $s->[$CONFIG]{IC_LOCKING};
	if($s->[$CONFIG]{_lock_handle}) {
		close $s->[$CONFIG]{_lock_handle};
		delete $s->[$CONFIG]{_lock_handle};
	}
}

sub lock_table {
	my $s = shift;
	return unless $s->[$CONFIG]{IC_LOCKING};
	my $lockhandle;
	if(not $lockhandle = $s->[$CONFIG]{_lock_handle}) {
		my $lf = $s->[$CONFIG]{file} . '.lock';
		unless($lf =~ m{/}) {
			$lf = ($s->[$CONFIG]{dir} || $Vend::Cfg->{ProductDir}) . "/$lf";
		}
		$lockhandle = gensym;
		$s->[$CONFIG]{_lock_file} = $lf;
		$s->[$CONFIG]{_lock_handle} = $lockhandle;
		open $lockhandle, ">> $lf"
			or die errmsg("Cannot lock table %s (%s): %s", $s->[$CONFIG]{name}, $lf, $!);
	}
#::logDebug("lock handle=$lockhandle");
	Vend::Util::lockfile($lockhandle);
}

sub unlock_table {
	my $s = shift;
	return unless $s->[$CONFIG]{IC_LOCKING};
	Vend::Util::unlockfile($s->[$CONFIG]{_lock_handle});
}

sub stuff {
    my ($val) = @_;
    $val =~ s,([\t\%]),$Hex_string[ord($1)],eg;
    return $val;
}

sub unstuff {
    my ($val) = @_;
    $val =~ s,%(..),chr(hex($1)),eg;
    return $val;
}

sub autonumber {
	my $s = shift;
	my $start;
	my $cfg = $s->[$CONFIG];

	return $s->autosequence() if $cfg->{AUTO_SEQUENCE};

	return '' if not $start = $cfg->{AUTO_NUMBER};
	local($/) = "\n";
	my $c = $s->[$CONFIG];
	if(! defined $c->{AutoNumberCounter}) {
		$c->{AutoNumberCounter} = new Vend::CounterFile
									$cfg->{AUTO_NUMBER_FILE},
									$start,
									$c->{AUTO_NUMBER_DATE},
									;
	}
	my $num;
	do {
		$num = $c->{AutoNumberCounter}->inc();
	} while $s->record_exists($num);
	return $num;
}

# These don't work in non-DBI databases
sub commit   { 1 }
sub rollback { 0 }

sub numeric {
	return exists $_[0]->[$CONFIG]->{NUMERIC}->{$_[1]};
}

sub quote {
	my($s, $value, $field) = @_;
	return $value if $s->numeric($field);
	$value =~ s/'/\\'/g;
	return "'$value'";
}

sub config {
	my ($s, $key, $value) = @_;
	$s = $s->import_db() if ! defined $s->[$TIE_HASH];
	return $s->[$CONFIG]{$key} unless defined $value;
	$s->[$CONFIG]{$key} = $value;
}

sub import_db {
	my($s) = @_;
	my $db = Vend::Data::import_database($s->[0], 1);
	return undef if ! $db;
	$Vend::Database{$s->[0]{name}} = $db;
	Vend::Data::update_productbase($s->[0]{name});
	if($db->[$CONFIG]{export_now}) {
		Vend::Data::export_database($db);
		delete $db->[$CONFIG]{export_now};
	}
	return $db;
}

sub close_table {
    my ($s) = @_;
	return 1 if ! defined $s->[$TIE_HASH];
#::logDebug("closing table $s->[$FILENAME]");
	undef $s->[$DBM];
	$s->clear_lock();
    untie %{$s->[$TIE_HASH]}
		or $s->log_error("%s %s: %s", errmsg("untie"), $s->[$FILENAME], $!);
	undef $s->[$TIE_HASH];
#::logDebug("closed table $s->[$FILENAME], self=" . ::uneval($s));
}

sub filter {
	my ($s, $ary, $col, $filter) = @_;
	my $column;
	for(keys %$filter) {
		next unless defined ($column = $col->{$_});
		$ary->[$column] = Vend::Interpolate::filter_value(
								$filter->{$_},
								$ary->[$column],
								$_,
						  );
	}
}

sub columns {
    my ($s) = @_;
	$s = $s->import_db() if ! defined $s->[$TIE_HASH];
    return @{$s->[$COLUMN_NAMES]};
}

sub column_exists {
	return defined test_column(@_);
}

sub test_column {
    my ($s, $column) = @_;
	$s = $s->import_db() if ! defined $s->[$TIE_HASH];
    return $s->[$COLUMN_INDEX]{$column};
}

sub column_index {
    my ($s, $column) = @_;
	$s = $s->import_db() if ! defined $s->[$TIE_HASH];
    my $i = $s->[$COLUMN_INDEX]{$column};
    die $s->log_error(
				"There is no column named '%s' in %s",
				$column,
				$s->[$FILENAME],
			) unless defined $i;
    return $i;
}

*test_record = \&record_exists;

sub record_exists {
    my ($s, $key) = @_;
	$s = $s->import_db() if ! defined $s->[$TIE_HASH];
    my $r = $s->[$DBM]->EXISTS("k$key");
    return $r;
}

sub name {
	my ($s) = shift;
	$s = $s->import_db() if ! defined $s->[$TIE_HASH];
	return $s->[$CONFIG]{name};
}

sub row_hash {
    my ($s, $key) = @_;
	$s = $s->import_db() if ! defined $s->[$TIE_HASH];
	return undef unless $s->record_exists($key);
	my %row;
    @row{ @{$s->[$COLUMN_NAMES]} } = $s->row($key);
	return \%row;
}

sub unstuff_row {
    my ($s, $key) = @_;
	$s->lock_table() if $s->[$CONFIG]{IC_LOCKING};
    my $line = $s->[$TIE_HASH]{"k$key"};
	$s->unlock_table() if $s->[$CONFIG]{IC_LOCKING};
    die $s->log_error(
					"There is no row with index '%s' in database %s",
					$key,
					$s->[$FILENAME],
			) unless defined $line;
    return map(unstuff($_), split(/\t/, $line, 9999))
		unless $s->[$CONFIG]{FILTER_FROM};
	my @f = map(unstuff($_), split(/\t/, $line, 9999));
	$s->filter(\@f, $s->[$COLUMN_INDEX], $s->[$CONFIG]{FILTER_FROM});
	return @f;
}

sub thaw_row {
    my ($s, $key) = @_;
	$s->lock_table() if $s->[$CONFIG]{IC_LOCKING};
    my $line = $s->[$TIE_HASH]{"k$key"};
	$s->unlock_table() if $s->[$CONFIG]{IC_LOCKING};
    die $s->log_error( "There is no row with index '%s'", $key,)
		unless defined $line;
    return (@{ Storable::thaw($line) })
		unless $s->[$CONFIG]{FILTER_FROM};
#::logDebug("filtering.");
	my $f = Storable::thaw($line);
	$s->filter($f, $s->[$COLUMN_INDEX], $s->[$CONFIG]{FILTER_FROM});
	return @{$f};
}

sub field_accessor {
    my ($s, $column) = @_;
	$s = $s->import_db() if ! defined $s->[$TIE_HASH];
    my $index = $s->column_index($column);
    return sub {
        my ($key) = @_;
        return ($s->row($key))[$index];
    };
}

sub row_settor {
    my ($s, @cols) = @_;
	$s = $s->import_db() if ! defined $s->[$TIE_HASH];
	my @index;
	my $key_idx = $s->[$KEY_INDEX] || 0;
	#shift(@cols);
	for(@cols) {
     	push @index, $s->column_index($_);
	}
#::logDebug("settor index=@index");
    return sub {
        my (@vals) = @_;
		my @row;
		my $key = $vals[$key_idx];
		eval {
			@row = $s->row($key);
		};
        @row[@index] = @vals;
#::logDebug("setting $key indices '@index' to '@vals'");
        $s->set_row(@row);
    };
}

sub get_slice {
    my ($s, $key, $fary) = @_;
	$s = $s->import_db() if ! defined $s->[$TIE_HASH];

	return undef unless $s->record_exists($key);

	if(ref $fary ne 'ARRAY') {
		shift; shift;
		$fary = [ @_ ];
	}

	my @result = ($s->row($key))[ map { $s->column_index($_) } @$fary ];
	return wantarray ? @result : \@result;
}

sub set_slice {
	my ($s, $key, $fary, $vary) = @_;
	$s = $s->import_db() if ! defined $s->[$TIE_HASH];

    if($s->[$CONFIG]{Read_only}) {
		$s->log_error(
			"Attempt to set slice of %s in read-only table %s",
			$key,
			$s->[$CONFIG]{name},
		);
		return undef;
	}

	my $opt;
	if (ref ($key) eq 'ARRAY') {
		$opt = shift @$key;
		$key = shift @$key;
	}
	$opt = {}
		unless ref ($opt) eq 'HASH';

	$opt->{dml} = 'upsert'
		unless defined $opt->{dml};

	if(ref $fary ne 'ARRAY') {
		my $href = $fary;
		$vary = [ values %$href ];
		$fary = [ keys   %$href ];
	}

	my $keyname = $s->[$CONFIG]{KEY};

	my ($found_key) = grep $_ eq $keyname, @$fary;

	if(! $found_key) {
		unshift @$fary, $keyname;
		unshift @$vary, $key;
	}

	my @current;

	if ($s->record_exists($key)) {
		if ($opt->{dml} eq 'insert') {
			$s->log_error(
				"Duplicate key on set_slice insert for key '$key' on table %s",
				$s->[$CONFIG]{name},
			);
			return undef;
		}
		@current = $s->row($key);
	}
	elsif ($opt->{dml} eq 'update') {
		$s->log_error(
			"No record to update set_slice for key '$key' on table %s",
			$s->[$CONFIG]{name},
		);
		return undef;
	}

	@current[ map { $s->column_index($_) } @$fary ] = @$vary;

	$key = $s->set_row(@current);
	length($key) or
		$s->log_error(
			"Did set_slice with empty key on table %s",
			$s->[$CONFIG]{name},
		);

	return $key;
}

sub field_settor {
    my ($s, $column) = @_;
	$s = $s->import_db() if ! defined $s->[$TIE_HASH];
    my $index = $s->column_index($column);
    return sub {
        my ($key, $value) = @_;
        my @row = $s->row($key);
        $row[$index] = $value;
        $s->set_row(@row);
    };
}

sub clone_row {
	my ($s, $old, $new) = @_;
	return undef unless $s->record_exists($old);
	my @ary = $s->row($old);
	$ary[$s->[$KEY_INDEX]] = $new;
	$s->set_row(@ary);
	return $new;
}

sub clone_set {
	my ($s, $col, $old, $new) = @_;
	return unless $s->column_exists($col);
	my $sel = $s->quote($old, $col);
	my $name = $s->[$CONFIG]{name};
	my ($ary, $nh, $na) = $s->query("select * from $name where $col = $sel");
	my $fpos = $nh->{$col} || return undef;
	$s->config('AUTO_NUMBER', '000001') unless $s->config('AUTO_NUMBER');
	for(@$ary) {
		my $line = $_;
		$line->[$s->[$KEY_INDEX]] = '';
		$line->[$fpos] = $new;
		$s->set_row(@$line);
	}
	return $new;
}

sub stuff_row {
    my ($s, @fields) = @_;
	my $key = $fields[$s->[$KEY_INDEX]];

#::logDebug("stuff key=$key");
	$fields[$s->[$KEY_INDEX]] = $key = $s->autonumber()
		if ! length($key);
	$s->filter(\@fields, $s->[$COLUMN_INDEX], $s->[$CONFIG]{FILTER_TO})
		if $s->[$CONFIG]{FILTER_TO};
	$s->lock_table();

    $s->[$TIE_HASH]{"k$key"} = join("\t", map(stuff($_), @fields));

	$s->unlock_table();
	return $key;
}

sub freeze_row {
    my ($s, @fields) = @_;
	my $key = $fields[$s->[$KEY_INDEX]];
#::logDebug("freeze key=$key");
	$fields[$s->[$KEY_INDEX]] = $key = $s->autonumber()
		if ! length($key);
	$s->filter(\@fields, $s->[$COLUMN_INDEX], $s->[$CONFIG]{FILTER_TO})
		if $s->[$CONFIG]{FILTER_TO};
	$s->lock_table();
	$s->[$TIE_HASH]{"k$key"} = Storable::freeze(\@fields);
	$s->unlock_table();
	return $key;
}

if($Storable) {
	*set_row = \&freeze_row;
	*row = \&thaw_row;
}
else {
	*set_row = \&stuff_row;
	*row = \&unstuff_row;
}

sub foreign {
    my ($s, $key, $foreign) = @_;
	$s = $s->import_db() if ! defined $s->[$TIE_HASH];
	$key = $s->quote($key, $foreign);
    my $q = "select $s->[$CONFIG]{KEY} from $s->[$CONFIG]{name} where $foreign = $key";
#::logDebug("foreign key query = $q");
    my $ary = $s->query({ sql => $q });
#::logDebug("foreign key query returned" . ::uneval($ary));
	return undef unless $ary and $ary->[0];
	return $ary->[0][0];
}

sub field {
    my ($s, $key, $column) = @_;
	$s = $s->import_db() if ! defined $s->[$TIE_HASH];
    return ($s->row($key))[$s->column_index($column)];
}

sub set_field {
    my ($s, $key, $column, $value) = @_;
	$s = $s->import_db() if ! defined $s->[$TIE_HASH];
    if($s->[$CONFIG]{Read_only}) {
		$s->log_error(
			"Attempt to write %s in read-only table",
			"$s->[$CONFIG]{name}::${column}::$key",
		);
		return undef;
	}
    my @row;
	if($s->record_exists($key)) {
		@row = $s->row($key);
	}
	else {
		$row[$s->[$KEY_INDEX]] = $key;
	}
    $row[$s->column_index($column)] = $value
		if $column;
    $s->set_row(@row);
	$value;
}

sub inc_field {
    my ($s, $key, $column, $adder) = @_;
	$s = $s->import_db() if ! defined $s->[$TIE_HASH];
    my($value);
    if($s->[$CONFIG]{Read_only}) {
		$s->log_error(
			"Attempt to write %s in read-only table",
			"$s->[$CONFIG]{name}::${column}::$key",
		);
		return undef;
	}
    my @row = $s->row($key);
	my $idx = $s->column_index($column);
#::logDebug("ready to increment key=$key column=$column adder=$adder idx=$idx row=" . ::uneval(\@row));
    $value = $row[$s->column_index($column)] += $adder;
    $s->set_row(@row);
    return $value;
}

sub create_sql {
    return undef;
}

sub touch {
    my ($s) = @_;
	$s = $s->import_db() if ! defined $s->[$TIE_HASH];
    my $now = time();
    utime $now, $now, $s->[$FILENAME];
}

sub ref {
	my $s = shift;
	return $s if defined $s->[$TIE_HASH];
	return $s->import_db();
}

sub sort_each {
	my($s, $sort_field, $sort_option) = @_;
	if(length $sort_field) {
		my $opt = {};
		$opt->{to} = $sort_option
			if $sort_option;
		$opt->{ml} = 99999;
		$opt->{st} = 'db';
		$opt->{tf} = $sort_field;
		$opt->{query} = "select * from $s->[$CONFIG]{name}";
		$s->[$EACH] = $s->query($opt);
		return;
	}
}

sub each_sorted {
	my $s = shift;
	if(! defined $s->[$EACH][0]) {
		undef $s->[$EACH];
		return ();
	}
	my $k = $s->[$EACH][0][$s->[$KEY_INDEX]];
	return ($k, @{shift @{ $s->[$EACH] } });
}

sub each_record {
    my ($s) = @_;
	$s = $s->import_db() if ! defined $s->[$TIE_HASH];
    my $key;

	return $s->each_sorted() if defined $s->[$EACH];
    for (;;) {
        $key = each %{$s->[$TIE_HASH]};
        if (defined $key) {
            if ($key =~ s/^k//) {
                return ($key, $s->row($key));
            }
        }
        else {
            return ();
        }
    }
}

my $sup;
my $restrict;
my $rfield;
my $hfield;
my $rsession;

sub each_nokey {
    my ($s, $qual) = @_;
	$s = $s->import_db() if ! defined $s->[$TIE_HASH];
    my ($key, $hf);

	if (! defined $restrict) {
		# Support hide_field
		if($qual) {
#::logDebug("Found qual=$qual");
			$hfield = $qual;
			if($hfield =~ s/^\s+WHERE\s+(\w+)\s*!=\s*1($|\s+)//) {
				$hf = $1;
#::logDebug("Found hf=$hf");
				$s->test_column($hf) and $hfield = $s->column_index($hf);
			}
			else {
				undef $hfield;
			}

#::logDebug("hf index=$hfield");
		}
		if($restrict = ($Vend::Cfg->{TableRestrict}{$s->config('name')} || 0)) {
#::logDebug("restricted?");
		$sup =  ! defined $Global::SuperUserFunction
					||
				$Global::SuperUserFunction->();
		if($sup) {
			$restrict = 0;
		}
		else {
			($rfield, $rsession) = split /\s*=\s*/, $restrict;
			$s->test_column($rfield) and $rfield = $s->column_index($rfield)
				or $restrict = 0;
			$rsession = $Vend::Session->{$rsession};
		}
	}

		$restrict = 1 if $hfield and $s->[$CONFIG]{HIDE_FIELD} eq $hf;

	}

    for (;;) {
        $key = each %{$s->[$TIE_HASH]};
#::logDebug("each_nokey: $key field=$rfield sup=$sup");
		if(! defined $key) {
			undef $restrict;
			return ();
		}
		$key =~ s/^k// or next;
		if($restrict) {
			my (@row) = $s->row($key);
#::logDebug("each_nokey: rfield='$row[$rfield]' eq '$rsession' ??") if defined $rfield;
#::logDebug("each_nokey: hfield='$row[$hfield]'") if defined $hfield;
			next if defined $hfield and $row[$hfield];
			next if defined $rfield and $row[$rfield] ne $rsession;
			return \@row;
		}
		return [ $s->row($key) ];
    }
}

sub suicide { 1 }

sub isopen {
	return defined $_[0]->[$TIE_HASH];
}

sub delete_record {
    my ($s, $key) = @_;
	$s = $s->import_db() if ! defined $s->[$TIE_HASH];
    if($s->[$CONFIG]{Read_only}) {
		$s->log_error(
			"Attempt to delete row '$key' in read-only table %s",
			$key,
			$s->[$CONFIG]{name},
		);
		return undef;
	}

#::logDebug("delete row $key from $s->[$FILENAME]");
    delete $s->[$TIE_HASH]{"k$key"};
	1;
}

sub sprintf_substitute {
	my ($s, $query, $fields, $cols) = @_;
	return sprintf $query, @$fields;
}

sub hash_query {
	my ($s, $query, $opt) = @_;
	$opt ||= {};
	$opt->{query} = $query;
	$opt->{hashref} = 1;
	return scalar $s->query($opt);
}

sub query {
    my($s, $opt, $text, @arg) = @_;

    if(! CORE::ref($opt)) {
        unshift @arg, $text if defined $text;
        $text = $opt;
        $opt = {};
    }

	$s = $s->import_db() if ! defined $s->[$TIE_HASH];
	$opt->{query} = $opt->{sql} || $text if ! $opt->{query};

#::logDebug("receieved query. object=" . ::uneval_it($opt));

	if(defined $opt->{values}) {
		@arg = $opt->{values} =~ /['"]/
				? ( Text::ParseWords::shellwords($opt->{values})  )
				: (grep /\S/, split /\s+/, $opt->{values});
		@arg = @{$::Values}{@arg};
	}

	if($opt->{type}) {
		$opt->{$opt->{type}} = 1 unless defined $opt->{$opt->{type}};
	}

	my $query;
    $query = ! scalar @arg
			? $opt->{query}
			: sprintf_substitute ($s, $opt->{query}, \@arg);

	my $codename = defined $s->[$CONFIG]{KEY} ? $s->[$CONFIG]{KEY} : 'code';
	my $ref;
	my $relocate;
	my $return;
	my $spec;
	my $stmt;
	my $update = '';
	my %nh;
	my @na;
	my @update_fields;
	my @out;

	if($opt->{STATEMENT}) {
		 $stmt = $opt->{STATEMENT};
		 $spec = $opt->{SPEC};
#::logDebug('rerouted. Command is ' . $stmt->command());
	}
	else {
		eval {
			($spec, $stmt) = Vend::Scan::sql_statement($query, $opt);
		};
		if($@) {
			my $msg = errmsg("SQL query failed: %s\nquery was: %s", $@, $query);
			$s->log_error($msg);
			Carp::croak($msg) if $Vend::Try;
			return ($opt->{failure} || undef);
		}
		my @additions = grep length($_) == 2, keys %$opt;
		for(@additions) {
			next unless length $opt->{$_};
			$spec->{$_} = $opt->{$_};
		}
	}
	my @tabs = @{$spec->{rt} || $spec->{fi}};

	my $reroute;
	my $tname = $s->[$CONFIG]{name};
	if ($tabs[0] ne $tname) {
		if("$tabs[0]_txt" eq $tname or "$tabs[0]_asc" eq $tname) {
			$tabs[0] = $spec->{fi}[0] = $tname;
		}
		else {
			$reroute = 1;
		}
	}

	if($reroute) {
		unless ($reroute = $Vend::Database{$tabs[0]}) {
			$s->log_error("Table %s not found in databases", $tabs[0]);
			return $opt->{failure} || undef;
		}
		$s = $reroute;
#::logDebug("rerouting to $tabs[0]");
		$opt->{STATEMENT} = $stmt;
		$opt->{SPEC} = $spec;
		return $s->query($opt, $text);
	}

eval {

	my @vals;
	if($stmt->command() ne 'SELECT') {
		if(defined $s and $s->[$CONFIG]{Read_only}) {
			$s->log_error(
					"Attempt to write read-only table %s",
					$s->[$CONFIG]{name},
			);
			return undef;
		}
		$update = $stmt->command();
		@vals = $stmt->row_values();
#::logDebug("row_values returned=" . ::uneval(\@vals));
	}


	@na = @{$spec->{rf}}     if $spec->{rf};

#::logDebug("spec->{ml}=$spec->{ml} opt->{ml}=$opt->{ml}");
	$spec->{ml} = $opt->{ml} if $opt->{ml};
	$spec->{ml} ||= '1000';
	$spec->{fn} = [$s->columns];

	my $sub;

	if($update eq 'INSERT') {
		if(! $spec->{rf} or  $spec->{rf}[0] eq '*') {
			@update_fields = @{$spec->{fn}};
		}
		else {
			@update_fields = @{$spec->{rf}};
		}
#::logDebug("update fields: " . uneval(\@update_fields));
		@na = $codename;
		$sub = $s->row_settor(@update_fields);
	}
	elsif($update eq 'UPDATE') {
		@update_fields = @{$spec->{rf}};
#::logDebug("update fields: " . uneval(\@update_fields));
		my $key = $s->config('KEY');
		@na = ($codename);
		$sub = sub {
					my $key = shift;
					$s->set_slice($key, [@update_fields], \@_);
				};
	}
	elsif($update eq 'DELETE') {
		@na = $codename;
		$sub = sub { delete_record($s, @_) };
	}
	else {
		@na = @{$spec->{fn}}   if ! scalar(@na) || $na[0] eq '*';
	}

	$spec->{rf} = [@na];

#::logDebug("tabs='@tabs' columns='@na' vals='@vals' uf=@update_fields update=$update"); 

    my $search;
    if (! defined $opt->{st} or "\L$opt->{st}" eq 'db' ) {
		for(@tabs) {
			s/\..*//;
		}
        $search = new Vend::DbSearch;
#::logDebug("created DbSearch object: " . ::uneval_it($search));
	}
	else {
        $search = new Vend::TextSearch;
#::logDebug("created TextSearch object: " . ::uneval_it($search));
    }

	my %fh;
	my $i = 0;
	%nh = map { (lc $_, $i++) } @na;
	$i = 0;
	%fh = map { ($_, $i++) } @{$spec->{fn}};

#::logDebug("field hash: " . Vend::Util::uneval_it(\%fh)); 
	for ( qw/rf sf/ ) {
		next unless defined $spec->{$_};
		map { $_ = $fh{$_} } @{$spec->{$_}};
	}

	if($update) {
		$opt->{row_count} = 1;
		die "Reached update query without object"
			if ! $s;
#::logDebug("Update operation is $update, sub=$sub");
		die "Bad row settor for columns @na"
			if ! $sub;
		if($update eq 'INSERT') {
			$sub->(@vals);
			$ref = [[ $vals[0] ]];
		}
		else {
			$ref = $search->array($spec);
			for(@$ref) {
#::logDebug("returned =" . uneval($_) . ", update values: " . uneval(\@vals));
				$sub->($_->[0], @vals);
			}
		}
	}
	elsif ($opt->{hashref}) {
		$ref = $Vend::Interpolate::Tmp->{$opt->{hashref}} = $search->hash($spec);
	}
	else {
#::logDebug(	" \$Vend::Interpolate::Tmp->{$opt->{arrayref}}");
		$ref = $Vend::Interpolate::Tmp->{$opt->{arrayref} || ''}
			 = $search->array($spec);
		$opt->{object} = $search;
		$opt->{prefix} = 'sql' unless defined $opt->{prefix};
	}
};
#::logDebug("search spec: " . Vend::Util::uneval($spec));
#::logDebug("name hash: " . Vend::Util::uneval(\%nh));
#::logDebug("ref returned: " . substr(Vend::Util::uneval($ref), 0, 100));
#::logDebug("opt is: " . Vend::Util::uneval($opt));
	if($@) {
		$s->log_error(
				"MVSQL query failed for %s: %s\nquery was: %s",
				$opt->{table},
				$@,
				$query,
			);
		$return = $opt->{failure} || undef;
	}

	if($opt->{search_label}) {
		$::Instance->{SearchObject}{$opt->{search_label}} = {
			mv_results => $ref,
			mv_field_names => \@na,
		};
	}

	if ($opt->{row_count}) {
		my $rc = $ref ? scalar @$ref : 0;
		return $rc unless $opt->{list};
		$ref = [ [ $rc ] ];
		@na = [ 'row_count' ];
		%nh = ( 'rc' => 0, 'count' => 0, 'row_count' => 0 );
	}

	return Vend::Interpolate::tag_sql_list($text, $ref, \%nh, $opt, \@na)
		if $opt->{list};
	return Vend::Interpolate::html_table($opt, $ref, \@na)
		if $opt->{html};
	return Vend::Util::uneval($ref)
		if $opt->{textref};
	return wantarray ? ($ref, \%nh, \@na) : $ref;
}

*import_quoted = *import_csv = \&import_ascii_delimited;

my %Sort = (

    ''  => sub { $a cmp $b              },
    none    => sub { $a cmp $b              },
    f   => sub { (lc $a) cmp (lc $b)    },
    fr  => sub { (lc $b) cmp (lc $a)    },
    n   => sub { $a <=> $b              },
    nr  => sub { $b <=> $a              },
    r   => sub { $b cmp $a              },
    rf  => sub { (lc $b) cmp (lc $a)    },
    rn  => sub { $b <=> $a              },
);

my $fafh;
sub file_access {
	my $function = shift;
	return <$fafh> 
}

sub import_ascii_delimited {
    my ($infile, $options, $table_name) = @_;
	my ($format, $csv);

	my $delimiter = quotemeta($options->{'delimiter'});

	if  ($delimiter eq 'CSV') {
		$csv = 1;
		$format = 'CSV';
	}
	elsif ($options->{CONTINUE}) {
		$format = uc $options->{CONTINUE};
	}
	else {
		$format = 'NONE';
	}

	my $realfile;
	if($options->{PRELOAD}) {
		if (-f $infile and $options->{PRELOAD_EMPTY_ONLY}) {
			# Do nothing, no preload
		}
		else {
			$realfile = -f $infile ? $infile : '';
			$infile = $options->{PRELOAD};
			$infile = "$Global::VendRoot/$infile" if ! -f $infile;
			($infile = $realfile, undef $realfile) if ! -f $infile;
		}
	}

	if(! defined $realfile) {
		open(IN, "+<$infile")
			or die errmsg("%s %s: %s\n", errmsg("open read/write"), $infile, $!);
		lockfile(\*IN, 1, 1)
			or die errmsg("%s %s: %s\n", errmsg("lock"), $infile, $!);
	}
	else {
		open(IN, "<$infile")
			or die errmsg("%s %s: %s\n", errmsg("open"), $infile, $!);
	}

	new_filehandle(\*IN);

	my $field_hash;
	my $para_sep;
	my $codere = '[\w-_#/.]+';
	my $idx = 0;

	my($field_count, @field_names);
	
	if($options->{hs}) {
		my $i = 0;
		<IN> while $i++ < $options->{hs};
	}
	if($options->{field_names}) {
		@field_names = @{$options->{field_names}};

		# This pulls COLUMN_DEF out of a field name
		# remains in ASCII file, though
		separate_definitions($options,\@field_names);

		if($options->{CONTINUE} eq 'NOTES') {
			$para_sep = $options->{NOTES_SEPARATOR} ||$options->{SEPARATOR} || "\f";
			$field_hash = {};
			for(@field_names) {
				$field_hash->{$_} = $idx++;
			}
			$idx = $#field_names;
		}
	}
	else {
		my $field_names;
		if ($csv) {
			@field_names = read_quoted_fields(\*IN);
		}
		else {
			$field_names = <IN>;
			chomp $field_names;
			$field_names =~ s/\s+$// unless $format eq 'NOTES';
			@field_names = split(/$delimiter/, $field_names);
		}

		# This pulls COLUMN_DEF out of a field name
		# remains in ASCII file, though
		separate_definitions($options,\@field_names);

#::logDebug("field names: @field_names");
		if($format eq 'NOTES') {
			$field_hash = {};
			for(@field_names) {
				s/:.*//;	
				if(/\S[ \t]+/) {
					die "Only one notes field allowed in NOTES format.\n"
						if $para_sep;
					$para_sep = $_;
					$_ = '';
				}
				else {
					$field_hash->{$_} = $idx++;
				}
			}
			my $msg;
			@field_names = grep $_, @field_names;
			$para_sep =~ s/($codere)[\t ]*(.)/$2/;
			push(@field_names, ($1 || 'notes_field'));
			$idx = $#field_names;
			$para_sep = $options->{NOTES_SEPARATOR} || "\f";
		}
	}

	local($/) = "\n" . $para_sep ."\n"
		if $para_sep;

	$field_count = scalar @field_names;

	no strict 'refs';
    my $out;
	if($options->{ObjectType}) {
		$out = &{"$options->{ObjectType}::create"}(
									$options->{ObjectType},
									$options,
									\@field_names,
									$table_name,
								);
	}
	else {
		$out = $options->{Object};
	}

	if(! $out) {
		die errmsg(q{No database object for table: %s

Probable mismatch of Database directive to database type,
for example calling DBI without proper modules or database
access.
},
					$table_name,
					);
	}
	my $fields;
    my (@fields, $key);
	my @addl;
	my $excel = '';
	my $excel_addl = '';

	if($options->{EXCEL}) {
	#Fix for quoted includes supplied by Larry Lesczynski
		$excel = <<'EndOfExcel';
			if(/"[^\t]*(?:,|"")/) {
				for (@fields) {
					next unless /[,"]/;
					s/^"//;
					s/"$//;
					s/""/"/g;
				}
			}
EndOfExcel
		$excel_addl = <<'EndOfExcel';
			if(/"[^\t]*(?:,|"")/) {
				for (@addl) {
					next unless /,/;
					s/^"//;
					s/"$//;
				}
			}
EndOfExcel
	}
	
	my $index = '';
	my @fh; # Array of file handles for sort
	my @fc; # Array of file handles for copy when symlink fails
	my @i;  # Array of field names for sort
	my @o;  # Array of sort options
	my %comma;
	if($options->{INDEX} and ! $options->{NO_ASCII_INDEX}) {
		my @f; my $f;
		my @n;
		my $i;
		@f = @{$options->{INDEX}};
		foreach $f (@f) {
			my $found = 0;
			$i = 0;
			if( $f =~ s/:(.*)//) {
				my $option = $1;
				push @o, $1;
			}
			elsif (exists $options->{INDEX_OPTIONS}{$f}) {

				push @o, $options->{INDEX_OPTIONS}{$f};
			}
			else {
				push @o, '';
			}
			for(@field_names) {
				if($_ eq $f) {
					$found++;
					push(@i, $i);
					push(@n, $f);
					last;
				}
				$i++;
			}
			(pop(@o), next) unless $found;
		}
		if(@i) {
			require IO::File;
			my $fh;
			my $f_string = join ",", @i;
			@f = ();
			for($i = 0; $i < @i; $i++) {
				my $fnum = $i[$i];
				$fh = new IO::File "> $infile.$i[$i]";
				die errmsg("%s %s: %s\n", errmsg("create"), "$infile.$i[$i]",
				$!) unless defined $fh;

				new_filehandle($fh);

				eval {
					unlink "$infile.$n[$i]" if -l "$infile.$n[$i]";
					symlink "$infile.$i[$i]", "$infile.$n[$i]";
				};
				push @fc, ["$infile.$i[$i]", "$infile.$n[$i]"]
					if $@;
				push @fh, $fh;
				if($o[$i] =~ s/c//) {
					$index .= <<EndOfIndex;
			map { print { \$fh[$i] } "\$_\\t\$fields[0]\\n" } split /\\s*,\\s*/, \$fields[$fnum];
EndOfIndex
				}
				elsif($o[$i] =~ s/s//) {
					$index .= <<EndOfIndex;
			map { print { \$fh[$i] } "\$_\\t\$fields[0]\\n" } split /\\s*;\\s*/, \$fields[$fnum];
EndOfIndex
				}
				else {
					$index .= <<EndOfIndex;
			print { \$fh[$i] } "\$fields[$fnum]\\t\$fields[0]\\n";
EndOfIndex
				}
			}
		}
	}

	my $numeric_guess = '';
	my $numeric_clean = '';
	my %non_numeric;
	my @empty;
	my @possible;
	my $clean;

	if($options->{GUESS_NUMERIC} and $options->{type} ne '8') {
		@possible = (0 .. $#field_names);
		@empty = map { 1 } (0 .. $#field_names);
		
		$numeric_guess = <<'EOF';
			for (@possible) {
				($empty[$_] = 0, next) if $fields[$_] =~ /^-?\d+\.?\d*$/;
				next if $empty[$_] && ! length($fields[$_]);
				$empty[$_] = undef;
				$clean = 1;
				$non_numeric{$_} = 1;
			}
EOF
		$numeric_clean = <<'EOF';
			next unless $clean;
			undef $clean;
			@possible = grep ! $non_numeric{$_}, @possible;
			%non_numeric = ();
EOF
	}

my %format = (

	NOTES => <<EndOfRoutine,
        while (<IN>) {
            chomp;
			\@fields = ();
			s/\\r?\\n\\r?\\n([\\000-\\377]*)//
				and \$fields[$idx] = \$1;

			while(s!($codere):[ \\t]*(.*)\\n?!!) {
				next unless defined \$field_hash->{\$1};
				\$fields[\$field_hash->{\$1}] = \$2;
			}
			$index
			$numeric_guess
            \$out->set_row(\@fields);
			$numeric_clean
        }
EndOfRoutine

	LINE => <<EndOfRoutine,
        while (<IN>) {
            chomp;
			\$fields = \@fields = split(/$delimiter/, \$_, $field_count);
			$index
			push (\@fields, '') until \$fields++ >= $field_count;
			$numeric_guess
            \$out->set_row(\@fields);
			$numeric_clean
        }
EndOfRoutine

	CSV => <<EndOfRoutine,
		while (\@fields = read_quoted_fields(\\*IN)) {
            \$fields = scalar \@fields;
			$index
            push (\@fields, '') until \$fields++ >= $field_count;
			$numeric_guess
            \$out->set_row(\@fields);
			$numeric_clean
        }
EndOfRoutine

	NONE => <<EndOfRoutine,
        while (<IN>) {
            chomp;
            \$fields = \@fields = split(/$delimiter/, \$_, 99999);
			$excel
			$index
            push (\@fields, '') until \$fields++ >= $field_count;
			$numeric_guess
            \$out->set_row(\@fields);
			$numeric_clean
        }
EndOfRoutine

	UNIX => <<EndOfRoutine,
        while (<IN>) {
            chomp;
			if(s/\\\\\$//) {
				\$_ .= <IN>;
				redo;
			}
			elsif (s/<<(\\w+)\$//) {
				my \$mark = \$1;
				my \$line = \$_;
				\$line .= Vend::Config::read_here(\\*IN, \$mark);
				\$_ = \$line;
				redo;
			}

            \$fields = \@fields = split(/$delimiter/, \$_, 99999);
			$excel
			$index
            push (\@fields, '') until \$fields++ >= $field_count;
			$numeric_guess
            \$out->set_row(\@fields);
			$numeric_clean
        }
EndOfRoutine

	DITTO => <<EndOfRoutine,
        while (<IN>) {
            chomp;
			if(/^$delimiter/) {
				\$fields = \@addl = split /$delimiter/, \$_, 99999;
				shift \@addl;
				$excel_addl
				my \$i;
				for(\$i = 0; \$i < \@addl; \$i++) {
					\$fields[\$i] .= "\n\$addl[\$i]"
						if \$addl[\$i] ne '';
				}
			}
			else {
				\$fields = \@fields = split(/$delimiter/, \$_, 99999);
				$excel
				$index
				push (\@fields, '') until \$fields++ >= $field_count;
			}
			$numeric_guess
            \$out->set_row(\@fields);
			$numeric_clean
        }
EndOfRoutine

);

    eval $format{$format};
	die errmsg("%s import into %s failed: %s", $options->{name}, $options->{table}, $@) if $@;
    if($realfile) {
		close IN
			or die errmsg("%s %s: %s\n", errmsg("close"), $infile, $!);
		if(-f $realfile) {
			open(IN, "+<$realfile")
				or die
					errmsg("%s %s: %s\n", errmsg("open read/write"), $realfile, $!);
			lockfile(\*IN, 1, 1)
				or die errmsg("%s %s: %s\n", errmsg("lock"), $realfile, $!);
			new_filehandle(\*IN);
			<IN>;
			eval $format{$format};
			die errmsg("%s %s: %s\n", errmsg("import"), $options->{name}, $!) if $@;
		}
		elsif (! open(IN, ">$realfile") && new_filehandle(\*IN) ) {
				die errmsg("%s %s: %s\n", errmsg("create"), $realfile, $!);
		} 
		else {
			print IN join($options->{DELIMITER}, @field_names);
			print IN $/;
			close IN;
		}
	}
	if(@fh) {
		my $no_sort;
		my $sort_sub;
		my $ftest = Vend::Util::catfile($Vend::Cfg->{ScratchDir}, 'sort.test');
		my $cmd = "echo you_have_no_sort_but_we_will_cope | sort -f -n -o $ftest";
		system $cmd;
		$no_sort = 1 if ! -f $ftest;
		
		my $fh;
		my $i;
		for ($i = 0; $i < @fh; $i++) {
			close $fh[$i] or die "close: $!";
			unless ($no_sort) {
				$o[$i] = "-$o[$i]" if $o[$i];
				$cmd = "sort $o[$i] -o $infile.$i[$i] $infile.$i[$i]";
				system $cmd;
			}
			else {
				$fh = new IO::File "$infile.$i[$i]";
				new_filehandle($fh);
				my (@lines) = <$fh>;
				close $fh or die "close: $!";
				my $option = $o[$i] || 'none';
				@lines = sort { &{$Sort{$option}} } @lines;
				$fh = new IO::File ">$infile.$i[$i]";
				new_filehandle($fh);
				print $fh @lines;
				close $fh or die "close: $!";
			}
		}
	}
	if(@fc) {
		require File::Copy;
		for(@fc) {
			File::Copy::copy(@{$_});
		}
	}

	unless($options->{no_commit}) {
		$out->commit() if $out->config('HAS_TRANSACTIONS');
	}
	delete $out->[$CONFIG]{Clean_start};
	delete $out->[$CONFIG]{_Dirty};
	unlockfile(\*IN) or die "unlock\n";
    close(IN);
	my $dot = $out->[$CONFIG]{HIDE_AUTO_FILES} ? '.' : '';
	if($numeric_guess) {
		my $fn = Vend::Util::catfile($out->[$CONFIG]{DIR}, "$dot$out->[$CONFIG]{file}");
		Vend::Util::writefile(
					">$fn.numeric",
					join " ", map { $field_names[$_] } @possible,
		);
	}
    return $out;
}

sub import_from_ic_db {
    my ($infile, $options, $table_name) = @_;

	my $tname = $options->{MIRROR}
		or die errmsg(
				"Memory mirror table not specified for table %s.",
				$table_name,
			);
#::logDebug("Importing mirrored $table_name from $tname");

	$Vend::Database{$tname} =
		Vend::Data::import_database($Vend::Cfg->{Database}{$tname})
			unless $Vend::Database{$tname};

	my $idb = Vend::Data::database_exists_ref($tname)
		or die errmsg(
				"Memory mirror table %s does not exist (yet) to create mirror %s.\n",
				$tname,
				$table_name,
			);

	my @field_names = $idb->columns;

	my $odb;

	if($options->{ObjectType}) {
		no strict 'refs';
		$odb = &{"$options->{ObjectType}::create"}(
									$options->{ObjectType},
									$options,
									\@field_names,
									$table_name,
								);
	}
	else {
		$odb = $options->{Object};
	}

#::logDebug("idb=$idb odb=$odb");
	eval {
		my $f;
		while($f = $idb->each_nokey($options->{MIRROR_QUAL})) {
#::logDebug("importing key=$f->[0]");
			$odb->set_row(@$f);
		}
	};

	if($@) {
		die errmsg(
				"Problem with mirror import from source %s to target %s\n",
				$tname,
				$table_name,
				);
	}
	
	$odb->[$CONFIG]{Mirror_complete} = 1;
	delete $odb->[$CONFIG]{Clean_start};
    return $odb;
}

my $white = ' \t';

sub read_quoted_fields {
    my ($filehandle) = @_;
    local ($_, $.);
    while(<$filehandle>) {
        s/[\r\n\cZ]+$//g;           # ms-dos cruft
        next if m/^[$white]*$/o;     # skip blank lines
        my @f = parse($_, $.);
#::logDebug("read: '" . join("','", @f) . "'");
        return parse($_, $.);
    }
    return ();
}

sub parse {
    local $_ = $_[0];
    my $linenum = $_[1];

    my $expect = 1;
    my @a = ();
    my $x;
    while ($_ ne '') {
        if    (m# \A ([$white]+) (.*) #ox) { }
        elsif (m# \A (,[$white]*) (.*) #ox) {
            push @a, '' if $expect;
            $expect = 1;
        }
        elsif (m# \A ([^",$white] (?:[$white]* [^,$white]+)*) (.*) #ox) {
            push @a, $1;
            $expect = 0;
        }
        elsif (m# \A " ((?:[^"] | (?:""))*) " (?!") (.*) #x) {
            ($x = $1) =~ s/""/"/g;
            push @a, $x;
            $expect = 0;
        }
        elsif (m# \A " #x) {
            die "Unterminated quote at line $linenum\n";
        }
        else { die "Can't happen: '$_'" }
        $_ = $2;
    }
    $expect and push @a, '';
    return @a;
}

sub reset {
	undef $restrict;
}

sub errstr {
	return shift(@_)->[$CONFIG]{last_error};
}

sub log_error {
	my ($s, $tpl, @args) = @_;
	if($tpl =~ /^(prepare|execute)$/) {
		if(!@args) {
			$tpl = "Statement $tpl failed: %s";
		}
		elsif (@args == 1) {
			$tpl = "Statement $tpl failed: %s\nQuery was: %s";
		}
		else {
			$tpl = "Statement $tpl failed: %s\nQuery was: %s";
			$tpl .= "\nAdditional: %s" for (2 .. scalar(@args));
		}
		unshift @args, $DBI::errstr;
	}
	my $msg = errmsg($tpl, @args);
	my $ekey = 'table ' . $s->[$CONFIG]{name};
	my $cfg = $s->[$CONFIG];
	unless(defined $cfg->{LOG_ERROR_CATALOG} and ! $cfg->{LOG_CATALOG}) {
		logError($msg);
	}
	if($cfg->{LOG_ERROR_GLOBAL}) {
		logGlobal($msg);
	}
	if($Vend::admin or ! defined($cfg->{LOG_ERROR_SESSION}) or $cfg->{LOG_ERROR_SESSION}) {
		$Vend::Session->{errors} = {} unless CORE::ref($Vend::Session->{errors}) eq 'HASH';
		$Vend::Session->{errors}{$ekey} = $msg;
	}
	die $msg if $cfg->{DIE_ERROR};
	return $cfg->{last_error} = $msg;
}

sub new_filehandle {
	my $fh = shift;
	binmode($fh, ":utf8") if $::Variable->{MV_UTF8};
	return $fh;
}

1;

__END__
