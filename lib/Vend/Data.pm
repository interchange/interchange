# Data.pm - Interchange databases
#
# $Id: Data.pm,v 1.13.4.2 2000-11-02 00:06:39 racke Exp $
# 
# Copyright (C) 1996-2000 Akopia, Inc. <info@akopia.com>
#
# This program was originally based on Vend 0.2
# Copyright 1995 by Andrew M. Wilcox <awilcox@world.std.com>
#
# Portions from Vend 0.3
# Copyright 1995 by Andrew M. Wilcox <awilcox@world.std.com>
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
# Software Foundation, Inc., 59 Temple Place, Suite 330, Boston,
# MA  02111-1307  USA.

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
item_description
item_field
item_price
item_subtotal
sql_query
open_database
product_code_exists_ref
product_code_exists_tag
product_description
product_field
product_price
set_field

);
@EXPORT_OK = qw(update_productbase column_index);

use strict;
use File::Basename;
use Vend::Util;
use Vend::Interpolate;
use Vend::Table::Common qw(import_ascii_delimited);

File::Basename::fileparse_set_fstype($^O);

BEGIN {
# SQL
	if($Global::DBI) {
		require Vend::Table::DBI;
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
}

my ($Products, $Item_price);

sub database_exists_ref {
	return $_[0]->ref() if ref $_[0];
	return $Vend::Interpolate::Db{$_[0]}
			if $Vend::Interpolate::Db{$_[0]};
	return undef unless defined $Vend::Database{$_[0]};
	return $Vend::Database{$_[0]}->ref() || undef;
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
	}
	$Products = $Vend::Productbase[0];
#::logError("Productbase: '@Vend::Productbase' --> " . ::uneval(\%Vend::Basefinder));

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

sub product_description {
    my ($code, $base) = @_;
    return "" unless $base = product_code_exists_ref($code, $base || undef);
    return database_field($base, $code, $Vend::Cfg->{DescriptionField});
}

sub database_field {
    my ($db, $key, $field_name) = @_;
    $db = database_exists_ref($db) or return undef;
    return '' unless $db->test_record($key);
    return '' unless defined $db->test_column($field_name);
    return $db->field($key, $field_name);
}

sub database_row {
    my ($db, $key, $field_name) = @_;
    $db = database_exists_ref($db) or return undef;
return undef unless defined $db;
    return '' unless $db->test_record($key);
    return $db->row_hash($key);
}

sub increment_field {
    my ($db, $key, $field_name, $adder) = @_;
	$db = $db->ref();
    return undef unless $db->test_record($key);
    return undef unless defined $db->test_column($field_name);
#::logDebug(__PACKAGE__ . "increment_field: " . ::uneval(\@_));
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
		$options->{'delimiter'} = $delimiter;
	}

	if($options->{'file'}) {
		$fn = $options->{'file'};
		if( $Global::NoAbsolute) {
			die "No absolute file names like '$fn' allowed.\n"
				if Vend::Util::file_name_is_absolute($fn);
		}
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
    my ($db, $key, $field_name, $value, $append) = @_;

	$db = database_exists_ref($db);
    return undef unless defined $db->test_column($field_name);

	# Create it if it doesn't exist
	unless ($db->record_exists($key)) {
		$db->set_row($key);
	}
	elsif ($append) {
		$value = $db->field($key, $field_name) . $value;
	}
    return $db->set_field($key, $field_name, $value);
}

sub product_field {
    my ($field_name, $code, $base) = @_;
	return database_field($Vend::Cfg->{OnlyProducts}, $field_name, $code)
		if $Vend::Cfg->{OnlyProducts};
	my ($db);
    $db = product_code_exists_ref($code, $base || undef)
		or return '';
    return "" unless defined $db->test_column($field_name);
    return $db->field($code, $field_name);
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

# SQL
sub sql_query {
	my($type, $query, $opt, $list) = @_;

	my ($db);

	$opt->{table} = $Vend::Cfg->{ProductFiles}[0] unless defined $opt->{table};
	$db = $Vend::Database{$opt->{table}}
		or die "dbi_query: unknown base table $opt->{table}.\n";
	$db = $db->ref();

	$type = lc $type;

	if ($list and $type ne 'list') {
		$query = '' if ! defined $query;
		$query .= $list;
	}

	my $perlquery;

	my @arg;
	while ($query =~ s:\[arg\](.*?)\[/arg\]::o) {
		push(@arg, $1);
	}

	while ($query =~ s:\[control\s+([\w][-\w]*)\]([\000-\377]*?)\[/control\]::) {
		my ($key, $val) = ($1, $2);
		if($key =~ /PERL/i) {
			$perlquery = 1;
			$opt->{textref} = 0;
		}
		elsif ($key =~ /BOTH/i){
			$perlquery = 1;
			$opt->{textref} = 1;
		}
		else {
			$opt->{"\L$key"} = $val;
		}
	}

	if($type eq 'list') {
		$opt->{list} = 1;
		push(@arg, $1) while $query =~ s:\[arg\](.*?)\[/arg\]::o;
		$list =~ s:\[query\]([\000-\377]+)\[/query\]::i and $query = $1;
	}
	elsif ($type eq 'hash') {
		$opt->{textref} = 1;
		$opt->{hashref} = 1;
	}
	elsif ($type eq 'array') {
		$opt->{textref} = 1;
	}
	elsif ($type eq 'param') {
		warn "sql query type=param deprecated";
		$opt->{list} = 1;
		$list = '"[sql-code]" ';
	}
	elsif ($type eq 'html') {
		$opt->{html} = 1;
	}
	$opt->{query} = $query if $query;
	return $db->query($opt, $list, @arg);
}
# END SQL

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
	my($db, $name);
	undef $Products;
	while( ($name)	= each %Vend::Database ) {
    	$Vend::Database{$name}->close_table()
			unless defined $Vend::Cfg->{SaveDatabase}{$name};
		delete $Vend::Database{$name};
	}
	undef %Vend::WriteDatabase;
	undef %Vend::Basefinder;
}

sub database_ref {
	my $db = $_[0] || $Products;
	return $db->ref() if $db;
	return undef;
}

## PRODUCTS

# Read in the shipping file.

*read_shipping = \&Vend::Interpolate::read_shipping;

# Read in the accessories file.

sub read_accessories {
    my($code, $accessories);

	my $file = $Vend::Cfg->{Special}{'accessories.asc'}
				|| Vend::Util::catfile($Vend::Cfg->{ProductDir}, 'accessories.asc');
	return undef unless -f $file;
    open(Vend::ACCESSORIES, "< $file") or return undef;
    while(<Vend::ACCESSORIES>) {
		chomp;
		tr/\r//d;
		if (s/\\\s*$//) { # handle continues
	        $_ .= <Vend::ACCESSORIES>;
			redo;
		}
		($code, $accessories) = split(/\t/, $_, 2);
		$Vend::Cfg->{Accessories}->{$code} = $accessories;
    }
    close Vend::ACCESSORIES;
	1;
}

# Read in the sales tax file.
sub read_salestax {
    my($code, $percent);

	return unless $Vend::Cfg->{SalesTax};
	my $file = $Vend::Cfg->{Special}{'salestax.asc'};
	$file = Vend::Util::catfile($Vend::Cfg->{ProductDir}, "salestax.asc")
		unless $file;

	$Vend::Cfg->{SalesTaxTable} = {};
    -f $file and open(Vend::SALESTAX, "< $file") or do {
					logError( "Could not open salestax file %s: %s" ,
								$file,
								$!
							)
						if ! $Vend::Cfg->{SalesTaxFunction};
					return undef;
				};
    while(<Vend::SALESTAX>) {
		chomp;
		tr/\r//d;
		($code, $percent) = split(/\s+/, $_, 2);
		$Vend::Cfg->{SalesTaxTable}->{"\U$code"} = $percent;
    }
    close Vend::SALESTAX;

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
	LINE => ["\n", "\n\n"],
	'%%%' => ["\n%%\n", "\n%%%\n"],
	'%%' => ["\n%%\n", "\n%%%\n"],
	CSV => ["CSV","\n"],
	PIPE => ['|', "\n"],
	TAB => ["\t", "\n"],

	);

sub find_delimiter {
	my ($type) = @_;
	$type = $type || 1;
	return @{$Delimiter{$type}}
		if defined $Delimiter{$type}; 
	return ("\t", "\n");
}

my %db_config = (
# SQL
		'DBI' => {
				qw/
					Extension			 sql
					RestrictedImport	 1
					Class                Vend::Table::DBI
				/
				},
# END SQL
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
    while (($name,$data) = each %{$Vend::Cfg->{Database}}) {
		if( $data->{type} > 6 or $data->{HOT} ) {
#::logDebug("Importing $data->{name}...");
			$Vend::Database{$name} = import_database($data);
		}
		else {
			if($data->{GUESS_NUMERIC}) {
				my $dir = $data->{dir} || $Vend::Cfg->{ProductDir};
				my $fn = Vend::Util::catfile( $dir, $data->{file} );
				my @fields = grep /\S/, split /\s+/, ::readfile("$fn.numeric");
#::logDebug("fields=@fields");
				$data->{NUMERIC} = {};
				for(@fields) {
					$data->{NUMERIC}{$_} = 1;
				}
			}
			my $class = $db_config{$data->{Class}}->{Class};
			$Vend::Database{$name} = new $class ($data);
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
		$Vend::Database{$name} =
				new $class ($data);
	}
	update_productbase();
}

my $tried_import;

sub import_database {
    my ($obj, $dummy) = @_;


	my $database = $obj->{'file'};
	my $type     = $obj->{'type'};
	my $name     = $obj->{'name'};
#	if($type == 9) {
#my @caller = caller();
#::logDebug ("enter import_database: dummy=$dummy");
#::logDebug("opening table table=$database config=" . ::uneval($obj) . " caller=@caller");
#
#::logDebug ("database=$database type=$type name=$name obj=" . ::uneval($obj));
#::logDebug ("database=$database type=$type name=$name obj=" . ::uneval($obj)) if $obj->{HOT};
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

	my $no_import = defined $Vend::Cfg->{NoImport}->{$name};

	if (defined $Vend::ForceImport{$name}) {
		undef $no_import;
		delete $Vend::ForceImport{$name};
	}

	$base = $obj->{'name'};
	$dir = $obj->{'dir'} if defined $obj->{'dir'};

	$class_config = $db_config{$obj->{Class} || $Global::Default_database};

#::logDebug ("params=$database_txt path='$path' base='$base' tail='$tail'") if $type == 9;
	$table_name     = $name;
	my $export;

  IMPORT: {
	last IMPORT if $no_import and $obj->{'dir'};
	last IMPORT if defined $obj->{IMPORT_ONCE} and $obj->{'dir'};
#::logDebug ("first no_import_check: passed") if $type == 9;

    $database_txt = $database;

	($base,$path,$tail) = fileparse $database_txt, '\.[^/.]+$';

	if(Vend::Util::file_name_is_absolute($database_txt)) {
		if ($Global::NoAbsolute) {
			my $msg = errmsg(
							"Security violation for NoAbsolute, trying to import %s",
							$database_txt);
			logError( $msg );
			die "Security violation.\n";
		}
		$dir = $path;
	}
	else {
		$dir = $Vend::Cfg->{ProductDir} || $Global::ConfigDir;
		$database_txt = Vend::Util::catfile($dir,$database_txt);
	}

	$obj->{'dir'} = $dir;

	$obj->{ObjectType} = $class_config->{Class};

	if($class_config->{Extension}) {
		$database_dbm = Vend::Util::catfile(
												$dir,
												"$base."     .
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
			or ! -f $database_txt
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

	last IMPORT if $no_import;
#::logDebug ("moving to import") if $type == 9;

	$change_delimiter = $obj->{DELIMITER} if defined $obj->{DELIMITER};

	my $txt_time;
	my $dbm_time;
    if (
		! defined $database_dbm
		or ! -e $database_dbm
        or ($txt_time = file_modification_time($database_txt))
				>
           ($dbm_time = file_modification_time($database_dbm))
		)
	{
		
        warn "Importing $obj->{'name'} table from $database_txt\n"
			unless $Vend::Quiet;

		$type = 1 unless $type;
		($delimiter, $record_delim) = find_delimiter($change_delimiter || $type);
		$obj->{'delimiter'} = $delimiter;

		my $save = $/;
		local($/) = $record_delim if defined $record_delim;
        $db = $delimiter ne 'CSV'
			? Vend::Table::Common::import_ascii_delimited($database_txt, $obj, $new_table_name)
        	: Vend::Table::Common::import_csv($database_txt, $obj, $new_table_name);

		$/ = $save;
		if(defined $database_dbm) {
			$db->close_table() if defined $db;
			undef $db;
			unlink $database_dbm if $Global::Windows;
        	rename($new_database_dbm, $database_dbm)
            	or die "Couldn't move '$new_database_dbm' to '$database_dbm': $!\n";
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
			$obj->{Read_only} = $obj->{WRITE_CATALOG}{$Vend::Cfg->{CatalogName}}
					? (! defined $Vend::WriteDatabase{$name}) 
					: 1;
		}
		elsif($obj->{WRITE_TAGGED}) {
			$obj->{Read_only} = ! defined $Vend::WriteDatabase{$name};
		}
	}
	else {
		$obj->{Read_only} = ! defined $Vend::WriteDatabase{$name}
			if $class_config->{Tagged_write};
	}

		
    if($class_config->{Extension}) {

		$obj->{db_file} = $table_name unless $obj->{db_file};
		$obj->{db_text} = $database_txt unless $obj->{db_text};
		no strict 'refs';
		eval { 
			if($MVSAFE::Safe) {
#::logDebug("Opening under Safe: $obj->{name}: table=$table_name") if $type == 9;
				$db = $Vend::Interpolate::Db{$class_config->{Class}}->open_table( $obj, $table_name );
			}
			else {
#::logDebug("Opening $obj->{name}: table=$table_name") if $type == 9;
				$db = $class_config->{Class}->open_table( $obj, $table_name );
#::logDebug("Opened $obj->{name}") if $type == 9;
			}
			$obj->{NAME} = $db->[$Vend::Table::Common::COLUMN_INDEX]
				unless defined $obj->{NAME};
		};

		if($@) {
#::logDebug("Dieing of $@");
			die $@ unless $no_import;
			die $@ unless $tried_import++;
			if(! -f $database_dbm) {
				$Vend::ForceImport{$obj->{name}} = 1;
				return import_database($obj);
			}
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
			logError("Vend::Data export: non-existent database %s", $db);
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
#	"options: " . Vend::Util::uneval($opt) . "\n"
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
			::logError(errmsg("index attempted on table '%s' with no fields, no search spec", $dbname));
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
				mv_list_only		=> 1,
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

#::logDebug( "search options: " . Vend::Util::uneval($c) . "\n");

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
	my(@data);
	my ($field, $delete);
	return undef unless defined $db;

	$field  = $opt->{field}         if $opt->{field};
	$delete = $opt->{delete}		if $opt->{delete};

	$db = database_exists_ref($db)
		or do {
			logError("Vend::Data export: non-existent database %s" , $db);
			return undef;
		};

	$db = $db->ref();

	my $table_name = $db->config('name');
	my $notes;
	if("\U$type" eq 'NOTES') {
		$type = 2;
		$notes = 1;
	}

	my ($delim, $record_delim) = find_delimiter($type || $db->config('type'));

	$file = $file || $db->config('file');

	$file = Vend::Util::catfile( $Vend::Cfg->{ProductDir}, $file)
		unless Vend::Util::file_name_is_absolute($file);

	my @cols = $db->columns();

	my ($notouch, $nuke);
	if ($field and ! $delete) {
#::logDebug("Trying for delete field=$field delete=$delete");
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
#::logDebug("Trying for add field=$field delete=$delete");
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
		while( (undef, @data) = $db->each_record() ) {
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
		while( (undef, @data) = $db->each_record() ) {
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
		if(defined $nuke) {
			while( (undef, @data) = $db->each_record() ) {
				splice(@data, $nuke, 1) if defined $nuke;
				$tempdata = join $delim, @data;
				$tempdata =~ s/\r?\n/\r/g;
				print EXPORT $tempdata, $record_delim;
			}
		}
		else {
			while( (undef, @data) = $db->each_record() ) {
				$tempdata = join $delim, @data;
				$tempdata =~ s/\r?\n/\r/g;
				print EXPORT $tempdata, $record_delim;
			}
		}
	}
	else {
		print EXPORT join $delim, @cols;
		print EXPORT $record_delim;
		while( (undef, @data) = $db->each_record() ) {
			splice(@data, $nuke, 1) if defined $nuke;
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
		$db->touch() unless defined $notouch;
	}
	1;
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
		@p = @{$ref} if ref $ref;
	}
	else {
		@p = Text::ParseWords::shellwords($raw);
	}
	if(scalar @p > 16) {
			::logError('Too many chained cost levels for item ' .  uneval($item) );
			return undef;
	}

#::logDebug("chain_cost item = " . uneval ($item) );
	my ($chain, $percent);
	my $passed_key;
	my $want_key;
CHAIN:
	foreach $price (@p) {
		if($its++ > 20) {
			::logError('Too many chained cost levels for item ' .  uneval($item) );
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
		$chain = $price =~ s/,$// ? 1 : 0 unless $chain;
		if ($price =~ /^ \(  \s*  (.*)  \s* \) \s* $/x) {
			$price = $1;
			$want_key = 1;
		}
		if ($price =~ s/^([^-+\d.].*)//s) {
			my $mod = $1;
			if($mod =~ s/^\$(\d|$)/$1/) {
				$price = $item->{mv_price} || $mod;
				redo CHAIN;
			}
			elsif($mod =~ /^(\w*):([^:]*)(:(\S*))?$/) {
				my ($table,$field,$key) = ($1, $2, $4);
				$field = $Vend::Cfg->{PriceDefault} if ! $field;
				if($passed_key) {
					(! $key   and $key   = $passed_key)
						or 
					(! $field and $field = $passed_key)
						or 
					(! $table and $table = $passed_key);
					undef $passed_key;
				}
				my @breaks;
				if($field =~ /,/ || $field =~ /\.\./) {
					my (@tmp) = split /,/, $field;
					for(@tmp) {
						if (/(.+)\.\.+(.+)/) {
							push @breaks, $1 .. $2;
						}
						else {
							push @breaks, $_;
						}
					}
				}
				if(@breaks) {
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
					for(@breaks) {
						$test = $_;
						$test =~ s/\D+//;
						last if $test > $quantity;
						$field = $_;
					}
				}
				$price = database_field(
						($table || $item->{mv_ib} || $Vend::Cfg->{ProductFiles}[0]),
											($key || $item->{code}),
											$field
										);
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
				$item->{$attribute} and
					do {
						$key = $field ? $item->{$attribute} : $item->{'code'};
						$price = database_field( ( $table ||
													$item->{mv_ib} ||
													$Vend::Cfg->{ProductFiles}[0]),
												$key,
												($field || $item->{$attribute})
										);
						redo CHAIN;
					};
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
#::logDebug("item_price: " . ::uneval_it(\@_));
	return $item->{mv_cache_price}
		if ! $quantity and defined $item->{mv_cache_price};
	my ($price, $base, $adjusted);
	$item = { 'code' => $item, 'quantity' => ($quantity || 1) } unless ref $item;
	if(not $base = $item->{mv_ib}) {
		$base = product_code_exists_tag($item->{code}, $item->{mv_ib})
			or $Vend::Cfg->{OnFly}
			or return undef;
	}
	$price = database_field($base, $item->{code}, $Vend::Cfg->{PriceField})
		if $Vend::Cfg->{PriceField};
#::logDebug("item_price before chain cost: $price PriceField=$Vend::Cfg->{PriceField} base=$base");
	$price = chain_cost($item,$price || $Vend::Cfg->{CommonAdjust});
	$price = $price / $Vend::Cfg->{PriceDivide};
#::logDebug("item_price before cache: $price");
	$item->{mv_cache_price} = $price
		if ! $quantity and exists $item->{mv_cache_price};
#::logDebug("item_price final: $price");
	return $price;
}

sub item_description {
	return item_field($_[0], $Vend::Cfg->{DescriptionField});
}

sub item_field {
	my $base = $Vend::Database{$_[0]->{mv_ib}} || $Products;
	return database_field($base, $_[0]->{code}, $_[1]);
}

sub item_subtotal {
	item_price($_[0]) * $_[0]->{quantity};
}

1;

__END__
