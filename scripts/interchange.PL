#$self = {
#	INSTALLPRIVLIB => '/usr/local/interchange/lib',
#	INSTALLARCHLIB => '/usr/local/interchange',
#};

use Config;
require 'scripts/initp.pl';

sub doit {
	my ($key) = @_;
	my $val;
	if ($MV::Self->{RPMBUILDDIR} and $val = $MV::Self->{$key}) {
		$val =~ s!^$MV::Self->{RPMBUILDDIR}/!/!; 
		return $val;
	}
	return $MV::Self->{$key} unless $key =~ /[a-z]/;
	return $Config{$key};
}

DOIT: {
	local ($/);
	local($_) = <<'_EoP_';
#!/usr/bin/perl
##!~_~perlpath~_~
#
# Interchange version 4.7.0
#
# $Id: interchange.PL,v 1.8.2.7 2000-11-27 19:46:31 zarko Exp $
#
# Copyright (C) 1996-2000 Akopia, Inc. <info@akopia.com>
#
# This program was originally based on Vend 0.2
# Copyright 1995 by Andrew M. Wilcox <awilcox@world.std.com>
#
# Portions from Vend 0.3
# Copyright 1995 by Andrew M. Wilcox <awilcox@world.std.com>
#
# See the file 'Changes' for information.
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
	$Vend::Foreground = 1;
	
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
	elsif(-f "$Global::VendRoot/interchange.cfg.dist") {
		$Global::ExeName = 'interchange';
		$Global::ConfigFile = 'interchange.cfg';
	}

	$Global::InitialErrorFile = $Global::ErrorFile = "$Global::VendRoot/error.log";

	if($^O =~ /win32/i) {
		$Global::Windows = 1;
	}

# Uncomment next line if you want to guarantee use of DB_File
#$ENV{MINIVEND_DBFILE} = 1;

# Uncomment next line if you want to guarantee use of GDBM and not DB_File
#$ENV{MINIVEND_GDBM} = 1;

# Uncomment next line if you want to use no DBM, sessions
# stored in files and databases in memory (or SQL)
#$ENV{MINIVEND_NODBM} = 1;

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
	$VERSION = '4.7.0';
}

use Fcntl;

# BSD, among others, defines sendmail to be in /usr/sbin, and
# we want to make sure the program is there. Insert the location
# of you sendmail binary (the configure script should do this)
$Global::SendMailLocation = ($Global::Windows and $Global::SendMailLocation) ||
	(-x $Global::SendMailLocation and $Global::SendMailLocation) ||
	(-x '/usr/lib/sendmail' and '/usr/lib/sendmail') ||
	(-x '/usr/sbin/sendmail' and '/usr/sbin/sendmail') ||
	'';
#	'~_~sendmail~_~';

#select a DBM

BEGIN {
	$Global::GDBM = $Global::DB_File =
# LDAP
	$Global::LDAP =
# END LDAP
# SQL
	$Global::DBI =
# END SQL
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
			(defined $ENV{MINIVEND_NODBM});
		eval {require GDBM_File and $Global::GDBM = 1};
		last AUTO if 
			(defined $ENV{MINIVEND_GDBM} and $Global::GDBM = 1);
		eval {require DB_File and $Global::DB_File = 1};
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
	$Global::Default_database = 'MEMORY'
			unless defined $Global::Default_database;
	require Vend::Table::InMemory;
}


use Vend::Util;
use Vend::Server;
use Vend::Session;
use Vend::Config;

# You might try commenting out these lines and uncommenting the ones
# below to compact memory size
# NOAUTOUSE
#use Vend::Order;
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
											signal_remove
											control_interchange
											change_catalog_directive
											change_global_directive
											remove_catalog
											add_catalog
											change_catalog_directive
											change_global_directive
									/;
use autouse 'Vend::Order' => qw/
											add_items
											check_order
											check_required
											cyber_charge
   										encrypt_standard_cc
   										mail_order
   										onfly
   										route_order
   										validate_whole_cc
   								/;

# END AUTOUSE

# GLIMPSE
use Vend::Glimpse;
# END GLIMPSE

# TRACK
use Vend::Track;
# END TRACK

use Vend::Scan;
use Vend::TextSearch;
use Vend::DbSearch;
use Vend::Data;
use Vend::UserDB;
use Vend::Interpolate;
use Vend::Page;
use Vend::Mail;
use File::CounterFile;

