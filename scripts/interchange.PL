#!/usr/bin/perl
##!~_~perlpath~_~
#
# Interchange version 4.9.3
#
# $Id: interchange.PL,v 2.55 2002-09-07 20:05:12 mheins Exp $
#
# Copyright (C) 1996-2002 Red Hat, Inc. and others.
# http://www.icdevgroup.org/
#
# This program was originally based on Vend 0.2 and 0.3
# Copyright 1995 by Andrew M. Wilcox <amw@wilcoxsolutions.com>
#
# See the files 'README' and 'WHATSNEW' for information.
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

use lib '/usr/local/interchange/lib';
#use lib '~_~INSTALLPRIVLIB~_~';
use lib '/usr/local/interchange';
#use lib '~_~INSTALLARCHLIB~_~';

use strict;

BEGIN {
	$Global::Foreground = 1;
	
	($Global::VendRoot = $ENV{MINIVEND_ROOT})
		if defined $ENV{MINIVEND_ROOT};
	
	$Global::VendRoot = $Global::VendRoot || '/usr/local/interchange';
#	$Global::VendRoot = $Global::VendRoot || '~_~INSTALLARCHLIB~_~';

	if(-f "$Global::VendRoot/interchange.cfg") {
		$Global::ExeName = 'interchange';
		$Global::ConfigFile = 'interchange.cfg';
	}
	elsif(-f "$Global::VendRoot/minivend.cfg") {
		$Global::ExeName = 'minivend';
		$Global::ConfigFile = 'minivend.cfg';
	}
	else {
		$Global::ExeName = 'interchange';
		$Global::ConfigFile = 'interchange.cfg';
	}

	$Global::InitialErrorFile = $Global::ErrorFile = "$Global::VendRoot/error.log";

	if($^O =~ /cygwin|win32/i) {
		$Global::Windows = 1;
	}

# Uncomment next line if you want to guarantee use of DB_File
#$ENV{MINIVEND_DBFILE} = 1;

# Uncomment next line in the unlikely event you want to ignore
# GDBM and DB_File and force use of SDBM.
#$ENV{MINIVEND_SDBM} = 1;

# Uncomment next line if you want to guarantee use of GDBM and not DB_File
#$ENV{MINIVEND_GDBM} = 1;

# Uncomment next line if you want to use no DBM, sessions
# stored in files and databases in memory (or SQL)
#$ENV{MINIVEND_NODBM} = 1;

# Uncomment next line if you want the ability to use ALL DBM.
# Otherwise we use only the first choice to save memory.
#$ENV{MINIVEND_ALLDBM} = 1;

# Uncomment next line if you DON'T want to use DBI, can
# save a bit on code size
#$ENV{MINIVEND_NO_DBI} = 1;

# Uncomment next line if you want to use the Storable
# module for storing session data. It improves session performance
# to a good degree. We will also do a bit of auto-detect below.
#$ENV{MINIVEND_STORABLE} = 1;

# Uncomment next line if you want to use the Storable
# module for storing database data. It improves GBDM/DB_File performance
# to a good degree. We will also do a bit of auto-detect below.
#$ENV{MINIVEND_STORABLE_DB} = 1;

# Uncomment AND SET next line to set PGP path to somewhere besides
# the Interchange user path
#$ENV{PGPPATH} = '/usr/local/pgp';

# Use the Storable module for storing data in DBM files.
if(-f "$Global::VendRoot/_session_storable") {
	$ENV{MINIVEND_STORABLE} = 1;
}

if(-f "$Global::VendRoot/_db_storable") {
	$ENV{MINIVEND_STORABLE_DB} = 1;
}

# Interchange can use syslog via the "logger" command
# This prevents parsing of the value, default is syslog off
$Global::SysLog		= '';

}

### END CONFIGURATION VARIABLES

use vars qw($VERSION);
require Exporter;

BEGIN {
	$VERSION = '4.9.3';
}

use Fcntl;

# BSD, among others, defines sendmail to be in /usr/sbin, and
# we want to make sure the program is there. Insert the location
# of you sendmail binary (the configure script should do this)
$Global::SendMailLocation = '' if ! $Global::SendMailLocation;
$Global::SendMailLocation = ($Global::Windows and $Global::SendMailLocation) ||
	($Global::SendMailLocation and -x $Global::SendMailLocation and $Global::SendMailLocation) ||
	(-x '/usr/lib/sendmail' and '/usr/lib/sendmail') ||
	(-x '/usr/sbin/sendmail' and '/usr/sbin/sendmail') ||
	'';
#	'~_~sendmail~_~';

#select a DBM

BEGIN {
	$Global::GDBM = $Global::DB_File = $Global::SDBM =
# LDAP
	$Global::LDAP =
# END LDAP
# SQL
	$Global::DBI =
# END SQL
    $Global::Shadow = 
	0;

# SQL
	# This is for standard DBI
	eval {
			die if $ENV{MINIVEND_NODBI};
			require DBI and $Global::DBI = 1
	};
# END SQL
# LDAP
	eval {
		die if $ENV{MINIVEND_NOLDAP};
		require Net::LDAP and $Global::LDAP = 1
	};
# END LDAP

	# Now can use any type of database
	AUTO: {
		last AUTO if 
			(defined $ENV{MINIVEND_DBFILE} and $Global::DB_File = 1);
		last AUTO if 
			(defined $ENV{MINIVEND_SDBM} and $Global::SDBM = 1);
		last AUTO if 
			(defined $ENV{MINIVEND_NODBM});
		eval {require GDBM_File and $Global::GDBM = 1};
		last AUTO if 
			(defined $ENV{MINIVEND_GDBM} and $Global::GDBM = 1);
		last AUTO if
				!   $ENV{MINIVEND_ALLDBM}
				and $Global::GDBM;
		eval {require DB_File and $Global::DB_File = 1};
		last AUTO if
				!   $ENV{MINIVEND_ALLDBM}
				and $Global::GDBM || $Global::DB_File;
		eval {require SDBM_File and $Global::SDBM = 1};
	}

	if($Global::GDBM) {
		require Vend::Table::GDBM;
		import GDBM_File;
		$Global::GDBM = 1;
		$Global::Default_database = 'GDBM'
			unless defined $Global::Default_database;
	}
	if($Global::DB_File) {
		require Vend::Table::DB_File;
		import DB_File;
		$Global::DB_File = 1;
		$Global::Default_database = 'DB_FILE'
			unless defined $Global::Default_database;
	}
	if($Global::SDBM) {
		require Vend::Table::SDBM;
		import SDBM_File;
		$Global::SDBM = 1;
		$Global::Default_database = 'SDBM'
			unless defined $Global::Default_database;
	}
	$Global::Default_database = 'MEMORY'
			unless defined $Global::Default_database;
	require Vend::Table::InMemory;
	require Vend::Table::Shadow;
}


use Vend::Util;
use Vend::Server;
use Vend::Session;
use Vend::Config;
use Vend::Payment;

# You might try commenting out these lines and uncommenting the ones
# below to compact memory size
# NOAUTOUSE
use Vend::Order;
#use Vend::Imagemap;
#use Vend::Error;
#use Vend::Control;
# END NOAUTOUSE


# You might try commenting out these lines and uncommenting the ones
# below to do development or test for strange problems
# AUTOUSE
use autouse 'Vend::Error' => qw/get_locale_message interaction_error do_lockout full_dump/;
use autouse 'Vend::Imagemap' => qw/action_map/;
use autouse 'Vend::Control' => qw/
											signal_reconfig
											signal_add
											signal_cron
											signal_remove
											control_interchange
											remove_catalog
											add_catalog
											change_catalog_directive
											change_global_directive
									/;
#use autouse 'Vend::Order' => qw/
#											add_items
#											check_order
#											check_required
#											cyber_charge
#   										encrypt_standard_cc
#   										mail_order
#   										onfly
#   										route_order
#   										validate_whole_cc
#   								/;

# END AUTOUSE

# GLIMPSE
use Vend::Glimpse;
# END GLIMPSE

# TRACK
use Vend::Track;
# END TRACK

use Vend::Scan;
use Vend::Data;
use Vend::UserDB;
use Vend::Interpolate;
use Vend::Page;
use Vend::CounterFile;

if($ENV{INTERCHANGE_REQUIRE}) {
	my @mods = split /[;\s]+/, $ENV{INTERCHANGE_REQUIRE};
	foreach my $mod (@mods) {
		eval {
			eval "require $mod";
			die $@ if $@;
		};
		if($@) {
			die errmsg(
				"FAILED to require module %s as specified in environment. Error: %s\n", 
				$mod,
				$@,
			);
		}
		else {
			warn errmsg(
				"Required module %s successfully as specified in environment.\n", 
				$mod,
			);
		}
	}
}

if( ! $Global::Windows and $> == -1 || scalar(getpwuid($>)) eq 'nobody' ) {
	warn errmsg("\aYou probably don't want to run as nobody!\n");
	sleep 1;
	warn errmsg("The security problems are on your head, though. Continuing...\n");
}

## This was set to 1 in Vend::Config, so that external programs calling it
## would act properly by default
undef $Vend::ExternalProgram;

my $H;
sub http {
	return $H;
}

sub response {
	my ($output) = @_;
	my $out = ref $output ? $output : \$output;
	if (defined $Vend::CheckHTML) {
		require Vend::External;
		Vend::External::check_html($out);
	}
	$H->respond($out);
}

## DO ORDER

# Order an item with product code CODE.

sub do_order {
    my($path) = @_;
	my $code        = $CGI::values{mv_arg};
#::logDebug("do_order: path=$path");
	my $cart;
	my $page;
# LEGACY
	if($path =~ s:/(.*)::) {
		$cart = $1;
		if($cart =~ s:/(.*)::) {
			$page = $1;
		}
	}
# END LEGACY
	if(defined $CGI::values{mv_pc} and $CGI::values{mv_pc} =~ /_(\d+)/) {
		$CGI::values{mv_order_quantity} = $1;
	}
	$CGI::values{mv_cartname} = $cart if $cart;
	$CGI::values{mv_nextpage} = $page if $page;
# LEGACY
	$CGI::values{mv_nextpage} = $CGI::values{mv_orderpage}
								|| find_special_page('order')
		if ! $CGI::values{mv_nextpage};
# END LEGACY
	add_items($code);
    return 1;
}

my @Scan_modifiers = qw/
		mv_ad
		mv_an
		mv_bd
		mv_bd
/;

