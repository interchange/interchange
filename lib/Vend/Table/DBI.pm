# Table/DBI.pm: access a table stored in an DBI/DBD Database
#
# $Id: DBI.pm,v 1.25.2.2 2000-11-30 02:51:14 heins Exp $
#
# Copyright (C) 1996-2000 Akopia, Inc. <info@akopia.com>
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

package Vend::Table::DBI;
$VERSION = substr(q$Revision: 1.25.2.2 $, 10);

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
			$Set_handle
            %DBI_connect_cache
            %DBI_connect_count
		 /;

($CONFIG, $TABLE, $KEY, $NAME, $TYPE, $DBI, $EACH) = (0 .. 6);

$TIE_HASH = $DBI;

my %Cattr = ( qw(
					RAISEERROR     	RaiseError
					PRINTERROR     	PrintError
					AUTOCOMMIT     	AutoCommit
				) );
my @Cattr = keys %Cattr;

my %Dattr = ( qw(
					WARN			Warn
					CHOPBLANKS		ChopBlanks	
					COMPATMODE		CompatMode	
					INACTIVEDESTROY	InactiveDestroy	
					PRINTERROR     	PrintError
					RAISEERROR     	RaiseError
					AUTOCOMMIT     	AutoCommit
					LONGTRUNCOK    	LongTruncOk
					LONGREADLEN    	LongReadLen
				) );
my @Dattr = keys %Dattr;

sub find_dsn {
	my ($config) = @_;
	my($param, $value, $cattr, $dattr, @out);
	my($user,$pass,$dsn,$driver);
	my $i = 0;
	foreach $param (qw! DSN USER PASS !) {
		$out[$i++] = $config->{ $param } || undef;
	}

	my @other = grep defined $config->{$_}, @Dattr;
	
	if(@other) {
		$dattr = { };
		$cattr = { };
		for(@other) {
			$dattr->{$Dattr{$_}} = $config->{$_};
			$cattr->{$Cattr{$_}} = $config->{$_}
				if defined $Cattr{$_};
		}
	}
	
	$out[3] = $cattr || undef;
	$out[4] = $dattr || undef;
#::logDebug("out# = " . scalar(@out));
#::logDebug("out dump= " . ::uneval(\@out)) if $Vend::Cfg->{CatalogName} eq 'construct';
	@out;
}

