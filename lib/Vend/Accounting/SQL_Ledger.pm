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
use vars qw/$Have_AR $Have_IC $Have_IS/;
eval {
	require SL::GL;
	require SL::AR;
	$Have_AR = 1;
};

eval {
	require SL::IC;
	$Have_IC = 1;
};


eval {
	require SL::IS;
	$Have_IS = 1;
};

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

	my $tab = $cfg->{link_table} || 'customer';
	my $db = ::database_exists_ref($tab)
				or die errmsg("No database '%s' for SQL-Ledger link!J", $tab);
	my $dbh = $db->dbh()
				or die errmsg("No database handle for table '%s'.", $tab);

	my $cq = 'select id from parts where partnumber = ?';
	my $sth = $dbh->prepare('select id from parts where partnumber = ?')
				or die errmsg("Prepare '%s' failed.", $cq);


	my @charges;
	if($Vend::Cfg->{Levies}) {
		$Tag->levies(1);
		my $lcart = $::Levies;
		for my $levy (@$lcart) {
			my $pid = $levy->{part_number};
			$pid ||= uc($levy->{group} || $levy->{type});
			my $lresult = {
						code => $pid,
						description => $levy->{description},
						mv_price => $levy->{cost},
			};
#::logDebug("levy result=" . ::uneval($lresult));
			push @charges, $lresult;
		}
	}
	else {
		my $salestax = $opt->{salestax};
		my $salestax_desc = $opt->{salestax_desc} || $cfg->{salestax_desc};
		my $salestax_part = $opt->{salestax_part} || $cfg->{salestax_part};
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
			my $part	= $opt->{handling_part}
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

		my $shipping = $opt->{shipping};
		my $shipping_desc = $opt->{shipping_desc};
		my $shipping_part = $opt->{shipping_part} || $cfg->{shipping_part};
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
	}

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
) VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?,
			(select c.id from chart c where c.accno = ?),
			(select c.id from chart c where c.accno = ?),
			(select c.id from chart c where c.accno = ?)
			)
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

my @all_part_fields = qw/
			partnumber
			description
			bin
			unit
			listprice
			sellprice
			weight
			onhand
			notes
			inventory_accno_id
			income_accno_id
			expense_accno_id
			obsolete
/;
my @update_part_fields = qw/
			partnumber
			description
			unit
			listprice
			weight
			obsolete
/;

my %query = (
	find   => 'SELECT id FROM parts WHERE partnumber = ?',
	insert => 'INSERT INTO parts ( $ALLFIELDS$ ) VALUES ( $ALLVALUES$ )',
	update => 'UPDATE parts set $UPDATEFIELDS$ WHERE id = ?',
);

my %default_source = (qw/
	listprice	products:price
	sellprice	products:price
	partnumber	products:sku
	weight		products:weight
	onhand		inventory:quantity
	obsolete	products:inactive
	description	products:description
/);

my %default_value = (
	unit	=> 'ea',
	weight	=> 0,
	onhand	=> 0,
	notes	=> 'Added from Interchange',
	inventory_accno_id	=> 1520,
	expense_accno_id	=> 5020,
	income_accno_id	=> 4020,
);

use vars qw/%value_filter %value_indirect/;

%value_filter = (
	obsolete => sub { my $val = shift; return $val =~ /1/ ? 't' : 'f'; },
	inventory_accno_id	=> sub { my $val = shift; return $val || shift || 0 },
	expense_accno_id	=> sub { my $val = shift; return $val || shift || 0 },
	income_accno_id		=> sub { my $val = shift; return $val || shift || 0 },
	weight		=> sub { my $val = shift; return $val || shift || 0 },
);


%value_indirect = (
	inventory_accno_id	=> 'select id from chart where accno = ?',
	expense_accno_id	=>  'select id from chart where accno = ?',
	income_accno_id		=>  'select id from chart where accno = ?',
);


