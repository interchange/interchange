# Vend::Data - Interchange databases
#
# Copyright (C) 2002-2009 Interchange Development Group
# Copyright (C) 1996-2002 Red Hat, Inc.
#
# This program was originally based on Vend 0.2 and 0.3
# Copyright 1995 by Andrew M. Wilcox <amw@wilcoxsolutions.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation and modified by the Interchange license;
# either version 2 of the License, or (at your option) any later version.
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

package Vend::Data;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(

close_database
column_exists
database_field
database_ref
database_exists_ref
database_key_exists
db_column_exists
export_database
import_database
increment_field
item_category
item_common
item_description
item_field
item_price
item_subtotal
open_database
product_category
product_code_exists_ref
product_code_exists_tag
product_description
product_common
product_field
product_price
product_row
product_row_hash
set_field
update_data

);
@EXPORT_OK = qw(update_productbase column_index);

use strict;
no warnings qw(uninitialized numeric);
use File::Basename;
use Vend::Util;
use Vend::Interpolate;
use Vend::Table::Common qw(import_ascii_delimited);

File::Basename::fileparse_set_fstype($^O);

BEGIN {
# SQL
	if($Global::DBI) {
		require Vend::Table::DBI;
		require Vend::Table::DBI_CompositeKey;
	}
# END SQL
# LDAP
	if($Global::LDAP) {
		require Vend::Table::LDAP;
	}
# END LDAP
	if($Global::GDBM) {
		require Vend::Table::GDBM;
	}
	if($Global::DB_File) {
		require Vend::Table::DB_File;
	}
	require Vend::Table::InMemory;
	require Vend::Table::Shadow;
}

my ($Products, $Item_price);

sub instant_database {
	my($file) = @_;
	return undef unless $file =~ /\.(txt|asc)$/;
	my $dir   = File::Basename::dirname($file);
	my $fname = File::Basename::basename($file);
	my $dbname = $fname;
	$dbname =~ s:\W:_:g;
	
	$Vend::Database{$dbname}
		and return $Vend::Database{$dbname}->ref();
	$Vend::WriteDatabase{$file} and $Vend::WriteDatabase{$dbname} = 1;
	if( file_name_is_absolute($_[0]) ) {
		my $msg = errmsg(
						"Instant database (%s): no absolute file names.",
						$_[0],
					);
		logError($msg);
		logGlobal($msg);
		return undef;
	}
	elsif (! -f $_[0]) {
		my $msg = errmsg(
						"Instant database (%s): no file found.",
						$_[0],
					);
		logError($msg);
		return undef;
	}
	return $Vend::Database{$dbname} = import_database({
													name => $dbname,
													DIR => $dir,
													type => 'AUTO',
													file => $fname,
													Class => 'TRANSIENT',
													EXPORT_ON_CLOSE => 1,
												});
}

sub database_exists_ref {
	return unless $_[0];
	return $_[0]->ref() if ref $_[0];
	return $Vend::Interpolate::Db{$_[0]}
			if $Vend::Interpolate::Db{$_[0]};
	$Vend::Database{$_[0]}
		and return $Vend::Database{$_[0]}->ref();
	return instant_database(@_);
}

sub database_key_exists {
    my ($db,$key) = @_;
    return $db->record_exists($key);
}

sub product_code_exists_ref {
    my ($code, $base) = @_;

    my($ref);
    if($base) {
        return undef unless $ref = $Vend::Productbase{$base};
        return $ref->ref() if $ref->record_exists($code);
    }

    my $return;
    foreach $ref (@Vend::Productbase) {
        return ($return = $ref) if $ref->record_exists($code);
    }
    return undef;
}

sub product_code_exists_tag {
    my ($code, $base) = @_;
	if($base) {
		return undef unless $Vend::Productbase{$base};
		return $base if $Vend::Productbase{$base}->record_exists($code);
		return 0;
	}

	foreach my $ref (@Vend::Productbase) {
		return $Vend::Basefinder{$ref} if $ref->record_exists($code);
	}
	return undef;
}

sub open_database {
	return tie_database() if $_[0] || $Global::AcrossLocks;
	dummy_database();
}

sub update_productbase {

	if(defined $_[0]) {
		return unless defined $Vend::Productbase{$_[0]};
	}
	undef @Vend::Productbase;
	for(@{$Vend::Cfg->{ProductFiles}}) {
		unless ($Vend::Database{$_}) {
		  die "$_ not a database, cannot use as products file\n";
		}
		$Vend::Productbase{$_} = $Vend::Database{$_};
		$Vend::Basefinder{$Vend::Database{$_}} = $_;
		push @Vend::Productbase, $Vend::Database{$_};
		$Vend::OnlyProducts = $_;
	}

	undef $Vend::OnlyProducts if scalar @Vend::Productbase > 1;

	$Products = $Vend::Productbase[0];
#::logError("Productbase: '@Vend::Productbase' --> " . uneval(\%Vend::Basefinder));

}

sub product_price {
    my ($code, $q, $base) = @_;

	$base = $Vend::Basefinder{$base}
		if ref $base;

	return item_price(
		{
			code		=> $code,
			quantity	=> $q || 1,
			mv_ib		=> $base || undef,
		},
		$q
	);
}

sub product_category {
	my ($code, $base) = @_;
    return "" unless $base = product_code_exists_ref($code, $base || undef);
    return database_field($base, $code, $Vend::Cfg->{CategoryField});
}

sub product_description {
    my ($code, $base) = @_;
    return "" unless $base = product_code_exists_ref($code, $base || undef);
    return database_field($base, $code, $Vend::Cfg->{DescriptionField});
}

sub database_field {
    my ($db, $key, $field_name, $foreign) = @_;
#::logDebug("database_field: " . uneval_it(\@_));
    $db = database_exists_ref($db) or return undef;
    return '' unless defined $db->test_column($field_name);
	$key = $db->foreign($key, $foreign) if $foreign;
    return '' unless $db->test_record($key);
    return $db->field($key, $field_name);
}

sub database_row {
    my ($db, $key) = @_;
    $db = database_exists_ref($db) or return undef;
    return '' unless $db->test_record($key);
    return $db->row_hash($key);
}

sub increment_field {
    my ($db, $key, $field_name, $adder) = @_;
	$db = $db->ref();
    return undef unless $db->test_record($key);
    return undef unless defined $db->test_column($field_name);
#::logDebug(__PACKAGE__ . "increment_field: " . uneval_it(\@_));
    return $db->inc_field($key, $field_name, $adder);
}

sub call_method {
	my($base, $method, @args) = @_;

	my $db = ref $base ? $base : $Vend::Database{$base};
	$db = $db->ref();

	no strict 'refs';
	$db->$method(@args);
}

sub import_text {
	my ($table, $type, $options, $text) = @_;
#::logDebug("Called import_text: table=$table type=$type opt=" . Data::Dumper::Dumper($options) . " text=$text");
	my ($delimiter, $record_delim) = find_delimiter($type);
	my $db = $Vend::Database{$table}
		or die ("Non-existent table '$table'.\n");
	$db = $db->ref();

	my @columns;
	@columns = ($db->columns());

	if($options->{'continue'}) {
		$options->{CONTINUE} = uc $options->{'continue'};
		$options->{NOTES_SEPARATOR} = uc $options->{separator}
			if defined $options->{separator};
	}

	my $sub = sub { return $db };
	my $now = time();
	my $fn = $Vend::Cfg->{ScratchDir} . "/import.$$.$now";
	$text =~ s/^\s+//;
	$text =~ s/\s+$//;

	if($delimiter eq 'CSV') {
		my $add = '"';
		$add .= join '","', @columns;
		$add .= '"';
		$text = "$add\n$text";
	}
	else {
		$options->{field_names} = \@columns;
		$options->{delimiter} = $options->{DELIMITER} = $delimiter;
	}

	if($options->{file}) {
		$fn = $options->{file};
		Vend::File::allowed_file($fn)
			or die ::errmsg("No absolute file names like '%s' allowed.\n", $fn);
	}
	else {
		Vend::Util::writefile($fn, $text)
			or die ("Cannot write temporary import file $fn: $!\n");
	}

	my $save = $/;
	local($/) = $record_delim if defined $record_delim;

	$options->{Object} = $db;

	## This is where the actual import happens
	Vend::Table::Common::import_ascii_delimited($fn, $options);

	$/ = $save;
	unlink $fn unless $options->{'file'};
	return 1;
}

sub set_field {
    my ($db, $key, $field_name, $value, $append, $foreign) = @_;

	$db = database_exists_ref($db);
    return undef unless defined $db->test_column($field_name);

	$key = $db->foreign($key, $foreign)
		if $foreign;

	# Create it if it doesn't exist
	unless ($db->record_exists($key)) {
		$db->set_row($key);
	}
	elsif ($append) {
		$value = $db->field($key, $field_name) . $value;
	}
    return $db->set_field($key, $field_name, $value);
}

sub product_row {
	my ($code) = @_;
	my $db = product_code_exists_ref($code) or return;
	return $db->row($code);
}

sub product_row_hash {
	my ($code) = @_;
	my $db = product_code_exists_ref($code) or return;
	return $db->row_hash($code);
}