# Returns undef if interaction error
sub update_quantity {
    return 1 unless defined  $CGI::values{"quantity0"}
		|| $CGI::values{mv_quantity_update};
	my($h, $i, $quantity, $modifier, $cart);

	if ($CGI::values{mv_cartname}) {
		$cart = $::Carts->{$CGI::values{mv_cartname}} ||= [];
	}
	else {
		$cart = $Vend::Items;
	}

	my @mods;
	@mods = @{$Vend::Cfg->{UseModifier}} if $Vend::Cfg->{UseModifier};

#::logDebug("adding modifiers");
	push(@mods, (grep $_ !~ /^mv_/, split /\0/, $CGI::values{mv_item_option}))
		if defined $CGI::values{mv_item_option};

	my %seen;
	push @mods, grep defined $CGI::values{"${_}0"}, @Scan_modifiers;
	@mods = grep ! $seen{$_}++, @mods;

	foreach $h (@mods) {
		delete @{$::Values}{grep /^$h\d+$/, keys %$::Values};
		foreach $i (0 .. $#$cart) {
#::logDebug("updating line $i modifiers: " . ::uneval($cart->[$i]));
#::logDebug(qq{CGI value=$CGI::values{"$h$i"}});
			$modifier = $CGI::values{"$h$i"}
					  || (defined $cart->[$i]{$h} ? '' : undef);
#::logDebug("line $i modifier $h now $modifier");
			if (defined($modifier)) {
				$modifier =~ s/\0+/\0/g;
				$modifier =~ s/\0$//;
				$modifier =~ s/^\0//;
				$modifier =~ s/\0/, /g;
				$cart->[$i]->{$h} = $modifier;
				$::Values->{"$h$i"} = $modifier;
				delete $CGI::values{"$h$i"};
			}
		}
	}

	foreach $i (0 .. $#$cart) {
#::logDebug("updating line $i quantity: " . ::uneval($cart->[$i]));
		my $line = $cart->[$i];
		$line->{mv_ip} = $i;
    	$quantity = $CGI::values{"quantity$i"};
    	next unless defined $quantity;
    	if ($quantity =~ m/^\d*$/) {
        	$line->{'quantity'} = $quantity || 0;
    	}
    	elsif ($quantity =~ m/^[\d.]+$/
				and $Vend::Cfg->{FractionalItems} ) {
        	$line->{'quantity'} = $quantity;
    	}
		# This allows a last-positioned input of item quantity to
		# remove the item
		elsif ($quantity =~ s/.*\00$/0/) {
			$CGI::values{"quantity$i"} = $quantity;
			redo;
		}
		# This allows a multiple input of item quantity to
		# pass -- FIRST ONE CONTROLS
		elsif ($quantity =~ s/\0.*//) {
			$CGI::values{"quantity$i"} = $quantity;
			redo;
		}
		else {
			my $item = $line->{'code'};
			$line->{quantity} = int $line->{quantity};
        	$Vend::Session->{errors}{mv_order_quantity} =
				errmsg("'%s' for item %s is not numeric/integer", $quantity, $item);
    	}
    	$::Values->{"quantity$i"} = delete $CGI::values{"quantity$i"};
		SKUSET: {
			my $sku;
			my $found_option;
			last SKUSET unless $sku = delete $CGI::values{"mv_sku$i"};
			my @sku = split /\0/, $sku, -1;
			for(@sku[1..$#sku]) {
				if (not length $_) {
				$_ = $::Variable->{MV_VARIANT_JOINER} || '0';
				next;
				}
				$found_option++;
			}

			if(@sku > 1 and ! $found_option) {
				splice @sku, 1;
			}

			$sku = join "-", @sku;

			my $ib;
			unless($ib 	= ::product_code_exists_tag($sku)) {
				push @{$Vend::Session->{warnings} ||= []},
					errmsg("Not a valid option combination: %s", $sku);
					last SKUSET;
			}

			$line->{mv_ib} = $ib;

			if($sku ne $line->{code}) {
				if($line->{mv_mp}) {
					$line->{mv_sku} = $line->{code} = $sku;
				}
				elsif (! $line->{mv_sku}) {
					$line->{mv_sku} = $line->{code};
					$line->{code} 	= $sku;
				}
				else {
					$line->{code}	= $sku;
				}
			}
		}
    }
#::logDebug("after update, cart is: " . ::uneval($cart));

	# If the user has put in "0" for any quantity, delete that item
    # from the order list. Handles sub-items.
    Vend::Cart::toss_cart($cart, $CGI::values{mv_cartname});

#::logDebug("after toss, cart is: " . ::uneval($cart));

	1;

}

sub set_db {
	my ($base, $thing) = @_;
	return ($base, $thing) unless $thing =~ /^(\w+):+(.*)/;
	my $t = $1;
	my $c = $2;

	# Security handled before this in update_data
	$Vend::WriteDatabase{$t} = 1;

	my $db = ::database_exists_ref($t);
	return undef unless $db;
	return ($db->ref(), $c);
}

## Update the user-entered fields.
sub update_data {
	my($key,$value);
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
	my ($ref, $db, $database);

	my $en_col;
#::logDebug("data_enable=$::Scratch->{mv_data_enable}, checking");
	if($::Scratch->{mv_data_enable} =~ /^(\w+):(.*?):/) {
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
    my @file_paths = split /[\s\0,]+/, $CGI::values{mv_data_file_path};
    my @file_oldfiles = split /[\s\0,]+/, $CGI::values{mv_data_file_oldfile};

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

	my (%data);
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
			unless (length($data{$file_fields[$i]}->[0])) {
				# no need for a file update
				$data{$file_fields[$i]}->[0] = $file_oldfiles[$i];
				next;
			}

			# remove path components
			$data{$file_fields[$i]}->[0] =~ s:.*/::; 
			$data{$file_fields[$i]}->[0] =~ s:.*\\::; 

			if (length ($file_paths[$i])) {
				# real file upload
				$outfile = join('/', $file_paths[$i], $data{$file_fields[$i]}->[0]);
#::logDebug("file upload: field=$file_fields[$i] path=$file_paths[$i] outfile=$outfile");
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
						::logError ("ACL function failed on '%s': %s", $outfile, $@);
					}
					else {
						::logError ("Not allowed to upload \"%s\"", $outfile);
					}
					next;
				} 
				my $err;
				Vend::Interpolate::tag_value_extended(
										$file_fields[$i],
										{
											test => 'isfile'
										}
										)
					or do {
						 ::logError("%s is not a file.", $data{$file_fields[$i]}->[0]);
						 next;
					};
				Vend::Interpolate::tag_value_extended(
										$file_fields[$i],
										{
											outfile => $outfile,
											umask => '022',
											yes => '1',
										}
										)
					or do {
						 ::logError("failed to write %s: %s", $outfile, $!);
						 next;
					};
			}
			else {
				# preparing to dump file contents into database column
				$data{$file_fields[$i]}->[0]
					= Vend::Interpolate::tag_value_extended ($file_fields[$i],
						{file_contents => 1});
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
			$safe = new Safe;
		}
		$base_db->column_exists($blob_ptr)
			or undef $blob_ptr;
#::logDebug("update_data: blob safe object=$safe");
	}

