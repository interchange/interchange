#
# Vend::Accounting::SQL_Ledger
#
# SQL-Ledger Accounting Interface for Interchange
#
# Copyright (c) 2002 Daniel H. Thompson
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License. 
#
# However, I do request that this copyright notice remain attached
# to the file, and that you please attach a note listing any 
# modifications you have made to the package.
#
# Copyright (c) 2002 Mike Heins
# Major changes made by Mike Heins to fit into Vend::Accounting interface

package Vend::Accounting::SQL_Ledger;

# See the bottom of this file for the POD documentation. 
# Search for the string '=head'.

use strict;
use warnings;
use Vend::Util;
use Vend::Accounting;
use Text::ParseWords;

use vars qw/$VERSION @ISA/;
@ISA = qw/ Vend::Accounting /;

my $Tag = new Vend::Tags;

sub new {
    my $class = shift;
	my $opt = shift;

	if($opt and ref($opt) ne 'HASH') {
		my $tmp = $opt;
		$opt = { $tmp, @_ };
	}

	my $self = new Vend::Accounting;

	my $cfg = $self->{Config} = {};
	while (my ($k, $v) = each %{$Vend::Cfg->{Accounting}}) {
		$cfg->{$k} = $v;
	}
	while (my ($k, $v) = each %$opt) {
		$cfg->{$k} = $v;
	}

	if(! $cfg->{counter}) {
		my $tab = $cfg->{link_table} || 'customer';
		$cfg->{counter} = "$tab:id";
	}
    bless $self, $class;
#::logDebug("Accounting self=" . ::uneval($self) );
	return $self;
}

# ------------------ START OF THE LIBRARY ------------

my %Def_filter = (

);

my %Def_map = (

customer => <<EOF,
    name            "{company?}{b_company?b_company:company}{/company?}{company:}{b_address1?b_lname:lname}{/company:}"
    addr1           {b_address1?b_address1:address1}
    addr2           {b_address1?b_address2:address2}
    addr3           "{b_address1?}{b_city}, {b_state}  {b_zip}{/b_address1?}{b_address1:}{city}, {state}  {zip}{/b_address1:}"
    addr4           "{b_address1?}{b_country}--{country:name:{b_country}}{/b_address1?}{b_address1:}{country}--{country:name:{country}}{/b_address1:}"
    contact         "{b_fname|{fname}} {b_lname|{lname}}"
    phone           "{b_phone|{phone_day}}"
    email			email
    shiptoname      "{company?}{company}{/company?}{company:}{lname}{/company:}"
    shiptoaddr1     address1
    shiptoaddr2     address2
    shiptoaddr3     "{city}, {state}  {zip}"
    shiptoaddr4     "{country} - {country:name:{country}}"
    shiptocontact   "{fname} {lname}"
    shiptophone     phone_day
    shiptofax       fax
    shiptoemail     email
EOF

	oe =>		q(
					ordnumber	order_number
					vendor_id   vendor_id
					customer_id username
					amount		total_cost
					reqdate		require_date
					curr		currency_code
				),

);

my %Include_map = (
	customer =>	[qw/
					name
					addr1
					addr2
					addr3
					addr4
					contact
					phone
					email
					shiptoname
					shiptoaddr1
					shiptoaddr2
					shiptoaddr3
					shiptoaddr4
					shiptocontact
					shiptophone
					shiptofax
					shiptoemail
				/],
	oe =>		[qw/
					ordnumber
					transdate
					vendor_id
					customer_id 
					amount
					netamount
					reqdate
					taxincluded
					shippingpoint
					notes
					curr
				/],
	);