sub product_field {
    my ($field_name, $code, $base) = @_;
#::logDebug("product_field: name=$field_name code=$code base=$base");
	return database_field($Vend::OnlyProducts, $code, $field_name)
		if $Vend::OnlyProducts;
#::logDebug("product_field: onlyproducts=$Vend::OnlyProducts");
	my ($db);
    $db = product_code_exists_ref($code, $base || undef)
		or return '';
#::logDebug("product_field: exists db=$db");
    return "" unless defined $db->test_column($field_name);
    return $db->field($code, $field_name);
}


sub product_common {
    my ($field_name, $code, $emptyok) = @_;
#::logDebug("product_field: name=$field_name code=$code base=$base");
	my $result;
	for(@{$Vend::Cfg->{ProductFiles}}) {
		my $db = database_exists_ref($_)
			or next;
		next unless defined $db->test_column($field_name);
		$result = database_field($db, $code, $field_name);
		last if $emptyok or length($result);
	}
    return $result;
}

my %T;

TAGBUILD: {

	my @th = (qw!

		arg
		/arg
		control
		/control
		query
		/query

	! );

	my $tag;
	for (@th) {
		$tag = $_;
		s/(\w)/[\u$1\l$1]/g;
		s/[-_]/[-_]/g;
		$T{$tag} = "\\[$_";
	}
}

sub column_index {
    my ($field_name) = @_;
	$Products = $Products->ref();
    return undef unless defined $Products->test_column($field_name);
    return $Products->column_index($field_name);
}

sub column_exists {
    my ($field_name) = @_;
    return defined $Products->test_column($field_name);
}

sub db_column_exists {
    my ($db,$field_name) = @_;
    return defined $db->test_column($field_name);
}

sub close_database {
	my $name;
	undef $Products;
	while( ($name)	= each %Vend::Database ) {
    	$Vend::Database{$name}->close_table()
			unless defined $Vend::Cfg->{SaveDatabase}{$name};
		delete $Vend::Database{$name};
	}
	undef %Vend::Table::DBI::DBI_connect_bad;
	undef %Vend::TransactionDatabase;
	undef %Vend::WriteDatabase;
	undef %Vend::Basefinder;
	undef $Vend::VarDatabase;
}

sub database_ref {
	my $db = $_[0] || $Products;
	return $db->ref() if $db;
	return undef;
}

## PRODUCTS

# Read in the shipping file.

*read_shipping = \&Vend::Interpolate::read_shipping;

# Read in the sales tax file.
sub read_salestax {
    my($code, $percent);

	return unless $Vend::Cfg->{SalesTax};
	return if $Vend::Cfg->{SalesTax} eq 'multi';
	my $file = $Vend::Cfg->{Special}{'salestax.asc'};
	$file = Vend::File::catfile($Vend::Cfg->{ProductDir}, "salestax.asc")
		unless $file;

	$Vend::Cfg->{SalesTaxTable} = {};

	my @lines = split /\n/, readfile($file);
    for(@lines) {
		tr/\r//d;
		($code, $percent) = split(/\s+/, $_, 2);
		$Vend::Cfg->{SalesTaxTable}->{"\U$code"} = $percent;
    }

	if(not defined $Vend::Cfg->{SalesTaxTable}->{DEFAULT}) {
		$Vend::Cfg->{SalesTaxTable}->{DEFAULT} = 0;
	}

	1;
}

my %Delimiter = (
	2 => ["\n", "\n\n"],
	3 => ["\n%%\n", "\n%%%\n"],
	4 => ["CSV","\n"],
	5 => ['|', "\n"],
	6 => ["\t", "\n"],
	7 => ["\t", "\n"],
	8 => ["\t", "\n"],
	10 => ["\t", "\n"],
	LINE => ["\n", "\n\n"],
	'%%%' => ["\n%%\n", "\n%%%\n"],
	'%%' => ["\n%%\n", "\n%%%\n"],
	CSV => ["CSV","\n"],
	PIPE => ['|', "\n"],
	TAB => ["\t", "\n"],
	"\t" => ["\t", "\n"],
	'|'  => ['|', "\n"],
	"\n%%\n" => ["\n%%\n", "\n%%%\n"],

	);

sub find_delimiter {
	my ($type) = @_;
	$type = $type || 1;
	return @{$Delimiter{$type}}
		if defined $Delimiter{$type}; 
	return;
}

sub auto_delimiter {
	my ($fn) = @_;
	my $fdelim = "\t";
	my $rdelim = "\n";
	my $tried_plain;
	my $type;
	open(AUTODELIM, $fn) 
		or die errmsg("Cannot open database text source file %s: %s\n", $fn, $!);
	local ($/);
	$/ = "\n";
	while(<AUTODELIM>) {
		my $line = $_;
		chomp;
		if(! $tried_plain and $_) {
			s/[^\t|,]//g;
			s/[ (=)]+//g;
			m/(.)/;
			my $char = $1;
			if (/^\Q$char\E+$/) {
				($fdelim, $rdelim) = ($char, "\n");
				last;
			}
		}
		$tried_plain++ or next;
		if($_ eq '%%') {
			$type = '%%';
			last;
		}
		elsif ($_ eq '') {
			$type = 'LINE';
			last;
		}
	}
	close AUTODELIM;
	$type = 'CSV' if $fdelim eq ',';
	if($type and defined $Delimiter{$type}) {
		($fdelim, $rdelim) =  @{$Delimiter{$type}};
	}
	return ($fdelim, $rdelim);
}

use vars '%db_config';

%db_config = (
# SQL
		'DBI_CompositeKey' => {
				qw/
					Extension			 sql
					RestrictedImport	 1
					Class                Vend::Table::DBI_CompositeKey
				/
				},
		'DBI' => {
				qw/
					Extension			 sql
					RestrictedImport	 1
					Class                Vend::Table::DBI
				/
				},
# END SQL
		'SHADOW' => {
				qw/
					Class                Vend::Table::Shadow
				/
				},
		'TRANSIENT' => {
				qw/
					Cacheable			 0
					Tagged_write		 1
					Class                Vend::Table::InMemory
					Export_on_close		 1
				/
				},
		'MEMORY' => {
				qw/
					Cacheable			 1
					Tagged_write		 1
					Class                Vend::Table::InMemory
				/
				},
		'GDBM' => {
				qw/
					TableExtension		 .gdbm
					Extension			 gdbm
					Tagged_write		 1
					Class                Vend::Table::GDBM
				/
				},
		'DB_FILE' => {
				qw/
					TableExtension		 .db
					Extension			 db
					Tagged_write		 1
					Class                Vend::Table::DB_File
				/
		},
		'SDBM' => {
				qw/
					TableExtension		 .sdbm
					Extension			 sdbm
					Tagged_write		 1
					Class                Vend::Table::SDBM
				/,
				FileExtensions	=> [ qw/dir pag/ ],
		},
# LDAP
		'LDAP' => {
				qw/
					RestrictedImport	 1
					Extension			 ldap
					Class				 Vend::Table::LDAP
				/
		},
# END LDAP
	);

sub tie_database {
	my ($name, $data);
	if($Global::Database) {
		copyref($Global::Database, $Vend::Cfg->{Database});
	}

	my @tables = keys %{$Vend::Cfg->{Database}};

	my @delayed;
	my $redone;

	TIEDB: {

		foreach $name (@tables) {
			$data = $Vend::Cfg->{Database}{$name} || {};
			if(! $redone and $data->{MIRROR}) {
#::logDebug("mirror database $name, delaying");
				$data->{HOT} = 1;
				push @delayed, $name;
				next;
			}
			if(! $data->{name}) {
				next;
			}
			if( $data->{type} > 6 or $data->{HOT} or $data->{IMPORT_ONCE} ) {
				eval {
					$Vend::Database{$name} = import_database($data);
				};
				if($@) {
						my $msg = "table '%s' failed: %s";
						$msg = errmsg($msg, $name, $@);
						logError($msg);
				}
			}
			else {
				if($data->{GUESS_NUMERIC}) {
					my $dir = $data->{DIR} || $Vend::Cfg->{ProductDir};
					my $fn = Vend::Util::catfile( $dir, $data->{file} );
					my @fields = grep /\S/, split /\s+/, readfile("$fn.numeric");
					$data->{NUMERIC} = {};
					for(@fields) {
						$data->{NUMERIC}{$_} = 1;
					}
				}
				my $class = $db_config{$data->{Class}}->{Class};
				$Vend::Database{$name} = new $class ($data);
			}
		}

		# So mirrors will not happen until after mirror source
		if(@delayed) {
			@tables = @delayed;
			@delayed = ();
			$redone = 1;
			redo TIEDB;
		}

	}
	update_productbase();
}

sub dummy_database {
	my ($name, $data);
    while (($name,$data) = each %{$Vend::Cfg->{Database}}) {
		if (defined $Vend::Cfg->{SaveDatabase}{$name}) {
			$Vend::Database{$name} = $Vend::Cfg->{SaveDatabase}{$name};
			next;
		}
		my $class = $db_config{$data->{Class}}->{Class};
		eval {
		$Vend::Database{$name} =
				new $class ($data);
		};
		if($@) {
			logGlobal("Error creating dummy database for $name: $@");
		}
	}
	update_productbase();
}

my $tried_import;

