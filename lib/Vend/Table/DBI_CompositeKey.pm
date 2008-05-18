# Vend::Table::DBI - Access a table stored in an DBI/DBD database
#
# $Id: DBI_CompositeKey.pm,v 1.14 2008-05-18 02:50:21 jon Exp $
#
# Copyright (C) 2002-2008 Interchange Development Group
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

package Vend::Table::DBI_CompositeKey;
$VERSION = substr(q$Revision: 1.14 $, 10);

use strict;

# 0: dummy open object
# 1: table name
# 2: key name
# 3: Configuration hash
# 4: Array of column names
# 5: database object
# 6: each reference (transitory)

use vars qw/
			$CONFIG
			$TABLE
			$KEY
			$NAME
			$TYPE
			$DBI
			$EACH
			$TIE_HASH
            %DBI_connect_cache
            %DBI_connect_count
            %DBI_connect_bad
		 /;

($CONFIG, $TABLE, $KEY, $NAME, $TYPE, $DBI, $EACH) = (0 .. 6);

$TIE_HASH = $DBI;

sub create {
    my ($class, $config, $columns, $tablename) = @_;
#::logDebug("DBI_CompositeKey trying create table $tablename");

	if(! $config->{COMPOSITE_KEY}) {
		die ::errmsg(
			"Class %s: requires COMPOSITE_KEY setting\n",
			$class,
		  );
	}

	if(! $config->{_Key_columns}) {
		my @keycols = grep length($_), split /[\s,\0]+/, $config->{COMPOSITE_KEY};
		$config->{_Key_columns} = \@keycols;
		$config->{_Key_where} = 'WHERE ';
		my $hash = {};

		my @what;
		for(@keycols) {
			push @what, "$_ = ?";
			$hash->{$_} = 1;
		}
		$config->{_Key_where} .= join " AND ", @what;
		$config->{_Key_is} = $hash;

		if($config->{KEY_SPLITTOR}) {
			$config->{_Key_splittor} = qr($config->{KEY_SPLITTOR});
		}
		else {
			$config->{_Key_splittor} = qr([\0,]);
		}
	}
	if(
		(! $config->{INDEX} or @{$config->{INDEX}} == 0)
		and
		! $config->{POSTCREATE}
	  )
	{
		my $fields = $config->{COMPOSITE_KEY};
		$fields =~ s/^\s+//;
		$fields =~ s/\s+$//;
		$fields =~ s/\s+/,/g;

		my $tabname = $config->{REAL_NAME} || $config->{name};
		$config->{POSTCREATE} = 
			["CREATE UNIQUE INDEX ${tabname}_index ON $tabname($fields)"];
#::logDebug("did POSTCREATE: $config->{POSTCREATE}");
	}

#::logDebug("open_table config=" . ::uneval($config));
	return Vend::Table::DBI::create($class, $config, $columns, $tablename);
}

sub open_table {
    my ($class, $config, $tablename) = @_;
#::logDebug("DBI_CompositeKey trying to open table $tablename");

	if(! $config->{COMPOSITE_KEY}) {
		die ::errmsg(
			"Class %s: requires COMPOSITE_KEY setting\n",
			$class,
		  );
	}

	if(! $config->{_Key_columns}) {
		my @keycols = grep length($_), split /[\s,\0]+/, $config->{COMPOSITE_KEY};
		$config->{_Key_columns} = \@keycols;
		$config->{_Key_where} = 'WHERE ';
		my $hash = {};

		my @what;
		for(@keycols) {
			push @what, "$_ = ?";
			$hash->{$_} = 1;
		}
		$config->{_Key_where} .= join " AND ", @what;
		$config->{_Key_is} = $hash;

		if($config->{KEY_SPLITTOR}) {
			$config->{_Key_splittor} = qr($config->{KEY_SPLITTOR});
		}
		else {
			$config->{_Key_splittor} = qr([\0,]);
		}
	}

#::logDebug("open_table config=" . ::uneval($config));
	return Vend::Table::DBI::open_table($class, $config, $tablename);
}

sub new {
	my ($class, $obj) = @_;
	$obj->{type} = 11;
#::logDebug("DBI_CompositeKey new object of" . ::uneval($obj));
	bless [$obj], $class;
}

sub key_values {
	my $s = shift;
	my $key = shift;

	my @key;

	if(ref($key) eq 'HASH') {
		for(@{$s->[$CONFIG]{_Key_columns}}) {
			push @key, $key->{$_};
		}
	}
	elsif(! ref($key)) {
		@key = split $s->[$CONFIG]{_Key_splittor}, $key;
	}
	else {
		@key = @$key;
	}
#::logDebug("DBI_CompositeKey keys = " . ::uneval(\@key));
	return @key;
}

