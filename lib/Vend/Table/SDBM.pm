# Vend::Table::SDBM - Access an Interchange table stored in Perl's internal SDBM
#
# $Id: SDBM.pm,v 2.17 2008-03-25 17:13:21 jon Exp $
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

package Vend::Table::SDBM;
use strict;
use Fcntl;
use SDBM_File;
use vars qw($VERSION @ISA);
use Vend::Table::Common;

@ISA = qw(Vend::Table::Common);
$VERSION = substr(q$Revision: 2.17 $, 10);

sub create {
	my ($class, $config, $columns, $filename) = @_;

	$config = {} unless defined $config;
#::logDebug("called create, config=" . ::uneval_it($config));
	my $File_permission_mode = $config->{File_permission_mode} || 0666;

	die ::errmsg("columns argument %s is not an array ref", $columns)
		unless CORE::ref($columns) eq 'ARRAY';

	my $column_index = Vend::Table::Common::create_columns($columns, $config);

	my $tie = {};
	my $flags = O_RDWR | O_CREAT;

	my $dbm;
	my $failed = 0;

	my $retry = $::Limit->{dbm_open_retries} || 10;

	while( $failed < $retry ) {
		$dbm = tie(%$tie, 'SDBM_File', $filename, $flags, $File_permission_mode)
			and undef($failed), last;
		$failed++;
		select(undef,undef,undef,$failed * .100);
	}

	die ::errmsg("%s could not tie to '%s': %s", 'SDBM', $filename, $!)
		unless $dbm;

#::logDebug("created dbm, hash=" . ::uneval($dbm));
	$tie->{'c'} = join("\t", @$columns);

#::logDebug("columns are $tie->{c}");
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
#::logDebug("object is " . ::uneval($s));
	return $s;
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
				$config->{AutoNumberCounter} = new Vend::CounterFile
									$config->{AUTO_NUMBER_FILE},
									$config->{AUTO_NUMBER} || '00001',
									$config->{AUTO_NUMBER_DATE};
			};
			if($@) {
				::logError("Cannot create AutoNumberCounter: %s", $@);
				$config->{AutoNumberCounter} = '';
			}
		}
	}

	my $dbm = tie(%$tie, 'SDBM_File', $filename, $flags, 0600)
		or die errmsg("%s %s: %s\n", errmsg("open"), $filename, $!);

	my $columns = [split(/\t/, $tie->{'c'})];

	$config->{VERBATIM_FIELDS} = 1 unless defined $config->{VERBATIM_FIELDS};

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
*errstr     	= \&Vend::Table::Common::errstr;
*field			= \&Vend::Table::Common::field;
*field_accessor	= \&Vend::Table::Common::field_accessor;
*field_settor	= \&Vend::Table::Common::field_settor;
*isopen			= \&Vend::Table::Common::isopen;
*inc_field		= \&Vend::Table::Common::inc_field;
*log_error  	= \&Vend::Table::Common::log_error;
*name			= \&Vend::Table::Common::name;
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