sub create_empty_txt {
	my ($obj, $database_txt, $delimiter, $record_delim) = @_;
	return if -f $database_txt;
	return unless $obj->{CREATE_EMPTY_TXT};
	my $ary;
	if($obj->{CREATE_EMPTY_TXT} =~ /[\s,]\w/) {
		$ary = [ grep /\S/, split /[\s,]+/, $obj->{CREATE_EMPTY_TXT} ];
	}
	else {
		$ary = $obj->{NAME};
	}
	unless (ref($ary) eq 'ARRAY') {
		logError("Cannot create text file with no database NAME parameter and no field names in CREATE_EMPTY_TXT");
	}
	else {
		$delimiter ||= "\t";
		$record_delim ||= "\n";
		my $line = join $obj->{DELIMITER}, @$ary;
		$line .= $record_delim;
		Vend::Util::writefile($database_txt, $line);
	}
	return;
}

sub import_database {
    my ($obj, $dummy) = @_;


	my $database = $obj->{'file'};
	my $type     = $obj->{'type'};
	my $name     = $obj->{'name'};
#	if($type == 9) {
#my @caller = caller();
#::logDebug ("enter import_database: dummy=$dummy");
#::logDebug("opening table table=$database config=" . uneval($obj) . " caller=@caller");
#
#::logDebug ("database=$database type=$type name=$name obj=" . uneval($obj));
#::logDebug ("database=$database type=$type name=$name obj=" . uneval($obj)) if $obj->{HOT};
#	
#	}
	return $Vend::Cfg->{SaveDatabase}->{$name}
		if defined $Vend::Cfg->{SaveDatabase}->{$name};

	my ($delimiter, $record_delim, $change_delimiter, $cacheable);
	my ($base,$path,$tail,$dir,$database_txt);

	die "import_database: No database name!\n"
		unless $database;


	my $database_dbm;
	my $new_database_dbm;
	my $table_name;
	my $new_table_name;
	my $class_config;
	my $db;

	my $no_import = defined $Vend::Cfg->{NoImport}->{$name} || $obj->{NO_IMPORT};

	if (defined $Vend::ForceImport{$name}) {
		undef $no_import;
		delete $Vend::ForceImport{$name};
	}

	$base = $obj->{'name'};
	$dir = $obj->{DIR} if defined $obj->{DIR};

	if ($obj->{OrigClass}) {
		my $ref = $db_config{$obj->{OrigClass} || $Global::Default_database};
		$class_config = {%$ref};
		$class_config->{Class} = $db_config{$obj->{Class}}->{Class};
		$class_config->{OrigClass} = $obj->{OrigClass};
	} else {
		$class_config = $db_config{$obj->{Class} || $Global::Default_database};
	}

#::logDebug ("params=$database_txt path='$path' base='$base' tail='$tail' dir='$dir'") if $type == 9;
	$table_name     = $name;
	my $export;

  IMPORT: {
	last IMPORT if $no_import and $obj->{DIR};
#::logDebug ("no_import_check: once=$obj->{IMPORT_ONCE} dir=$obj->{DIR}");
	last IMPORT if defined $obj->{IMPORT_ONCE} and $obj->{DIR};
#::logDebug ("first no_import_check: passed") if $type == 9;

    $database_txt = $database;

	($base,$path,$tail) = fileparse $database_txt, '\.[^/.]+$';

	if(Vend::Util::file_name_is_absolute($database_txt)) {
		unless (allowed_file($database_txt)) {
			my $msg = errmsg(
							"Security violation, trying to import %s",
							$database_txt,
							);
			logError( $msg );
			die "Security violation.\n";
		}
		$dir = $path;
	}
	else {
		$dir = $obj->{DIR} || $Vend::Cfg->{ProductDir} || $Global::ConfigDir;
		$database_txt = Vend::Util::catfile($dir,$database_txt);
	}

	$obj->{DIR} = $dir;

	$obj->{ObjectType} = $class_config->{Class};

	my $dot = $obj->{HIDE_AUTO_FILES} ? '.' : '';

	$obj->{AUTO_NUMBER_FILE} = Vend::File::make_absolute_file(
		$obj->{AUTO_NUMBER_FILE} || "$dir/$dot$obj->{name}.autonumber"
	);

	if($class_config->{Extension}) {
		$database_dbm = Vend::Util::catfile(
												$dir,
												"$dot$base."     .
												$class_config->{Extension}
											);
		$new_database_dbm =  Vend::Util::catfile(
												$dir,
												"new_$base."     .
												$class_config->{Extension}
											);
	}

	if($class_config->{TableExtension}) {
		$table_name     = $database_dbm;
		$new_table_name = $new_database_dbm;
	}
	else {
		$table_name = $new_table_name = $base;
	}

	$cacheable = $class_config->{Cacheable} || undef;

	if ($class_config->{RestrictedImport}) {
		$obj->{db_file_extended} = $database_dbm;
		if (
			$Vend::Cfg->{NoImportExternal}
			or -f $database_dbm
			or (! $obj->{CREATE_EMPTY_TXT} and ! -f $database_txt)
			)
		{
			$no_import = 1;
		}
		else {
			open(Vend::Data::TMP, ">$new_database_dbm");
			print Vend::Data::TMP "\n";
			close(Vend::Data::TMP);
		}
	}

	if($obj->{MIRROR}) {
		if($obj->{Mirror_complete}) {
			$no_import = 1;
		}
		else {
#::logDebug ("table $new_table_name: undeffing $database_dbm, hot=$obj->{HOT}");
			undef $database_dbm;
			undef $no_import;
		}
	}

	last IMPORT if $no_import;
#::logDebug ("moving to import") if $type == 9;

	$change_delimiter = $obj->{DELIMITER} if defined $obj->{DELIMITER};

	my $txt_time;
	my $dbm_time;
    if (
		! defined $database_dbm
		or ! -e $database_dbm
		or $obj->{MIRROR}
        or ($txt_time = file_modification_time($database_txt, $obj->{PRELOAD}))
				>
           ($dbm_time = file_modification_time($database_dbm))
		)
	{
        warn "Importing $obj->{'name'} table from $database_txt\n"
			unless $Vend::Quiet;

		$type = 1 unless $type;
		($delimiter, $record_delim) = find_delimiter($change_delimiter || $type);

		if(! $delimiter) {
			($delimiter, $record_delim) = auto_delimiter($database_txt);
		}

		$obj->{delimiter} = $obj->{DELIMITER} = $delimiter;

		my $save = $/;

		local($/) = $record_delim if defined $record_delim;

		if($obj->{CREATE_EMPTY_TXT}) {
			create_empty_txt($obj, $database_txt, $delimiter, $record_delim);
		}

		if($obj->{MIRROR}) {
			$db = Vend::Table::Common::import_from_ic_db(
							$database_txt,
							$obj,
							$new_table_name,
				);
		}
		else {
        $db = Vend::Table::Common::import_ascii_delimited(
							$database_txt,
							$obj,
							$new_table_name,
				);
		}

		$/ = $save;
		if(defined $database_dbm) {
			$db->close_table() if defined $db;
			undef $db;
			unlink $database_dbm if $Global::Windows;
			if($class_config->{FileExtensions}) {
				open(TOUCH, ">>$database_dbm")
					or die "Couldn't freshen $database_dbm: $_";
				close TOUCH 
					or die "Couldn't freshen $database_dbm: $_";
				for(@{$class_config->{FileExtensions}}) {
					my ($old, $new) = ("$new_database_dbm.$_", "$database_dbm.$_");
					rename($old, $new)
						or die
							"Couldn't move '$old' to '$new': $!\n";
				}
			}
			else {
				rename($new_database_dbm, $database_dbm)
					or die "Couldn't move '$new_database_dbm' to '$database_dbm': $!\n";
			}
		}
    }
	elsif ($obj->{AUTO_EXPORT} and $dbm_time > $txt_time) {
		$obj->{export_now} = 1;
	}

  }

	my $read_only;

	if($obj->{WRITE_CONTROL}) {
		if($obj->{READ_ONLY}) {
			$obj->{Read_only} = 1;
		}
		elsif($obj->{WRITE_ALWAYS}) {
			$obj->{Read_only} = 0;
		}
		elsif($obj->{WRITE_CATALOG}) {
			$obj->{Read_only} = $obj->{WRITE_CATALOG}{$Vend::Cat}
					? (! defined $Vend::WriteDatabase{$name}) 
					: 1;
		}
		elsif(! defined $obj->{WRITE_TAGGED} or $obj->{WRITE_TAGGED}) {
			$obj->{Read_only} = ! defined $Vend::WriteDatabase{$name};
		}
	}
	else {
		$obj->{Read_only} = ! defined $Vend::WriteDatabase{$name}
			if $class_config->{Tagged_write};
	}

	$obj->{Transactions} = 1 if $Vend::TransactionDatabase{$name};

    if($class_config->{Extension}) {

		$obj->{db_file} = $table_name unless $obj->{db_file};
		$obj->{db_text} = $database_txt unless $obj->{db_text};
		no strict 'refs';
#::logDebug("ready to try opening db $table_name") if ! $db;
		eval { 
			if($MVSAFE::Safe) {
                if (exists $Vend::Interpolate::Db{$class_config->{Class}}) {
				    $db = $Vend::Interpolate::Db{$table_name}->open_table( $obj, $obj->{db_file} );
                } else {
                    die errmsg("no access for database %s", $table_name);
                }
			}
			else {
				$db = $class_config->{Class}->open_table( $obj, $obj->{db_file} );
			}
			$obj->{NAME} = $db->[$Vend::Table::Common::COLUMN_INDEX]
				unless defined $obj->{NAME};
#::logDebug("didn't die but no db") if ! $db;
		};

#::logDebug("db=$db, \$\!='$!' \$\@='$@' (" . length($@) . ")\n") if ! $db;
		if($@) {
#::logDebug("Dieing of $@");
			die $@ unless $no_import;
			die $@ if $tried_import++;
			if(! -f $database_dbm) {
				$Vend::ForceImport{$obj->{name}} = 1;
				return import_database($obj);
			}
			die $@;
		}
		undef $tried_import;
#::logDebug("Opening $obj->{name}: RO=$obj->{Read_only} WC=$obj->{WRITE_CONTROL} WA=$obj->{WRITE_ALWAYS}");
	}

	if(defined $cacheable) {
		$Vend::Cfg->{SaveDatabase}->{$name} = $db;
	}

	$Vend::Basefinder{$db} = $name;

	return $db;
}