sub autonumber { return '' }

sub inc_field {
    my ($s, $key, $column, $value) = @_;
	$s = $s->import_db() if ! defined $s->[$DBI];
	$column = $s->[$NAME][ $s->column_index($column) ]; 

	my @key = $s->key_values($key);

	my $q1 = "select $column from $s->[$TABLE] $s->[$CONFIG]->{_Key_where}";
	my $q2 = "update $s->[$TABLE] set $column = ? $s->[$CONFIG]->{_Key_where}";
    my $sth1 = $s->[$DBI]->prepare($q1)
		or $s->log_error("%s query (%s) failed: %s", 'inc_field', $q1, $DBI::errstr)
		and return undef;
    my $sth2 = $s->[$DBI]->prepare($q2)
		or $s->log_error("%s query (%s) failed: %s", 'inc_field', $q2, $DBI::errstr)
		and return undef;
    $sth1->execute(@key)
		or $s->log_error("%s query (%s) failed: %s", 'inc_field', $q1, $DBI::errstr)
		and return undef;
    $value += ($sth1->fetchrow_array)[0];
    $sth2->execute($value, @key)
		or $s->log_error("%s query (%s) failed: %s", 'inc_field', $q2, $DBI::errstr)
		and return undef;
    $value;
}

sub field_accessor {
    my ($s, $column) = @_;
	$s = $s->import_db() if ! defined $s->[$DBI];
	$column = $s->[$NAME][ $s->column_index($column) ]; 
	my $q = "select $column from $s->[$TABLE] $s->[$CONFIG]{_Key_where}";
	my $sth = $s->[$DBI]->prepare($q)
		or $s->log_error("field_accessor statement (%s) -- bad result.", $q)
		and return undef;
#::logDebug("binding sub to $q");
    return sub {
        my ($key) = @_;
		my @key = $s->key_values($key);
		$sth->execute(@key);
        my ($return) = $sth->fetchrow_array();
		return $return;
    };
}

sub clone_row {
	my ($s, $old, $new, $change) = @_;
#::logDebug("called clone_row old=$old new=$new change=$change");
	$s = $s->ref();
	my @old = $s->key_values($old);
	return undef unless $s->record_exists(@old);
	my @ary = $s->row(@old);
#::logDebug("called clone_row ary=" . join "|", @ary);
	if($change and ref $change) {
		for (keys %$change) {
			my $pos = $s->column_index($_) 
				or next;
			$ary[$pos] = $change->{$_};
		}
	}
	my @new = $s->key_values($new);
	for(@{$s->[$CONFIG]{_Key_columns}}) {
		my $i = $s->column_index($_);
		$ary[$i] = shift @new;
	}
	$ary[$s->[$CONFIG]{KEY_INDEX}] = $new;
#::logDebug("called clone_row now=" . join "|", @ary);
	my $k = $s->set_row(@ary);
#::logDebug("cloned, key=$k");
	return $k;
}

sub clone_set {

	#### Can't yet be used
	my ($s, $col, $old, $new) = @_;
#::logDebug("called clone_set col=$col old=$old new=$new");
	return unless $s->column_exists($col);
	my $sel = $s->quote($old, $col);
	my $name = $s->[$CONFIG]{name};
	my ($ary, $nh, $na) = $s->query("select * from $name where $col = $sel");
	my $fpos = $nh->{$col} || return undef;
	$s->config('AUTO_NUMBER', '000001') unless $s->config('AUTO_NUMBER');
	for(@$ary) {
		my $line = $_;
		$line->[$s->[$CONFIG]{KEY_INDEX}] = '';
		$line->[$fpos] = $new;
		my $k = $s->set_row(@$line);
#::logDebug("cloned, key=$k");
	}
	return $new;
}