if( ! $Global::Windows and $> == -1 || scalar(getpwuid($>)) eq 'nobody' ) {
	warn errmsg("\aYou probably don't want to run as nobody!\n");
	sleep 1;
	warn errmsg("The security problems are on your head, though. Continuing...\n");
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

# Returns undef if interaction error
sub update_quantity {
    return 1 unless defined  $CGI::values{"quantity0"};
	my($h, $i, $quantity, $modifier, $cart);

	$cart = Vend::Cart::get_cart($CGI::values{mv_cartname});

	if(ref $Vend::Cfg->{UseModifier}) {
		foreach $h (@{$Vend::Cfg->{UseModifier}}) {
			delete @{$::Values}{grep /^$h\d+$/, keys %$::Values};
			foreach $i (0 .. $#$cart) {
#::logDebug("updating line $i modifiers: " . ::uneval($cart->[$i]));
				$modifier = $CGI::values{"$h$i"} || undef;
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
	}

	foreach $i (0 .. $#$cart) {
#::logDebug("updating line $i quantity: " . ::uneval($cart->[$i]));
    	$quantity = $CGI::values{"quantity$i"};
    	if (! defined $quantity) {
        	interaction_error("Variable '$quantity' not passed from form\n");
        	return undef;
		}
    	elsif ($quantity =~ m/^\d*$/) {
        	$cart->[$i]->{'quantity'} = $quantity || 0;
    	}
    	elsif ($quantity =~ m/^[\d.]+$/
				and $Vend::Cfg->{FractionalItems} ) {
        	$cart->[$i]->{'quantity'} = $quantity;
    	}
		# This allows a multiple input of item quantity to
		# pass -- FIRST ONE CONTROLS
		elsif ($quantity =~ s/\0.*//) {
			$CGI::values{"quantity$i"} = $quantity;
			redo;
		}
		else {
			my $item = $cart->[$i]->{'code'};
        	interaction_error("'$quantity' for item $item is not numeric\n");
        	return undef;
    	}
    	$::Values->{"quantity$i"} = delete $CGI::values{"quantity$i"};
    }
#::logDebug("after update, cart is: " . ::uneval($cart));

	# If the user has put in "0" for any quantity, delete that item
    # from the order list.
    Vend::Cart::toss_cart($cart);

#::logDebug("after toss, cart is: " . ::uneval($cart));

	1;

}

## Update the user-entered fields.
sub update_data {
	my($key,$value);
	# Update a database record

	# Check to see if this is allowed
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

	$ref = $Vend::Cfg->{Database}->{$table} || '';

	if (! $ref) {
		logError("set: non-existent table %s", $table);
		return undef;
	}
	$Vend::WriteDatabase{$table} = 1;

	my $base_db = database_exists_ref($table)
		or die "Not a defined database '$table': $!\n";
	$base_db = $base_db->ref();

	my @fields		= grep $_ && $_ ne $prikey,
						split /[\s\0,]+/, $CGI::values{mv_data_fields};
	unshift(@fields, $prikey);
	$function = 'update' unless $function;

	my (%data);
	for(@fields) {
		$data{$_} = [];
	}

	while (($key, $value) = each %CGI::values) {
		next unless defined $data{$key};
		@{$data{$key}} = split /\0/, $value;
	}

	if (not defined $data{$prikey}) {
		logError("No key '%s' in field specifier %s", $prikey, 'mv_data_fields');
		return undef;
	} elsif ( ! @{$data{$prikey}}) {
		logError("No key '%s' found for function='%s' table='%s'",
					$prikey, $function, $CGI::values{mv_data_table},
					);
		return undef;
	}

	my ($query,$i);
	my (@k);
	my (@v);
	my (@c);
#::logDebug("update_data:db=$db key=$prikey VALUES=" . ::uneval(\%CGI::values));
	my $select_key;
	for($i = 0; $i < @{$data{$prikey}}; $i++) {
		@k = (); @v = ();
		for(keys %data) {
			next unless (length($value = $data{$_}->[$i]) || $CGI::values{mv_update_empty} );
			push(@k, $_);
# LEGACY
			HTML::Entities::decode($value) if $decode;
# END LEGACY
			if(defined $CGI::values{"mv_data_filter_$_"}) {
				$value = Vend::Interpolate::filter_value(
							 $CGI::values{"mv_data_filter_$_"},
							 $value,
							 $i,
							 );
			}
			$select_key = $value if $_ eq $prikey;
			push(@v, $value);
		}

		if($function eq 'delete') {
			$base_db->delete_record($select_key);
		} else {
			my $field;
			$key = $data{$prikey}->[$i];
			while($field = shift @k) {
				$value = shift @v;
				next if $field eq $prikey;

				if($field =~ /^(\w+):+(.*)/) {
					my $d = $1;
					my $f = $2;
					$Vend::WriteDatabase = 1 if $::Scratch->{mv_data_enable} =~ /\b$d\b/;
					$d = ::database_exists_ref($d);
					if($d) {
						$base_db = $d->ref();
						$field = $f;
					} else {
						$base_db = $field = undef;
					}
				}

#::logDebug("update_data:db=$base_db key=$key field=$field value=$value");
				$base_db->set_field($key, $field, $value);
			}
		}
	}

	if($CGI::values{mv_auto_export}) {
		Vend::Data::export_database($table);
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
my %Ignore = qw(
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
	mv_more_ip  1
	mv_credit_card_number  1
	);

sub update_values {

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

	my ($key, $value);
    while (($key, $value) = each %CGI::values) {
        next if defined $Ignore{$key};
        next if defined $Vend::Cfg->{FormIgnore}->{$key};
        next if ($key =~ m/^quantity\d+$/);
		# We add any checkbox ordered items, but don't update -- 
		# we don't want to order them twice
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
	if(defined $CGI::values{mv_click}) {
		@clicks = split /\s*[\0]+\s*/, $CGI::values{mv_click};
	}

	if(defined $CGI::values{mv_click_map}) {
		my(@map) = split /\s*[\0]+\s*/, $CGI::values{mv_click_map};
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
		Vend::Server::response($msg);
		return 0;
	}

	if (! -f $file) {
		$Vend::StatusLine = "Status: 404\nContent-Type: text/html";
		my $msg = get_locale_message(404, <<EOF, $file);
<B>Not Found<B>
<P>
The requested file %s was not found on this server.

EOF
		Vend::Server::response($msg);
		return 0;
	}

	$Vend::StatusLine = "Content-Type: " .
						($CGI::values{mv_content_type} || 'application/octet-stream');
	Vend::Server::response(	Vend::Util::readfile (
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
					my($missing,$next,$status,$final);

					# Set shopping cart if necessary
					# Vend::Items is tied, remember!
					$Vend::Items = $CGI::values{mv_cartname}
						if $CGI::values{mv_cartname};

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

					my $provisional;
					if ($status and defined $CGI::values{mv_order_route}) {
						# This checks only route order profiles
#::logDebug("Routing order, pre-check");
						($status, $provisional, $missing) = route_order(
												$CGI::values{mv_order_route},
												$Vend::Items,
												'check',
											);
					} 

					$final = $provisional if ! $final;

#::logDebug("Routing status status=$status final=$final errors=$missing");
					if($status) {
						$CGI::values{mv_nextpage} = $::Values->{mv_successpage} 
							if $::Values->{mv_successpage};
						$CGI::values{mv_nextpage} = $::Values->{mv_orderpage} 
							if ! $CGI::values{mv_nextpage};
					}
					else {
						$CGI::values{mv_nextpage} = $::Values->{mv_failpage}
							if $::Values->{mv_failpage};
						$CGI::values{mv_nextpage} = find_special_page('needfield')
							if ! $CGI::values{mv_nextpage};
						undef $final;
					}

					return 1 unless $final;

					my $order_no;
					if (defined $CGI::values{mv_order_route}) {
						# $ok will not be defined unless Route "supplant" was set
						# $order_no will come back so we don't issue two of them
#::logDebug("Routing order");
						($ok, $order_no) = route_order(
											$CGI::values{mv_order_route},
											$Vend::Items
											);
					}
					my $mode = $CGI::values{mv_payment_mode};
					if (! $ok and defined $Vend::Cfg->{ActionMap}{$mode}) {
						($ok, $status) = $Vend::Cfg->{ActionMap}{$mode}->();
					} elsif(
							$Vend::Cfg->{CyberCash}
							and defined $CGI::values{mv_cyber_mode}
						)
					{
#::logDebug("Cyber charge");
						$status = cyber_charge();
						unless($status) {
							$CGI::values->{mv_nextpage} = find_special_page('failed')
								if ! $CGI::values->{mv_nextpage};
							return 1;
						}
					}

					# This function (followed down) now does the rudimentary
					# backend ordering with AsciiTrack and the order report.
					# If the "supplant" option was set in order routing it will
					# not be used ($ok would have been defined)

# TRACK
					$Vend::Track->finish_order ();
# END TRACK

#::logDebug("Order number=$order_no\n");
					$ok = mail_order(undef, $order_no || undef) unless defined $ok;
#::logDebug("Order number=$order_no\n");

					# Display a receipt if configured

					if ($ok) {
						eval {
							display_special_page(
											$::Values->{mv_order_receipt}	||
											find_special_page('receipt')
											);
						};
						if($@) {
							my $msg = $@;
							::logError( 
								'Display of receipt on order number %s failed: %s',
								$::Values->{mv_order_number},
								$msg,
							);
						}
					} else {
						display_special_page(
								find_special_page('failed'),
								errmsg('Error transmitting order(%s): %s', $!, $@),
						);
					}

					# Remove the items
					@$Vend::Items = ();
					put_session();
					return 0;
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
					update_user();
					update_data();
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
	do_click();

	my $todo = $CGI::values{mv_todo};

	# Maybe we have an imagemap input, if not, use $doit
	if( ! defined $todo) {
		if (defined $CGI::values{'mv_todo.x'}) {
				my $x = $CGI::values{'mv_todo.x'};
				my $y = $CGI::values{'mv_todo.y'};
				my $map = $CGI::values{'mv_todo.map'};
				$todo = Vend::Imagemap::action_map($x,$y,$map);
		} elsif (defined $CGI::values{'mv_todo.submit.x'}) {
			$todo = 'submit';
		} elsif (defined $CGI::values{'mv_todo.checkout.x'}) {
			$todo = 'checkout';
		} elsif (defined $CGI::values{'mv_todo.return.x'}) {
			$todo = 'return';
		} else {
			$todo = $CGI::values{mv_doit} if defined $CGI::values{mv_doit};
		}
	}

	my ($sub, $status);
	# Now determine the action on the todo
	if(defined $Vend::Cfg->{FormAction}{$todo}) {
		$sub = $Vend::Cfg->{FormAction}{$todo};
		new Vend::Parse;
	} elsif(defined $form_action{$todo}) {
		$sub = $form_action{$todo};
	} else {
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
		Vend::Server::response($template);
	}

	return $status;
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
            if $rw && (! -f "$Vend::Cfg->{StaticDBM}.gdbm" || $Vend::BuildingPages);
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

## DEBUG

sub dontwarn {

# STATICPAGE
	$File::Find::name +
	$File::Find::prune +
	<DATA> + 
# END STATICPAGE
	$Global::AdminSub +
	$Global::DomainTail +
	$Global::FullUrl +
    $Global::HitCount +
    $Global::LockoutCommand +
	$Global::IpHead +
	$Vend::CheckHTML +
	$Vend::Action +
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
	print "Interchange version $VERSION Copyright 1996-2000 Akopia, Inc.\n";
}

=head1 NAME

interchange - an e-commerce and general HTTP database display system

=head1 SYNOPSIS

interchange [--options] [file]

=head1 VERSION

4.0

=head1 DESCRIPTION

Interchange is a database access and retrieval system focused on e-commerce.
It allows customers to select items to buy from catalog pages. The program
tracks user information in sessions and interacts with an HTTP server
through sockets.

Interchange has many, many, functions and features; they are too numerous
to describe in this venue. Complete information can be found at
its web site:

		http://www.akopia.com/

Interchange requires Perl 5.005 or higher; more information on Perl can
be seen at:

		http://www.perl.com

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

=item C<-b catalog, --build=catalog>

Build static page tree for C<catalog>.

=item -d dir, --dir=dir

Directory for VendRoot. This is where the Interchange configuration file
will be looked for (if not redefined with C<-f>), and where the log file
will go (if not redefined with the ErrorFile directive).

=item -e name, --exclude=name

Exclude catalog from this startup.

=item -f file, --config=file

Configuration file to use (default is interchange.cfg in VendRoot).

=item --files spec

File specification to build (perl regexp OK) for static page tree

=item -h, --help

Display help on command line options.

=item -i, --inetmode

Run with internet-domain socket only. Normally Interchange runs with
both UNIX- and internet-domain sockets (except on Windows).

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

=item -D, --DEBUG

Run foreground in debug mode. It is normal to receive warnings about
various things.

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

     --add=catalog         remove a catalog from operation, parms taken
                           from the standard input
     -b catalog
        --build=catalog    build static page tree for catalog
     -d dir, --dir=dir     directory for VendRoot (interchange.cfg, error.log, etc.)
     -e name,
        --exclude=name     exclude catalog
     -f file,
        --config=file      configuration file (default interchange.cfg)
     --files spec          filespec (perl regexp OK) for static page tree
     -h, --help            display this message
     -i, --inetmode        run with Internet-domain socket (TCP)
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
     -D, --DEBUG           run foreground in debug mode
END
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
						$Vend::CatalogToBuild{$val} = 1 if $mode eq 'build';
						$Vend::mode = $mode;
					};

	my ($c_direc, $g_direc);

	my @args = @ARGV;
	my $ignore = 0;

	my %optctl = (

		DEBUG 		    => \$Global::DEBUG,
		build           => $modesub,
		reconfig        => $rcfgsub,
		confdir         => \$Global::ConfDir,
		configfile      => \$Global::ConfigFile,
		dir          	=> \$Global::VendRoot,
		exclude         => \%Vend::CatalogToSkip,
		files	        => \$Vend::BuildSpec,
		help            => sub { usage(); exit 0 },
		inetmode        => \$Global::Inet_Mode,
		log             => \$Global::ErrorFile,
		quiet			=> \$Vend::Quiet,
		pidfile			=> \$Global::PIDfile,
		serve           => $modesub,

		test			=> $modesub,
		unixmode        => \$Global::Unix_Mode,
		version         => sub { version(); exit 0 },
		stop			=> \&control_interchange,
		add				=> \&signal_add,
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
		DEBUG|D:i
		Ignore
		add|a=s
		build|b=s
		confdir=s
		configfile|config|c|f=s
		dir|vendroot|d=s
		exclude|e=s
		files=s
		help|h
		inetmode|inet|i
		kill:s
		log|logfile|l=s
		quiet|q
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
	$Global::PIDfile = "$Global::ConfDir/$Global::ExeName.pid";

	$Vend::mode = 'serve';      # mode will be reset by options if appropriate

	# Parse command line options, getting mode if not -serve
	# May actually exit in some situations
	parse_options()
		or die usage() . "\n";

	# Cannot run as root unless in 'make test'
	if($> == 0 and ! $Global::Windows) {
		die errmsg("The Interchange server must not be run as root.\n")
			unless $ENV{MINIVEND_ROOT} =~ m{/blib$};
	}

	## Bring in the CyberCash libraries if present
	## Moved here to prevent unwanted messages
	eval {
		package Vend::Order;
		require CCLib;
		$Vend::CC2 = 1;
		my $ver = $CCLib::VERSION || '2.1';
		::logGlobal({}, "CyberCash module found (Version %s)", $ver )
			unless $Vend::Quiet;
	};

	$Vend::CyberCash = ! $@;

	eval {
		package Vend::Order;
		require CCMckLib3_2 ;
		import CCMckLib3_2 qw/InitConfig %Config $MCKversion/;
		require CCMckDirectLib3_2;
		import CCMckDirectLib3_2 qw/SendCC2_1Server doDirectPayment/;
		require CCMckErrno3_2;
		import CCMckErrno3_2 qw/MCKGetErrorMessage/;
		$Vend::CC3 = 1;
		$Vend::CC3server = 0;
		my $ver = $CCMckLib3_2::VERSION || '3.x';
		::logGlobal({}, "CyberCash module found (Version %s)", $ver )
			unless $Vend::Quiet;
	};

	$Vend::CyberCash = $Vend::CyberCash || ! $@;

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
			next if
				$Vend::mode eq 'build' and
				! defined $Vend::CatalogToBuild{$g->{'name'}};
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
					elsif (m![^\w-_:~#/.]!) {
						warn "Bad alias $_, skipping.\n";
					}
					$Global::Selector{$_} = $c;
					$Global::SelectorAlias{$_} = $g->{'script'};
				}
			}
# STATICPAGE
			# This is probably not useful any more.....use the
			# regen feature of the UI.
			if ($Vend::CatalogToBuild{$g->{name}}) {
				require Vend::Misc::Static;
				eval {
					Vend::Misc::Static::build_all($g->{name});
				};
				if($@) {
					die "Error building pages: $@\n";
				}
				undef $Vend::BuildingPages;
			}
# END STATICPAGE
			print "done.\n"  unless $Vend::Quiet or $g->{name} =~ /^_/;
		}
	}

	#undef $Global::DumpStructure;

	if ($Vend::mode eq 'serve') {
		undef $Vend::Foreground;

		# Here we prepare enter the daemon mode.

		# Set the $0 to something not having 'perl' (won't
		# work on Solaris and IRIX among possibly others)
		if(defined $Global::Variable->{MV_DOLLAR_ZERO}) {
			$0 = $Global::Variable->{MV_DOLLAR_ZERO};
			$0 = "interchange --> $Global::VendRoot"
					if length($0) < 2;
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
	elsif ($Vend::mode eq 'test' || $Vend::mode eq 'build') {
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
	logGlobal( $msg );
	if ($Global::DisplayErrors) {
		print "$msg\n";
	}
	die "$msg\n" if $Vend::ForeGround;
}

=head1 SEE ALSO

mvdocs(8), compile_link(1), config_prog(1), configdump(1), dump(1), expire(1),
expireall(1), localize(1), makecat(1), offline(1), restart(1), update(1),
http://www.akopia.com/

=head1 LICENSE

Interchange comes with ABSOLUTELY NO WARRANTY.  This is free software, and
you are welcome to redistribute and modify it under the terms of the
GNU General Public License.

=head1 COPYRIGHT

Copyright 1995-2000, Mike Heins. All rights reserved except as in the
license.

=cut

=head1 AUTHOR

Mike Heins, <heins@akopia.com>. Please do not contact the author for
direct help with the system. Use the Interchange mail lists:

	interchange-users	(English, subscribe at http://developer.akopia.com/)

General information and documentation for Interchange is at:

	http://www.akopia.com/
	http://developer.akopia.com/

=head1 SPECIAL ACKNOWLEDGEMENTS

Original author of the Vend was Andrew Wilcox. Interchange could never
have come into being without him.

Stefan Hornburg has had his hand in many parts of Interchange, and is by
far the most prolific bug-finder. He also was primarily responsible for
bringing MiniMate, precursor to the Interchange UI database editor,
to being as a supported facility. He continues to make valuable
contributions.

=head1 ACKNOWLEDGEMENTS

Original author of Vend, ancestor to Minivend and Interchange, was Andrew
Wilcox. Interchange was based on Vend 0.2, with portions from Vend 0.3;
both were produced in 1995.

Contributions to Interchange have been made by:

    Andreas Koenig     
    Bill Randle
    Birgitt Funk       
    Bob Jordan         
    Brian Bullen       
    Bruce Albrecht     
	Cameron Prince
    Christian Mueller
    Christopher Thompson
    Dave Adams
    Dan Busarow
    Dave Wingate
	Dennis Cronin
    Don Grodecki       
    Frank Bonita       
    Gunnar Hellekson   
    Heinz Wittenbecher
    Jason Holt
    Jeff Carnahan
    Jeff Nappi
    Jochen Wiedmann
    Jon Jensen
    Keiko
    Keith Oberlin
    Larry Leszczynski
    Marc Austin
    Mark Stosberg
    Michael McCune
    Michael Wilk
    Mike Frager
    Neil Evans
    Raj Goel
    Ray Desjardins
    Sonny Cook
    Tim Baverstock
    Ton Verhagen
    William Dan Terry
    and many others

and, of course, the entire Perl team without whom Interchange could not exist.

=cut

__END__

_EoP_
	s{.*\n(#(.*)~_~(\w+)~_~(.*))}{$2 . doit($3) . "$4\n$1"}eg;
	my $file = $0;
	$file =~ s/\.PL$//;
	open(OUT, ">$file") 
		or die "Create $file: $!\n";
	print OUT $_;
}