sub index_database {
	my($dbname, $opt) = @_;

	return undef unless defined $dbname;

	my $db;
	$db = database_exists_ref($dbname)
		or do {
			logError("Vend::Data export: non-existent database %s", $dbname);
			return undef;
		};

	$db = $db->ref();

	my $ext = $opt->{extension} || 'idx';

	my $db_fn = $db->config('db_file');
	my $bx_fn = $opt->{basefile} || $db->config('db_text');
	my $ix_fn = "$bx_fn.$ext";
	my $type  = $opt->{type} || $db->config('type');

#::logDebug(
#	"dbname=$dbname db_fn=$db_fn bx_fn=$bx_fn ix_fn=$ix_fn\n" .
#	"options: " . uneval($opt) . "\n"
#	);

	if(		! -f $bx_fn
				or 
			file_modification_time($db_fn)
				>
            file_modification_time($bx_fn)		)
	{
		export_database($dbname, $bx_fn, $type);
	}

	return if $opt->{export_only};

	if(		-f $ix_fn
				and 
			file_modification_time($ix_fn)
				>=
            file_modification_time($bx_fn)		)
	{
		# We didn't need to index if got here
		return;
	}

	if(! $opt->{spec}) {
		$opt->{fn} = $opt->{fn} || $opt->{fields} || $opt->{col} || $opt->{columns};
		my $key = $db->config('KEY');
		my @fields = grep $_ ne $key, split /[\0,\s]+/, $opt->{fn};
		my $sort = join ",", @fields;
		if(! $opt->{fn}) {
			logError(errmsg("index attempted on table '%s' with no fields, no search spec", $dbname));
			return undef;
		}
		$opt->{spec} = <<EOF;
ra=1
rf=$opt->{fn}
tf=$sort
EOF
	}

	my $scan = Vend::Interpolate::escape_scan($opt->{spec});
	$scan =~ s:^scan/::;

	my $c = {
				mv_list_only        => 1,
				mv_search_file		=> $bx_fn,
			};

	Vend::Scan::find_search_params($c, $scan);
	
	$c->{mv_matchlimit} = 100000
		unless defined $c->{mv_matchlimit};
	my $f_delim = $c->{mv_return_delim} || "\t";
	my $r_delim = $c->{mv_record_delim} || "\n";

	my @fn;
	if($c->{mv_return_fields}) {
		@fn = split /\s*[\0,]+\s*/, $c->{mv_return_fields};
	}

#::logDebug( "search options: " . uneval($c) . "\n");

	open(Vend::Data::INDEX, "+<$ix_fn") or
		open(Vend::Data::INDEX, "+>$ix_fn") or
	   		die "Couldn't open $ix_fn: $!\n";
	lockfile(\*Vend::Data::INDEX, 1, 1)
		or die "Couldn't exclusive lock $ix_fn: $!\n";
	open(Vend::Data::INDEX, "+>$ix_fn") or
	   	die "Couldn't write $ix_fn: $!\n";

	if(@fn) {
		print INDEX " ";
		print INDEX join $f_delim, @fn;
		print INDEX $r_delim;
	}
	
	my $ref = Vend::Scan::perform_search($c);
	for(@$ref) {
		print INDEX join $f_delim, @$_; 
		print INDEX $r_delim;
	}

	unlockfile(\*Vend::Data::INDEX)
		or die "Couldn't unlock $ix_fn: $!\n";
	close(Vend::Data::INDEX)
		or die "Couldn't close $ix_fn: $!\n";
	return 1 if $opt->{show_status};
	return;
}

sub export_database {
	my($db, $file, $type, $opt) = @_;
	return undef unless defined $db;

	my (@data, $field, $delete);

	$field  = $opt->{field}         if $opt->{field};
	$delete = $opt->{delete}		if $opt->{delete};

	$db = database_exists_ref($db)
		or do {
			logError("Vend::Data export: non-existent database %s" , $db);
			return undef;
		};

	$db = $db->ref();

	if ($Vend::Cfg->{NoExportExternal} and !$opt->{force}) {
		# Skip export only for "external" tables (currently SQL and LDAP),
		# just like NoImportExternal does
		my $class = $db->config('Class');
		my $class_config = $db_config{$class || $Global::Default_database};
		return 1 if $class_config->{RestrictedImport};
	}

	my $table_name = $db->config('name');

	return 1 if $Vend::Cfg->{NoExport}{$table_name} and !$opt->{force};

	my $qual;
	if($qual = $opt->{where}) {
		if(ref $qual) {
			my @out;
			for(keys %$qual) {
				my $val = $db->quote($qual->{$_}, $_);
				push @out, "$_ = $val";
			}
			$qual = 'WHERE ' . join(" AND ", @out);
		}
		elsif($qual !~ /^\s*where\s+/i) {
			$qual = "WHERE $qual";
		}
	}

	my $notes;
	if("\U$type" eq 'NOTES') {
		$type = 2;
		$notes = 1;
	}

	my ($delim, $record_delim) = find_delimiter($type || $db->config('type'));
	$delim or ($delim, $record_delim) = find_delimiter($db->config('DELIMITER'));
	$delim or ($delim, $record_delim) = find_delimiter('TAB');

	$file = $file || $db->config('file');
	my $dir = $db->config('DIR');

	$file = Vend::Util::catfile( $dir, $file)
		unless Vend::Util::file_name_is_absolute($file);

	my @cols = $db->columns();

	my ($notouch, $nuke);
	if ($field and ! $delete) {
#::logDebug("Trying for add field=$field delete=$delete");
		if($db->column_exists($field)) {
			logError(
				"Can't define column '%s' twice in table '%s'",
				$field,
				$table_name,
			);
			return undef;
		}
		logError("Adding column %s to table %s" , $field, $table_name);
		push @cols, $field;
		$notouch = 1;
	}
	elsif ($field) {
#::logDebug("Trying for delete field=$field delete=$delete");
		if(! $db->column_exists($field)) {
			logError(
				"Can't delete non-existent column '%s' in table '%s'",
				$field,
				$table_name,
			);
			return undef;
		}
		logError("Deleting column %s from table %s" , $field, $table_name);
		my @new = @cols;
		@cols = ();
		my $i = 0;
		for(@new) {
			unless ($_ eq $field) {
				push @cols, $_;
			}
			else {
				$nuke = $i;
				$notouch = 1;
				logError("Deleting field %s" , $_ );
			}
			$i++;
		}
	}

	my $tempdata;
	open(EXPORT, "+<$file") or
	   open(EXPORT, "+>$file") or
	   		die "Couldn't open $file: $!\n";
	lockfile(\*EXPORT, 1, 1)
		or die "Couldn't exclusive lock $file: $!\n";
	open(EXPORT, "+>$file") or
	   	die "Couldn't write $file: $!\n";
	
#::logDebug("EXPORT_SORT=" . $db->config('EXPORT_SORT'));
	if($opt->{sort} ||= $db->config('EXPORT_SORT')) {
#::logDebug("Found EXPORT_SORT=$opt->{sort}");
		my ($sort_field, $sort_option) = split /:/, $opt->{sort};
#::logDebug("Found sort_field=$sort_field sort_option=$sort_option");
		$db->sort_each($sort_field, $sort_option);
	}

	if($delim eq 'CSV') {
		$delim = '","';
		print EXPORT '"';
		print EXPORT join $delim, @cols;
		print EXPORT qq%"\n%;
		while( (undef, @data) = $db->each_record($qual) ) {
			print EXPORT '"';
			splice(@data, $nuke, 1) if defined $nuke;
			$tempdata = join $delim, @data;
			$tempdata =~ tr/\n/\r/;
			print EXPORT $tempdata;
			print EXPORT qq%"\n%;
		}
	}
	elsif ($delim eq "\n" and $notes || $db->config('CONTINUE') eq 'NOTES') {
		my $sep;
		my $nf_col;
		my $nf;
		if($db->config('CONTINUE') eq 'NOTES') {
			$sep	= $db->config('NOTES_SEPARATOR');
			$nf_col	= $#cols;
			$nf		= pop @cols;
		}
		else {
			$sep = $opt->{notes_separator} || "\f";
			$nf = $opt->{notes_field} || 'notes_field';
			for( my $i = 0; $i < @cols; $i++ ) {
				next unless $cols[$i] eq $nf;
				$nf_col = $i;
				last;
			}
			$nf_col = scalar @cols if ! defined $nf_col;
			splice(@cols, $nf_col, 1);
		}
		print EXPORT join "\n", @cols;
		print EXPORT "\n$nf $sep\n\n";
		my $i;
		while( (undef, @data) = $db->each_record($qual) ) {
			splice(@data, $nuke, 1) if defined $nuke;
			my $nd = splice(@data, $nf_col, 1);
			# Yes, we don't want the last field yet. 8-)
			for($i = 0; $i < $#data; $i++) {
				next if $data[$i] eq '';
				$data[$i] =~ tr/\n/\r/;
				print EXPORT
					"$cols[$i]: $data[$i]\n" unless $data[$i] eq '';
			}
			print EXPORT "\n$nd\n$sep\n";
		}
	}
	elsif($record_delim eq "\n") {
		print EXPORT join $delim, @cols;
		print EXPORT $record_delim;
		my $detab = ($delim eq "\t") ? 1 : 0;
		if(defined $nuke) {
			while( (undef, @data) = $db->each_record($qual) ) {
				splice(@data, $nuke, 1);
				if ($detab) { s/\t/ /g for @data; }
				$tempdata = join $delim, @data;
				$tempdata =~ s/\r?\n/\r/g;
				print EXPORT $tempdata, $record_delim;
			}
		}
		else {
			while( (undef, @data) = $db->each_record($qual) ) {
				if ($detab) { s/\t/ /g for @data; }
				$tempdata = join $delim, @data;
				$tempdata =~ s/\r?\n/\r/g;
				print EXPORT $tempdata, $record_delim;
			}
		}
	}
	else {
		print EXPORT join $delim, @cols;
		print EXPORT $record_delim;
		my $detab = ($delim eq "\t" or $record_delim eq "\t") ? 1 : 0;
		while( (undef, @data) = $db->each_record($qual) ) {
			splice(@data, $nuke, 1) if defined $nuke;
			if ($detab) { s/\t/ /g for @data; }
			print EXPORT join($delim, @data);
			print EXPORT $record_delim;
		}
	}
	unlockfile(\*EXPORT)
		or die "Couldn't unlock $file: $!\n";
	close(EXPORT)
		or die "Couldn't close $file: $!\n";
	if(defined $notouch) {
		my $f = $db->config('db_file_extended');
		unlink $f if $f;
	}
	else {
		$db->touch();
	}
	if (my $subs = $db->config('POSTEXPORT')) {
		# Make a copy of the options once to hand off to each sub.
		my $options = { %$opt, delim => $delim, record_delim => $record_delim };
		for my $name (@$subs) {
			my $sub = $Vend::Cfg->{Sub}{$name} || $Global::GlobalSub->{$name}
				or do {
					logError("Unknown POSTEXPORT sub '%s' on database '%s'.", $name, $db->name);
					next;
				};
			$sub->($db->name, $file, $options)
				or logError("Failed call to POSTEXPORT sub '%s' on database '%s'!", $name, $db->name);
		}
	}
	1;
}