sub map_data {
	my ($s, $type, $ref, $record) = @_;
	$record ||= {};
	$ref    ||= $::Values;

	my $keys = $s->{Config}{"include_$type"}	|| $Include_map{$type};
	my $map  = $s->{Config}{"map_$type"}		|| $Def_map{$type};
	my $filt = $s->{Config}{"filter_$type"}		|| $Def_filter{$type};
	$map =~ s/\r?\n/ /g;
	$map =~ s/^\s+//;
	$map =~ s/\s+$//;
	my %map  = Text::ParseWords::shellwords($map);
	my %filt;
	%filt = Text::ParseWords::shellwords($filt) if $filt;

	my @keys;
	if(ref($keys)) {
		@keys = @$keys;
	}
	else {
		$keys =~ s/^\s+//;
		$keys =~ s/\s+$//;
		@keys = split /[\s,\0]+/, $keys;
	}

	for my $k (@keys) {
		my $filt = $filt{$k};
		my $v = $map{$k};
		$filt = 'strip mac' unless defined $filt;
		my $val;
		if($v =~ /^(\w+)\:(\w+)$/) {
			$val = length($ref->{$1}) ? $ref->{$1} : $ref->{$2};	
		}
		elsif ( $v =~ /{/) {
			$val = Vend::Interpolate::tag_attr_list($v, $ref);
		}
		elsif(length($v)) {
			$val = $ref->{$v};
		}
		else {
			$val = $ref->{$k};
		}
		$record->{$k} = Vend::Interpolate::filter_value($filt, $val);
	}
	return $record;
}

sub save_customer_data {

    my ($self, $userid, $hashdata) = @_;

    my $result;

	my $record = $self->map_data('customer');
	$userid =~ s/\D+//g;
    $record->{id} = $userid;
	my $tab = $self->{Config}{customer_table} || 'customer';

	my $db = ::database_exists_ref($tab)
		or die errmsg("Customer table database '%s' inaccessible.", $tab);
	return $db->set_slice($userid, $record);
}

sub assign_customer_number {
	my $s = shift || { Config => { counter => 'customer:id' } };
	return $Tag->counter( { sql => $s->{Config}{counter} } );
}

sub create_vendor_purchase_order {
    my ($self, $string) = @_;
    return $string;
}

sub create_order_entry {

	## For syntax check
	# use vars qw($Tag);

    my $self = shift;
    my $opt = shift;

	my $cfg = $self->{Config} || {};

	my $cart = delete $opt->{cart};

	## Allow a cart name, a cart reference, or default to current cart
	if($cart and ! ref($cart)) {
		$cart = $Vend::Session->{carts}{$cart};
	}

	$cart ||= $Vend::Items;

	my @charges;
	my $salestax = delete $opt->{salestax};
	my $salestax_desc = delete($opt->{salestax_desc}) || $cfg->{salestax_desc};
	my $salestax_part = delete($opt->{salestax_part}) || $cfg->{salestax_part};
	$salestax_part ||= 'SALESTAX';
	if(not length $salestax) {
		$salestax = $Tag->salestax( { noformat => 1 } );
	}
	$salestax_desc ||= "$::Values->{state} Sales Tax";
	push @charges, {
					code => $salestax_part,
					description => $salestax_desc,
					mv_price => $salestax,
				};

	if($::Values->{mv_handling}) {
		my @handling = split /\0+/, $::Values->{mv_handling};
		my $part	= delete ($opt->{handling_part})
					|| $cfg->{handling_part}
					|| 'HANDLING';
		for (@handling) {
			my $desc = $Tag->shipping_desc($_);
			my $cost = $Tag->shipping( { mode => $_, noformat => 1 });
			push @charges, {
							code => $part,
							description => $desc,
							mv_price => $cost,
						};
		}
	}

	my $shipping = delete $opt->{shipping};
	my $shipping_desc = delete($opt->{shipping_desc});
	my $shipping_part = delete($opt->{shipping_part}) || $cfg->{shipping_part};
	$shipping_part ||= 'SHIPPING';
	if(not length $shipping) {
		$shipping = $Tag->shipping( { noformat => 1 } );
	}
	$shipping_desc ||= $Tag->shipping_desc();
	push @charges, {
					code => $shipping_part,
					description => $shipping_desc,
					mv_price => $shipping,
				};

	my $tab = $cfg->{link_table} || 'customer';
	my $db = ::database_exists_ref($tab)
				or die errmsg("No database '%s' for SQL-Ledger link!J", $tab);
	my $dbh = $db->dbh()
				or die errmsg("No database handle for table '%s'.", $tab);

	my $cq = 'select id from parts where partnumber = ?';
	my $sth = $dbh->prepare('select id from parts where partnumber = ?')
				or die errmsg("Prepare '%s' failed.", $cq);

	my @oe;

	my $olq = q{
				INSERT INTO orderitems 
					   (trans_id, parts_id, description, qty, sellprice, discount)
						VALUES (?, ?, ?, ?, ?, ?)
				};
	my $ol_sth = $dbh->prepare($olq)
		or die errmsg("Prepare '%s' failed.", $olq, $tab);

	my @items;
	foreach my $item (@$cart) {
		my $code = $item->{code};
		my $desc = $item->{description} || Vend::Data::item_description($item);
		my $price = Vend::Data::item_price($item);
		my $qty = $item->{quantity};
		my $sub = $qty * $price;
		my $discsub = Vend::Interpolate::discount_price($item, $sub, $qty);
		my $discount = 0;
		if($discsub != $sub) {
			$discount = 100 * (1 - $discsub / $sub);
		}
		$sth->execute($code)
			or die errmsg("Statement '%s' failed for '%s'.", $cq, $code);
		my ($pid) = $sth->fetchrow_array;
		if(! $pid) {
			my $iacc = $cfg->{inventory_accno_id}	|| 1520;
			my $sacc = $cfg->{income_accno_id}		|| 4020;
			my $eacc = $cfg->{expense_accno_id}		|| 5010;
			my @add;
			my $addq = <<EOF;
INSERT INTO parts (
	partnumber,
	description,
	unit,
	listprice,
	sellprice,
	lastcost,
	weight,
	notes,
	rop,
	inventory_accno_id,
	income_accno_id,
	expense_accno_id
) VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? )
EOF
			my $sh = $dbh->prepare($addq)
				or die errmsg("Prepare add part '%s' failed.", $addq);

			# partnumber
			push @add, $code;
			# description
			push @add, $desc;
			# unit
			push @add, $Tag->field('uom', $code) || 'ea';
			# listprice
			push @add, $price;
			# sellprice
			push @add, $price;
			# lastcost
			push @add, 0;
			# weight
			push @add, $Tag->field('weight', $code) || 0;
			# notes
			push @add, '';
			# rop
			push @add, 0;
			# inventory_accno_id
			push @add, $iacc;
			# income_accno_id
			push @add, $sacc;
			# expense_accno_id
			push @add, $eacc;
			$sh->execute(@add) 
				or die errmsg("Execute add part '%s' failed.", $addq);
				
		}
		$sth->execute($code)
			or die errmsg("Statement '%s' failed for '%s'.", $cq, $code);
		my ($newpid) = $sth->fetchrow_array;
		push @items, [$newpid, $desc, $qty, $price, $discount];
	}

#(trans_id, parts_id, description, qty, sellprice, discount)

	for my $c (@charges) {
		$sth->execute($c->{code})
			or die errmsg("Statement '%s' failed.", $cq);
		my ($pid) = $sth->fetchrow_array;
		push @items, [$pid, $c->{description}, 1, $c->{mv_price}, 0]; 
	}

	my ($tid) = $Tag->counter({ sql => "$tab:id" });

	my $tq = q{
		INSERT INTO oe VALUES (
			?,
			?,
			date('now'::text),
			0,
			?,
			?,
			?,
			date('now'::text),
			'f',
			'',
			?,
			?)
		};

	my $total = $Tag->total_cost({ noformat => 1 });

	my $tsth = $dbh->prepare($tq)
		or die errmsg("Statement '%s' failed.", $tq);

	my $customer_id = $opt->{customer_id} || $Vend::Session->{username};
	$customer_id =~ s/\D+//g;
	my @vals = (
				$tid,
				$opt->{order_number} || $::Values->{mv_order_number},
				$customer_id,
				$total,
				$total,
				$opt->{notes} || $::Values->{gift_note},
				$cfg->{currency_code} || 'usd',
				);
	
	$tsth->execute(@vals) 
		or die errmsg("Statement '%s' failed.", $tq);

	for(@items) {
		$ol_sth->execute($tid, @$_);
	}
		
#::logDebug("past accounting, ready to return 1");
    return 1;
}