sub get_slice {
    my ($s, $key, $fary) = @_;
	$s = $s->import_db() if ! defined $s->[$DBI];

	my $tkey;
	my $sql;
	my @key = $s->key_values($key);
#::logDebug("key values for get_slice=" . ::uneval(\@key));
	return undef unless $s->record_exists(\@key);

#::logDebug("tkey now $tkey");

	# Better than failing on a bad ref...
	if(ref $fary ne 'ARRAY') {
		shift; shift;
		$fary = [ @_ ];
	}

	my $fstring = join ",", @$fary;
	$sql = "SELECT $fstring from $s->[$TABLE] $s->[$CONFIG]{_Key_where}";

#::logDebug("get_slice query: $sql");
#::logDebug("get_slice key/fields:\nkey=$key\n" . ::uneval($fary));
	my $sth;
	my $ary;
	eval {
		$sth = $s->[$DBI]->prepare($sql)
			or die ::errmsg("prepare %s: %s", $sql, $DBI::errstr);
		$sth->execute(@key);
	};

	if($@) {
		my $msg = $@;
		$s->log_error("failed %s::%s routine: %s", __PACKAGE__, 'get_slice', $msg);
		return undef;
	}

	return wantarray ? $sth->fetchrow_array() : $sth->fetchrow_arrayref();
}

sub set_slice {
    my ($s, $key, $fin, $vin) = @_;
	my ($fary, $vary);
	
	$s = $s->import_db() if ! defined $s->[$DBI];

    if($s->[$CONFIG]{Read_only}) {
		$s->log_error(
			"Attempt to set slice of %s in read-only table %s",
			$key,
			$s->[$CONFIG]{name},
		);
		return undef;
	}

	my $opt;
	if (ref ($key) eq 'ARRAY' && ref ($key->[0]) eq 'HASH') {
		$opt = shift @$key;
		$key = shift @$key;
	}
	$opt ||= {};

	$opt->{dml} = 'upsert'
		unless defined $opt->{dml};

	my @key;
	my $exists;
	if($key) {
		@key = $s->key_values($key);
		$exists = $s->record_exists($key);
	}

	my $sql;

	if (ref $fin eq 'ARRAY') {
		$fary = [@$fin];
		$vary = [@$vin];
	}
	elsif (ref $fin eq 'HASH') {
		my $href = { %$fin };

		if(! $key) {
			@key = ();
			for( @{$s->[$CONFIG]{_Key_columns}} ) {
				push @key, delete $href->{$_};
			}
			$key = \@key;
			$exists = $s->record_exists(\@key);
		}

		$vary = [ values %$href ];
		$fary = [ keys   %$href ];
	}

	if(! $key) {
		for my $kp (@{$s->[$CONFIG]{_Key_columns}}) {
			my $idx;
			my $i = -1;
			for(@$fary) {
				$i++;
				next unless $_ eq $kp;
				$idx = $i;
				last;
			}
			if(! defined $idx) {
				my $caller = caller();
				$s->log_error(
					'%s error as called by %s: %s',
					'set_slice',
					$caller,
					'unable to find key in field array',
				);
				return undef;
			}
			push @key, $vary->[$idx];
		}
#::logDebug("No key, key now=" . ::uneval(\@key));
		$exists = $s->record_exists(\@key);
	}

	if ($s->[$CONFIG]->{PREFER_NULL}) {
		my $prefer_null = $s->[$CONFIG]->{PREFER_NULL};
		my $i = 0;
		for (@$fary) {
			undef $vary->[$i]
				if exists $prefer_null->{$_} and $vary->[$i] eq '';
			++$i;
		}
	}

    if($s->[$CONFIG]->{LENGTH_EXCEPTION_DEFAULT}) {

		my $lcfg   = $s->[$CONFIG]{FIELD_LENGTH_DATA}
			or $s->log_error("No field length data with LENGTH_EXCEPTION defined!")
			and return undef;

		for (my $i=0; $i < @$fary; $i++){
			next unless defined $lcfg->{$fary->[$i]};

			$vary->[$i] = $s->length_exception($fary->[$i], $vary->[$i])
				if length($vary->[$i]) > $lcfg->{$fary->[$i]}{LENGTH};

		}
    }

	my $force_insert =
		$opt->{dml} eq 'insert';
	my $force_update =
		$opt->{dml} eq 'update';

	if ( $force_update or !$force_insert and $exists ) {
		unless (@$fary) {
			# as there are no data columns, we can safely skip the update
			return $key;
		}
		my $fstring = join ",", map { "$_=?" } @$fary;
		$sql = "update $s->[$TABLE] SET $fstring $s->[$CONFIG]{_Key_where}";
	}
	else {
		my $found;
		my %found;
		for(my $i = 0; $i < @$fary; $i++) {
			next unless $s->[$CONFIG]{_Key_is}{$fary->[$i]};
			$found{$fary->[$i]} = 1;
		}

		for(@{$s->[$CONFIG]{_Key_columns}}) {
			if($found{$_}) {
				shift(@key);
			}
			else {
				unshift @$fary, $_;
				unshift @$vary, shift(@key);
			}
		}
		my $fstring = join ",", @$fary;
		my $vstring = join ",", map {"?"} @$vary;
		$sql = "insert into $s->[$TABLE] ($fstring) VALUES ($vstring)";
	}

#::logDebug("exists=$exists set_slice query: $sql");
#::logDebug("set_slice key/fields/values:\nkey=$key\n" . ::uneval($fary, $vary));

	my $val;
	eval {
		my $sth = $s->[$DBI]->prepare($sql)
			or die ::errmsg("prepare %s: %s", $sql, $DBI::errstr);
		my $rc = $sth->execute(@$vary,@key)
			or die ::errmsg("execute %s: %s", $sql, $DBI::errstr);

		$val = $key;
	};

#::logDebug("set_slice key: $val");

	if($@) {
		my $caller = caller();
		$s->log_error(
			"%s error as called by %s: %s\nquery was:%s\nvalues were:'%s'",
			'set_slice',
			$caller,
			$@,
			$sql,
			join("','", @$vary),
		);
		return undef;
	}

	return $val;
}

