# Vend::Table::GDBM - Access an Interchange table stored in a GDBM file
#
# $Id: GDBM.pm,v 2.5 2003-01-14 02:25:53 mheins Exp $
#
# Copyright (C) 1996-2002 Red Hat, Inc. <interchange@redhat.com>
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

package Vend::Table::GDBM;
use strict;
use vars qw($VERSION @ISA);
use GDBM_File;
use Vend::Table::Common;

@ISA = qw(Vend::Table::Common);
$VERSION = substr(q$Revision: 2.5 $, 10);

sub new {
	my ($class, $obj) = @_;
	bless [$obj], $class;
}

sub create {
	my ($class, $config, $columns, $filename) = @_;

	$config = {} unless defined $config;
	my ($File_permission_mode, $Fast_write)
		= @$config{'File_permission_mode', 'Fast_write'};
	$File_permission_mode = 0666 unless defined $File_permission_mode;
	$Fast_write = 1 unless defined $Fast_write;

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
	my $flags = GDBM_NEWDB;
	$flags |= GDBM_FAST if $Fast_write;
	my $dbm = tie(%$tie, 'GDBM_File', $filename, $flags, $File_permission_mode)
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

sub open_table {
	my ($class, $config, $filename) = @_;
	my @caller = caller();
#::logDebug("opening table class=$class filename=$filename config=" . ::uneval($config) . " caller=@caller");
	my $tie = {};

	my $flags = GDBM_READER;

	if (! $config->{Read_only}) {
		undef $config->{Transactions};
		$config->{_Auto_number} = 1 if $config->{AUTO_NUMBER};
		$flags = GDBM_WRITER;
		if(! defined $config->{AutoNumberCounter}) {
			eval {
				$config->{AutoNumberCounter} = new Vend::CounterFile
											"$config->{DIR}/$config->{name}.autonumber",
											$config->{AUTO_NUMBER} || '00001';
			};
			if($@) {
				::logError("Cannot create AutoNumberCounter: %s", $@);
				$config->{AutoNumberCounter} = '';
			}
		}
	}

	my $dbm;
	my $failed = 0;

	my $retry = $Vend::Cfg->{Limit}{dbm_open_retries} || 10;

	while( $failed < $retry ) {
		$dbm = tie(%$tie, 'GDBM_File', $filename, $flags, 0777)
			and undef($failed), last;
		$failed++;
		select(undef,undef,undef,$failed * .100);
	}

	die ::errmsg("%s could not tie to '%s': %s", 'GDBM', $filename, $!)
		unless $dbm;

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
*test_record	= \&Vend::Table::Common::record_exists;
*touch			= \&Vend::Table::Common::touch;
*test_column	= \&Vend::Table::Common::test_column;

1;