sub enter_payment {
    my ($self, $string) = @_;
	my $datastuff = ::uneval(\@_);
	`echo "This is a enter_customer_payment test... $datastuff" >> testlog.txt`;
    return $string;
}

return 1;


=head

CREATE SEQUENCE "id" start 1 increment 1 maxvalue 2147483647 minvalue 1  cache 1 ;

CREATE TABLE "makemodel" (
	"id" integer,
	"parts_id" integer,
	"name" text
);
CREATE TABLE "gl" (
	"id" integer DEFAULT nextval('id'::text),
	"source" text,
	"description" text,
	"transdate" date DEFAULT date('now'::text)
);

CREATE TABLE "chart" (
	"id" integer DEFAULT nextval('id'::text),
	"accno" integer,
	"description" text,
	"charttype" character(1) DEFAULT 'A',
	"gifi" integer,
	"category" character(1),
	"link" text
);

CREATE TABLE "defaults" (
	"inventory_accno_id" integer,
	"income_accno_id" integer,
	"expense_accno_id" integer,
	"fxgain_accno_id" integer,
	"fxloss_accno_id" integer,
	"invnumber" text,
	"ordnumber" text,
	"yearend" character varying(5),
	"curr" text,
	"weightunit" character varying(5),
	"businessnumber" text,
	"version" character varying(8)
);