sub set_row {
    my ($s, @fields) = @_;
	$s = $s->import_db() if ! defined $s->[$DBI];
	my $cfg = $s->[$CONFIG];
	my $ki = $cfg->{KEY_INDEX};

	$s->filter(\@fields, $s->[$CONFIG]{COLUMN_INDEX}, $s->[$CONFIG]{FILTER_TO})
		if $cfg->{FILTER_TO};

	if ($cfg->{PREFER_NULL}) {
		for (keys %{$cfg->{PREFER_NULL}}) {
			my $i = $cfg->{COLUMN_INDEX}{$_};
			undef $fields[$i] if $fields[$i] eq '';
		}
	}

	my $val;

	my @key;
	my @vals;
	my @flds;
	my $force_key;

	if(scalar @fields == 1) {
		$force_key = 1;
		@key = $s->key_values($fields[0]);
		for(@{$cfg->{_Key_columns}}) {
			$vals[$s->column_index($_)] = shift @key;
		}
	}
	else {
		for(@{$cfg->{_Key_columns}}) {
			push @key, $fields[$s->column_index($_)];
		}
	}

	if($force_key) {
		my $key_string;
		my $val_string;
		my $ary;
		if($cfg->{_Default_ary} || $cfg->{_Default_session_ary}) {
			my $ary = $cfg->{_Default_ary} || [];
			my $sary = $cfg->{_Default_session_ary} || [];
			my $max = $#$ary > $#$sary ? $#$ary : $#$sary;
			for (my $i = 0; $i <= $max; $i++) {
				if($sary->[$i] and ! defined $vals[$i]) {
					push @flds, $s->[$NAME][$i];
					$vals[$i] = $sary->[$i]->($s);
					next;
				}
				next unless defined $ary->[$i];
				$flds[$i] = $s->[$NAME][$i];
				$vals[$i] = $ary->[$i];
			}
		}
		my @f;
		my @v;
		for( my $i = 0; $i < @flds; $i++) {
			next unless $flds[$i];
			push @f, $flds[$i];
			push @v, $vals[$i];
		}
		$key_string = join ",", @f;
		$val_string = join ",", @v;
#::logDebug("def_ary query will be: insert into $s->[$TABLE] ($key_string) VALUES ($val_string)");
		eval {
			$s->delete_record(\@key);
			$s->[$DBI]->do("insert into $s->[$TABLE] ($key_string) VALUES ($val_string)");
		};
		if($@) {
			my $caller = caller();
			$s->log_error(
				"%s error as called by %s: %s\nfields=%s\nvalues=%s",
				'set_row',
				$caller,
				$@,
				$key_string,
				$val_string,
			);
			return undef;
		}
		return \@key;
	}

	if (! $s->[$CONFIG]{Clean_start}) {
		eval {
			$s->delete_record(\@key);
		};
	}

#::logDebug("set_row fields='" . join(',', @fields) . "'" );
	if(! $cfg->{_Insert_h}) {
		my (@ins_mark);
		my $i = 0;
		for(@{$s->[$NAME]}) {
			push @ins_mark, '?';
			$i++;
		}
		my $fstring = '';

		my $ins_string = join ", ",  @ins_mark;
		my $query = "INSERT INTO $s->[$TABLE]$fstring VALUES ($ins_string)";
#::logDebug("set_row query=$query");
		$cfg->{_Insert_h} = $s->[$DBI]->prepare($query)
			or die $s->log_error(
							"%s error on %s: $DBI::errstr",
							'set_row',
							$query,
							$DBI::errstr,
							);
	}

#::logDebug("set_row fields='" . join(',', @fields) . "'" );
    $s->bind_entire_row($cfg->{_Insert_h}, @fields);

	my $rc = $cfg->{_Insert_h}->execute()
		or die $s->log_error("%s error: $DBI::errstr", 'set_row', $DBI::errstr);

#::logDebug("set_row rc=$rc key=" . ::uneval_it(\@key));
	return \@key;
}