sub parts_update {
	my ($self, $opt) = @_;
	my $cfg = $self->{Config};
	my $atab = $cfg->{link_table}
		or die errmsg("missing accounting link_table: %s", 'definition');
	my $adb = ::database_exists_ref($atab)
		or die errmsg("missing accounting link_table: %s", 'table');
	my $dbh = $adb->dbh()
		or die errmsg("missing accounting link_table: %s", 'handle');


	my %source  = %default_source;
	my %default = %default_value;
	for(@all_part_fields) {
		my $src = $cfg->{"parts_source_$_"};
		if(defined $src) {
			$source{$_} = $src;
		}
		my $def = $cfg->{"parts_default_$_"};
		if(defined $def) {
			$default{$_} = $def;
		}
	}
	my @fields = grep defined $source{$_} || defined $default{$_}, @all_part_fields;
	my $fstring = join ", ", @fields;

	my @ufields;
	if($cfg->{update_fields}) {
		@ufields = grep /\S/, split /[\s,\0]+/, $cfg->{update_fields};
	}
	else {
		@ufields = @update_part_fields;
	}

	my @vph;
	my @uph;

	push(@vph, '?') for @fields;
	for(@ufields) {
		push @uph, "$_ = ?";
	}

	my $partskey = $cfg->{parts_key} || 'sku';

	my %dbo;
	my %rowfunc;
	my %row;

	my $colsub = sub {
		my ($name) = @_;
		my $src = $source{$name};
		my $val;
		my ($st, $sc) = split /:/, ($src || '');
		if($sc and defined $row{$st}) {
			$val = defined $row{$st}{$sc} ? $row{$st}{$sc} : $default{$name};
		}
		else {
			$val = $default{$name};
		}

		$val = '' if ! defined $val;
		my $filt = $value_filter{$name} || '';
		my $indir = $value_indirect{$name} || '';
#::logDebug("$name='$val' filter=$filt indir=$indir");
		if($indir) {
			my $sth = $dbh->prepare($indir);
			$sth->execute($val);
			$val = ($sth->fetchrow_array)[0];
		}

		if($filt) {
			$val = $filt->($val, $default{$name});
		}
#::logDebug("$name='$val'");
		return $val;
	};

	for (values %source) {
		my ($t,$c) = split /:/, $_;
		if(! $t) {
			$rowfunc{""} ||= sub { return Vend::Data::product_row_hash(shift) };
		}
		else {
			my $d = $dbo{$t} ||= ::database_exists_ref($t);
			$rowfunc{$t} ||= sub { return $d->row_hash(shift) };
		}
	}

	my $qst = $dbh->prepare('select id from parts where partnumber = ?')
		or die errmsg("accounting statement handle: %s", 'part check');

	my $upq = $query{update};
	$upq =~ s/\$UPDATEFIELDS\$/join ", ", @uph/e;
#::logDebug("update query is: $upq");
	my $qup = $dbh->prepare($upq)
		or die errmsg("accounting statement prepare: %s", 'update query');

	my $inq = $query{insert};
	$inq =~ s/\$ALLFIELDS\$/join ", ", @fields/e;
	$inq =~ s/\$ALLVALUES\$/join ",", @vph/e;
#::logDebug("insert query is: $inq");
	my $qin = $dbh->prepare($inq)
		or die errmsg("accounting statement prepare: %s", 'update query');

	my @parts;

	my $source_tables = $cfg->{parts_tables} || 'products';

	if($opt->{skus}) {
		@parts = grep /\S/, split /[\s,\0]+/, $opt->{skus};
	}
	else {
		my @tabs = grep /\S/, split /[\s,\0]+/, $source_tables;
		for(@tabs) {
			 my $q = "select $partskey from $_";
			 my $db = ::database_exists_ref($_)
			 	or next;
			 my $ary = $db->query($q) || [];
			 for(@$ary) {
			 	push @parts, $_->[0];
			 }
		}
	}
	
	my $updated = 0;

	foreach my $p (@parts) {
#::logDebug("Doing part $p");
		%row = ();
		for(keys %rowfunc) {
			$row{$_} = $rowfunc{$_}->($p);
		}
		my $pid;
		if($qst->execute($p)) {
			$pid = ($qst->fetchrow_array)[0];
		}
		
		if($pid) {
			my @v;
			for(@ufields) {
				push @v, $colsub->($_);
			}
			push @v, $pid;
			$qup->execute(@v);
			$updated++;
		}
		else {
			my @v;
			for(@fields) {
				push @v, $colsub->($_); 
			}
			$qin->execute(@v);
			$updated++;
		}
	}

	return $updated;
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
