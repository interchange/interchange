# Table/GDBM.pm: access a table stored in a GDBM file
#
# $Id: GDBM.pm,v 1.1 2000-05-26 18:50:42 heins Exp $
#
# Copyright 1996-2000 by Michael J. Heins <mikeh@minivend.com>
#
# This program was originally based on Vend 0.2
# Copyright 1995 by Andrew M. Wilcox <awilcox@world.std.com>
#
# Portions from Vend 0.3
# Copyright 1995 by Andrew M. Wilcox <awilcox@world.std.com>
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
$VERSION = substr(q$Revision: 1.1 $, 10);

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

    my $flags = GDBM_WRITER;

    if ($config->{Read_only}) {
        $flags = GDBM_READER;
    }

	my $dbm;
    my $failed = 0;

    while( $failed < 10 ) {
        $dbm = tie(%$tie, 'GDBM_File', $filename, $flags, 0777)
            and undef($failed), last;
        $failed++;
        select(undef,undef,undef,$failed * .100);
    }

    die ::errmsg("Could not tie to '%s': %s", $filename, $!)
        if $failed;
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
*columns		= \&Vend::Table::Common::columns;
*config			= \&Vend::Table::Common::config;
*delete_record	= \&Vend::Table::Common::delete_record;
*each_record	= \&Vend::Table::Common::each_record;
*field			= \&Vend::Table::Common::field;
*field_accessor	= \&Vend::Table::Common::field_accessor;
*field_settor	= \&Vend::Table::Common::field_settor;
*inc_field		= \&Vend::Table::Common::inc_field;
*numeric		= \&Vend::Table::Common::numeric;
*quote			= \&Vend::Table::Common::quote;
*record_exists	= \&Vend::Table::Common::record_exists;
*ref			= \&Vend::Table::Common::ref;
*row			= \&Vend::Table::Common::row;
*row_hash		= \&Vend::Table::Common::row_hash;
*row_settor		= \&Vend::Table::Common::row_settor;
*set_field		= \&Vend::Table::Common::set_field;
*set_row  		= \&Vend::Table::Common::set_row;
*test_record	= \&Vend::Table::Common::record_exists;
*touch			= \&Vend::Table::Common::touch;
*test_column	= \&Vend::Table::Common::test_column;

1;