sub last_sequence_value {
	die ::errmsg("No last_sequence_value with DBI_CompositeKey");
}

sub row {
    my ($s, $key) = @_;
	$s = $s->import_db() if ! defined $s->[$DBI];
	my $q = "select * from $s->[$TABLE] $s->[$CONFIG]{_Key_where}";
	my @key = $s->key_values($key);
    my $sth = $s->[$DBI]->prepare($q)
		or $s->log_error("%s prepare error for %s: %s", 'row', $q, $DBI::errstr)
		and return undef;
    $sth->execute(@key)
		or $s->log_error("%s execute error for %s: %s", 'row', $q, $DBI::errstr)
		and return undef;
	return @{ $sth->fetchrow_arrayref() || [] };
}

sub row_hash {
    my ($s, $key) = @_;
	$s = $s->import_db() if ! defined $s->[$DBI];
	my $q = "select * from $s->[$TABLE] $s->[$CONFIG]{_Key_where}";
	my @key = $s->key_values($key);
    my $sth = $s->[$DBI]->prepare($q)
		or $s->log_error("%s prepare error for %s: %s", 'row_hash', $q, $DBI::errstr)
		and return undef;
    $sth->execute(@key)
		or $s->log_error("%s execute error for %s: %s", 'row_hash', $q, $DBI::errstr)
		and return undef;

	return $sth->fetchrow_hashref()
		unless $s->[$TYPE];
	my $ref;
	if($s->config('UPPERCASE')) {
		my $aref = $sth->fetchrow_arrayref()
			or return undef;
		$ref = {};
		my @nm = @{$sth->{NAME}};
		for ( my $i = 0; $i < @$aref; $i++) {
			$ref->{$nm[$i]} = $ref->{lc $nm[$i]} = $aref->[$i];
		}
	}
	else {
		$ref = $sth->fetchrow_hashref();
	}
	return $ref unless $s->[$CONFIG]{FIELD_ALIAS};
	my ($k, $v);
	while ( ($k, $v) = each %{ $s->[$CONFIG]{FIELD_ALIAS} } ) {
		$ref->{$v} = $ref->{$k};
	}
	return $ref;
}

sub field_settor {
    my ($s, $column) = @_;
	$s = $s->import_db() if ! defined $s->[$DBI];
	my $q = "update $s->[$TABLE] SET $column = ? $s->[$CONFIG]{_Key_where}";
	my $sth = $s->[$DBI]->prepare($q)
		or $s->log_error("Unable to prepare query for field_settor: %s", $q)
		and return undef;
    return sub {
        my ($key, $value) = @_;
		my @key = $s->key_values($key);
        $sth->execute($value, @key);
    };
}

sub foreign {
	die "Foreign keys not supported for multiple-key database tables\n";
}

sub field {
    my ($s, $key, $column) = @_;
#::logDebug("Called DBI_CompositeKey field");
	$s = $s->import_db() if ! defined $s->[$DBI];
	my @key = $s->key_values($key);
	my $idx;
	if( $s->[$TYPE] and $idx = $s->column_index($column) )  {
		$column = $s->[$NAME][$idx];
	}
	my $query = "select $column from $s->[$TABLE] $s->[$CONFIG]{_Key_where}";
#::logDebug("DBI field: key=$key column=$column query=$query");
    my $sth;
	eval {
		$sth = $s->[$DBI]->prepare($query);
		$sth->execute(@key);
	};
	if($@) {
		$s->log_error("field: failed to execute %s", $query);
		return '';
	}
	my $data = ($sth->fetchrow_array())[0];
	return '' unless $data =~ /\S/;
	$data;
}