my $opt_remap = 0;
my %opt_map;

sub remap_options {
	return if not defined $opt_remap;
	my $record = shift;
	if($opt_remap and $record) {
		my %rec;
		my @del;
		my ($k, $v);
		while (($k, $v) = each %opt_map) {
			next unless defined $record->{$v};
			$rec{$k} = $record->{$v};
			push @del, $v;
		}
		delete @{$record}{@del};
		@{$record}{keys %rec} = (values %rec);
	}
	elsif($::Variable->{MV_OPTION_TABLE_MAP}) {
		$opt_remap = $::Variable->{MV_OPTION_TABLE_MAP};
		$opt_remap =~ s/^\s+//;
		$opt_remap =~ s/\s+$//;
		map { m{(.*?)=(.*)} and $opt_map{$2} = $1} split /[\0,\s]+/, $opt_remap;
		$opt_remap = 1;
		remap_options($record);
	}
	else {
		undef $opt_remap;
	}
	return;
}

sub chain_cost {
	my ($item, $raw) = @_;

	return $raw if $raw =~ /^[\d.]*$/;
	my $price;
	my $final = 0;
	my $its = 0;
	my @p;
	$raw =~ s/^\s+//;
	$raw =~ s/\s+$//;
	if($raw =~ /^\[\B/ and $raw =~ /\]$/) {
		my $ref = Vend::Interpolate::tag_calc($raw);
		@p = ref $ref ? @{$ref} : $ref;
	}
	else {
		@p = Text::ParseWords::shellwords($raw);
	}
	if(scalar @p > ($::Limit->{chained_cost_levels} || 64)) {
		logError('Too many chained cost levels for item ' .  uneval($item) );
		return undef;
	}

#::logDebug("chain_cost item = " . uneval ($item) . "\np=" . uneval(\@p) );
	my ($chain, $percent);
	my $passed_key;
	my $want_key;
CHAIN:
	foreach $price (@p) {
		next if ! length($price);
		if($its++ > ($::Limit->{chained_cost_levels} || 64)) {
			logError('Too many chained cost levels for item ' .  uneval($item) );
			last CHAIN;
		}
		$price =~ s/^\s+//;
		$price =~ s/\s+$//;
		if ($want_key) {
			$passed_key = $price;
			undef $want_key;
			next CHAIN;
		}
		if ($price =~ s/^;//) {
			next if $final;
		}
		$price =~ s/,$// and $chain = 1;
		if ($price =~ /^ \(  \s*  (.*)  \s* \) \s* $/x) {
			$price = $1;
			$want_key = 1;
		}
		if ($price =~ s/^([^-+\d.].*)//s) {
			my $mod = $1;
			if($mod =~ s/^\$(\d|$)/$1/) {
				$price = $item->{mv_price} || $mod;
				if($price =~ /^\s*free\s*$/i) {
					$final = 0;
					last CHAIN;
				}
				redo CHAIN;
			}
			elsif($mod =~ /^(\w*):([^:]*)(?::(\S*))?$/) {
				my ($table, $field, $key) = ($1, $2, $3);
#::logDebug("field begins as '$field'");
				$field = $Vend::Cfg->{PriceDefault} if ! $field;
				if($passed_key) {
					(! $key   and $key   = $passed_key)
						or 
					(! $field and $field = $passed_key)
						or 
					(! $table and $table = $passed_key);
					undef $passed_key;
				}
				$table = $item->{mv_ib} || $Vend::Cfg->{ProductFiles}[0]
					if ! $table;
				if($key and defined $item->{$key}) {
					$key = $item->{$key};
				}
				my @breaks;
				if($field =~ /,/ || $field =~ /\.\./) {
					my (@tmp) = split /,/, $field;
					for(@tmp) {
						if (/(.+?)(\d+)\.\.+.+?(\d+)/) {
							push @breaks, map { "$1$_" } $2 .. $3;
						}
						else {
							push @breaks, $_;
						}
					}
				}
				if(@breaks) {
#::logDebug("price breaks: " . join(',', @breaks));
					my $quantity;
					my $attribute;
					$attribute = shift @breaks  if $breaks[0] !~ /\d/;
					if (! $attribute || ! $item->{$attribute}) {
						$quantity = $item->{quantity};
					}
					else {
						my $regex;
						$regex = $item->{$attribute}
							unless $item->{$attribute} =~ /^[\d.]+$/;
						$quantity = Vend::Util::tag_nitems(
									undef, 
									{
										qualifier => $attribute,
										compare   => $regex || undef,
									},
						);
					}

					$field = shift @breaks;
					my $test = $field;
					$test =~ s/\D+//;
					redo CHAIN if $quantity < $test;

					my $t = $table || $item->{mv_ib} || $Vend::Cfg->{ProductFiles}[0];
					my $k = $key || $item->{code};
					my $row = database_row($t, $k);
#::logDebug("database reference to price breaks found table=$t key=$k row=" . ::uneval($row));
					redo CHAIN if ref $row ne 'HASH';

					my $keep;
					$keep = $row->{$field}
						if length($row->{$field}) && $row->{$field} != 0;
					for (@breaks) {
						next unless exists $row->{$_};
						$test = $_;
						$test =~ s/\D+//;
						last if $test > $quantity;
						$field = $_;
						$keep = $row->{$field} if $row->{$field} != 0;
					}
#::logDebug("price=$keep") if $keep;
					$price = $keep if $keep;
					redo CHAIN;
				}
				$price = database_field(
						($table || $item->{mv_ib} || $Vend::Cfg->{ProductFiles}[0]),
						($key || $item->{code}),
						$field
						);
#::logDebug("database reference found table=$table field=$field key=$key|$item->{$key}|$item->{code} price=$price");
				redo CHAIN;
			}
			elsif ($mod =~ s/(\w+)=(.*)//) {
				my $tag = $1;
				my(@args) = split /:/, $2;
				my $sub	=   # $intrinsic_price{$tag} ||
							$Vend::Cfg->{Sub}{$tag} || $Global::GlobalSub->{$tag};

				my %i = %$item;
			
				for(@args) {
					my($k, $v) = split /=/, $_;
					$i{$k} = $v;
				}

				$i{final} = $final;
				$i{passed_key} = $passed_key if $passed_key;

				if ($sub) {
					$price = $sub->(\%i);
				}
				else {
					$price = Vend::Tags->$tag(\%i);
				}
				redo CHAIN;
			}
			elsif ($mod =~ s/^[&]//) {
				$Vend::Interpolate::item = $item;
				$Vend::Interpolate::s = $final;
				$Vend::Interpolate::q = $item->{quantity};
				$price = Vend::Interpolate::tag_calc($mod);
				undef $Vend::Interpolate::item;
				redo CHAIN;
			}
			elsif ($mod =~ s/^=([\d.]*)=([^=]+)//) {
				$final += $1 if $1;
				my ($attribute, $table, $field, $key) = split /:/, $2;
				if($attribute) {
					$key = $field ? $item->{$attribute} : $item->{code}
						unless $key;
					$price = database_field( ( $table ||
												$item->{mv_ib} ||
												$Vend::Cfg->{ProductFiles}[0]),
											$key,
											($field || $item->{$attribute})
									);
					redo CHAIN;
				}
				elsif ($table) {
#::logDebug("before option_cost price=$price final=$final");
					my ($p, $f);
					($p, $f) = Vend::Options::option_cost($item, $table, $final);
					$final = $f if defined $f;
					$price = $p || '';
#::logDebug("option_cost returned p=$p f=$f, price=$price final=$final");
					redo CHAIN;
				}
			}
			elsif($mod =~ /^\s*[[_]+/) {
				$::Scratch->{mv_item_object} = $Vend::Interpolate::item = $item;
				$Vend::Interpolate::s = $final;
				$Vend::Interpolate::q = $item->{quantity};
				$price = Vend::Interpolate::interpolate_html($mod);
				undef $::Scratch->{mv_item_object};
				undef $Vend::Interpolate::item;
				redo CHAIN;
			}
			elsif($mod =~ s/^>>+//) {
				# This can point to a new mode for shipping
				# or taxing
				$final = $mod;
				last CHAIN;
			}
			else {
				$passed_key = $mod;
				next CHAIN;
			}
		}
		elsif($price =~ s/%$//) {
			$price = $final * ($price / 100); 
		}
		elsif($price =~ s/\s*\*$//) {
			$final *= $price;
			undef $price;
		}
		$final += $price if $price;
		last if ($final and !$chain);
		undef $chain;
		undef $passed_key;
#::logDebug("chain_cost intermediate '$final'");
	}
#::logDebug("chain_cost returning '$final'");
	return $final;
}


sub item_price {
	my($item, $quantity, $noformat) = @_;

#::logDebug("item_price initial call: " . (ref $item ? $item->{code} : $item));

	return $item->{mv_cache_price}
		if ! $quantity and defined $item->{mv_cache_price};

	$item = { 'code' => $item } unless ref $item;
	$item->{quantity} = 1 if ! defined $item->{quantity};

	if(	!	$item->{mv_ib}
		and	$Vend::Cfg->{AutoModifier}
		and	$item->{mv_ib} = product_code_exists_tag($item->{code})
		)
	{
		foreach my $i (@{$Vend::Cfg->{AutoModifier}}) {
			my $attr;
			my ($table,$key,$foreign) = split /:+/, $i, 3;

			if($table =~ /=/) {
				($attr, $table) = split /\s*=\s*/, $table, 2;
			}

			if(! $key and ! $foreign) {
				$attr ||= $table;
				$item->{$attr} = item_common($item, $table);
				next;
			}

			unless ($key) {
				$key = $table;
				$table = $item->{mv_ib};
			}

			$attr ||= $key;
			$table ||= $Vend::Cfg->{ProductFiles}[0];

			my $select = $foreign ? $item->{$foreign} : $item->{code};
			$select ||= $item->{code};

#::logDebug("attr=$attr table=$table key=$key select=$select foreign=$foreign");
			$item->{$attr} = ::tag_data($table, $key, $select);
#::logDebug("item->$attr=$item->{$attr}");
		}
#::logDebug("item=" . ::uneval($item));
	}

	my $master;

	my @items;

	if ($item->{mv_mp}) {
		return 0 if $item->{mv_si};
		$master = $item;
		my $mv_mp = $item->{mv_mi}
			or do {
				logError("Bad modular item %s: ", uneval_it($item));
				return 0;
			};
		for(@$Vend::Items) {
			next unless $_->{mv_si} and $_->{mv_mi} eq $mv_mp;
#::logDebug("pushing item $_->{code}, mv_mi=$item->{mv_mi}, mv_mp=$item->{mv_mp}, mv_si=$item->{mv_si}");
			push @items, $_;
		}
	}
	

	my $final = 0;
	do {
		my $price;

		if ($Vend::Cfg->{PriceField}) {
			my $base;
			if (not $base = $item->{mv_ib}) {
				$base = product_code_exists_tag($item->{code})
					or ($Vend::Cfg->{OnFly} && 'mv_fly')
					or return undef;
			}
			$price = database_field($base, $item->{code}, $Vend::Cfg->{PriceField});
		}

#::logDebug("price for item before chain $item->{code}=$price PriceField=$Vend::Cfg->{PriceField}");
		$price = chain_cost($item,$price || $Vend::Cfg->{CommonAdjust});
		if($Vend::Cfg->{PriceDivide} == 0) {
			my $msg = "Locale %s PriceDivide non-numeric or zero [%s].";
			$msg .= " Possibly bad locale data.",
			logError(
				$msg,
				$::Scratch->{mv_currency} || $::Scratch->{mv_locale},
				$Vend::Cfg->{PriceDivide},
			);
			$Vend::Cfg->{PriceDivide} = 1;
		}
		$price = $price / $Vend::Cfg->{PriceDivide};

		$item->{mv_cache_price} = $price
			if ! $quantity and exists $item->{mv_cache_price};
#::logDebug("price for item $item->{code}=$price item=" . ::uneval_it($item)) if $price != 0;
		$final += $price;
	} while ($item = shift @items);
#::logDebug("#### final price for item $master->{code}=$final item=" . ::uneval($master)) if $master;
	$master->{mv_cache_price} = $final 
			if $master and ! $quantity and exists $master->{mv_cache_price};
#::logDebug("final price in item $master->{code} is $master->{mv_cache_price}") if $master;
	return $final;
}

sub item_category {
	my $item = shift;
	my $base = $Vend::Database{$item->{mv_ib}} || $Products;
	return database_field($base, $item->{code}, $Vend::Cfg->{CategoryField});
}

sub item_description {
	my $item = shift;
	my $base = $Vend::Database{$item->{mv_ib}} || $Products;
	return database_field($base, $item->{code}, $Vend::Cfg->{DescriptionField});
}

sub item_common {
	my ($item, $field, $emptyok) = @_;
	my $base = $item->{mv_ib};
	my %seen;
	my $res;
	foreach my $code ($item->{code}, $item->{mv_sku}) {
		next if ! length($code);
		for my $dbname ($base, @{$Vend::Cfg->{ProductFiles}} ) {
			next if ! $dbname;
			next if $seen{$dbname}++;
			my $db = database_exists_ref($dbname)
				or next;
			last unless defined $db->test_column($field);
			$res = database_field($db, $code, $field);
			return $res if $emptyok or length($res);
		}
	}
}

sub item_field {
	my ($item, $field) = @_;
	my $base = $Vend::Database{$item->{mv_ib}} || $Products;
	my $res = database_field($base, $item->{code}, $field);
	return $res if length($res);
	return database_field($base, $item->{mv_sku}, $field);
}

sub item_subtotal {
	item_price($_[0]) * ($_[0]->{quantity} || 0);
}

sub set_db {
	my ($base, $thing) = @_;
	return ($base, $thing) unless $thing =~ /^(\w+):+(.*)/;
	my $t = $1;
	my $c = $2;

	# Security handled before this in update_data
	$Vend::WriteDatabase{$t} = 1;

	my $db = database_exists_ref($t);
	return undef unless $db;
	return ($db->ref(), $c);
}

## Update the user-entered fields.
sub update_data {
	my($key,$value);
	my @cgi_keys = keys %CGI::values;
    # Update a database record
	# Check to see if this is allowed
#::logDebug("mv_data_enable=$::Scratch->{mv_data_enable}");
	if(! $::Scratch->{mv_data_enable}) {
		logError(
			 "Attempted database update without permission, table=%s key=%s.",
			 $CGI::values{mv_data_table},
			 $CGI::values{$CGI::values{mv_data_key}},
		);
		return undef;
	}
	unless (defined $CGI::values{mv_data_table} and 
		    defined $CGI::values{mv_data_key}      ) {
		logError("Attempted database operation without table, fields, or key.\n" .
					 "Table: '%s'\n" .
					 "Fields:'%s'\n" .
					 "Key:   '%s'\n",
					 $CGI::values{mv_data_table},
					 $CGI::values{mv_data_fields},
					 $CGI::values{mv_data_key},
				 );

		return undef;
	}

	my $function	= lc (delete $CGI::values{mv_data_function});
	if($function eq 'delete' and ! delete $CGI::values{mv_data_verify}) {
		logError("update_data: DELETE without VERIFY, abort");
		return undef;
	}
	my $table		= $CGI::values{mv_data_table};
	my $prikey		= $CGI::values{mv_data_key};
	my $decode		= is_yes($CGI::values{mv_data_decode});

	my $en_col;
#::logDebug("data_enable=$::Scratch->{mv_data_enable}, checking");
	if($::Scratch->{mv_data_enable} =~ /^(\w+):(.*?):/s) {
		# check for single key and possible set of columns
		my $en_table = $1;
		$en_col   = $2;
		my $en_key   = $::Scratch->{mv_data_enable_key};
#::logDebug("en_table=$en_table en_col=$en_col, en_key=$en_key, checking");
		if(  $en_table ne $table
			 or 
			 ($en_key and $CGI::values{$prikey} ne $en_key)
			)
		{
			logError("Attempted database operation without permission:\n" .
						 "Permission: '%s' (key='$en_key')\n" .
						 "Table: '%s'\n" .
						 "Fields:'%s'\n" .
						 "Key:   '%s'\n",
						 $::Scratch->{mv_data_enable},
						 $CGI::values{mv_data_table},
						 $CGI::values{mv_data_fields},
						 $CGI::values{$CGI::values{mv_data_key}},
				 );
			return undef;
		}
	}


	$Vend::WriteDatabase{$table} = 1;

    my $base_db = database_exists_ref($table)
        or die "Not a defined database '$table': $!\n";
    $base_db = $base_db->ref();

	my @fields		= grep $_ && $_ ne $prikey,
						split /[\s\0,]+/, $CGI::values{mv_data_fields};
	unshift(@fields, $prikey);

    my @file_fields = split /[\s\0,]+/, $CGI::values{mv_data_file_field};
    my @file_paths = split /\0/, $CGI::values{mv_data_file_path};
    my @file_name_from = split /\0/, $CGI::values{mv_data_file_name_from};
    my @file_oldfiles = split /\0/, $CGI::values{mv_data_file_oldfile};

	if($en_col) {
		$en_col =~ s/^\s+//;
		$en_col =~ s/\s+$//;
		my %col_present;
		@col_present{ grep /\S/, split /[\s\0,]+/, $en_col } = ();
		$col_present{$prikey} = 1;
		for(@fields, $CGI::values{mv_blob_field}, $CGI::values{mv_blob_pointer}) {
			next unless $_;
			next if exists $col_present{$_};
			next if /:/ and $::Scratch->{mv_data_enable} =~ / $_ /;
			logError("Attempted database operation without permission:\n" .
						 "Permission: '%s'\n" .
						 "Table: '%s'\n" .
						 "Fields:'%s'\n" .
						 "Key:   '%s'\n",
						 $::Scratch->{mv_data_enable},
						 $CGI::values{mv_data_table},
						 $CGI::values{mv_data_fields},
						 $CGI::values{$CGI::values{mv_data_key}},
				 );
			return undef;
		}
	}
	$function = 'update' unless $function;

	my %data;
	my %sneakdata;
	for(@fields) {
		$data{$_} = [];
	}

	my $count;
	my $multi = $CGI::values{$prikey} =~ tr/\0/\0/;
	my $max = 0;
	my $min = 9999;
	my ($minname, $maxname);

	while (($key, $value) = each %CGI::values) {
		next unless defined $data{$key};
		if($CGI::values{"mv_data_prep_$key"}) {
			$value = Vend::Interpolate::filter_value(
						 $CGI::values{"mv_data_prep_$key"},
						 $value
						 );
		}
		$count = (@{$data{$key}} = split /\0/, $value, -1);
		$max = $count, $maxname = $key if $count > $max;
		$min = $count, $minname = $key if $count < $min;
	}

	if( $multi and ($max - $min) > 1 and ! $CGI::values{mv_data_force}) {
		logError("probable bad form -- number of values min=%s (%s) max=%s (%s)", $min, $minname, $max, $maxname);
		return;
	}

	my $autonumber;
#::logDebug("function=$function auto_number=" . $base_db->config('_Auto_number'));
	if ($CGI::values{mv_data_auto_number}) {
		$autonumber = 1;
		my $ref = $data{$prikey};
		while (scalar @$ref < $max) {
			push @$ref, '';
		}
		$base_db->config('AUTO_NUMBER', '000001')
			if ! $base_db->config('_Auto_number');
		$CGI::values{mv_data_return_key} = $prikey
			unless $CGI::values{mv_data_return_key};
	}
	elsif($function eq 'insert' and $base_db->config('_Auto_number') ) {
			$autonumber = 1;
	}
#::logDebug("autonumber=$autonumber");

	my $multikey = $base_db->config('COMPOSITE_KEY');

 	if(@file_fields) {
		my $Tag = new Vend::Tags;
		my $acl_func;
		my $outfile;
		if($Vend::Session->{logged_in} and $Vend::admin) {
			$acl_func = sub {
				return $Tag->if_mm('files', shift);
			};
		}
		elsif($Vend::Session->{logged_in} and ! $Vend::admin) {
			$acl_func = sub {
				my $file = shift;
				return 1 if $::Scratch->{$file} == 1;
				return $Tag->userdb(
								function => 'check_file_acl',
								location => $file,
								mode => 'w'
								);
			};
		}
		else {
			$acl_func = sub { return $::Scratch->{shift(@_)} == 1 }
		}

		for (my $i = 0; $i < @file_fields; $i++) {
			my $nm = $file_fields[$i];

			next if $nm =~ /__\d+$/;
			my $dref;
			my $dmain;
			my $ntag = '';
			if($nm =~ m{^(\d+)_} and $CGI::values{$nm}) {
				$ntag = $1;
				$ntag .= "_";
				$sneakdata{$nm}->[0] =  $CGI::values{$nm};
				for(qw/ mv_data_file_name_to_ mv_data_file_size_to_ /) {
					my $t = $_ . $nm;
					my $fld = $CGI::values{$t}
						or next;
					$fld = "$ntag$fld";
					$sneakdata{$fld}->[0] = $CGI::values{$fld};
				}
				$dref = $sneakdata{$nm};
				$dmain = \%sneakdata;
			}
			else {
				$dref = $data{$nm};
				$dmain = \%data;
			}

			unless (length($dref->[0])) {
				# no need for a file update
				if($file_oldfiles[$i]) {
					$dref->[0] = $file_oldfiles[$i];
				}
				next;
			}

			# remove path components
			$dref->[0] =~ s:.*/::; 
			$dref->[0] =~ s:.*\\::; 

			if(my $switch = $file_name_from[$i]) {
				my $new;
				if($data{$switch} and $new = $data{$switch}->[0]) {
					my $ext = $dref->[0];
					if($ext =~ s/.*\.//) {
						$dref->[0] = join '.', $new, $ext;
					}
					else {
						$dref->[0] = $new;
					}
				}
			}

			if (length ($file_paths[$i])) {
				# real file upload
				$outfile = join('/', $file_paths[$i], $dref->[0]);
				my $ok;
				if (-f $outfile) {
					eval {
						$ok = $acl_func->($outfile);
					};
				} else {
					eval {
						$ok = $acl_func->($file_paths[$i]);
					};
				}
				if (! $ok) {
					if($@) {
						logError ("ACL function failed on '%s': %s", $outfile, $@);
					}
					else {
						logError ("Not allowed to upload \"%s\"", $outfile);
					}
					next;
				} 
				my $err;
				Vend::Interpolate::tag_value_extended(
										$nm,
										{
											test => 'isfile'
										}
										)
					or do {
						 logError("%s is not a file (does form allow file upload?).", $dref->[0]);
						 next;
					};
				Vend::Interpolate::tag_value_extended(
						$nm,
						{
							outfile => $outfile,
							umask => $::Scratch->{mv_create_umask} || '022',
							auto_create_dir => $::Scratch->{mv_auto_create_dir},
							yes => '1',
						}
					)
					or do {
						 logError("failed to write %s: %s", $outfile, $!);
						 next;
					};
			}
			else {
				# preparing to dump file contents into database column
				if(my $nfield = $CGI::values{"mv_data_file_name_to_$nm"}) {
					$dmain->{"$ntag$nfield"}->[0] = $dmain->{$nm}->[0];
				}
				$dmain->{$nm}->[0]
					= Vend::Interpolate::tag_value_extended ($nm,
						{file_contents => 1});
				if(my $sfield = $CGI::values{"mv_data_file_size_to_$nm"}) {
					$dmain->{"$ntag$sfield"}->[0] = length $dmain->{$nm}->[0];
				}
			}
		}
	}

	if (not defined $data{$prikey}) {
		logError("No key '%s' in field specifier %s", $prikey, 'mv_data_fields');
		return undef;
	}
	elsif ( ! @{$data{$prikey}}) {
		if($autonumber) {
			@{$data{$prikey}} = map { '' } @{ $data{$fields[1]} };
		}
		else {
			logError("No key '%s' found for function='%s' table='%s'",
						$prikey, $function, $CGI::values{mv_data_table},
						);
			return undef;
		}
	}

	my ($query,$i);
	my (@k);
	my (@v);
	my (@c);
	my (@rows_set);
	my (@email_rows);

	my $safe;
	my $blob_field;
	my $blob_nick;
	my $blob_ptr;

	# Fields to set in database despite mv_blob_only
	my %blob_exception;

	if($CGI::values{mv_blob_field} and $CGI::values{mv_blob_nick}) {
#::logDebug("update_data: blob processing enabled");
		$blob_field = $CGI::values{mv_blob_field};
		$blob_nick  = $CGI::values{mv_blob_nick};
		$blob_ptr   = $CGI::values{mv_blob_pointer};

		%blob_exception   =
				map { ($_, 1) } split /[\s,\0]+/, $CGI::values{mv_blob_exception};

		if( ! $base_db->column_exists($blob_field) ) {
			undef $blob_field;
			undef $blob_nick;
			logError("No blob field '%s' found for table='%s', skipping blob save.",
						$CGI::values{mv_blob_field}, $CGI::values{mv_data_table},
						);
		}
		elsif ($MVSAFE::Safe) {
			$safe = $Vend::Interpolate::ready_safe;
		}
		else {
			$safe = new Vend::Safe;
		}
		$base_db->column_exists($blob_ptr)
			or undef $blob_ptr;
#::logDebug("update_data: blob safe object=$safe");
	}

	my @multis;
	my $multiqual = $CGI::values{mv_data_multiple_qual} || $prikey;
	if($CGI::values{mv_data_multiple}) {
		my $re = qr/^\d+_$prikey$/;
		@multis = grep $_ =~ $re, @cgi_keys;
		for(@multis) {
			s/_.*//;
		}
		@multis = sort { $a <=> $b } @multis;
	}

#::logDebug("update_data:db=$base_db key=$prikey VALUES=" . ::uneval(\%CGI::values));
#::logDebug("update_data:db=$base_db key=$prikey data=" . ::uneval(\%data));
	my $select_key;
 SETDATA: {
	for($i = 0; $i < @{$data{$prikey}}; $i++) {
#::logDebug("iteration of update_data:db=$base_db key=$prikey data=" . ::uneval(\%data));
		@k = (); @v = ();
		for(keys %data) {
			next unless (length($value = $data{$_}->[$i]) || $CGI::values{mv_update_empty} );
			push(@k, $_);
# LEGACY
			HTML::Entities::decode($value) if $decode;
# END LEGACY
			if($CGI::values{"mv_data_filter_$_"}) {
				$value = Vend::Interpolate::filter_value(
							 $CGI::values{"mv_data_filter_$_"},
							 $value,
							 $i,
							 );
			}
			$select_key = $value if $_ eq $prikey;
			not defined $value and $value = '';
			push(@v, $value);
		}

		if(! length($select_key) ) {
			next if  defined $CGI::values{mv_update_empty_key}
					 and   ! $CGI::values{mv_update_empty_key};
		}

		if($function eq 'delete') {
			$base_db->delete_record($select_key);
		}
		else {
			my $field;
			$key = $data{$prikey}->[$i];
			if(! length($key) and ! $autonumber) {
				## KEY IS possibly SET HERE 
				$key = $base_db->set_row($key);
			}
			push(@rows_set, $key);

			# allow form submissions to go to database and to mail
			if ($CGI::values{mv_data_email}) {
				push( @email_rows,
					[ errmsg("### Form Submission from %s", $key), $blob_nick, ],
					[ $prikey, $key, ],
				);
			}

			my $qd = {};
			my $qf = {};
			my $qv = {};
			my $qret;

			my $blob;
			my $brec;
			if($blob_field) {
				my $string = $base_db->field($key, $blob_field);
#::logDebug("update_data: blob string=$string");
				$blob = $safe->reval($string);
#::logDebug("update_data: blob object=$blob");
				$blob = {} unless ref($blob) eq 'HASH';
				$brec = $blob;
				my @keys = split /::/, $blob_nick;
				for(@keys) {
					unless ( ref($brec->{$_}) eq 'HASH') {
						$brec->{$_} = {};
					}
					$brec = $brec->{$_};
				}
			}
			while($field = shift @k) {
				$value = shift @v;
				next if $field eq $prikey and ! $multikey;
				
				## DATA IS SET HERE
				# We are going to set the field unless it is only for
				# storing in a blob (and possibly emailing)
				my  ($d, $f);
				if ($CGI::values{mv_blob_only} and ! $blob_exception{$field}) {
#::logDebug("$field not storing, only blob");
					$f = $field;
				}
				else {
#::logDebug("storing d=$d $field blob_only=$CGI::values{mv_blob_only}");
					($d, $f) = set_db($base_db, $field);
#::logDebug("storing table=$table d=$d f=$f key=$key");

					if(! $value and ! length($value)) {
						$value = $CGI::values{"mv_data_undef:$field"} ? undef : '';
					}

					if(! defined $qd->{$d}) {
						$qd->{$d} = $d;
						$qf->{$d} = [$f];
						$qv->{$d} = [$value];
					}
					else {
						push @{$qf->{$d}}, $f;
						push @{$qv->{$d}}, $value;
					}
					#$d->set_field($key, $f, $value);
				}

				push(@email_rows, [$f, $value])
					if $CGI::values{mv_data_email};
#::logDebug("update_data:db=$d key=$key field=$f value=$value");
				$brec->{$f} = $value if $brec;
			}

			my $dml = { dml => 'upsert' };
			$dml->{dml} = $function
				if $::Pragma->{dml} eq 'strict'
					|| $function eq 'insert' && $::Pragma->{dml} eq 'preserve';

			for(keys %$qd) {
#::logDebug("update_data: Getting ready to set_slice");
				my $k = $multikey ? undef : $key;
				$qret = $qd->{$_}->set_slice([$dml, $k], $qf->{$_}, $qv->{$_});
				$rows_set[$i] = $qret unless $rows_set[$i];
			}
			if($blob && $rows_set[$i]) {
				$brec->{mv_data_fields} = join " ", @fields;
				my $string =  uneval_it($blob);
#::logDebug("update_data: blob saving string=$string");
				$base_db->set_field($key, $blob_field, $string);
				if($blob_ptr) {
					$base_db->set_field($key, $blob_ptr, $blob_nick);
				}
			}
			push(
					@email_rows,
					[ errmsg("### END FORM SUBMISSION %s", $key), $blob_nick, ]
				)
				if $CGI::values{mv_data_email};
		}
	}

	if(my $new = shift(@multis)) {
		last SETDATA unless length $CGI::values{"${new}_$multiqual"};
		for(@fields) {
			my $t = $new . "_$_";
			if($sneakdata{$t}) {
				$data{$_} = delete $sneakdata{$t};
			}
			else {
				$data{$_} = [ $CGI::values{$_} = $CGI::values{$t} ];
			 
			}
		}
		redo SETDATA;
	}
 } # end SETDATA

	if($CGI::values{mv_data_return_key}) {
		my @keys = split /\0/, $CGI::values{mv_data_return_key};
		for(@keys) {
			$CGI::values{$_} = join("\0", @rows_set);
		}
	}

	if($CGI::values{mv_auto_export}) {
		Vend::Data::export_database($table);
	}

	if($CGI::values{mv_data_email}) {
		push @email_rows, [ 'mv_data_fields', \@fields ];
		Vend::Interpolate::tag_mail('', { log_error => 1 }, \@email_rows);
	}

	# Allow setting in one then returning to another
	if($CGI::values{mv_return_table}) {
		$CGI::values{mv_data_table} = $CGI::values{mv_return_table};
	}

	my @reloads = grep /^mv_data_table__\d+$/, keys %CGI::values;
	if(@reloads) {
		@reloads = map { m/.*__(\d+)$/; $1 } @reloads;
		@reloads = sort { $a <=> $b } @reloads;
		my $new = shift @reloads;
		my $this = qr{__$new$};
		my $some = qr{__\d+$};
#::logDebug("Reloading, new=$new this=$this some=$some");
		my %cgiset;
		my @death_row;
		for(@cgi_keys) {
			push(@death_row, $_), next unless $_ =~ $some;
			if($_ =~ $this) {
				my $k = $_;
				$k =~ s/$this//;
				$cgiset{$k} = delete $CGI::values{$_};
			}
		}

		my @file_death;
		my %filekill;
		my %filemove;

		for(my $i = 0; $i < @file_fields; $i++) {
			push(@file_death, $i), next unless $file_fields[$i] =~ $some;
			if($file_fields[$i] =~ $this) {
				my $k = $file_fields[$i];
				$k =~ s/$this//;
				$filemove{$file_fields[$i]} = $k;
			}
		}

		my $i;
		while (defined($i = pop @file_death)) {
			splice @file_fields, $i, 1;
			splice @file_paths, $i, 1;
			splice @file_oldfiles, $i, 1;
		}

		for(@file_fields) {
			if(my $new = $filemove{$_}) {
				$_ = $new;
			}

		}

		while(my ($k,$v) = each %filemove) {
			$CGI::file{$v} = delete $CGI::file{$k};
		}


		$::Scratch->{mv_data_enable} = delete $::Scratch->{"mv_data_enable__$new"};
		delete $::Scratch->{mv_data_enable_key};

		for(@death_row) {
			next unless /^mv_(data|blob|update)_/ or $data{$_}; # Reprieve!
			delete $CGI::values{$_};
		}

		@CGI::values{keys %cgiset} = values %cgiset;
		$CGI::values{mv_data_file_field} = join "\0", @file_fields;
		$CGI::values{mv_data_file_path} = join "\0", @file_paths;
		$CGI::values{mv_data_file_oldfiles} = join "\0", @file_oldfiles;
#::logDebug("Reloading, function=$CGI::values{mv_data_function}");
		update_data();
	}

	return;
}

1;

__END__