sub config {
	my ($s, $key, $value) = @_;
	$s = $s->import_db() if ! defined $s->[$DBI];
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

my $Info;

my %known_capability = (
	AUTO_INDEX_PRIMARY_KEY => {
		Oracle	=> 1
	},
	HAS_LIMIT => {
		mysql	=> 1,
		Pg		=> 1,
		Oracle	=> 1,
	},
	ALTER_DELETE => { 
		mysql => 'ALTER TABLE _TABLE_ DROP _COLUMN_',
	},
	ALTER_CHANGE => { 
		mysql => 'ALTER TABLE _TABLE_ CHANGE COLUMN _COLUMN_ _COLUMN_ _DEF_',
	},
	ALTER_ADD	 => { 
		mysql => 'ALTER TABLE _TABLE_ ADD COLUMN _COLUMN_ _DEF_',
	},
);

sub check_capability {
	my ($config, $driver_name) = @_;
	return if $config->{_Checked_capability}++;

	my ($k, $known);
	while ( ($k, $known) = each %known_capability ) {
		if(! defined $config->{$k} ) {
#::logDebug("checking $driver_name cap $k: $known->{$driver_name}");
			$config->{$k} = $known->{$driver_name}
				if defined $known->{$driver_name};
		}
	}
}

sub create {
    my ($class, $config, $columns, $tablename) = @_;
#::logDebug("trying create table $tablename");
	my @call = find_dsn($config);
	my $dattr = pop @call;

	my $db;
	eval {
		$db = DBI->connect( @call );
	};
	if(! $db) {
		my $msg = $@ || $DBI::errstr;
		if(! $msg) {
			my($dname);
			(undef, $dname) = split /:+/, $config->{DSN};
			eval {
				DBI->install_driver($dname);
			};
			$msg = $@
					|| $DBI::errstr
					|| "unknown error. Driver '$dname' installed?";
		}
		die "connect failed (create) -- $msg\n";
	}

	if($config->{HANDLE_ONLY}) {
		return bless [$config, $tablename, undef, undef, undef, $db], $class;
	}

	check_capability($config, $db->{Driver}{Name});

    die "columns argument $columns is not an array ref\n"
        unless CORE::ref($columns) eq 'ARRAY';

	if(defined $dattr) {
		for(keys %$dattr) {
			$db->{$_} = $dattr->{$_};
		}
	}

    my ($i, $key, $keycol);
	my(@cols);

	$key = $config->{KEY} || $columns->[0];

	my $def_type = $config->{DEFAULT_TYPE} || 'char(128)';
#::logDebug("columns coming in: @{$columns}");
    for ($i = 0;  $i < @$columns;  $i++) {
        $cols[$i] = $$columns[$i];
#::logDebug("checking column '$cols[$i]'");
		if(defined $key) {
			$keycol = $i if $cols[$i] eq $key;
		}
		if(defined $config->{COLUMN_DEF}->{$cols[$i]}) {
			$cols[$i] .= " " . $config->{COLUMN_DEF}->{$cols[$i]};
		}
		else {
			$cols[$i] .= " $def_type";
		}
		$$columns[$i] = $cols[$i];
		$$columns[$i] =~ s/\s+.*//;
    }

	$keycol = 0 unless defined $keycol;
	$config->{KEY_INDEX} = $keycol;
	$config->{KEY} = $key;

	$cols[$keycol] =~ s/\s+.*/ char(16) NOT NULL/
			unless defined $config->{COLUMN_DEF}->{$key};

	my $query = "create table $tablename ( \n";
	$query .= join ",\n", @cols;
	$query .= "\n)\n";

	if($config->{CREATE_SQL}) {
#::logDebug("Trying to create with specified CREATE_SQL:\n$config->{CREATE_SQL}");
		$db->do($config->{CREATE_SQL})
			or die ::errmsg(
				"DBI: Create table '%s' failed, explicit CREATE_SQL. Error: %s\n",
				$tablename,
				$DBI::errstr,
				);
	}
	else {
		# test creation of table
		TESTIT: {
			my $q = $query;
			eval {
				$db->do("drop table ic_test_create")
			};
			$q =~ s/create\s+table\s+\S+/create table ic_test_create/;
			if(! $db->do($q) ) {
				::logError(
							"unable to create test table:\n%s\n\nError: %s",
							$query,
							$DBI::errstr,
				);
				warn "$DBI::errstr\n";
				return undef;
			}
			$db->do("drop table ic_test_create")
		}

		eval {
			$db->do("drop table $tablename")
				and $config->{Clean_start} = 1
				or warn "$DBI::errstr\n";
		};
	#::logDebug("Trying to create with:$query");
		$db->do($query)
			or warn "DBI: Create table '$tablename' failed: $DBI::errstr\n";
		::logError("table %s created: %s" , $tablename, $query );

	}

	if(ref $config->{POSTCREATE}) {
		for(@{$config->{POSTCREATE}} ) {
			$db->do($_) 
				or ::logError(
								"DBI: Post creation query '%s' failed: %s" ,
								$_,
								$DBI::errstr,
					);
		}
	} elsif ($config->{AUTO_INDEX_PRIMARY_KEY}) {
		# Oracle automatically creates indexes on primary keys,
		# so we don't need to do it again
	} else {
		$db->do("create index ${tablename}_${key} on $tablename ($key)")
			or ::logError("table %s index failed: %s" , $tablename, $DBI::errstr);
	}

	if($config->{GUESS_NUMERIC}) {
		list_fields($db, $tablename, $config);
	}

	$config->{NAME} = $columns;

    my $s = [$config, $tablename, $key, $columns, undef, $db];
    bless $s, $class;
}

sub new {
	my ($class, $obj) = @_;
	bless [$obj], $class;
}

sub open_table {
    my ($class, $config, $tablename) = @_;
	
	$config->{PRINTERROR} = 0 if ! defined $config->{PRINTERROR};
	$config->{RAISEERROR} = 1 if ! defined $config->{RAISEERROR};
    my @call = find_dsn($config);
    my $dattr = pop @call;
    my $db;

    if (! $config->{Read_only} and ! defined $config->{AutoNumberCounter}) {
		$config->{AutoNumberCounter} = new File::CounterFile
									"$config->{DIR}/$config->{name}.autonumber",
									$config->{AUTO_NUMBER} || '00001';
    }

	unless($config->{dsn_id}) {
		$config->{dsn_id} = join "_", @call;
    	if($Global::HotDBI->{$Vend::Cfg->{CatalogName}}) {
			$config->{hot_dbi} = 1;
			$DBI_connect_count{$config->{dsn_id}}++;
		}
	}
	unless ($db = $DBI_connect_cache{ $config->{dsn_id} }) {
#::logDebug("connecting to " . ::uneval(\@call));
		eval {
			$db = DBI->connect( @call );
		};
#::logDebug("DBI didn't die");
		if(! $db) {
			my $msg = $@ || $DBI::errstr;
			if(! $msg) {
				my($dname);
				(undef, $dname) = split /:+/, $config->{DSN};
				eval {
					DBI->install_driver($dname);
				};
				$msg = $@ || $DBI::errstr || "unknown error. Driver '$dname' installed?";
			}
			die "connect failed -- $msg\n";
		}
		$DBI_connect_cache{$config->{dsn_id}} = $db;
#::logDebug("connected to $config->{dsn_id}");
	}

	check_capability($config, $db->{Driver}{Name});

	if(! $Info and ($db->can('table_info') and $Info = $db->table_info()) ) {
#::logDebug("$tablename table_info: " . ::uneval($Info->fetchall_arrayref()));
	}

    unless ($config->{hot_dbi}) {
		$DBI_connect_count{$config->{dsn_id}}++;
	}
#::logDebug("connect count open: " . $DBI_connect_count{$config->{dsn_id}});

	die "$tablename: $DBI::errstr" unless $db;

	if($config->{HANDLE_ONLY}) {
		return bless [$config, $tablename, undef, undef, undef, $db], $class;
	}
	my $key;
	my $columns;

	if(defined $dattr) {
		for(keys %$dattr) {
			$db->{$_} = $dattr->{$_};
		}
	}

	if(! defined $config->{EXTENDED}) {
		$config->{NAME} = list_fields($db, $tablename, $config)
			if ! $config->{NAME};
		$config->{COLUMN_INDEX} = fields_index($config->{NAME}, $config)
			if ! $config->{COLUMN_INDEX};
		$config->{EXTENDED} =	defined($config->{FIELD_ALIAS}) 
							||	defined $config->{FILTER_FROM}
							||	defined $config->{FILTER_TO}
							||	$config->{UPPERCASE}
							||	'';
	}

	if($config->{GUESS_NUMERIC} and ! $config->{NUMERIC}) {
		list_fields($db, $tablename, $config);
	}

	$config->{NUMERIC} = {} unless $config->{NUMERIC};

	die "DBI: no column names returned for $tablename\n"
			unless defined $config->{NAME}[1];

	# Check if we have a non-first-column key
	if($config->{KEY}) {
		$key = $config->{KEY};
	}
	else {
		$key = $config->{KEY} = $config->{NAME}[0];
	}
	$config->{KEY_INDEX} = $config->{COLUMN_INDEX}{lc $key}
		if ! $config->{KEY_INDEX};
	die ::errmsg("Bad key specification: %s"  .
					::uneval($config->{NAME}) .
					::uneval($config->{COLUMN_INDEX}),
					$key
		)
		if ! defined $config->{KEY_INDEX};

    my $s = [$config, $tablename, $key, $config->{NAME}, $config->{EXTENDED}, $db];
	bless $s, $class;
}

sub close_table {
	my $s = shift;
	return 1 if ! defined $s->[$DBI];
	undef $s->[$CONFIG]{_Insert_h};
	undef $s->[$CONFIG]{Update_handle};
    undef $s->[$CONFIG]{Exists_handle};
    return 1 if $s->[$CONFIG]{hot_dbi};
#::logDebug("connect count close: " . ($DBI_connect_count{$s->[$CONFIG]->{dsn_id}} - 1));
	return 1 if --$DBI_connect_count{$s->[$CONFIG]->{dsn_id}} > 0;
	undef $DBI_connect_cache{$s->[$CONFIG]->{dsn_id}};
	$s->[$DBI]->disconnect();
}

sub columns {
	my ($s) = shift;
	$s = $s->import_db() if ! defined $s->[$DBI];
    return @{$s->[$NAME]};
}

sub test_column {
    my ($s, $column) = @_;
	$s = $s->import_db() if ! defined $s->[$DBI];
	return $s->[$CONFIG]->{COLUMN_INDEX}{lc $column};
}

sub quote {
	my($s, $value, $field) = @_;
	$s = $s->import_db() if ! defined $s->[$DBI];
	return $s->[$DBI]->quote($value)
		unless $field and $s->numeric($field);
	return $value;
}

sub numeric {
	return exists $_[0]->[$CONFIG]->{NUMERIC}->{$_[1]};
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

sub inc_field {
    my ($s, $key, $column, $value) = @_;
	$s = $s->import_db() if ! defined $s->[$DBI];
	$column = $s->[$NAME][ $s->column_index($column) ]; 
	$key = $s->[$DBI]->quote($key)
		unless exists $s->[$CONFIG]{NUMERIC}{$s->[$KEY]};
    my $sth = $s->[$DBI]->prepare(
		"select $column from $s->[$TABLE] where $s->[$KEY] = $key");
    die "inc_field: $DBI::errstr\n" unless defined $sth;
    $sth->execute();
    $value += ($sth->fetchrow_array)[0];
	#$value = $s->[$DBI]->quote($value, $column);
    $sth = $s->[$DBI]->do("update $s->[$TABLE] SET $column=$value where $s->[$KEY] = $key");
    $value;
}

sub column_index {
    my ($s, $column) = @_;
	$s = $s->import_db() if ! defined $s->[$DBI];
	return $s->[$CONFIG]{COLUMN_INDEX}{lc $column};
}

sub column_exists {
    my ($s, $column) = @_;
	$s = $s->import_db() if ! defined $s->[$DBI];
	return defined($s->[$CONFIG]{COLUMN_INDEX}{lc $column});
}

sub field_accessor {
    my ($s, $column) = @_;
	$s = $s->import_db() if ! defined $s->[$DBI];
	$column = $s->[$NAME][ $s->column_index($column) ]; 
	my $q = "select $column from $s->[$TABLE] where $s->[$KEY] = ?";
	my $sth = $s->[$DBI]->prepare($q)
		or die "field_accessor statement ($q) -- bad result.\n";
#::logDebug("binding sub to $q");
    return sub {
        my ($key) = @_;
		$sth->bind_param(1, $key);
		$sth->execute();
        my ($return) = $sth->fetchrow_array();
		return $return;
    };
}

sub bind_entire_row {
	my($s, $sth, $key, @fields) = @_;
#::logDebug("bind_entire_row=" . ::uneval(\@_));
	my $i;
	my $numeric = $s->[$CONFIG]->{NUMERIC};
	my $name = $s->[$NAME];
	my $j = 1;
	for($i = 0; $i < scalar @$name; $i++, $j++) {
#::logDebug("bind $j=$fields[$i]");
		$sth->bind_param(
			$j,
			$fields[$i],
			(! exists $numeric->{$name->[$i]} ? undef : DBI::SQL_INTEGER),
			);
	}
	$sth->bind_param(
			$j,
			$key,
			(! exists $numeric->{$name->[$i]} ? undef : DBI::SQL_INTEGER),
			)
		if $key;
	return;
}

sub add_column {
	my ($s, $column, $def) = @_;
	return $s->alter_column($column, $def, 'ALTER_ADD');
}

sub change_column {
	my ($s, $column, $def) = @_;
	return $s->alter_column($column, $def, 'ALTER_CHANGE');
}

sub delete_column {
	my ($s, $column, $def) = @_;
	return $s->alter_column($column, $def, 'ALTER_DELETE');
}

sub alter_column {
	my ($s, $column, $def, $function) = @_;
	$s = $s->import_db() if ! defined $s->[$DBI];
	$function = 'ALTER_CHANGE' unless $function;
	my $template = $s->config($function);
	if(! $template) {
		::logError(
			$s->config(
				'last_error',
				::errmsg(
					"No %s template defined for table %s. Skipping.",
					$function,
					$s->[$TABLE],
				),
			),
		);
		return undef;
	}

	if($function =~ /^(ALTER_CHANGE)$/ and ! $s->column_exists($column) ) {
		::logError(
			$s->config(
				'last_error',
				::errmsg(
					"Column '%s' doesn't exist in table %s. Skipping.",
					$column,
					$s->[$TABLE],
				),
			),
		);
		return undef;
	}

	$template =~ s/\b_TABLE_\b/$s->[$TABLE]/g;
	$template =~ s/\b_COLUMN_\b/$column/g;
	$template =~ s/\b_DEF_\b/$def/g;

	my $rc;
	eval {
		$rc = $s->[$DBI]->do($template);
	};

	if($@) {
		::logError(
			$s->config(
				'last_error',
				::errmsg(
					"'%s' failed. Error: %s",
					$template,
				),
			),
		);
		return undef;
	}

	return $rc;
}

sub clone_row {
	my ($s, $old, $new, $change) = @_;
#::logDebug("called clone_row old=$old new=$new change=$change");
	$s = $s->ref();
	return undef unless $s->record_exists($old);
	my @ary = $s->row($old);
#::logDebug("called clone_row ary=" . join "|", @ary);
	if($change and ref $change) {
		for (keys %$change) {
			my $pos = $s->column_index($_) 
				or next;
			$ary[$pos] = $change->{$_};
		}
	}
	$ary[$s->[$CONFIG]{KEY_INDEX}] = $new;
#::logDebug("called clone_row now=" . join "|", @ary);
	my $k = $s->set_row(@ary);
#::logDebug("cloned, key=$k");
	return $k;
}

sub clone_set {
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

sub set_row {
    my ($s, @fields) = @_;
	$s = $s->import_db() if ! defined $s->[$DBI];
	my $cfg = $s->[$CONFIG];

	$s->filter(\@fields, $s->[$CONFIG]{COLUMN_INDEX}, $s->[$CONFIG]{FILTER_TO})
		if $cfg->{FILTER_TO};
	my ($val);

	if(scalar @fields == 1) {
		$fields[0] = $s->autonumber()
			if ! length($fields[0]);
		eval {
			$val = $s->quote($fields[0], $s->[$KEY]);
			$s->[$DBI]->do("delete from $s->[$TABLE] where $s->[$KEY] = $val");
			$s->[$DBI]->do("insert into $s->[$TABLE] ($s->[$KEY]) VALUES ($val)");
		};
		die "$DBI::errstr\n" if $@;
		return $fields[0];
	}

	if(! $cfg->{_Insert_h}) {
		my (@ins_mark);
		my $i = 0;
		for(@{$s->[$NAME]}) {
			push @ins_mark, '?';
			$i++;
		}
		my $ins_string = join ", ",  @ins_mark;
		my $query = "INSERT INTO $s->[$TABLE] VALUES ($ins_string)";
#::logDebug("set_row query=$query");
		$cfg->{_Insert_h} = $s->[$DBI]->prepare($query);
		die "$DBI::errstr\n" if ! defined $cfg->{_Insert_h};
	}

	if(! length($fields[$cfg->{KEY_INDEX}]) and $cfg->{AUTO_NUMBER}) {
		$fields[$cfg->{KEY_INDEX}] = $s->autonumber();
	}

	unless ($s->[$CONFIG]{Clean_start}) {
		eval {
			$val = $s->quote($fields[$cfg->{KEY_INDEX}], $s->[$KEY]);
			$s->[$DBI]->do("delete from $s->[$TABLE] where $s->[$KEY] = $val")
				unless $s->[$CONFIG]{Clean_start};
		};
	}

    $s->bind_entire_row($cfg->{_Insert_h}, undef, @fields);
	$val = $fields[$cfg->{KEY_INDEX}];
	my $rc = $cfg->{_Insert_h}->execute()
		or die "$DBI::errstr\n";
##::logDebug("set_row rc=$rc key=$val");
	return $val;
}

sub row {
    my ($s, $key) = @_;
	$s = $s->import_db() if ! defined $s->[$DBI];
	$key = $s->[$DBI]->quote($key)
		unless exists $s->[$CONFIG]{NUMERIC}{$s->[$KEY]};
    my $sth = $s->[$DBI]->prepare(
		"select * from $s->[$TABLE] where $s->[$KEY] = $key");
    $sth->execute()
		or die("execute error: $DBI::errstr");

	return @{$sth->fetchrow_arrayref()};
}

sub row_hash {
    my ($s, $key) = @_;
	$s = $s->import_db() if ! defined $s->[$DBI];
	$key = $s->[$DBI]->quote($key)
		unless exists $s->[$CONFIG]{NUMERIC}{$s->[$KEY]};
    my $sth = $s->[$DBI]->prepare(
		"select * from $s->[$TABLE] where $s->[$KEY] = $key");
    $sth->execute()
		or die("execute error: $DBI::errstr");

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
    return sub {
        my ($key, $value) = @_;
		$value = $s->[$DBI]->quote($value)
			unless exists $s->[$CONFIG]->{NUMERIC}->{$column};
		$key = $s->[$DBI]->quote($key)
			unless exists $s->[$CONFIG]{NUMERIC}{$s->[$KEY]};
        $s->[$DBI]->do("update $s->[$TABLE] SET $column=$value where $s->[$KEY] = $key");
    };
}

sub field {
    my ($s, $key, $column) = @_;
	$s = $s->import_db() if ! defined $s->[$DBI];
	$key = $s->[$DBI]->quote($key)
		unless exists $s->[$CONFIG]{NUMERIC}{$s->[$KEY]};
	my $idx;
	if( $s->[$TYPE] and $idx = $s->column_index($column) )  {
		$column = $s->[$NAME][$idx];
	}
	my $query = "select $column from $s->[$TABLE] where $s->[$KEY] = $key";
#::logDebug("DBI field: key=$key column=$column query=$query");
    my $sth;
	eval {
		$sth = $s->[$DBI]->prepare($query);
		$sth->execute();
	};
	return '' if $@;
	my $data = ($sth->fetchrow_array())[0];
	return '' unless $data =~ /\S/;
	$data;
}

sub set_field {
    my ($s, $key, $column, $value) = @_;
	$s = $s->import_db() if ! defined $s->[$DBI];
    if($s->[$CONFIG]{Read_only}) {
		::logError("Attempt to set %s in read-only table",
					"$s->[$CONFIG]{name}::${column}::$key",
					);
		return undef;
	}
	my $rawkey = $key;
	my $rawval = $value;
	$key   = $s->quote($key, $s->[$KEY]);
	$value = $s->quote($value, $column);
	my $query;
	if(! $s->record_exists($rawkey)) {
		$s->set_row($rawkey);
	}
	$query = <<EOF;
update $s->[$TABLE] SET $column = $value where $s->[$KEY] = $key
EOF
	$s->[$DBI]->do($query)
		or die "$DBI::errstr\n";
	return $rawval;
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
    my $query;
    $query = $s->[$CONFIG]{Exists_handle}
        or
	    $query = $s->[$DBI]->prepare(
				"select $s->[$KEY] from $s->[$TABLE] where $s->[$KEY] = ?"
			)
        and
		$s->[$CONFIG]{Exists_handle} = $query;
    my $status;
    eval {
        $status = defined $s->[$DBI]->selectrow_array($query, undef, $key);
    };
    return undef if $@;
    return $status;
}

sub delete_record {
    my ($s, $key) = @_;
	$s = $s->import_db() if ! defined $s->[$DBI];

    if($s->[$CONFIG]{Read_only}) {
		::logError("Attempt to delete record '%s' from read-only database %s",
						$key,
						$s->[$CONFIG]{name},
						);
		return undef;
	}
	$key = $s->[$DBI]->quote($key)
		unless exists $s->[$CONFIG]{NUMERIC}{$s->[$KEY]};
    $s->[$DBI]->do("delete from $s->[$TABLE] where $s->[$KEY] = $key");
}

sub fields_index {
	my($fields, $config) = @_;
	my %idx;
	my $alias = $config->{FIELD_ALIAS} || {};
	for( my $i = 0; $i < @$fields; $i++) {
		$idx{lc $fields->[$i]} = $i;
		next unless defined $alias->{lc $fields->[$i]};
#::logDebug("alias found: $fields->[$i] = $alias->{lc $fields->[$i]} = $i");
		$idx{ $alias->{ lc $fields->[$i] } } = $i;
	}
	return \%idx;
}

sub list_fields {
	my($db, $name, $config) = @_;
	my @fld;

	my $q = "select * from $name";
	$q .= " limit 1" if $config->{HAS_LIMIT};
	my $sth = $db->prepare($q)
		or die $DBI::errstr;

	# Wish we didn't have to do this, but we cache the columns
	$sth->execute()		or die "$DBI::errstr\n";

	if($config and $config->{NAME_REQUIRES_FETCH}) {
		$sth->fetch();
	}
	@fld = @{$sth->{NAME}};
	if($config->{GUESS_NUMERIC}) {
		$config->{NUMERIC} = {} if ! $config->{NUMERIC};
		eval {
			for (my $i = 0; $i < @fld; $i++) {
				my $info =
					(defined $db->type_info($sth->{TYPE}[$i])->{NUM_PREC_RADIX})
					|| 
					($db->type_info($sth->{TYPE}[$i])->{TYPE_NAME} =~ /\bint(?:eger)?/i);
				next unless $info;
				$config->{NUMERIC}{$fld[$i]} = 1;
			}
		};
	}
	if($config->{UPPERCASE}) {
		@fld = map { lc $_ } @fld;
	}
	return \@fld;
}

# OLDSQL

# END OLDSQL

sub touch {
	return ''
}

sub sort_each {
	my($s, $sort_field, $sort_option) = @_;
	if(length $sort_field) {
		$sort_field .= " DESC" if $sort_option =~ /r/;
		$s->[$CONFIG]{Export_order} = " ORDER BY $sort_field"
	}
}

*each_sorted = \&each_record;

# Now supported, including qualification
sub each_record {
    my ($s, $qual) = @_;
#::logDebug("each_record qual=$qual");
	$qual = '' if ! $qual;
	$qual .= $s->[$CONFIG]{Export_order} 
		if $s->[$CONFIG]{Export_order};
	$s = $s->import_db() if ! defined $s->[$DBI];
    my ($table, $db, $each);
    unless(defined $s->[$EACH]) {
		($table, $db, $each) = @{$s}[$TABLE,$DBI,$EACH];
		my $query = $db->prepare("select * from $table $qual")
            or die $DBI::errstr;
		$query->execute();
		my $idx = $s->[$CONFIG]{KEY_INDEX};
		$each = sub {
			my $ref = $query->fetchrow_arrayref()
				or return undef;
			return ($ref->[$idx], $ref);
		};
        push @$s, $each;
    }
	my ($key, $return) = $s->[$EACH]->();
	if(! defined $key) {
		pop @$s;
		delete $s->[$CONFIG]{Export_order};
		return ();
	}
    return ($key, @$return);
}

# Now supported, including qualification
sub each_nokey {
    my ($s, $qual) = @_;
#::logDebug("each_nokey qual=$qual");
	$qual = '' if ! $qual;
	$qual .= $s->[$CONFIG]{Export_order} 
		if $s->[$CONFIG]{Export_order};
	$s = $s->import_db() if ! defined $s->[$DBI];
    my ($table, $db, $each);
    unless(defined $s->[$EACH]) {
		($table, $db, $each) = @{$s}[$TABLE,$DBI,$EACH];
		my $restrict;
		if($restrict = $Vend::Cfg->{TableRestrict}{$table}
			and (
				! defined $Global::SuperUserFunction
					or
				! $Global::SuperUserFunction->()
				)
			) {
			$qual = $qual ? "$qual AND " : 'WHERE ';
			my ($rfield, $rsession) = split /\s*=\s*/, $restrict;
#::logDebug("qual=$qual");
			$qual .= "$rfield = '$Vend::Session->{$rsession}'";
		}
		my $query = $db->prepare("select * from $table " . ($qual || '') )
            or die $DBI::errstr;
		$query->execute();
		my $idx = $s->[$CONFIG]{KEY_INDEX};
		$each = sub {
			my $ref = $query->fetchrow_arrayref()
				or return undef;
			return ($ref);
		};
        push @$s, $each;
    }
	my ($return) = $s->[$EACH]->();
	if(! defined $return->[0]) {
		pop @$s;
		delete $s->[$CONFIG]{Export_order};
		return ();
	}
    return (@$return);
}

sub sprintf_substitute {
	my ($s, $query, $fields, $cols) = @_;
	my ($tmp, $arg);
	my $i;
	if(defined $cols->[0]) {
		for($i = 0; $i <= $#$fields; $i++) {
			$fields->[$i] = $s->quote($fields->[$i], $cols->[$i])
				if defined $cols->[0];
		}
	}
	return sprintf $query, @$fields;
}

sub query {
    my($s, $opt, $text, @arg) = @_;

    if(! CORE::ref($opt)) {
        unshift @arg, $text;
        $text = $opt;
        $opt = {};
    }

	$s = $s->import_db() if ! defined $s->[$DBI];
	$opt->{query} = $opt->{sql} || $text if ! $opt->{query};

#::logDebug("\$db->query=$opt->{query}");
	if(defined $opt->{values}) {
		# do nothing
		@arg = $opt->{values} =~ /['"]/
				? ( Text::ParseWords::shellwords($opt->{values})  )
				: (grep /\S/, split /\s+/, $opt->{values});
		@arg = @{$::Values}{@arg};
	}

	my $query;
    $query = ! scalar @arg
			? $opt->{query}
			: sprintf_substitute ($s, $opt->{query}, \@arg);

	my $codename = $s->[$CONFIG]{KEY};
	my $ref;
	my $relocate;
	my $return;
	my $spec;
	my $stmt;
	my $sth;
	my $update;
	my $rc;
	my %nh;
	my @na;
	my @out;
	my $db = $s->[$DBI];

    if ( 0 and "\L$opt->{st}" eq 'db') {
		eval {
			($spec, $stmt) = Vend::Scan::sql_statement($query, $ref);
		};
		if(! CORE::ref $spec) {
			::logError("Bad SQL, query was: %s", $query);
			return ($opt->{failure} || undef);
		}
		my @additions = grep length($_) == 2, keys %$opt;
		if(@additions) {
			@{$spec}{@additions} = @{$opt}{@additions};
		}
	}
	else {
		$update = 1 if $query !~ /^\s*select\s+/i;

		eval {
			if($update and $s->[$CONFIG]{Read_only}) {
				my $msg = ::errmsg(
							"Attempt to do update on read-only table.\nquery: %s",
							$query,
						  );
				::logError($msg);
				die "$msg\n";
			}
			$opt->{row_count} = 1 if $update;
			$sth = $db->prepare($query);
			$rc = $sth->execute();
			
			if ($opt->{hashref}) {
				my @ary;
				while ( defined (my $rowhashref = $sth->fetchrow_hashref) ) {
					if ($s->config('UPPERCASE')) {
						$rowhashref->{lc $_} = $rowhashref->{$_} for (keys %$rowhashref);
					}
					push @ary, $rowhashref;
				}
				die $DBI::errstr if $sth->err();
				$ref = $Vend::Interpolate::Tmp->{$opt->{hashref}} = \@ary;
			}
			else {
				my $i = 0;
				@na = @{$sth->{NAME} || []};
				%nh = map { (lc $_, $i++) } @na;
				$ref = $Vend::Interpolate::Tmp->{$opt->{arrayref}}
					= $sth->fetchall_arrayref()
					 or die $DBI::errstr;
			}
		};
		if($@) {
			if(! $sth) {
				# query failed, probably because no table
				# Do nothing but log to debug and fall through to MVSEARCH
				::logDebug(qq{query "$query" failed: $@});
			}
			else {
				::logError("SQL query failed: %s\nquery was: %s", $@, $query);
				$return = $opt->{failure} || undef;
			}
		}
	}

MVSEARCH: {
	last MVSEARCH if defined $ref;

	my @tabs = @{$spec->{fi} || [ $s->[$CONFIG]{name} ]};
	for (@tabs) {
		s/\..*//;
	}
	if (! defined $s || $tabs[0] ne $s->[$CONFIG]{name}) {
		unless ($s = $Vend::Database{$tabs[0]}) {
			::logError("Table %s not found in databases", $tabs[0]);
			return $opt->{failure} || undef;
		}
#::logDebug("rerouting to $tabs[0]");
		$opt->{STATEMENT} = $stmt;
		$opt->{SPEC} = $spec;
		return $s->query($opt, $text);
	}

eval {

	if($stmt->command() ne 'SELECT') {
		if(defined $s and $s->[$CONFIG]{Read_only}) {
			die ("Attempt to write read-only database $s->[$CONFIG]{name}");
		}
		$update = $stmt->command();
	}
	my @vals = $stmt->row_values();
	
	@na = @{$spec->{rf}}     if $spec->{rf};

	$spec->{fn} = [$s->columns];
	if(! @na) {
		@na = ! $update || $update eq 'INSERT' ? '*' : $codename;
	}
	@na = @{$spec->{fn}}       if $na[0] eq '*';
	$spec->{rf} = [@na];
	
#::logDebug("tabs='@tabs' columns='@na' vals='@vals'"); 

    my $search;
	$opt->{bd} = $tabs[0];
	$search = new Vend::DbSearch;

	my %fh;
	my $i = 0;
	%nh = map { (lc $_, $i++) } @na;
	$i = 0;
	%fh = map { ($_, $i++) } @{$spec->{fn}};

#::logDebug("field hash: " . Vend::Util::uneval(\%fh)); 
	for ( qw/rf sf/ ) {
		next unless defined $spec->{$_};
		map { $_ = $fh{$_} } @{$spec->{$_}};
	}

	if($update) {
		die "DBI tables must be updated natively.\n";
	}
	elsif ($opt->{hashref}) {
		$ref = $Vend::Interplate::Tmp->{$opt->{hashref}} = $search->hash($spec);
	}
	else {
		$ref = $Vend::Interplate::Tmp->{$opt->{arrayref}} = $search->array($spec);
	}
};
#::logDebug("search spec: " . Vend::Util::uneval($spec));
#::logDebug("name hash: " . Vend::Util::uneval(\%nh));
#::logDebug("ref returned: " . Vend::Util::uneval($ref));
#::logDebug("opt is: " . Vend::Util::uneval($opt));
	if($@) {
		::logError("MVSQL query failed for %s: %s\nquery was: %s",
					$opt->{table},
					$@,
					$query,
					);
		$return = $opt->{failure} || undef;
	}
} # MVSEARCH
#::logDebug("finished query, rc=$rc ref=$ref arrayref=$opt->{arrayref} Tmp=$Vend::Interpolate::Tmp->{$opt->{arrayref}}");
	return $rc
		if $opt->{row_count};
	return Vend::Interpolate::tag_sql_list($text, $ref, \%nh, $opt)
		if $opt->{list};
	return Vend::Interpolate::html_table($opt, $ref, \@na)
		if $opt->{html};
	return Vend::Util::uneval($ref)
		if $opt->{textref};
	return wantarray ? ($ref, \%nh, \@na) : $ref;
}

*autonumber = \&Vend::Table::Common::autonumber;

1;

__END__