sub set_field {
    my ($s, $key, $column, $value) = @_;
	$s = $s->import_db() if ! defined $s->[$DBI];
    if($s->[$CONFIG]{Read_only}) {
		$s->log_error("Attempt to set %s in read-only table",
					"$s->[$CONFIG]{name}::${column}::$key",
					);
		return undef;
	}

	my $lcfg;
    if(
		$s->[$CONFIG]->{LENGTH_EXCEPTION_DEFAULT}
		and $s->[$CONFIG]{FIELD_LENGTH_DATA}
		and $lcfg = $s->[$CONFIG]{FIELD_LENGTH_DATA}{$column}
		and $lcfg->{LENGTH} < length($value)
		)
	{

		$value = $s->length_exception($column, $value);
    }


	my @key = $s->key_values($key);

	undef $value if $value eq '' and exists $s->[$CONFIG]{PREFER_NULL}{$column};

	$s->set_slice($key, [$column], [$value])
		and return $value;
	return undef;
}

sub ref {
	return $_[0] if defined $_[0]->[$DBI];
	return $_[0]->import_db();
}

sub test_record {
	1;
}

sub record_exists {
    my ($s, $key) = @_;
    $s = $s->import_db() if ! defined $s->[$DBI];
	my @key = $s->key_values($key);
    my $query;

	# Does any SQL allow empty key?
	return '' if ! length($key) and ! $s->[$CONFIG]{ALLOW_EMPTY_KEY};
	my $mainkey = $s->[$CONFIG]{_Key_columns}[0];
#::logDebug("record_exists for mainkey=$mainkey key=" . ::uneval(\@key));

    $query = $s->[$CONFIG]{Exists_handle}
        or
	    $query = $s->[$DBI]->prepare(
				"select $mainkey from $s->[$TABLE] $s->[$CONFIG]{_Key_where}"
			)
        and
		$s->[$CONFIG]{Exists_handle} = $query;
    my $status;
#::logDebug("record_exists query=$query");
    eval {
        $status = defined $s->[$DBI]->selectrow_array($query, undef, @key);
    };
    if($@) {
		$s->log_error("Bad execution of record_exists query");
		return undef;
	}
#::logDebug("record_exists status=$status");
    return $status;
}

sub delete_record {
    my ($s, $key) = @_;
	$s = $s->import_db() if ! defined $s->[$DBI];

    if($s->[$CONFIG]{Read_only}) {
		$s->log_error("Attempt to delete record '%s' from read-only database %s",
						$key,
						$s->[$CONFIG]{name},
						);
		return undef;
	}
	my @key = $s->key_values($key);
	my $sth = $s->[$DBI]->prepare("delete from $s->[$TABLE] $s->[$CONFIG]{_Key_where}");
	my $rc = $sth->execute(@key);
	return $rc > 0 ? $rc : 0;
}

*import_db = \&Vend::Table::DBI::import_db;
*suicide = \&Vend::Table::DBI::suicide;
*close_table = \&Vend::Table::DBI::close_table;
*dbh = \&Vend::Table::DBI::dbh;
*name = \&Vend::Table::DBI::name;
*columns = \&Vend::Table::DBI::columns;
*test_column = \&Vend::Table::DBI::test_column;
*quote = \&Vend::Table::DBI::quote;
*numeric = \&Vend::Table::DBI::numeric;
*filter = \&Vend::Table::DBI::filter;
*commit = \&Vend::Table::DBI::commit;
*rollback = \&Vend::Table::DBI::rollback;
*isopen = \&Vend::Table::DBI::isopen;
*column_index = \&Vend::Table::DBI::column_index;
*column_exists = \&Vend::Table::DBI::column_exists;
*bind_entire_row = \&Vend::Table::DBI::bind_entire_row;
*length_exception = \&Vend::Table::DBI::length_exception;
*fields_index = \&Vend::Table::DBI::fields_index;
*list_fields = \&Vend::Table::DBI::list_fields;
*touch = \&Vend::Table::DBI::touch;
*sort_each = \&Vend::Table::DBI::sort_each;
*each_record = \&Vend::Table::DBI::each_record;
*each_nokey = \&Vend::Table::DBI::each_nokey;
*sprintf_substitute = \&Vend::Table::DBI::sprintf_substitute;
*hash_query = \&Vend::Table::DBI::hash_query;
*query = \&Vend::Table::DBI::query;
*auto_config = \&Vend::Table::DBI::auto_config;
*config = \&Vend::Table::DBI::config;
*reset = \&Vend::Table::Common::reset;
*log_error = \&Vend::Table::Common::log_error;
*errstr = \&Vend::Table::Common::errstr;

1;

__END__