CREATE TABLE "acc_trans" (
	"trans_id" integer,
	"chart_id" integer,
	"amount" double precision,
	"transdate" date DEFAULT date('now'::text),
	"source" text,
	"cleared" boolean DEFAULT 'f',
	"fx_transaction" boolean DEFAULT 'f'
);

CREATE TABLE "invoice" (
	"id" integer DEFAULT nextval('id'::text),
	"trans_id" integer,
	"parts_id" integer,
	"description" text,
	"qty" real,
	"allocated" real,
	"sellprice" double precision,
	"fxsellprice" double precision,
	"discount" real,
	"assemblyitem" boolean DEFAULT 'f'
);

CREATE TABLE "vendor" (
	"id" integer DEFAULT nextval('id'::text),
	"name" character varying(35),
	"addr1" character varying(35),
	"addr2" character varying(35),
	"addr3" character varying(35),
	"addr4" character varying(35),
	"contact" character varying(35),
	"phone" character varying(20),
	"fax" character varying(20),
	"email" text,
	"notes" text,
	"terms" smallint DEFAULT 0,
	"taxincluded" boolean
);

CREATE TABLE "customer" (
	"id" integer DEFAULT nextval('id'::text),
	"name" character varying(35),
	"addr1" character varying(35),
	"addr2" character varying(35),
	"addr3" character varying(35),
	"addr4" character varying(35),
	"contact" character varying(35),
	"phone" character varying(20),
	"fax" character varying(20),
	"email" text,
	"notes" text,
	"discount" real,
	"taxincluded" boolean,
	"creditlimit" double precision DEFAULT 0,
	"terms" smallint DEFAULT 0,
	"shiptoname" character varying(35),
	"shiptoaddr1" character varying(35),
	"shiptoaddr2" character varying(35),
	"shiptoaddr3" character varying(35),
	"shiptoaddr4" character varying(35),
	"shiptocontact" character varying(20),
	"shiptophone" character varying(20),
	"shiptofax" character varying(20),
	"shiptoemail" text
);

