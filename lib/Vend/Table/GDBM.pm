# Vend::Table::GDBM - Access an Interchange table stored in a GDBM file
#
# $Id: GDBM.pm,v 2.20 2009-03-22 19:32:31 mheins Exp $
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

package Vend::Table::GDBM;
use strict;
use vars qw($VERSION @ISA);
use GDBM_File;
use Vend::Table::Common;

if ($ENV{MINIVEND_DISABLE_UTF8}) {
	sub encode($$;$){}
	sub decode($$;$){}
}
else {
	require Encode;
	import Encode qw( decode encode );
}

@ISA = qw(Vend::Table::Common);
$VERSION = substr(q$Revision: 2.20 $, 10);

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

	die ::errmsg("columns argument %s is not an array ref", $columns)
		unless CORE::ref($columns) eq 'ARRAY';

	my $column_index = Vend::Table::Common::create_columns($columns, $config);

	my $tie = {};
	my $flags = GDBM_NEWDB;
	$flags |= GDBM_FAST if $Fast_write;
	my $dbm = tie(%$tie, 'GDBM_File', $filename, $flags, $File_permission_mode)
		or die ::errmsg("%s %s: %s\n", ::errmsg("create"), $filename, $!);

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
		$flags |= GDBM_NOLOCK if $config->{IC_LOCKING};
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

	my $dbm;
	my $failed = 0;

	my $retry = $::Limit->{dbm_open_retries} || 10;

	while( $failed < $retry ) {
		$dbm = tie(%$tie, 'GDBM_File', $filename, $flags, 0777)
			and undef($failed), last;
		$failed++;
		select(undef,undef,undef,$failed * .100);
	}

	die ::errmsg("%s could not tie to '%s': %s", 'GDBM', $filename, $!)
		unless $dbm;

	apply_utf8_filters($dbm) if $config->{GDBM_ENABLE_UTF8};

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

sub apply_utf8_filters {
	my ($handle) = shift;

#::logDebug("applying UTF-8 filters to GDBM handle");

	my $out_filter = sub { $_ = encode('utf-8', $_) };
	my $in_filter  = sub { $_ = decode('utf-8', $_) };

	$handle->filter_store_key($out_filter);
	$handle->filter_store_value($out_filter);
	$handle->filter_fetch_key($in_filter);
	$handle->filter_fetch_value($in_filter);

	return $handle;
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
*inc_field		= \&Vend::Table::Common::inc_field;
*isopen			= \&Vend::Table::Common::isopen;
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
*test_record	= \&Vend::Table::Common::record_exists;
*touch			= \&Vend::Table::Common::touch;
*test_column	= \&Vend::Table::Common::test_column;

1;
