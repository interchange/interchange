# Vend::Table::DB_File - Access an Interchange table stored in a DB file hash
#
# $Id: DB_File.pm,v 2.0.2.3 2002-11-26 03:21:13 jon Exp $
#
# Copyright (C) 1996-2002 Red Hat, Inc. and
# Interchange Development Group, http://www.icdevgroup.org/
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
# Software Foundation, Inc., 59 Temple Place, Suite 330, Boston,
# MA  02111-1307  USA.

package Vend::Table::DB_File;
use strict;
use Fcntl;
use DB_File;
use vars qw($VERSION @ISA);
use Vend::Table::Common;

@ISA = qw(Vend::Table::Common);
$VERSION = substr(q$Revision: 2.0.2.3 $, 10);

sub create {
	my ($class, $config, $columns, $filename) = @_;

	$config = {} unless defined $config;
	my $File_permission_mode = $config->{File_permission_mode} || 0666;

	die "columns argument $columns is not an array ref\n"
		unless CORE::ref($columns) eq 'ARRAY';

	# my $column_file = "$filename.columns";
	# my @columns = @$columns;
	# open(COLUMNS, ">$column_file")
	#    or die "Couldn't create '$column_file': $!";
	# print COLUMNS join("\t", @columns), "\n";
	# close(COLUMNS);

	my $column_index = Vend::Table::Common::create_columns($columns, $config);

	my $tie = {};
	my $flags = O_RDWR | O_CREAT;

	my $dbm = tie(%$tie, 'DB_File', $filename, $flags, $File_permission_mode)
		or die "Could not create '$filename': $!";

	$tie->{'c'} = join("\t", @$columns);

	my $s = [
				$config,
				$filename,
				$columns,
				$column_index,
				$config->{KEY_INDEX},
				$tie,
				$dbm
			];
	bless $s, $class;
}

sub new {
	my ($class, $obj) = @_;
	bless [$obj], $class;
}


sub open_table {
	my ($class, $config, $filename) = @_;

	my $tie = {};

	my $flags = O_RDONLY;

	if (! $config->{Read_only}) {
		undef $config->{Transactions};
		$config->{_Auto_number} = 1 if $config->{AUTO_NUMBER};
		$flags = O_RDWR;
		if(! defined $config->{AutoNumberCounter}) {
			eval {
				$config->{AutoNumberCounter} = new File::CounterFile
											"$config->{DIR}/$config->{name}.autonumber",
											$config->{AUTO_NUMBER} || '00001';
			};
			if($@) {
				::logError("Cannot create AutoNumberCounter: %s", $@);
				$config->{AutoNumberCounter} = '';
			}
		}
	}

	my $dbm = tie(%$tie, 'DB_File', $filename, $flags, 0600)
		or die "Could not open '$filename': $!";

	my $columns = [split(/\t/, $tie->{'c'})];

	my $column_index = Vend::Table::Common::create_columns($columns, $config);

	my $s = [
				$config,
				$filename,
				$columns,
				$column_index,
				$config->{KEY_INDEX},
				$tie,
				$dbm
			];
	bless $s, $class;
}

# Unfortunate hack need for Safe searches
*column_index	= \&Vend::Table::Common::column_index;
*column_exists	= \&Vend::Table::Common::column_exists;
*columns		= \&Vend::Table::Common::columns;
*commit			= \&Vend::Table::Common::commit;
*config			= \&Vend::Table::Common::config;
*delete_record	= \&Vend::Table::Common::delete_record;
*each_record	= \&Vend::Table::Common::each_record;
*field			= \&Vend::Table::Common::field;
*field_accessor	= \&Vend::Table::Common::field_accessor;
*field_settor	= \&Vend::Table::Common::field_settor;
*inc_field		= \&Vend::Table::Common::inc_field;
*isopen			= \&Vend::Table::Common::isopen;
*numeric		= \&Vend::Table::Common::numeric;
*quote			= \&Vend::Table::Common::quote;
*record_exists	= \&Vend::Table::Common::record_exists;
*ref			= \&Vend::Table::Common::ref;
*rollback		= \&Vend::Table::Common::rollback;
*row			= \&Vend::Table::Common::row;
*row_hash		= \&Vend::Table::Common::row_hash;
*row_settor		= \&Vend::Table::Common::row_settor;
*set_field		= \&Vend::Table::Common::set_field;
*set_slice		= \&Vend::Table::Common::set_slice;
*set_row  		= \&Vend::Table::Common::set_row;
*suicide		= \&Vend::Table::Common::suicide;
*test_column	= \&Vend::Table::Common::test_column;
*test_record	= \&Vend::Table::Common::record_exists;
*touch			= \&Vend::Table::Common::touch;

1;