CREATE TABLE "parts" (
	"id" integer DEFAULT nextval('id'::text),
	"partnumber" text,
	"description" text,
	"bin" text,
	"unit" character varying(5),
	"listprice" double precision,
	"sellprice" double precision,
	"lastcost" double precision,
	"priceupdate" date DEFAULT date('now'::text),
	"weight" real,
	"onhand" real DEFAULT 0,
	"notes" text,
	"makemodel" boolean DEFAULT 'f',
	"assembly" boolean DEFAULT 'f',
	"alternate" boolean DEFAULT 'f',
	"rop" real,
	"inventory_accno_id" integer,
	"income_accno_id" integer,
	"expense_accno_id" integer,
	"obsolete" boolean DEFAULT 'f'
);

CREATE TABLE "assembly" (
	"id" integer,
	"parts_id" integer,
	"qty" double precision
);

CREATE TABLE "ar" (
	"id" integer DEFAULT nextval('id'::text),
	"invnumber" text,
	"ordnumber" text,
	"transdate" date DEFAULT date('now'::text),
	"customer_id" integer,
	"taxincluded" boolean,
	"amount" double precision,
	"netamount" double precision,
	"paid" double precision,
	"datepaid" date,
	"duedate" date,
	"invoice" boolean DEFAULT 'f',
	"shippingpoint" text,
	"terms" smallint DEFAULT 0,
	"notes" text,
	"curr" character(3)
);

CREATE TABLE "ap" (
	"id" integer DEFAULT nextval('id'::text),
	"invnumber" text,
	"transdate" date DEFAULT date('now'::text),
	"vendor_id" integer,
	"taxincluded" boolean,
	"amount" double precision,
	"netamount" double precision,
	"paid" double precision,
	"datepaid" date,
	"duedate" date,
	"invoice" boolean DEFAULT 'f',
	"ordnumber" text,
	"curr" character(3)
);

CREATE TABLE "partstax" (
	"parts_id" integer,
	"chart_id" integer
);

CREATE TABLE "tax" (
	"chart_id" integer,
	"rate" double precision,
	"taxnumber" text
);

CREATE TABLE "customertax" (
	"customer_id" integer,
	"chart_id" integer
);

CREATE TABLE "vendortax" (
	"vendor_id" integer,
	"chart_id" integer
);

CREATE TABLE "oe" (
	"id" integer DEFAULT nextval('id'::text),
	"ordnumber" text,
	"transdate" date DEFAULT date('now'::text),
	"vendor_id" integer,
	"customer_id" integer,
	"amount" double precision,
	"netamount" double precision,
	"reqdate" date,
	"taxincluded" boolean,
	"shippingpoint" text,
	"notes" text,
	"curr" character(3)
);

CREATE TABLE "orderitems" (
	"trans_id" integer,
	"parts_id" integer,
	"description" text,
	"qty" real,
	"sellprice" double precision,
	"discount" real
);

CREATE TABLE "exchangerate" (
	"curr" character(3),
	"transdate" date,
	"buy" double precision,
	"sell" double precision
);

SLInterface

SQL-Ledger Accounting Interface for Interchange

This module is an attempt to create a set of callable routines 
that will allow the easy integration of the SQL-Ledger Accounting 
package with "Red Hat's" Interchange. 

It handles the mapping of the Interchange variable names to the 
appropriate SQL-Ledger ones as well as parsing the html returned 
by the SQL-Ledger "API".

Background: SQL-Ledger Accounting "www.sql-ledger.org" 
is a multiuser, double entry, accounting system written in Perl 
and is licensed under the GNU General Public License. 

The SQL-Ledger API: SQL-Ledger functions can be accessed from the 
command line by passing all the variables in one long string to 
the perl script. The variable=value pairs must be separated by an 
ampersand. See "www.sql-ledger.org/misc/api.html" for more details 
on the command line interface. 

------------------------------------------------------------------

This module also happens to be the author's first perl module and probably 
his second or third perl program in addition to "Hello World". :) 

So please go easy on me. -Daniel  

=cut