#::logDebug("update_data:db=$db key=$prikey VALUES=" . ::uneval(\%CGI::values));
#::logDebug("update_data:db=$db key=$prikey data=" . ::uneval(\%data));
	my $select_key;
	for($i = 0; $i < @{$data{$prikey}}; $i++) {
#::logDebug("iteration of update_data:db=$db key=$prikey data=" . ::uneval(\%data));
		@k = (); @v = ();
		for(keys %data) {
#::logDebug("iteration of field $_");

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
			if(! length($key) and $autonumber) {
				## KEY IS possibly SET HERE 
				$key = $base_db->set_row($key);
			}
			push(@rows_set, $key);

			# allow form submissions to go to database and to mail
			if ($CGI::values{mv_data_email}) {
				push( @email_rows,
					[ ::errmsg("### Form Submission from %s", $key), $blob_nick, ],
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
				next if $field eq $prikey;
				
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

			for(keys %$qd) {
				$qret = $qd->{$_}->set_slice($key, $qf->{$_}, $qv->{$_});
				$rows_set[$i] = $qret unless $rows_set[$i];
			}
			if($blob) {
				$brec->{mv_data_fields} = join " ", @fields;
				my $string =  ::uneval_it($blob);
#::logDebug("update_data: blob saving string=$string");
				$base_db->set_field($key, $blob_field, $string);
				if($blob_ptr) {
					$base_db->set_field($key, $blob_ptr, $blob_nick);
				}
			}
			push(
					@email_rows,
					[ ::errmsg("### END FORM SUBMISSION %s", $key), $blob_nick, ]
				)
				if $CGI::values{mv_data_email};
		}
	}

	if($CGI::values{mv_data_return_key}) {
		my @keys = split /\0/, $CGI::values{mv_data_return_key};
		for(@keys) {
#::logDebug("return_key, setting $_");
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
	return;
}

# Parse the mv_click and mv_check special variables
sub parse_click {
	my ($ref, $click, $extra) = @_;
    my($codere) = '[-\w_#/.]+';
	my $params;

#::logDebug("Looking for click $click");
	if($params = $::Scratch->{$click}) {
		# Do nothing, we found the click
#::logDebug("Found scratch click $click = |$params|");
	}
	elsif(defined ($params = $Vend::Cfg->{OrderProfileName}{$click}) ) {
		# Do nothing, we found the click
		$params = $Vend::Cfg->{OrderProfile}[$params];
#::logDebug("Found profile click $click = |$params|");
	}
	elsif(defined ($params = $Global::ProfilesName->{$click}) ) {
		# Do nothing, we found the click
		$params = $Global::Profiles->[$params];
#::logDebug("Found profile click $click = |$params|");
	}
	elsif($params = $::Scratch->{"mv_click $click"}) {
		$::Scratch->{mv_click_arg} = $click;
	}
	elsif($params = $::Scratch->{mv_click}) {
		$::Scratch->{mv_click_arg} = $click;
	}
	else {
#::logDebug("Found NO click $click");
		return 1;
	} # No click processor

	my($var,$val,$parameter);
	$params = interpolate_html($params);
	my(@param) = split /\n+/, $params;

	for(@param) {
		next unless /\S/;
		next if /^\s*#/;
		s/^[\r\s]+//;
		s/[\r\s]+$//;
		$parameter = $_;
		($var,$val) = split /[\s=]+/, $parameter, 2;
		$val =~ s/&#(\d+);/chr($1)/ge;
		$ref->{$var} = $val;
		$extra->{$var} = $val
			if defined $extra;
	}
}

# This is the set of CGI-passed variables to ignore, in other words
# never set in the user session.  If set in the mv_check pass, though,
# they will stick.
%Global::Ignore = qw(
	mv_todo  1
	mv_todo.submit.x  1
	mv_todo.submit.y  1
	mv_todo.return.x  1
	mv_todo.return.y  1
	mv_todo.checkout.x  1
	mv_todo.checkout.y  1
	mv_todo.todo.x  1
	mv_todo.todo.y  1
	mv_todo.map  1
	mv_doit  1
	mv_check  1
	mv_click  1
	mv_nextpage  1
	mv_failpage  1
	mv_successpage  1
	mv_more_ip  1
	mv_credit_card_number  1
	mv_credit_card_cvv2  1
	);

sub update_values {

	my (@keys) = @_;

	my $set;
	if(@keys) {
		$set = {};
		@{$set}{@keys} = @CGI::values{@keys};
	}
	else {
		$set = \%CGI::values;

		if( $Vend::Cfg->{CreditCardAuto} and $CGI::values{mv_credit_card_number} ) {
			(
				@{$::Values}{
					qw/
							mv_credit_card_valid
							mv_credit_card_info
							mv_credit_card_exp_month
							mv_credit_card_exp_year
							mv_credit_card_exp_all
							mv_credit_card_type
							mv_credit_card_reference
							mv_credit_card_error
					/ }
			) = encrypt_standard_cc(\%CGI::values);
		}	
	}

	my $restrict;
	if($restrict = $Vend::Session->{restrict_html} and ! ref $restrict) {
		$restrict = [ map { lc $_ } split /\s+/, $restrict ];
		$Vend::Session->{restrict_html} = $restrict;
	}

    while (my ($key, $value) = each %$set) {
		# values explicly ignored in configuration
        next if defined $Global::Ignore{$key};
        next if defined $Vend::Cfg->{FormIgnore}{$key};

#LEGACY
		# We add any checkbox ordered items, but don't update -- 
		# we don't want to order them twice
        next if ($key =~ m/^quantity\d+$/);
#END LEGACY

		# Admins should know what they are doing
		if($Vend::admin) {
			$::Values->{$key} = $value;
			next;
		}
		elsif ($restrict and $value =~ /</) {
			# Allow designer to allow only certain HTML tags from trusted users
			# Will go away when current session ends...
			# [ script start character handled in [value ...] ITL tag
			$value = Vend::Interpolate::filter_value(
						'restrict_html',
						$value,
						undef,
						@$restrict,
					);
			$::Values->{$key} = $value;
			next;
		}
		$value =~ tr/<[//d;
		$value =~ s/&lt;//ig;
		$value =~ s/&#91;//g;
        $::Values->{$key} = $value;
    }
}

sub update_user {
	my($key,$value);
    # Update the user-entered fields.

	add_items() if defined $CGI::values{mv_order_item};
	update_values();

	if($CGI::values{mv_check}) {
		my(@checks) = split /\s*[,\0]+\s*/, delete $CGI::values{mv_check};
		my($check);
		foreach $check (@checks) {
				parse_click $::Values, $check, \%CGI::values;	
		}
	}

	check_save if defined $CGI::values{mv_save_session};

}

## DO PROCESS

sub do_click {
	my($click, @clicks);
	do {
		if($CGI::values{mv_click}) {
			@clicks = split /\s*[\0]+\s*/, delete $CGI::values{mv_click};
		}

		if(defined $CGI::values{mv_click_map}) {
			my(@map) = split /\s*[\0]+\s*/, delete $CGI::values{mv_click_map};
			foreach $click (@map) {
				push (@clicks, $click)
					if defined $CGI::values{"mv_click.$click.x"}
					or defined $CGI::values{"$click.x"}
					or $click = $CGI::values{"mv_click_$click"};
			}
		}

		foreach $click (@clicks) {
			parse_click \%CGI::values, $click;
		}
	} while $CGI::values{mv_click};
	return 1;
}

sub do_deliver {
	my $file = $CGI::values{mv_data_file};
	my $mode = $CGI::values{mv_acl_mode} || '';
	if($::Scratch->{mv_deliver} !~ m{(^|\s)$file(\s|$)}
		and 
		! Vend::UserDB::userdb(
							'check_file_acl',
							location => $file,
							mode => $mode,
							)
		)
	{
		$Vend::StatusLine = "Status: 403\nContent-Type: text/html";
		my $msg = get_locale_message(403, <<EOF);
<B>Authorization Required<B>
<P>
This server could not verify that you are authorized to access the document
requested. 
EOF
		::response($msg);
		return 0;
	}

	if (! -f $file) {
		$Vend::StatusLine = "Status: 404\nContent-Type: text/html";
		my $msg = get_locale_message(404, <<EOF, $file);
<B>Not Found<B>
<P>
The requested file %s was not found on this server.

EOF
		::response($msg);
		return 0;
	}

	$Vend::StatusLine = "Content-Type: " .
						($CGI::values{mv_content_type} || 'application/octet-stream');
	::response(	Vend::Util::readfile (
					$CGI::values{mv_data_file},
					$Global::NoAbsolute,
				)
			);
	return 0;
}

my %form_action = (

	search	=> \&do_search,
	deliver	=> \&do_deliver,
	submit	=>
				sub {
					update_user();
					update_quantity()
						or return interaction_error("quantities");
					my $ok;
					my($missing,$next,$status,$final,$result_hash);

					# Set shopping cart if necessary
					# Vend::Items is tied, remember!
					$Vend::Items = $CGI::values{mv_cartname}
						if $CGI::values{mv_cartname};

#::logDebug("Default order route=$::Values->{mv_order_route}");
					## Determine the master order route, if routes
					## are not set in CGI values (4.7.x default)
					if(
						$Vend::Cfg->{Route}
						and ! defined $::Values->{mv_order_route}
						)
					{
						my $curr = $Vend::Cfg->{Route};
						my $repos = $Vend::Cfg->{Route_repository};

						if($curr->{master}) {
							# Default route is master

							for(keys %$repos) {
								next unless $curr eq $repos->{$_};
								$::Values->{mv_order_route} = $_;
								last;
							}
						}
						else {
							for(keys %$repos) {
								next unless $repos->{$_}->{master};
								$::Values->{mv_order_route} = $_;
								last;
							}
						}
					}

#::logDebug("Default order route=$::Values->{mv_order_route}");

				  CHECK_ORDER: {

					# If the user sets this later, will be used
					delete $Vend::Session->{mv_order_number};

					if (defined $CGI::values{mv_order_profile}) {
						($status,$final,$missing) =
							check_order($CGI::values{mv_order_profile});
					}
					else {
						$status = $final = 1;
					}
#::logDebug("Profile status status=$status final=$final errors=$missing");

					my $provisional;
					if ($status and defined $::Values->{mv_order_route}) {
						# This checks only route order profiles
#::logDebug("Routing order, pre-check");
						($status, $provisional, $missing)
										= route_order(
												$::Values->{mv_order_route},
												$Vend::Items,
												'check',
											);
					} 

					$final = $provisional if ! $final;

#::logDebug("Routing status status=$status final=$final errors=$missing");
					if($status) {
						$CGI::values{mv_nextpage} = $CGI::values{mv_successpage} 
							if $CGI::values{mv_successpage};
						$CGI::values{mv_nextpage} = $::Values->{mv_orderpage} 
							if ! $CGI::values{mv_nextpage};
					}
					else {
						$CGI::values{mv_nextpage} = $CGI::values{mv_failpage}
							if $CGI::values{mv_failpage};
						$CGI::values{mv_nextpage} = find_special_page('needfield')
							if ! $CGI::values{mv_nextpage};
						undef $final;
					}

					return 1 unless $final;

					my $order_no;
					if (defined $::Values->{mv_order_route}) {
						# $ok will not be defined unless Route "supplant" was set
						# $order_no will come back so we don't issue two of them
#::logDebug("Routing order $::Values->{mv_order_route}");
						($ok, $order_no, $result_hash) = route_order(
											$::Values->{mv_order_route},
											$Vend::Items
											);
						return 1 unless $ok;
					}

					$result_hash = {} unless $result_hash;

# TRACK
                    $Vend::Track->finish_order ();
# END TRACK
					# This function (followed down) now does the rudimentary
					# backend ordering with AsciiTrack and the order report.
					# If the "supplant" option was set in order routing it will
					# not be used ($ok would have been defined)


#::logDebug("Order number=$order_no\n");
					$ok = mail_order(undef, $order_no || undef) unless defined $ok;
#::logDebug("Order number=$order_no, result_hash=" . ::uneval($result_hash));

					# Display a receipt if configured

					my $not_displayed = 1;

					if(! $ok) {
						display_special_page(
								find_special_page('failed'),
								errmsg('Error transmitting order(%s): %s', $!, $@),
						);
					}
					elsif (! $result_hash->{no_receipt} ) {
						eval {

							my $receipt = $result_hash->{receipt}
										|| $::Values->{mv_order_receipt}
										|| find_special_page('receipt');
#::logDebug("selected receipt=$receipt");
							display_special_page($receipt);
						};
						$not_displayed = 0;
#::logDebug("not_displayed=$not_displayed");
						if($@) {
							my $msg = $@;
							::logError( 
								'Display of receipt on order number %s failed: %s',
								$::Values->{mv_order_number},
								$msg,
							);
						}
					}

					# Remove the items
					@$Vend::Items = ();
#::logDebug("returning order_number=$order_no, not_displayed=$not_displayed");
					return $not_displayed;
				  }
			},
	refresh	=> sub {
					update_quantity()
						or return interaction_error("quantities");
# LEGACY
					$CGI::values{mv_nextpage} = $CGI::values{mv_orderpage}
						if $CGI::values{mv_orderpage};
# END LEGACY
					$CGI::values{mv_nextpage} = $CGI::values{mv_orderpage}
												|| find_special_page('order')
						if ! $CGI::values{mv_nextpage};
					update_user();
					return 1;
				},
	set		=> sub {
					update_user() unless $CGI::values{mv_data_auto_number};
					update_data();
					update_user() if $CGI::values{mv_data_auto_number};
					return 1;
				},
	autoset	=> sub {
					update_data();
					update_user();
					return 1;
				},
	back    => sub { return 1 },
	return	=> sub {
					update_user();
					update_quantity()
						or return interaction_error("quantities");
					return 1;
				},
	cancel	=> sub {
					put_session();
					get_session();
					init_session();
					$CGI::values{mv_nextpage} = find_special_page('canceled')
						if ! $CGI::values{mv_nextpage};
					return 1;
				},
);

$form_action{go} = $form_action{return};

# Process the completed order or search page.

sub do_process {

	if($CGI::values{mv_form_profile}) {
#::logDebug("checking form profile $CGI::values{mv_form_profile} = $::Scratch->{$CGI::values{mv_form_profile}}");
		my ($status) = check_order($CGI::values{mv_form_profile}, \%CGI::values);
#::logDebug("checked form profile=" . (defined $status ? $status : 'undef') );
		return 1 if defined $status and ! $status;
	}

#::logDebug("todo=$CGI::values{mv_todo} prior to mv_click=" . join ",", split /\0/, $CGI::values{mv_click});

    my $orig_todo = $CGI::values{mv_todo};

	do_click();

    my $todo = $CGI::values{mv_todo};

#::logDebug("todo=$todo after mv_click");

	# Maybe we have an imagemap input, if not, use $doit
	if($orig_todo ne $todo) {
		# Don't mess with it, changed in click
	}
	elsif (defined $CGI::values{'mv_todo.x'}) {
		my $x = $CGI::values{'mv_todo.x'};
		my $y = $CGI::values{'mv_todo.y'};
		my $map = $CGI::values{'mv_todo.map'};
		# Called with action_map and not package id
		# since "autouse" is possibly in force...found
		# by Jeff Carnahan
		$todo = action_map($x,$y,$map);
	}
	elsif( my @todo = grep /^mv_todo\.\w+(?:\.x)?$/, keys %CGI::values ) {
		# Only one todo!
		for(@todo) {
			delete $CGI::values{$_};
			s/^mv_todo\.(\w+)(?:\.[xy])?$/$1/;
		}
		$todo = shift @todo;
	}

	$todo = $CGI::values{mv_doit} || 'back' if ! $todo;

#::logDebug("todo=$todo after mv_click");

	my ($sub, $status);
	#Now determine the action on the todo
    if (defined $Vend::Cfg->{FormAction}{$todo}) {
		$sub = $Vend::Cfg->{FormAction}{$todo};
	}
    elsif (not $sub = $form_action{$todo} ) {
		interaction_error("No action passed for processing\n");
		return;
    }
	eval {
		$status = $sub->($todo);
	};
	if($@) {
		undef $status;
		my $err = $@;
		my $template = <<EOF;
Sorry, there was an error in processing this form action. Please 
report the error or try again later.
EOF
		$template .= "\n\nError: %s\n"
				if $Global::DisplayErrors && $Vend::Cfg->{DisplayErrors}
			;
		$template = get_locale_message(500, $template, $err);
		$template .= "($err)";
		::logError($err);
		::response($template);
	}

	return $status;
}

sub run_in_catalog {
	my ($cat, $job, $itl) = @_;
	my ($g,$c);

#::logGlobal("running job in cat=$cat");
	$g = $Global::Catalog{$cat};
	unless (defined $g) {
		logGlobal( "Can't find catalog '%s'" , $cat );
		return undef;
	}

	#$Vend::Log_suppress = 1;

	unless ($Vend::Quiet) {
		logGlobal("Run catalog '%s' cron group=%s", $cat, $job || 'INTERNAL');
	}
	#undef $Vend::Log_suppress;

	open_cat($cat);

	logError("Run cron group=%s", $job || 'INTERNAL');

	my $croncfg = $Vend::Cfg->{Cron};

	my $dir;
	my @itl;
	if($job) {
		my $ct = $croncfg->{base_directory} || 'etc/cron';
		my $gt = '';
		$gt = "$Global::ConfDir/$ct" if $croncfg->{use_global};

		for my $d ($ct, $gt) {
#::logGlobal("check directory=$d for $job");
			next unless $d;
			next unless -d "$d/$job";
			$dir = "$d/$job";
			last;
		}
		if($dir) {
			my @f = glob("$dir/*");
			@f = grep ! -d $_, @f;
			@f = grep $_ !~ /$Vend::Cfg->{HTMLsuffix}$/, @f;
			for(@f) {
#::logGlobal("found cron piece file=$_");
				push @itl, [$_, readfile($_)];
			}
		}
	}

	if ($itl) {
		push @itl, ["Passed ITL", $itl];
	}

	my @out;

	if(@itl) {
		# Run once at beginning
		run_macro($croncfg->{initialize});

		# initialize or autoload can create session
		# but must handle all aspects
		init_session() unless $Vend::Session;

		$CGI::remote_addr ||= 'none';
		$CGI::useragent   ||= 'commandline';

		for(@itl) {
			# Run once at beginning of each job
			run_macro($croncfg->{autoload});

			push @out, interpolate_html($_->[1]);
		}
	}
	else {
		logGlobal("Empty cron job=%s", $job);
	}
	my $out = join "", @out;
	$out =~ s/^\s+//;
	$out =~ s/\s+$/\n/;
	$out .= full_dump() if $croncfg->{add_session};
	
	close_cat();

	# don't send email and/or write log entry if cron job returns
	# no output (in spirit of the real cron)
	return unless $out;
	
	if(my $addr = $Vend::CronEmail || $croncfg->{email}) {
		my $subject = $croncfg->{subject} || 'Interchange cron results for job: %s';
		$subject = errmsg($subject, $job);
		my $from = $croncfg->{from} || $Vend::Cfg->{MailOrderTo};
		Vend::Interpolate::tag_mail($addr,
									{
										from => $from,
										to => $addr,
										subject => $subject,
										reply_to => $croncfg->{reply_to},
										mailer => "Interchange $::VERSION",
										extra => $croncfg->{extra_headers},
									    log_error => 1,
									},
									$out,
								);
	}

	if($croncfg->{log}) {
		logData($croncfg->{log}, $out);
	}

	return $out;
}

sub config_named_catalog {
	my ($cat_name, $source, $db_only, $dbconfig) = @_;
	my ($g,$c);

	$g = $Global::Catalog{$cat_name};
	unless (defined $g) {
		logGlobal( "Can't find catalog '%s'" , $cat_name );
		return undef;
	}

	$Vend::Log_suppress = 1;

	unless ($db_only or $Vend::Quiet) {
		logGlobal( "Config '%s' %s%s", $g->{'name'}, $source );
	}
	undef $Vend::Log_suppress;

    chdir $g->{'dir'}
            or die "Couldn't change to $g->{'dir'}: $!\n";

	if($db_only) {
		logGlobal(
			"Config table '%s' (file %s) for catalog %s from %s",
			$db_only,
			$dbconfig,
			$g->{'name'},
			$source,
			);
		my $cfg = $Global::Selector{$g->{script}}
			or die errmsg("'%s' not a catalog (%s).", $g->{name}, $g->{script});
		undef $cfg->{Database}{$db_only};
		$Vend::Cfg = config(
				$g->{name},
				$g->{dir},
				undef,
				undef,
				$cfg,
				$dbconfig,
				)
			or die errmsg("error configuring catalog %s table %s: %s",
							$g->{name},
							$db_only,
							$@,
					);
		open_database();
		close_database();
		return $Vend::Cfg;
	}

    eval {
        $c = config($g->{'name'},
					$g->{'dir'},
					undef,
					$g->{'base'} || undef,
# OPTION_EXTENSION
#					$Vend::CommandLine->{$g->{'name'}} || undef
# END OPTION_EXTENSION
					);
    };

    if($@) {
		my $msg = $@;
        logGlobal( "%s config error: %s" , $g->{'name'}, $msg );
     	return undef;
    }

	if (defined $g->{base}) {
		open_database(1);
		dump_structure($c, $g->{name}) if $Global::DumpStructure;
		return $c;
	}

	eval {
		$Vend::Cfg = $c;	
		$::Variable = $Vend::Cfg->{Variable};
		$::Pragma   = $Vend::Cfg->{Pragma};
		Vend::Data::read_salestax();
		Vend::Data::read_shipping();
		open_database(1);
		my $db;

		LREAD: {
			last LREAD unless $db = $Vend::Cfg->{LocaleDatabase};
			$db = database_exists_ref($db)
				or last LREAD;
			$db = $db->ref();
			my ($k, @f);	# key and fields
			my @l;			# refs to locale repository
			my @n;			# names of locales

			@n = $db->columns();
			my $extra;
			for(@n) {
				$Vend::Cfg->{Locale_repository}{$_} = {}
					unless $Vend::Cfg->{Locale_repository}{$_};
				push @l, $Vend::Cfg->{Locale_repository}{$_};
			}
			my $i;
			while( ($k , @f ) = $db->each_record) {
				for ($i = 0; $i < @f; $i++) {
					next unless length($f[$i]);
					$l[$i]->{$k} = $f[$i];
				}
			}
			unless ($Vend::Cfg->{Locale}) {
				for(@n) {
					next unless $Vend::Cfg->{Locale_repository}{$_}{'default'};
					$Vend::Cfg->{DefaultLocale} = $_;
					$Vend::Cfg->{Locale} = $Vend::Cfg->{Locale_repository}{$_};
					last;
				}
				unless ($Vend::Cfg->{Locale}) {
					$Vend::Cfg->{Locale} = $Vend::Cfg->{Locale_repository}{$n[0]};
					$Vend::Cfg->{DefaultLocale} = $n[0];
				}
			}
		}

		close_database();
	};

	undef $Vend::Cfg;
    if($@) {
		my $msg = $@;
		$msg =~ s/\s+$//;
        logGlobal( "%s config error: %s" , $g->{'name'}, $msg );
     	return undef;
    }

	dump_structure($c, $g->{name}) if $Global::DumpStructure;

	my $stime = scalar localtime();
	Vend::Util::writefile(">$Global::RunDir/status.$g->{name}", "$stime\n");
	Vend::Util::writefile(">$c->{ConfDir}/status.$g->{name}", "$stime\n");

	return $c;

}

sub is_retired {
	my $id = shift;
	mkdir "$Vend::Cfg->{ScratchDir}/retired", 0777
		unless -d "$Vend::Cfg->{ScratchDir}/retired";
	my $fn = Vend::Util::get_filename($id, 2, 1, "$Vend::Cfg->{ScratchDir}/retired");
	return -f $fn ? 1 : 0;
}

sub retire_id {
	my $id = shift;
	return unless $id =~ /^\w+$/;
	mkdir "$Vend::Cfg->{ScratchDir}/retired", 0777
		unless -d "$Vend::Cfg->{ScratchDir}/retired";
	my $fn = Vend::Util::get_filename($id, 2, 1, "$Vend::Cfg->{ScratchDir}/retired");
	open(TMPRET, ">$fn")
		or die "retire id open: $!\n";
	close(TMPRET);
	return;
}

sub tie_static_dbm {
	my $rw = shift;
	untie(%Vend::StaticDBM) if $rw;
	if($Global::GDBM) {
        my $flags = $rw ? &GDBM_WRITER : &GDBM_READER;
        $flags = &GDBM_NEWDB
            if $rw && (! -f "$Vend::Cfg->{StaticDBM}.gdbm");
        tie(%Vend::StaticDBM,
            'GDBM_File',
            "$Vend::Cfg->{StaticDBM}.gdbm",
            $flags,
            $Vend::Cfg->{'FileCreationMask'},
        )
        or $Vend::Cfg->{SaveStaticDBM} = delete $Vend::Cfg->{StaticDBM};
	}
	elsif ($Global::DB_File) {
		tie(%Vend::StaticDBM,
			'DB_File',
			"$Vend::Cfg->{StaticDBM}.db",
			($rw ? &O_RDWR | &O_CREAT : &O_RDONLY),
			$Vend::Cfg->{'FileCreationMask'},
			)
		or undef $Vend::Cfg->{StaticDBM};
	}
	else {
        $Vend::Cfg->{SaveStaticDBM} = delete $Vend::Cfg->{StaticDBM};
	}
	::logError("Failed to create StaticDBM %s", $Vend::Cfg->{StaticDBM})
		if $rw && ! $Vend::Cfg->{StaticDBM};
	return $Vend::Cfg->{StaticDBM} || undef;
}


sub adjust_cgi {

    my($host);

    die "REQUEST_METHOD is not defined" unless defined $CGI::request_method
		or @Global::argv;

	# The great and really final AOL fix
	#
    $host      = $CGI::remote_host;
    $CGI::ip   = $CGI::remote_addr;

	if($Global::DomainTail and $host) {
		$host =~ s/.*?([-A-Za-z0-9]+\.[A-Za-z]+)$/$1/;
	}
	elsif($Global::IpHead) {
		$host = $Global::IpQuad == 0 ? 'nobody' : '';
		my @ip;
		@ip = split /\./, $CGI::ip;
		$CGI::ip = '';
		$CGI::ip = join ".", @ip[0 .. ($Global::IpQuad - 1)] if $Global::IpQuad;
	}
	#
	# end AOL fix

	# Fix Cobalt/CGIwrap problem
    if($Global::Variable->{CGIWRAP_WORKAROUND}) {
        $CGI::path_info =~ s!^$CGI::script_name!!;
    }

    $CGI::host = $host || $CGI::ip;

    $CGI::user = $CGI::remote_user if $CGI::remote_user;
	undef $CGI::authorization if $CGI::remote_user;

	unless ($Global::FullUrl) {
		$CGI::script_name = $CGI::script_path;
	}
	else {
		if($CGI::server_port eq '80') { $CGI::server_port = ''; }
		else 		{ $CGI::server_port = ":$CGI::server_port"; }
		$CGI::script_name = $CGI::server_name .
							$CGI::server_port .
							$CGI::script_path;
	}
}

sub url_history {
	$Vend::Session->{History} = []
		unless defined $Vend::Session->{History};
	shift @{$Vend::Session->{History}}
		if $#{$Vend::Session->{History}} >= $Vend::Cfg->{History};
	if(
		($CGI::pragma =~ /\bno-cache\b/ and ! $CGI::values{mv_force_cache})
		or $CGI::values{mv_no_cache}
		)
	{
		push (@{$Vend::Session->{History}},  [ 'expired', {} ]);
	}
	else {
		my $save_number = delete $CGI::values{mv_credit_card_number};
		my $save_cvv2   = delete $CGI::values{mv_credit_card_cvv2};
		push (@{$Vend::Session->{History}},  [ $CGI::path_info, \%CGI::values ]);
		$CGI::values{mv_credit_card_number} = $save_number if length($save_number);
		$CGI::values{mv_credit_card_cvv2}   = $save_cvv2   if length($save_cvv2);
	}
	return;
}

## DISPATCH

# Parse the invoking URL and dispatch to the handling subroutine.

my %action = (
    process	=> \&do_process,
	ui_wrap => \&UI::Primitive::ui_wrap,
	ui		=> sub { 
					&UI::Primitive::ui_acl_global();
					&do_process(@_);
				   },
    scan	=> \&do_scan,
    search	=> \&do_search,
    order	=> \&do_order,
    obtain	=> \&do_order,
    silent	=> sub {
						$Vend::StatusLine = "Status: 204 No content";
						my $extra_click = $Vend::FinalPath;
						$extra_click =~ s:/:\0:g;
						$CGI::values{mv_click} =  $CGI::values{mv_click}
											? "$CGI::values{mv_click}\0$extra_click"
											:  $extra_click;
						do_process(@_);
						::respond('');
						return 0;
					},
);

sub open_cat {
	my $cat = shift;

	if($cat) {
		%CGI::values = ();
		if($Global::Catalog{$cat}) {
			$CGI::script_path = $Global::Catalog{$cat}->{script};
			$CGI::script_name = $CGI::script_path;
		}
	}

	unless (defined $Global::Selector{$CGI::script_name}) {
		my $msg = get_locale_message(
						404,
						"Undefined catalog: %s",
						$CGI::script_name || $cat,
						);
		$Vend::StatusLine = <<EOF;
Status: 404 Not Found
Content-Type: text/plain
EOF
		if($H) {
			::response($msg);
		}
		logGlobal($msg);
		# No close_cat() necessary
		return;
	}

	if($Global::Foreground) {
		my %hash;
		tie %hash, 'Tie::ShadowHash', $Global::Selector{$CGI::script_name} ;
		$Vend::Cfg = \%hash;
	}
	else {
		$Vend::Cfg = $Global::Selector{$CGI::script_name};
	}

	$Vend::Cat = $Vend::Cfg->{CatalogName};
	my $catref = $Global::Catalog{$Vend::Cat};
	if(! $Global::Foreground and defined $catref->{directive}) {
		no strict 'refs';
		my ($key, $val);
		while ( ($key, $val) = each %{$catref->{directive}}) {
#::logDebug("directive key=$key val=" . ::uneval($val));
			${"Global::$key"} = $val;
		}
	}

	# See if it is a subcatalog
	if (defined $Vend::Cfg->{BaseCatalog}) {
		my $name = $Vend::Cfg->{BaseCatalog};
		my $ref = $Global::Catalog{$name};
		my $c = $Vend::Cfg;
		$Vend::Cfg = $Global::Selector{$ref->{'script'}};
		for(keys %{$c->{Replace}}) {
			undef $Vend::Cfg->{$_};
		}
		copyref $c, $Vend::Cfg;
		if($Vend::Cfg->{Variable}{MV_LANG}) {
			my $loc = $Vend::Cfg->{Variable}{MV_LANG};
			$Vend::Cfg->{Locale} = $Vend::Cfg->{Locale_repository}{$loc}
					if defined $Vend::Cfg->{Locale_repository}{$loc};
		}
		$Vend::Cfg->{StaticPage} = {}
			unless $Vend::Cfg->{Static};
	}
	$::Variable = $Vend::Cfg->{Variable};
	$::Pragma   = { %{ $Vend::Cfg->{Pragma} } };

	if (defined $Global::SelectorAlias{$CGI::script_name}
		and ! defined $Vend::InternalHTTP                 )
	{
		my $real = $Global::SelectorAlias{$CGI::script_name};
		unless (	$CGI::secure                                        or
					$Vend::Cfg->{SecureURL} =~ m{$CGI::script_name$}     and
					$Vend::Cfg->{VendURL}   !~ m{/nph-[^/]+$} 		     and
					$Vend::Cfg->{VendURL}   !~ m{$CGI::script_name$} 		)
		{
			$Vend::Cfg->{VendURL}   =~ s!$real!$CGI::script_name!;
			$Vend::Cfg->{SecureURL} =~ s!$real!$CGI::script_name!;
		}
	}
	elsif ($Vend::InternalHTTP) {
		$Vend::Cfg->{VendURL} = "http://" .
								$CGI::http_host .
								$CGI::script_path;
		$Vend::Cfg->{ImageDir} = $Vend::Cfg->{ImageDirInternal}
			if  $Vend::Cfg->{ImageDirInternal};
	}

	if($Global::HitCount and ! $cat) {
		my $ctr = new Vend::CounterFile
					"$Global::ConfDir/hits.$Vend::Cat";
        $ctr->inc();
	}

	if ($Vend::Cfg->{SetGroup}) {
		eval {
			$) = "$Vend::Cfg->{SetGroup} $Vend::Cfg->{SetGroup}";
		};
		if ($@) {
			my $msg = $@;
			logGlobal( "Can't set group to GID %s: %s",
						$Vend::Cfg->{SetGroup}, $msg
					);
			logError("Can't set group to GID %s: %s",
						$Vend::Cfg->{SetGroup}, $msg
					);
		}
	}

	chdir $Vend::Cfg->{VendRoot} 
		or die "Couldn't change to $Vend::Cfg->{VendRoot}: $!\n";
	set_file_permissions();
# STATICPAGE
	tie_static_dbm() if $Vend::Cfg->{StaticDBM};
# END STATICPAGE
	umask $Vend::Cfg->{Umask};

#show_times("end cgi and config mapping") if $Global::ShowTimes;
	open_database();
#show_times("end open_database") if $Global::ShowTimes;
}

sub close_cat {
	put_session() if $Vend::HaveSession;
	close_session() if $Vend::SessionOpen;
	close_database();
}

sub run_macro {
	my $macro = shift
		or return;
	my $content_ref = shift;

	my @mac;
	if(ref $macro eq 'ARRAY') {
		@mac = @$macro;
	}
	elsif ($macro =~ /^[-\s\w,]+$/) {
		@mac = grep /\S/, split /[\s,]+/, $macro;
	}
	else {
		push @mac, $macro;
	}

	for my $m (@mac) {
		if ($m =~ /^\w+$/) {
			my $sub = $Vend::Cfg->{Sub}{$m} || $Global::GlobalSub->{$m}
				or do {
					logError("Unknown Autoload macro '%s'.", $macro);
					next;
				};
			$sub->($content_ref);
		}
		elsif($m =~ /^\w+-\w+$/) {
			Vend::Interpolate::tag_profile($m);
		}
		else {
			interpolate_html($m);
		}
	}
}

sub dispatch {
	my($http) = @_;
	$H = $http;

	adjust_cgi();

	open_cat();

	$CGI::user = Vend::Util::check_authorization($CGI::authorization)
		if defined $CGI::authorization;

    my($sessionid, $seed);

	$sessionid = $CGI::values{mv_session_id} || undef;
	$sessionid =~ s/\0.*//s;

	$::Instance->{CookieName} = $Vend::Cfg->{CookieName};

	if($CGI::values{mv_tmp_session}) {
#::logDebug("setting tmp_session");
		$Vend::tmp_session = $Vend::new_session = 1;
		$sessionid = 'nsession';
		$Vend::Cookie = 1;
		$Vend::Cfg->{ScratchDefault}{mv_no_count} = 1;
		$Vend::Cfg->{ScratchDefault}{mv_no_session_id} = 1;
	}
	elsif ($::Instance->{CookieName} and defined $CGI::cookie) {
		$CGI::cookie =~ m{$::Instance->{CookieName}=($Vend::Cfg->{CookiePattern})};
		$seed = $sessionid = $1;
		$::Instance->{ExternalCookie} = $sessionid || 1;
		$Vend::CookieID = $Vend::Cookie = 1;
	}
	elsif (defined $CGI::cookie and
		 $CGI::cookie =~ /\bMV_SESSION_ID=(\w{8,32})
								[:_] (
									(	\d{1,3}\.   # An IP ADDRESS
										\d{1,3}\.
										\d{1,3}\.
										\d{1,3})
									# A user name or domain
									|	([A-Za-z0-9][-\@A-Za-z.0-9]+) )?
									\b/x)
	{
		$sessionid = $1
			unless defined $CGI::values{mv_pc} and $CGI::values{mv_pc} eq 'RESET';
		$CGI::cookiehost = $3;
		$CGI::cookieuser = $4;
		$Vend::CookieID = $Vend::Cookie = 1;
    }

	$::Instance->{CookieName} = 'MV_SESSION_ID' if ! $::Instance->{CookieName};

	$CGI::host = 'nobody' if $Vend::Cfg->{WideOpen};

	if(! $sessionid) {
		my $id = $::Variable->{MV_SESSION_ID};
		$sessionid = $CGI::values{$id} if $CGI::values{$id};
		if (! $sessionid and $Vend::Cfg->{FallbackIP}) {
			$sessionid = generate_key($CGI::remote_addr . $CGI::useragent);
		}
	}
	elsif (! $::Instance->{ExternalCookie} and $sessionid !~ /^\w+$/) {
		my $msg = get_locale_message(
						403,
						"Unauthorized for that session %s. Logged.",
						$sessionid,
						);
		$Vend::StatusLine = <<EOF;
Status: 403 Unauthorized
Content-Type: text/plain
EOF
		::response($msg);
		logGlobal($msg);
		close_cat();
		return;
	}

# DEBUG
#::logDebug ("session='$sessionid' cookie='$CGI::cookie' chost='$CGI::cookiehost'");
# END DEBUG

RESOLVEID: {
    if ($sessionid) {
		$Vend::SessionID = $sessionid;
    	$Vend::SessionName = session_name();
		if($Vend::tmp_session) {
			$Vend::Session = {};
			init_session;
			last RESOLVEID;
		}
		# get_session will return a value if a session is read,
		# if not it will return false and a new session has been created.
		# The IP address will be counted for robot_resolution
		if(! get_session($seed) and ! $::Instance->{ExternalCookie}) {
			retire_id($sessionid);
			last RESOLVEID;
		}
		my $now = time;
		if(! $Vend::CookieID) {
			if( is_retired($sessionid) ) {
				new_session();
				last RESOLVEID;
			}
			my $compare_host	= $CGI::secure
								? ($Vend::Session->{shost})
								: ($Vend::Session->{ohost});

			if($Vend::Cfg->{WideOpen}) {
				# do nothing, no host checking
			}
			elsif(! $compare_host) {
				new_session($seed) unless $CGI::secure;
				init_session();
				$Vend::Session->{shost} = $CGI::remote_addr;
			}
			elsif ($compare_host ne $CGI::remote_addr) {
				new_session($seed);
				init_session();
			}
		}
		if ($now - $Vend::Session->{'time'} > $Vend::Cfg->{SessionExpire}) {
			if($::Instance->{ExternalCookie}) {
				init_session();
			}
			else {
				retire_id($sessionid);
				new_session();
			}
			last RESOLVEID;
		}
		elsif($Vend::Cfg->{RobotLimit}) {
			if ($now - $Vend::Session->{'time'} > 30) {
				$Vend::Session->{accesses} = 0;
			}
			else {
				$Vend::Session->{accesses}++;
#::logDebug("accesses=$Vend::Session->{accesses} admin=$Vend::admin");
				if($Vend::Session->{accesses} > $Vend::Cfg->{RobotLimit}
					and ! $Vend::admin
					)
				{
					my $msg = errmsg(
			"WARNING: POSSIBLE BAD ROBOT. %s accesses with no 30 second pause.",
			$Vend::Session->{accesses},
					);
					do_lockout($msg);
				}
			}
		}
    }
	else {
		if($Vend::Cfg->{RobotLimit}) {
			if (Vend::Session::count_ip() > $Vend::Cfg->{RobotLimit}) {
				my $msg;
				# Here they can get it back if they pass expiration time
				my $wait = $Global::Variable->{MV_ROBOT_EXPIRE} || 86400;
				$wait /= 3600;
				$msg = errmsg(<<EOF, $wait); 
Too many new ID assignments for this IP address. Please wait at least %d hours
before trying again. Only waiting that period will allow access. Terminating.
EOF
				$msg = Vend::Page::get_locale_message(403, $msg);
				do_lockout($msg);
				$Vend::StatusLine = <<EOF;
Status: 403 Forbidden
Content-Type: text/plain
EOF
					::response($msg);
					close_cat();
					return;
			}
		}
		new_session();
    }
}

#::logDebug("session name='$Vend::SessionName'\n");

	$Vend::Calc_initialized = 0;
	$CGI::values{mv_session_id} = $Vend::Session->{id} = $Vend::SessionID;

	if($Vend::Cfg->{CookieLogin}) {
		COOKIELOGIN: {
			last COOKIELOGIN if $Vend::Session->{logged_in};
			last COOKIELOGIN if defined $CGI::values{mv_username};
			last COOKIELOGIN unless
				$CGI::values{mv_username} = Vend::Util::read_cookie('MV_USERNAME');
			my $password;
			last COOKIELOGIN unless
				$password = Vend::Util::read_cookie('MV_PASSWORD');
			$CGI::values{mv_password} = $password;
			my $profile = Vend::Util::read_cookie('MV_USERPROFILE');
			local(%SIG);
			undef $SIG{__DIE__};
			eval {
				Vend::UserDB::userdb('login', profile => $profile );
			};
			if($@) {
				$Vend::Session->{failure} .= $@;
			}
		}
	}

	$Vend::Session->{'arg'} = $Vend::Argument = ($CGI::values{mv_arg} || undef);

	if ($CGI::values{mv_pc} =~ /\D/) {
		$Vend::Session->{source} =	$CGI::values{mv_pc} eq 'RESET'
										? ''
										: $CGI::values{mv_pc};
	}
	elsif($CGI::values{mv_source}) {
		$Vend::Session->{source} =	$CGI::values{mv_source};
	}

	$Vend::Session->{'user'} = $CGI::user;

	undef $Vend::Cookie if 
		$Vend::Session->{logged_in} && ! $Vend::Cfg->{StaticLogged};

	$CGI::pragma = 'no-cache'
		if delete $::Scratch->{mv_no_cache};
#show_times("end session get") if $Global::ShowTimes;

	$Vend::FinalPath = $Vend::Session->{last_url} = $CGI::path_info;

	if( defined $Vend::Session->{path_alias}{$Vend::FinalPath}	) {
		$CGI::path_info
					= $Vend::FinalPath
					= $Vend::Session->{path_alias}{$Vend::FinalPath};
		delete $Vend::Session->{path_alias}{$Vend::FinalPath}
			if delete $Vend::Session->{one_time_path_alias}{$Vend::FinalPath};
	}

    url_history($Vend::FinalPath) if $Vend::Cfg->{History};

# TRACK
    $Vend::Track = new Vend::Track;
# END TRACK

	if($Vend::Cfg->{DisplayErrors} and $Global::DisplayErrors) {
		$SIG{"__DIE__"} = sub {
							my $msg = shift;
							put_session() if $Vend::HaveSession;
							my $content = get_locale_message(500, <<EOF, $msg);
<HTML><HEAD><TITLE>Fatal Interchange Error</TITLE></HEAD><BODY>
<H1>FATAL error</H1>
<PRE>%s</PRE>
</BODY></HTML>
EOF
							::response(\$content);
							exit 0;
		};
	}

	# Do it here so we can use autoloads and such
	Vend::Interpolate::reset_calc() if $Global::Foreground;
	Vend::Interpolate::init_calc();
	new Vend::Tags;
# LEGACY
	ROUTINES: {
		last ROUTINES unless index($Vend::FinalPath, '/process/') == 0;
		while ($Vend::FinalPath =~ s:/process/(locale|language|currency)/([^/]*)/:/process/:) {
			$::Scratch->{"mv_$1"} = $2;
		}
		$Vend::FinalPath =~ s:/process/page/:/:;
	}
	my $locale;
	if($locale = $::Scratch->{mv_language}) {
		$Global::Variable->{LANG}
			= $::Variable->{LANG} = $locale;
	}

	if ($Vend::Cfg->{Locale}								and
		$locale = $::Scratch->{mv_locale}	and
		defined $Vend::Cfg->{Locale_repository}->{$locale}
		)
	{ 
		$Global::Variable->{LANG}
				= $::Variable->{LANG}
				= $::Scratch->{mv_language}
				= $locale
			 if ! $::Scratch->{mv_language};
		Vend::Util::setlocale(	$locale,
								($::Scratch->{mv_currency} || undef),
								{ persist => 1 }
							);
	}
# END LEGACY

	run_macro($Vend::Cfg->{Autoload});
#show_times("end global Autoload macro") if $Global::ShowTimes;

	for my $macro ( $Vend::Cfg->{Filter}, $Vend::Session->{Filter}) {
		next unless $macro;
		if (ref($macro) ne 'HASH') {
			logError("Bad CGI filter '%s'", $macro);
		}
		for(keys %$macro) {
			Vend::Interpolate::input_filter_do($_, { op => $macro->{$_} } );
		}
	}

	run_macro($Vend::Session->{Autoload});
#show_times("end session Autoload macro") if $Global::ShowTimes;

    # If the cgi-bin program was invoked with no extra path info,
    # just display the catalog page.
    if (! $Vend::FinalPath || $Vend::FinalPath =~ m:^/+$:) {
		$Vend::FinalPath = find_special_page('catalog');
    }

	$Vend::FinalPath =~ s:^/+::;
	$Vend::FinalPath =~ s/(\.html?)$//;

	my $record;
	my $adb;

	if(ref $Vend::Session->{alias_table}) {
		$record = $Vend::Session->{alias_table}{$Vend::FinalPath};
		$Vend::Cfg->{AliasTable} ||= 'alias';
	}

	if(
		$Vend::Cfg->{AliasTable}
			and
		$record 
			or 
		(
			$adb = database_exists_ref($Vend::Cfg->{AliasTable})
			  and 
			$record = $adb->row_hash($Vend::FinalPath)
		)
	 )
	{
		$Vend::FinalPath = $record->{real_page};

		# This prevents filesystem access when we never want it
		# If base page is not passed we allow normal resolution
		$record->{base_page}
			and $Vend::ForceFlypage = $record->{base_page};

		my $ref;

		## Here we populate CGI variables if desired
		## Explicitly passed variables override this
		if(
			$record->{base_control}
				and
			$ref = get_option_hash($record->{base_control})
		  )
		{
			for(keys %$ref) {
				next if defined $CGI::values{$_};
				$CGI::values{$_} = $ref->{$_};
			}
		}

	}

	$Vend::Session->{extension} = $1 || '';
#::logDebug("path=$Vend::FinalPath");

  DOACTION: {
    my @path = split('/', $Vend::FinalPath, 2);
	if (defined $CGI::values{mv_action}) {
		$CGI::values{mv_todo} = $CGI::values{mv_action}
			if ! defined $CGI::values{mv_todo}
			and ! defined $CGI::values{mv_doit};
		if($path[0] eq 'ui_wrap') {
			$Vend::Action = 'ui_wrap';
			delete $CGI::values{mv_action};
			shift(@path);
			$CGI::values{mv_nextpage} = $path[0]
				if ! defined $CGI::values{mv_nextpage};
			$path[0] = "process/$path[0]";
		}
		else {
			$Vend::Action = 'process';
			$CGI::values{mv_nextpage} = $Vend::FinalPath
				if ! defined $CGI::values{mv_nextpage};
		}
	}
	else {
		$Vend::Action = shift @path;
	}

#::logGlobal("action=$Vend::Action path=$Vend::FinalPath");
	my ($sub, $status, $action);
	if(defined $Vend::Cfg->{ActionMap}{$Vend::Action}) {
		$sub = $Vend::Cfg->{ActionMap}{$Vend::Action};
		$CGI::values{mv_nextpage} = $Vend::FinalPath
			if ! defined $CGI::values{mv_nextpage};
		new Vend::Parse;
	}
	elsif ( defined ($sub = $action{$Vend::Action}) )  {
		$Vend::FinalPath = join "", @path;
	}

#show_times("end path/action resolve") if $Global::ShowTimes;

	eval {
		if(defined $sub) {
				$status = $sub->($Vend::FinalPath);
#show_times("end action") if $Global::ShowTimes;
		}
		else {
			$status = 1;
		}
	};
	(undef $Vend::RedoAction, redo DOACTION) if $Vend::RedoAction;

	if($@) {
		undef $status;
		my $err = $@;
		my $template = <<EOF;
Sorry, there was an error in processing this form action. Please 
report the error or try again later.
EOF
		$template .= "\n\nError: %s\n"
				if $Global::DisplayErrors && $Vend::Cfg->{DisplayErrors}
			;
		$template = get_locale_message(500, $template, $err);
		$template .= "($err)";
		::response($template);
	}

	$CGI::values{mv_nextpage} = $Vend::FinalPath
		if ! defined $CGI::values{mv_nextpage};

	do_page() if $status;
#show_times("end page display") if $Global::ShowTimes;


	if(my $macro = $Vend::Cfg->{AutoEnd}) {
		if($macro =~ /\[\w+/) {
			interpolate_html($macro);
		}
		elsif ($macro =~ /^\w+$/) {
			$sub = $Vend::Cfg->{Sub}{$macro} || $Global::GlobalSub->{$macro};
			$sub->();
		}
#show_times("end AutoEnd macro") if $Global::ShowTimes;
	}
  }

# TRACK
	$Vend::Track->filetrack();
# END TRACK

	close_cat();

	undef $H;

#show_times("end dispatch cleanup") if $Global::ShowTimes;

	return 1;
}

## DEBUG

sub dontwarn {

# STATICPAGE
	$File::Find::name +
	$File::Find::prune +
	$File::Find::prune +
	<DATA> + 
# END STATICPAGE
	$Global::AdminSub +
	$Global::DomainTail +
	$Global::FullUrl +
    $Global::HitCount +
    $Global::ProfilesName +
    $Global::Profiles +
    $Global::LockoutCommand +
    $Global::LockoutCommand +
	$Global::IpHead +
	$Vend::CheckHTML +
	$Vend::Action +
	$Vend::CC3 +
	$CGI::server_name +
	$CGI::content_type +
	$CGI::http_host +

	1;
}

sub dump_env {
    my($var, $value);

    open(Vend::E, ">$Vend::Cfg->{'VendRoot'}/env");
    while(($var, $value) = each %ENV) {
	print Vend::E "export $var='$value'\n";
    }
    close Vend::E;
}

sub version {
	print "Interchange version $VERSION copyright 1996-2002 Red Hat, Inc. and others.\n";
}

=head1 NAME

interchange - an e-commerce and general HTTP database display system

=head1 SYNOPSIS

interchange [--options] [file]

=head1 VERSION

4.9.3

=head1 DESCRIPTION

Interchange is a database access and retrieval system focused on e-commerce.
It allows customers to select items to buy from catalog pages. The program
tracks user information in sessions and interacts with an HTTP server
through sockets.

Interchange has many, many, functions and features; they are too numerous
to describe in this venue. Complete information can be found at
its web site:

		http://www.icdevgroup.org/

Interchange requires Perl 5.005 or higher; more information on Perl can
be seen at:

		http://www.perl.com/

=head1 OPTIONS

Interchange uses the Getopt::Long module, and most options will be recognized
if they uniquely identifiable. The canonical forms are:

=over 4 

=item C<-a, --add>

Add a catalog to the system. Information taken from the input file
(or standard input). Implies reconfig=catalog. Example:

  echo "Catalog simple /catalogs/simple /simple.cgi" | bin/interchange -a

The information is in the form of a standard Interchange catalog line,
and must be in the single-line format.

=item --cron=catalog[=job]

Run a cron group which is a series of files in a directory with
the name corresponding to the C<job>. For instance, if you 
set up a directory called "weekly" in your pages directory
for the catalog C<foundation>, you can run those files with:

	interchange --cron=foundation=weekly

Files ending in .html (or whatever HTMLsuffix is for that catalog)
are skipped. It is not tree-recursive -- directories are ignored.

Results can be emailed to an address if you specify --email=address,
and they will be put in the cron log file.

Alternatively jobs can be specified with --job=jobname B<before>
the --cron option. In other words, this will work:

	interchange --job=weekly --cron=foundation

This will NOT work:

	interchange --cron=foundation --job=weekly

=item -d dir, --dir=dir

Directory for VendRoot. This is where the Interchange configuration file
will be looked for (if not redefined with C<-f>), and where the log file
will go (if not redefined with the ErrorFile directive).

=item -e name, --exclude=name

Exclude catalog from this startup.

=item -email=address

Email address to email cron job results to.

=item -f file, --config=file

Configuration file to use (default is interchange.cfg in VendRoot).

=item -h, --help

Display help on command line options.

=item -i, --inetmode

Run with internet-domain socket only. Normally Interchange runs with
both UNIX- and internet-domain sockets (except on Windows).

=item --job=job

Sets the job for --cron if that is not included in the --cron
call. MUST precede the --cron entry on the command line.

	interchange --job=weekly --cron=foundation

See --cron for an explanation of what this does.

=item --kill [signal]

By default, kills the server ungracefully with signal KILL (9, usually).
The optional signal will be sent instead if supplied.

=item -q, --quiet

Suppress informational messages on startup. Only errors are shown.

=item --reconfig=name

Cause only catalog C<name> to re-read its configuration.

=item --remove=catalog

Remove a catalog from operation; any future requests will get a not-found
message.

=item -r, --restart

Stop and restart the server. This may take a long time if many catalogs
are in use, and will temporarily take the system offline. If you want to
change a UserTag, use the --add option instead.

=item --serve

This is the default if no mode options (--reconfig, --kill, --restart, etc.)
are supplied.

=item --stop

Stop server gracefully with a TERM signal.

=item -t, --test

Report problems with config files; causes a complete configuration of 
the Interchange server but no server start.

=item -u, --unix

Run with unix-domain socket only. Normally Interchange runs with
both UNIX- and internet-domain sockets. This will not work on Windows.

=item -v, --version

Display program version.

=item --DEBUG=1

Set to true value to run foreground in debug mode. It is normal to
receive warnings about various things if you run with perl -w.

=cut

=item Directive=value

Set a Interchange global directive upon start (or --restart). Example:

	interchange SocketPerms=0666

This will start the server and override the default of SocketPerms or the
value set in interchange.cfg for this instance only. Any --restarts must
re-specify the directive if it is still to have that value.

=item name:Directive=value

Set a Interchange directive for catalog C<name> upon start (or --restart). Example:

	interchange simple:VendURL="http://localhost/cgi-bin/simple"

This will start the server and override the default of VendURL for the
value set in catalog.cfg for this instance only. Any --restarts must
re-specify the directive if it is still to have that value.

=back

=cut

sub usage {
	version();
	print <<'END';

Interchange comes with ABSOLUTELY NO WARRANTY.  This is free software, and
you are welcome to redistribute and modify it under the terms of the
GNU General Public License.

Command line options (first letter will usually work):

     --add=catalog         add a catalog to operation; parms taken from the
                           standard input as a "Catalog ..." directive
     --cron=catalog[=job]  run cron jobs for a particular catalog
                           (can use --job and -email)
     -d dir, --dir=dir     directory for VendRoot (interchange.cfg, error.log, etc.)
     -e name,
        --exclude=name     exclude catalog
     --email=emailaddr     Send results of cron job to emailaddr
     -f file,
        --config=file      configuration file (default interchange.cfg)
     --files spec          filespec (perl regexp OK) for static page tree
     -h, --help            display this message
     -i, --inetmode        run with Internet-domain socket (TCP)
     --job=jobname         cron jobs to run (hourly, daily, weekly, etc.)
     --kill [signal]       kill server ungracefully (9 or with optional signal)
     -q, --quiet           suppress informational messages on startup
     --reconfig=catalog    reconfig a particular catalog on the server
     --remove=catalog      remove a catalog from operation
     --restart             restart server
     --serve               start server (default) (-start is alias)
     --stop                stop server gracefully
     -t, --test            report problems with config files
     -u, --unix            run with UNIX-domain socket
     -v, --version         display program version
     --DEBUG=1             run foreground in debug mode
END
}

## FILE PERMISSIONS

sub set_file_permissions {
	my($r, $w, $p, $u);

	$r = $Vend::Cfg->{'ReadPermission'};
	if    ($r eq 'user')  { $p = 0400;   $u = 0277; }
	elsif ($r eq 'group') { $p = 0440;   $u = 0227; }
	elsif ($r eq 'world') { $p = 0444;   $u = 0222; }
	else                  { die "Invalid value for ReadPermission\n"; }

	$w = $Vend::Cfg->{'WritePermission'};
	if    ($w eq 'user')  { $p += 0200;  $u &= 0577; }
	elsif ($w eq 'group') { $p += 0220;  $u &= 0557; }
	elsif ($w eq 'world') { $p += 0222;  $u &= 0555; }
	else                  { die "Invalid value for WritePermission\n"; }

	$Vend::Cfg->{'FileCreationMask'} = $p;
	$Vend::Cfg->{'Umask'} = $u;
}

## MAIN

sub catch_warnings {
	unless($_[0]) {
		$SIG{'__WARN__'} = '';
		return;
	}
	$SIG{'__WARN__'} = sub {
		return @_ unless $_[0] =~ /^Use of uninitialized /;
		my $warn = $_[0];
		my $configline;
		if($warn =~ /CONFIG>\s+chunk\s+(\d+)/) {
			return <<EOF;
There is a possible problem in this catalog at line $configline
of the catalog.cfg file. Please check it out.
EOF
		}
		return @_;
	};
}

sub parse_options {

	use Getopt::Long;

	Getopt::Long::config(qw/permute/);

	#Getopt::Long::config(qw/debug/);
	my $rcfgsub = sub {
						my ($mode, $val) = @_;
						die "Can't set two modes -$mode and -$Vend::mode.\n"
								if $Vend::saw_mode;
						$Vend::Quiet = 1
							unless defined $Vend::Quiet;
						$Vend::saw_mode = 1;
						push @Vend::CatalogToReconfig, $val;
						$Vend::mode = $mode;
					};
	my $modesub = sub {
						my ($mode, $val) = @_;
						die "Can't set two modes -$mode and -$Vend::mode.\n"
								if $Vend::saw_mode;
						$Vend::saw_mode = 1;
						$Vend::mode = $mode;
					};

	my ($c_direc, $g_direc);

	my @args = @ARGV;
	my $ignore = 0;

	my %optctl = (

		DEBUG 		    => \$Global::DEBUG,
		reconfig        => $rcfgsub,
		confdir         => \$Global::ConfDir,
		rundir          => \$Global::RunDir,
		configfile      => \$Global::ConfigFile,
		dir          	=> \$Global::VendRoot,
		exclude         => \%Vend::CatalogToSkip,
		help            => sub { usage(); exit 0 },
		inetmode        => \$Global::Inet_Mode,
		log             => \$Global::ErrorFile,
		quiet			=> \$Vend::Quiet,
		pidfile			=> \$Global::PIDfile,
		soappidfile		=> \$Global::SOAP_PIDfile,
		serve           => $modesub,

		test			=> $modesub,
		unixmode        => \$Global::Unix_Mode,
		version         => sub { version(); exit 0 },
		stop			=> \&control_interchange,
		add				=> \&signal_add,
		email			=> \$Vend::CronEmail,
		job				=> \$Vend::CronJob,
		cron			=> \&signal_cron,
		remove			=> \&signal_remove,
		kill			=> \&control_interchange,
		Ignore 			=> \$ignore,
		restart			=> sub {
								return if $ignore;
								$ignore = 1;
								control_interchange('stop', 'TERM', 1);
								sleep 3;
								exec $0, '--Ignore', @args;
							},
		'<>'			=> sub {
							my ($arg) = @_;
							return unless $arg =~ /=/;
							my ($opt, $val) = split /=/, $arg, 2;
							my $cat;
							if($opt =~ /:/) {
								($cat, $opt) = split /:/, $opt, 2;
							}

							my $direc;
							if($cat) {
								$c_direc = Vend::Config::catalog_directives()
									unless $c_direc;
								$direc = $c_direc;
							}
							else {
								$g_direc = Vend::Config::global_directives()
									unless $g_direc;
								$direc = $g_direc;
								$cat = 'mv_global';
							}
							my $found;

							for (@$direc) {
								next unless (lc $opt) eq (lc $_->[0]);
								$found = $_->[0];
								last;
							}
							unless ($found) {
								warn "Unrecognized directive '$arg', skipping.\n";
								return;
							}

							$MV::Default{$cat} = {},
							$MV::DefaultAry{$cat} = []
								unless $MV::Default{$cat};
							$MV::Default{$cat}{$found} = $val
								unless defined $MV::Default{$cat}{$found};
							push @{$MV::DefaultAry{$cat}}, "$found $val";
							return;
							},
	);

	my @options = ( qw/
		DEBUG:i
		Ignore
		add|a=s
        confdir=s
        configfile|config|c|f=s
        cron=s
        dir|vendroot|d=s
        email=s
        exclude|e=s
        help|h
        inetmode|inet|i
        job=s
        kill:s
        log|logfile|l=s
        quiet|q
        rundir=s
		pidfile=s
		reconfig=s
		remove=s
		restart|r
		serve|start|s
		stop:s
		test|t
		unixmode|unix
		version|v
		<>
	/ );

	GetOptions(\%optctl, @options);

}

# This routine is called at startup. It performs the program and
# catalog configuration functions, to wit:
#
#   --- seed random generator
#   --- set up a couple of preloaded arrays
#   --- parse command-line options
#   --- read global configuration file interchange.cfg and
#       get catalog definitions
#   --- configure each catalog and store its configuration
#       in a reference mapped to the SCRIPT_NAME or catalog name
#   --- determine the program mode, and if it is to begin daemon
#       operation, run the Vend::Server::run_server() routine.
#   --- If Vend::Server::run_server() is entered, that will
#       never exit until a signal is sent
#
sub main_loop {
	# Setup
	unless ($Global::Windows) {
		$ENV{'PATH'} = '/bin:/usr/bin';
		$ENV{'SHELL'} = '/bin/sh';
		$ENV{'IFS'} = '';
	}
	# Initially seed the random generator
	srand;

	# Set up a couple of arrays
	setup_escape_chars();

	# These are only starting values, can be changed by command-line
	# options or the interchange.cfg file
	$Global::ConfDir = "$Global::VendRoot/etc";
	$Global::RunDir = "$Global::VendRoot/etc";
	$Global::PIDfile = "$Global::RunDir/$Global::ExeName.pid";
	$Global::SOAP_PIDfile = "$Global::RunDir/$Global::ExeName.soap.pid";

	$Vend::mode = 'serve';      # mode will be reset by options if appropriate

	# Parse command line options, getting mode if not -serve
	# May actually exit in some situations
	parse_options()
		or usage(), die "\n";

	# Cannot run as root unless in 'make test'
	if($> == 0 and ! $Global::Windows) {
		die errmsg("The Interchange server must not be run as root.\n")
			unless $ENV{MINIVEND_ROOT} =~ m{/blib$};
	}

	# Kept here for compatibility
	eval {
		require Vend::Payment::CyberCash;
	};

	# These modules no longer necessary, why take up memory?
	delete $INC{'Getopt/Long.pm'};

	$Global::ErrorFile = "$Global::VendRoot/error.log"
		if $Global::ErrorFile eq $Global::InitialErrorFile;
	undef $Global::InitialErrorFile;

	chdir($Global::VendRoot) 
		or die "Couldn't change directory to $Global::VendRoot: $!\n";
	$Global::ConfigFile = "$Global::VendRoot/$Global::ExeName.cfg"
		if ! $Global::ConfigFile;

	die "Interchange not configured, no $Global::ConfigFile.\n"
		unless -f $Global::ConfigFile;

	if(! $Global::DEBUG) {
		$Global::DEBUG = $ENV{MINIVEND_DEBUG} || 0;
	}

print errmsg("\n##### DEBUG MODE, running in foreground #####\n") if $Global::DEBUG;

	# Restrictive file permissions to begin with
	umask 077;

	# Read interchange.cfg (or whatever its name is set to be)
	global_config();
	# Select locking mode
	set_lock_type();

	@action{keys %{$Global::ActionMap}} = (values %{$Global::ActionMap})
		if $Global::ActionMap;
	@form_action{keys %{$Global::FormAction}} = (values %{$Global::FormAction})
		if $Global::FormAction;

#::logDebug(::uneval(\%Global::Catalog));

	# This is only gotten to if -reconfig passed in on command line
	if($Vend::mode eq 'reconfig') {
		eval {
			signal_reconfig(@Vend::CatalogToReconfig);
		};
		die "$@\n" if $@;
		exit;
	}

	$| = 1;
	logGlobal( "Interchange V$VERSION");

	# The global configuration set up which catalogs exist.
	# Certain ones may have been skipped with -skip on command line...
	CATCONFIG: {
		my $i = 0;
		my ($g, $c, $name);
		foreach $name (sort keys %Global::Catalog) {
			$g =  $Global::Catalog{$name};
			next if defined $Vend::CatalogToSkip{$g->{'name'}};
			print "Configuring catalog " . $g->{'name'} . '...'
				unless $Vend::Quiet or $g->{name} eq '_mv_admin';
			if (exists $Global::Selector{$g->{'script'}}) {
				warn "Two catalogs with same script name $g->{'script'}.\n";
				warn "Skipping catalog $g->{'name'}....\n\n";
				next;
			}

			# Set WARN handler to atch certain warnings and maybe elucidate
			catch_warnings(1);

			# This actually configures the catalog
			eval {
				$c = config_named_catalog($name, "at server startup");
			};

			# See if catalog configuration erred in some way....
			if ($@ or ! defined $c) {
				my $msg = $@;
				print "\n$msg\n\a$g->{'name'}: error in configuration. Skipping.\n";
				$msg =~ s/\s+$//;
				$msg = " -- $msg" if $msg;
				logGlobal $g->{'name'} . ": config error$msg. Skipping.";
				undef $Global::Selector{$g->{'script'}};
				next;
			}

			# Reset WARN handler
			catch_warnings(0);

			# Set up the mapping of the main SCRIPT_NAME
			$Global::Selector{$g->{script}} = $c;

			# Set up aliases
			if (defined $g->{alias}) {
				for(@{$g->{alias}}) {
					if (exists $Global::Selector{$_}) {
						warn "Alias $_ used a second time, skipping.\n";
						next;
					}
					elsif (m![^-\w_:~#/.]!) {
						warn "Bad alias $_, skipping.\n";
					}
					$Global::Selector{$_} = $c;
					$Global::SelectorAlias{$_} = $g->{'script'};
				}
			}

			print "done.\n"  unless $Vend::Quiet or $g->{name} =~ /^_/;
		}
	}

	#undef $Global::DumpStructure;

	if ($Vend::mode eq 'serve') {
		undef $Global::Foreground;

		# Here we prepare enter the daemon mode.

		# Set $0 to something pretty for ps(1).
		# Won't work on Solaris and IRIX among possibly others.
		# Dumps core on FreeBSD 4 stock Perl build.
		if (defined $Global::Variable->{MV_DOLLAR_ZERO}) {
			if ($Global::Variable->{MV_DOLLAR_ZERO}) {
				if (length($Global::Variable->{MV_DOLLAR_ZERO}) > 1) {
					$0 = $Global::Variable->{MV_DOLLAR_ZERO};
				}
				else {
					$0 = "interchange --> $Global::VendRoot";
				}
			}
			# do nothing if MV_DOLLAR_ZERO is defined but false
		}
		else {
			$0 = 'interchange';
		}

		# We won't have much output on any of this, but if we get some
		# we want it immediately
        select STDERR; 
        $| = 1;
        select STDOUT;
        $| = 1;

		# This should never return unless killed or a catastrophic error
        Vend::Server::run_server();
	}
	elsif($Vend::mode eq 'test') {
		# Blank by design, this option only tests config files
		# or builds catalogs
	}
	else {
		die "No mode!\n";
	}

}

### This is where we run after the first portion of the initialization
eval { main_loop(); };
if ($@) {
	my($msg) = ($@);
	$Vend::Log_suppress = 1;
	logGlobal( $msg );
	if ($Global::DisplayErrors) {
		print "$msg\n";
	}
	die "$msg\n" if $Global::Foreground;
}

=head1 SEE ALSO

compile_link(1), config_prog(1), configdump(1), dump(1), expire(1),
expireall(1), localize(1), makecat(1), offline(1), restart(1), update(1),
http://www.icdevgroup.org/

=head1 LICENSE

Interchange comes with ABSOLUTELY NO WARRANTY. This is free software, and
you are welcome to redistribute and modify it under the terms of the
GNU General Public License.

=head1 COPYRIGHT

Copyright 1995-2002, Red Hat, Inc. and others.
All rights reserved except those granted in the license.

=cut

=head1 AUTHOR

Mike Heins is the primary author of Interchange.

The Interchange Development Group is:

Brev Patterson
Dan Browning
Ed LaFrance
Jonathan Clark
Jon Jensen
Kevin Walsh
Mike Heins
Stefan Hornburg (aka Racke), captain
Ton Verhagen

Please do not contact the authors for direct help with the system.
Use the Interchange mail list:

    interchange-users@icdevgroup.org

Information on subscribing to the list, as well as general information and
documentation for Interchange is at:

    http://www.icdevgroup.org/

=head1 SPECIAL ACKNOWLEDGEMENTS

The original author of Vend was Andrew Wilcox. Interchange could never
have come into being without him.

Stefan Hornburg has had his hand in many parts of Interchange, and is by
far the most prolific bug-finder. He also was primarily responsible for
bringing MiniMate, precursor to the Interchange store administration UI,
to being as a supported facility. He continues to make valuable
contributions.

=head1 ACKNOWLEDGEMENTS

Original author of Vend, ancestor to Minivend and Interchange, was Andrew
Wilcox <amw@wilcoxsolutions.com>. Interchange was based on Vend 0.2, with
portions from Vend 0.3; both were produced in 1995.

# columnize with "sort -u | pr -t -2 | expand -8 | sed 's/^/    /'"

Contributions to Interchange have been made by:

    Andreas Koenig                      Jason Kohles
    Bill Carr                           Javier Martin
    Bill Dawkins                        Jeff Carnahan
    Bill Randle                         Jeff Nappi
    Birgitt Funk                        Jochen Wiedmann
    Bob Jordan                          Jon Jensen
    Brev Patterson                      Jonathan Clark
    Brian Bullen                        José Mª Revuelto
    Brian Kosick                        Jurgen Botz
    Bruce Albrecht                      Keiko
    Cameron Prince                      Keith Oberlin
    Chen Naor                           Kevin Walsh
    Christian Mueller                   Kim Lauritz Christensen
    Christopher Miller                  Larry Leszczynski
    Christopher Thompson                Marc Austin
    Dan Browning                        Mark Johnson
    Dan Busarow                         Mark Stosberg
    Dan Helfman                         Massimiliano Ciancio
    Daniel Thompson                     Matthew Schick
    Dave Wingate                        Michael McCune
    David Adams                         Michael Wilk
    David Kelly                         Mike Frager
    Dennis Cronin                       Neil Evans
    Don Grodecki                        Nelson Ferrari
    Ed LaFrance                         Raj Goel
    Frank Bonita                        Ray Desjardins
    Frederic Steinfels                  Ron Phipps
    Greg Hanson                         Shozo Murahashi
    Gunnar Hellekson                    Sonny Cook
    Hamish Bradick                      Tim Baverstock
    Hans-Joachim Leidinger              Tom Friedel
    Heinz Wittenbecher                  Tommi Laberno
    Hiroyuki Cozy Kojima                Ton Verhagen
    Ignacio Lizarán                     Troy Davis
    Jack Tsai                           Victor Nolton
    Jason Holt                          William Dan Terry
    and many others

and, of course, the entire Perl team without whom Interchange could not exist.

=cut

$Global::mod_perl ? 1 : 0;

__END__
