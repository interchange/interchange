#
# Vend::Accounting::SQL_Ledger
# $Id: SQL_Ledger.pm,v 1.13 2006-08-16 13:34:09 mheins Exp $
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
use utf8;

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
#::logDebug("Accounting self=" . uneval($self) );
	return $self;
}

sub myconfig {
	my $self = shift;
	return $self->{_myconfig} if $self->{_myconfig};

	my @keys = qw(
		acs address admin businessnumber charset company countrycode currency
		dateformat dbconnect dbdriver dbhost dbname dboptions dbpasswd dbport
		dbuser email fax name numberformat password printer shippingpoint sid
		signature stylesheet tel templates
	);

	my $cfg = $self->{Config};
	if($cfg->{myconfig_file}) {
	  no strict;
	  my $string =  readfile($cfg->{myconfig_file});
	  $string =~ s/.*%myconfig\s*=\s*\(/{/s;
	  $string =~ s/\);\s*$/}/s;
	  $self->{_myconfig} = Vend::Interpolate::tag_calc($string);
	  if(! $self->{_myconfig}) {
	  	die errmsg(
				"operation '%s' failed: %s",
				"myconfig_file $cfg->{myconfig_file}",
				$Vend::Session->{last_error},
				);
	  }
	}
	elsif ($cfg->{myconfig_string}) {
		$self->{_myconfig} = get_option_hash($cfg->{myconfig_string});
	}
	else {
		my $confhash = {};
		for (@keys) {
			$confhash->{$_} = $cfg->{$_};
		}
		$self->{_myconfig} = $confhash;
	}
	return $self->{_myconfig};
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

sub save_transactions_list {
	my ($self, $opt) = @_;
	use vars qw($Tag);

	my $ary = $opt->{transaction_array};

	if(! $ary) {
		my $tab = $opt->{transactions_table} || 'transactions';
		my $db = ::database_exists_ref($tab)
			or die errmsg("bad %s table '%s'", 'transactions', $tab);
		my $q = $opt->{sql} || "select * from $tab";
		$ary = $db->query( { sql => $q, hashref => 1 } );
	}

	die errmsg("No transactions array sent!")
		unless ref($ary) eq 'ARRAY';

	my $prof = $self->{userdb_profile} || 'default';
	my $ucfg = $Vend::Cfg->{UserDB_repository}{$prof} || {};
	
	my $tab = $opt->{orderline_table} || 'orderline';
	my $db = ::database_exists_ref($tab)
		or die errmsg("bad %s table '%s'", 'orderline', $tab);

	my $count;
	for(@$ary) {
		my $rec = $_;
		my $id = $rec->{username};
		$id =~ s/\s+$//;
		if($id !~ /^\d+$/) {
			$id = $Tag->counter( { sql => $ucfg->{sql_counter} || 'customer::id'});
			my $msg = errmsg(
				"assigned arbitrary customer number %s to user %s",
				$id,
				$rec->{username},
			);
			logError($msg);
#::logDebug($msg);
		}
#::logDebug("passing rec=" . uneval($rec));
		$self->save_customer_data($id, $rec);
		my $on = $rec->{order_number};
		my $query = "select * from $tab where order_number = '$on'";
		my $oary = $db->query( { sql => $query, hashref => 1 } );
		my @cart;
		foreach my $item (@$oary) {
			my $price = $item->{price};
			my $quan = $item->{quantity}
				or next;
			next if $quan <= 0;
			if ($item->{subtotal} <= 0) {
				$item->{subtotal} = $quan * $price;
			}

			my $psubt = round_to_frac_digits($quan * $price);
			my $asubt = round_to_frac_digits($item->{subtotal});
			if($asubt != $psubt) {
				$price = $item->{subtotal} / $quan;
			}
			my $ip = $item->{code};
			$ip =~ s/.*-//;
			$ip--;
			push @cart, {
				code => $item->{sku},
				quantity => $quan,
				description => $item->{description},
				mv_price => $price,
				mv_ip => $ip,
			};
		}

		my $obj = new Vend::Accounting::SQL_Ledger;
		my $notes = $rec->{gift_note};
		$notes = $notes ? "$notes\n" : "";
		$notes .= 'Added automatically by IC';
		my $o = {
				order_number => $on,
				cart => \@cart,
				order_date => $rec->{order_date},
				notes => $rec->{gift_note},
				salestax => $rec->{salestax} || 0,
				shipping => $rec->{shipping} || 0,
				handling => $rec->{handling} || 0,
				total_cost => $rec->{total_cost} || 0,
			};
#::logDebug("Getting ready to create order entry: " . uneval($o));
		$obj->create_order_entry($o);
		$count++;
	}
	return $count;
}

sub save_customer_data {
    my ($self, $userid, $hashdata) = @_;

    my $result;
	my $record = $self->map_data('customer', $hashdata);

	$userid =~ s/\D+//g;
    $record->{id} = $userid;

	my $tab = $self->{Config}{customer_table} || 'customer';

	my $db = ::database_exists_ref($tab)
		or die errmsg("Customer table database '%s' inaccessible.", $tab);
	my $status = $db->set_slice($userid, $record);
	return $status;
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
	use vars qw($Tag);

    my $self = shift;
    my $opt = shift;

	my $cfg = $self->{Config} || {};

	my $cart = delete $opt->{cart};
	my $no_levies;

	## Allow a cart name, a cart reference, or default to current cart
	if($cart and ! ref($cart)) {
		$cart = $Vend::Session->{carts}{$cart};
	}
	elsif($cart
			and defined $opt->{salestax} 
			and defined $opt->{shipping} 
			and defined $opt->{handling} 
			)
	{
		## Must be passed order batch
		$no_levies = 1;
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
#::logDebug("Levies=" . uneval($Vend::Cfg->{Levies}));
	if($Vend::Cfg->{Levies}) {
		$Tag->levies(1);
		my $lcart = $::Levies;
#::logDebug("levy cart=" . uneval($lcart));
		for my $levy (@$lcart) {
			my $pid = $levy->{part_number};
			$pid ||= uc($levy->{group} || $levy->{type});
			my $lresult = {
						code => $pid,
						description => $levy->{description},
						mv_price => $levy->{cost},
			};
#::logDebug("levy result=" . uneval($lresult));
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
					}
			if $salestax  > 0 || $cfg->{add_zero_salestax};

	if($::Values->{mv_handling}) {
		my @handling = split /\0+/, $::Values->{mv_handling};
			my $part	= $opt->{handling_part}
					|| $cfg->{handling_part}
					|| 'HANDLING';
		for (@handling) {
			my $desc = $Tag->shipping_desc($_);
			my $cost = $Tag->shipping( { mode => $_, noformat => 1 });
				next unless $cost > 0 || $cfg->{add_zero_handling};
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
					}
			if $shipping > 0 || $cfg->{add_zero_shipping};
	}

	my @oe;

	my $olq = q{
				INSERT INTO orderitems 
					   (trans_id, parts_id, description, qty, sellprice, discount)
						VALUES (?, ?, ?, ?, ?, ?)
				};
	
	my $ol_sth = $dbh->prepare($olq)
		or die errmsg("Prepare '%s' failed.", $olq, $tab);

=head2 parts table

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

=cut

	my $plq = q{SELECT	id,
						partnumber,
						description,
						bin,
						unit,
						listprice,
						assembly,
						inventory_accno_id,
						income_accno_id,
						expense_accno_id
				FROM parts
				WHERE id = ?};
	
	my $pl_sth = $dbh->prepare($plq)
		or die errmsg("Prepare '%s' failed.", $plq, 'parts');

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
#::logDebug("doing item $c->{code}");
		$sth->execute($c->{code})
			or die errmsg("Statement '%s' failed.", $cq);
		my ($pid) = $sth->fetchrow_array;
		push @items, [$pid, $c->{description}, 1, $c->{mv_price}, 0]; 
	}

	my ($tid) = $Tag->counter({ sql => "$tab:id" });

	my $res = {}; # Repository for result array

	my @t = localtime();
	$res->{invdate} = $opt->{order_date} || POSIX::strftime('%Y-%m-%d', @t);
	$res->{duedate} = $opt->{req_date}   || POSIX::strftime('%Y-%m-%d', @t);

=head2 oe table

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

=cut

	my $tq = q{
		INSERT INTO oe VALUES (
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?,
			?)
		};

	$opt->{total_cost} ||= $Tag->total_cost({ noformat => 1 });

	my $tsth = $dbh->prepare($tq)
		or die errmsg("Statement '%s' failed.", $tq);

	$opt->{customer_id} ||= $Vend::Session->{username};
	$opt->{customer_id} =~ s/\D+//g;

	$res->{orderid}		= $tid;
	$res->{ordnumber}	= $opt->{order_number} ||= $::Values->{mv_order_number},
	$res->{vendor_id} = 0; # This is not a PO
	$res->{customer_id} = $opt->{customer_id};
	$res->{taxincluded} = $opt->{taxincluded} ? 't' : 'f',
	$res->{shippingpoint} = $opt->{shippingpoint};
	$res->{notes}    	= $opt->{notes} || $::Values->{gift_note},
	$res->{currency}    = $opt->{currency_code} || $cfg->{currency_code} || 'USD';

	my @vals = (
				$res->{orderid},
				$res->{ordnumber},
				$res->{invdate},
				$res->{vendor_id},
				$res->{customer_id},
				$opt->{total_cost},
				$opt->{netamount} || $opt->{total_cost},
				$res->{duedate},
				$res->{taxincluded} ? 't' : 'f',
				$res->{shippingpoint} || '',
				$res->{notes},
				$res->{currency},
				);
	
#::logDebug("ready to execute tquery=$tq with values=" . uneval(\@vals));
	$tsth->execute(@vals) 
		or die errmsg("Statement '%s' failed.", $tq);

	my $idx = 1;
	my $acq = qq{SELECT accno from chart where id = ?};
	my $asth = $dbh->prepare($acq)
		or die errmsg("Prepare '%s' failed.", $acq);

	for my $line (@items) {
		$ol_sth->execute($tid, @$line);
		my ($newpid, $desc, $qty, $price, $discount) = @$line;

		$pl_sth->execute($newpid);
		my $href = $pl_sth->fetchrow_hashref()
			or die errmsg("Failed to retrieve part: %s", $DBI::errstr);
		for(qw/ assembly bin description listprice partnumber unit /) {
			$res->{$_ . "_$idx"} = defined $href->{$_} ? $href->{$_} : '';
		}
		for(qw/ expense_accno inventory_accno income_accno /) {
			my $id = $href->{$_ . "_id"} || 0;
			my $acc;
			if($id > 0) {
				$asth->execute($id);
				my $ary;
				$ary = $asth->fetchrow_arrayref
					and $acc = $ary->[0];
			}
			$res->{$_ . "_$idx"} = $acc || 0;
		}

		## Shows order: push @items, [$newpid, $desc, $qty, $price, $discount];
		$res->{"id_$idx"} = $newpid;
		$res->{"sellprice_$idx"} = $price;
		$res->{"qty_$idx"} = $qty;
		$res->{"discount_$idx"} = $discount;

		$idx++;
	}
		
	$res->{rowcount} = $idx;
#::logDebug("past accounting, ready to return res=" . uneval($res));

	if($opt->{do_payment}) {
		$res->{paid_1} = $opt->{total_cost};
	}

	if($opt->{do_invoice}) {
		$res = $self->post_invoice($res);
	}

    return $res;
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
	my $datastuff = uneval(\@_);
    return $string;
}

sub post_invoice {

	my ($self, $opt) = @_;

	my $form = Form->new($opt);
	my $myconfig = $self->myconfig();
	my $cfg = $self->{Config};

#::logDebug("have myconfig=" . uneval($myconfig));
	$form->{AR}				||= $cfg->{default_ar}			|| 1200;
	$form->{AR_paid}		||= $cfg->{default_ar_paid}		|| 1060;
	$form->{fxgain_accno}	||= $cfg->{default_fxgain_accno}|| 4450;
	$form->{fxloss_accno}	||= $cfg->{default_fxloss_accno}|| 5810;
	$form->{invnumber}  	||= $Tag->counter( {
								sql => $cfg->{inv_counter} || $cfg->{counter},
							});

	if($form->{paid_1} > 0) {
		$form->{paidaccounts} = 1;
		$form->{AR_paid_1}  = $form->{AR_paid};
		$form->{datepaid_1} = $form->{invdate};
	}
	else {
		$form->{paid_1} = 0;
		$form->{paid} = 0;
	}

	IS->customer_details($myconfig, $form);

	foreach my $key (qw(name addr1 addr2 addr3 addr4)) {
	  unless ($form->{"shipto$key"}) {
		$form->{"shipto$key"} = defined $form->{$key} ? $form->{$key} : '';
	  }
	  $form->{"shipto$key"} =~ s/"/&quot;/g;
	}

#::logDebug("customer details back, form set up=" . uneval($form));
	my $status = IS->post_invoice($myconfig, $form);
#::logDebug("post_status=$status, form now=" . uneval($form));
	return $form;
}

package Form;

use DBI;
use Vend::Util;

no strict 'subs';

sub new {
    my $type = shift;
    my $opt = shift;
    
    my $self = {};

    if(! ref($opt) eq 'HASH') {
    	$opt = { $opt, @_ };
    }

    while (my ($k, $v) = each %$opt) {
		$self->{$k} = $v;
	}

    $self->{action} = lc $self->{action};
    $self->{action} =~ s/( |-|,)/_/g;

	$self->{version} = $Vend::Accounting::SQL_Ledger::VERSION;

	bless $self, $type;
}


sub debug {
  my $self = shift;
  
  foreach my $key (sort keys %{$self}) {
    logDebug("$key = $self->{$key}\n");
  }
} 

  
sub escape {
  shift;
  return hexify(shift);
}


sub unescape {
  shift;
  return unhexify(shift);
}

sub error {
    my ($self, $msg) = @_;

    $msg = errmsg($msg, @_);

    if ($self->{error_function}) {
        $self->{error_function}->($msg);
    }
	else {
        die errmsg("SQL-Ledger error: %s\n", $msg);
    }
}


sub dberror {
  my ($self, $msg) = @_;

  $self->error("$msg\n".$DBI::errstr);
  
}


sub isblank {
  my ($self, $name, $msg) = @_;

  if ($self->{$name} =~ /^\s*$/) {
    $self->error($msg);
  }
}
  

sub header {
  return;
}


sub redirect {
}


sub isposted {
  my ($self, $rc) = @_;

  if ($rc) {
    $self->redirect;
  }

  $rc;
  
}


sub isdeleted {
  my ($self, $rc) = @_;

  if ($rc) {
    $self->redirect;
  }

  $rc;
  
}


sub sort_columns {
  my ($self, @columns) = @_;

  @columns = grep !/^$self->{sort}$/, @columns;
  splice @columns, 0, 0, $self->{sort};

  @columns;
  
}


sub format_amount {
  my ($self, $myconfig, $amount, $places, $dash) = @_;

  if (defined $places) {
    $amount = $self->round_amount($amount, $places) if ($places >= 0);
  }

  # is the amount negative
  my $negative = ($amount < 0);
  
  if ($amount != 0) {
    if ($myconfig->{numberformat} && ($myconfig->{numberformat} ne '1000.00')) {
      my ($whole, $dec) = split /\./, "$amount";
      $whole =~ s/-//;
      $amount = join '', reverse split m{}, $whole;
      
      if ($myconfig->{numberformat} eq '1,000.00') {
	$amount =~ s/\d{3,}?/$&,/g;
	$amount =~ s/,$//;
	$amount = join '', reverse split m{}, $amount;
	$amount .= "\.$dec" if $dec;
      }
      
      if ($myconfig->{numberformat} eq '1.000,00') {
	$amount =~ s/\d{3,}?/$&./g;
	$amount =~ s/\.$//;
	$amount = join '', reverse split m{}, $amount;
	$amount .= ",$dec" if $dec;
      }
      
      if ($myconfig->{numberformat} eq '1000,00') {
	$amount = "$whole";
	$amount .= ",$dec" if $dec;
      }

      if ($dash =~ /-/) {
	$amount = ($negative) ? "($amount)" : "$amount";
      } elsif ($dash =~ /DRCR/) {
	$amount = ($negative) ? "$amount DR" : "$amount CR";
      } else {
	$amount = ($negative) ? "-$amount" : "$amount";
      }
    }
  } else {
    $amount = ($dash) ? "$dash" : "";
  }

  $amount;

}


sub parse_amount {
  my ($self, $myconfig, $amount) = @_;

  $amount = 0 if ! defined $amount;

  if (($myconfig->{numberformat} eq '1.000,00') ||
      ($myconfig->{numberformat} eq '1000,00')) {
    $amount =~ s/\.//g;
    $amount =~ s/,/\./;
  }

  $amount =~ s/,//g;
  
  return ($amount * 1);

}


sub round_amount {
  my ($self, $amount, $places) = @_;

  # compensate for perl bug, add 1/10^$places+2
  sprintf("%.${places}f", $amount + (1 / (10 ** ($places + 2))) * (($amount > 0) ? 1 : -1));

}


sub parse_template {
	return 1;
}


sub format_string {
  my ($self, @fields) = @_;

  my $format = $self->{format};
  if ($self->{format} =~ /(postscript|pdf)/) {
    $format = 'tex';
  }
  
  # order matters!!!
  my %umlaute = ( 'order' => { 'html' => [ '&', '<', '>', quotemeta('\n'), '',
                                           'ä', 'ö', 'ü',
					   'Ä', 'Ö', 'Ü',
					   'ß' ],
                               'tex'  => [ '&', quotemeta('\n'), '',
			                   'ä', 'ö', 'ü',
					   'Ä', 'Ö', 'Ü',
					   'ß', '\$', '%' ] },
                  'html' => {
                '&' => '&amp;', '<' => '&lt;', '>' => '&gt;', quotemeta('\n') => '<br>', '' => '<br>',
                'ä' => '&auml;', 'ö' => '&ouml;', 'ü' => '&uuml;',
	        'Ä' => '&Auml;', 'Ö' => '&Ouml;', 'Ü' => '&Uuml;',
	        'ß' => '&szlig;',
	        '\x84' => '&auml;', '\x94' => '&ouml;', '\x81' => '&uuml;',
	        '\x8e' => '&Auml;', '\x99' => '&Ouml;', '\x9a' => '&Uuml;',
	        '\xe1' => '&szlig;'
		            },
	          'tex' => {
	        'ä' => '\"a', 'ö' => '\"o', 'ü' => '\"u',
	        'Ä' => '\"A', 'Ö' => '\"O', 'Ü' => '\"U',
	        'ß' => '{\ss}',
	        '\x84' => '\"a', '\x94' => '\"o', '\x81' => '\"u',
	        '\x8e' => '\"A', '\x99' => '\"O', '\x9a' => '\"U',
	        '\xe1' => '{\ss}',
	        '&' => '\&', '\$' => '\$', '%' => '\%',
		quotemeta('\n') => '\newline ', '' => '\newline '
                        }
	        );

  foreach my $key (@{ $umlaute{order}{$format} }) {
    map { $self->{$_} =~ s/$key/$umlaute{$format}{$key}/g; } @fields;
  }

}

# Database routines used throughout

sub dbconnect {
  my ($self, $myconfig) = @_;

  # connect to database
  my $dbh = DBI->connect($myconfig->{dbconnect}, $myconfig->{dbuser}, $myconfig->{dbpasswd}) or $self->dberror;

  $dbh->trace($Global::DataTrace, $Global::DebugFile)
	if $Global::DataTrace and $Global::DebugFile;

  # set db options
  if ($myconfig->{dboptions}) {
    $dbh->do($myconfig->{dboptions}) || $self->dberror($myconfig->{dboptions});
  }

  $dbh;

}


sub dbconnect_noauto {
  my ($self, $myconfig) = @_;

  # connect to database
  my $dbh = DBI->connect($myconfig->{dbconnect}, $myconfig->{dbuser}, $myconfig->{dbpasswd}, {AutoCommit => 0}) or $self->dberror;

  $dbh->trace($Global::DataTrace, $Global::DebugFile)
	if $Global::DataTrace and $Global::DebugFile;

  # set db options
  if ($myconfig->{dboptions}) {
    $dbh->do($myconfig->{dboptions}) || $self->dberror($myconfig->{dboptions});
  }

  $dbh;

}


sub update_balance {
  my ($self, $dbh, $table, $field, $where, $value) = @_;

  # if we have a value, go do it
  if ($value != 0) {
    # retrieve balance from table
    my $query = "SELECT $field FROM $table WHERE $where";
    my $sth = $dbh->prepare($query);

    $sth->execute || $self->dberror($query);
    my ($balance) = $sth->fetchrow_array;
    $sth->finish;

    $balance += $value;
    # update balance
    $query = "UPDATE $table SET $field = $balance WHERE $where";
    $dbh->do($query) || $self->dberror($query);
  }
}



sub update_exchangerate {
  my ($self, $dbh, $curr, $transdate, $buy, $sell) = @_;

  # some sanity check for currency
  return if ($curr eq '');

  my $query = qq|SELECT curr FROM exchangerate
                 WHERE curr = '$curr'
	         AND transdate = '$transdate'|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);
  
  my $set;
  if ($buy != 0 && $sell != 0) {
    $set = "buy = $buy, sell = $sell";
  } elsif ($buy != 0) {
    $set = "buy = $buy";
  } elsif ($sell != 0) {
    $set = "sell = $sell";
  }
  
  if ($sth->fetchrow_array) {
    $query = qq|UPDATE exchangerate
                SET $set
		WHERE curr = '$curr'
		AND transdate = '$transdate'|;
  } else {
    $query = qq|INSERT INTO exchangerate (curr, buy, sell, transdate)
                VALUES ('$curr', $buy, $sell, '$transdate')|;
  }
  $sth->finish;
  $dbh->do($query) || $self->dberror($query);
  
}


sub get_exchangerate {
  my ($self, $dbh, $curr, $transdate, $fld) = @_;
  
  my $query = qq|SELECT $fld FROM exchangerate
                 WHERE curr = '$curr'
		 AND transdate = '$transdate'|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  my ($exchangerate) = $sth->fetchrow_array;
  $sth->finish;

  ($exchangerate) ? $exchangerate : 1;

}


# the selection sub is used in the AR, AP and IS module
#
sub all_vc {
  my ($self, $myconfig, $table) = @_;

  # create array for vendor or customer
  my $dbh = $self->dbconnect($myconfig);

  my $query;
  my $sth;
  
  unless ($self->{"${table}_id"}) {
    my $arap = ($table eq 'customer') ? "ar" : "ap";
    $arap = 'oe' if ($self->{type} =~ /_order/);

    $query = qq|SELECT ${table}_id FROM $arap
                WHERE oid = (SELECT max(oid) FROM $arap
		             WHERE ${table}_id > 0)|;
    $sth = $dbh->prepare($query);
    $sth->execute || $self->dberror($query);

    unless (($self->{"${table}_id"}) = $sth->fetchrow_array) {
      $self->{"${table}_id"} = 0;
    }
    $sth->finish;
  }
  
  $query = qq|SELECT id, name
              FROM $table
	      ORDER BY name|;
  $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  my $ref = $sth->fetchrow_hashref(NAME_lc);
  push @{ $self->{"all_$table"} }, $ref;

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    push @{ $self->{"all_$table"} }, $ref;
  }

  $sth->finish;
  $dbh->disconnect;

}


sub create_links {
  my ($self, $module, $myconfig, $table) = @_;

  # get all the customers or vendors
  &all_vc($self, $myconfig, $table);

  my %xkeyref = ();
  
  my $dbh = $self->dbconnect($myconfig);
  # now get the account numbers
  my $query = qq|SELECT accno, description, link
                 FROM chart
		 WHERE link LIKE '%$module%'
		 ORDER BY accno|;
  my $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
    
    foreach my $key (split(/:/, $ref->{link})) {
      if ($key =~ /$module/) {
	# cross reference for keys
	$xkeyref{$ref->{accno}} = $key;
	
	push @{ $self->{"${module}_links"}{$key} }, { accno => $ref->{accno},
                                       description => $ref->{description} };
      }
    }
  }
  $sth->finish;
  
 
  if ($self->{id}) {
    my $arap = ($table eq 'customer') ? 'ar' : 'ap';
    
    $query = qq|SELECT invnumber, transdate, ${table}_id, datepaid, duedate,
		ordnumber, taxincluded, curr AS currency
		FROM $arap
		WHERE id = $self->{id}|;
    $sth = $dbh->prepare($query);
    $sth->execute || $self->dberror($query);
    
    my $ref = $sth->fetchrow_hashref(NAME_lc);
    foreach my $key (keys %$ref) {
      $self->{$key} = $ref->{$key};
    }
    $sth->finish;

    # get amounts from individual entries
    $query = qq|SELECT accno, description, source, amount, transdate, cleared
		FROM acc_trans, chart
		WHERE chart.id = acc_trans.chart_id
		AND trans_id = $self->{id}
		AND fx_transaction = '0'
		ORDER BY transdate|;
    $sth = $dbh->prepare($query);
    $sth->execute || $self->dberror($query);


    my $fld = ($module eq 'AR') ? 'buy' : 'sell';
    # get exchangerate for currency
    $self->{exchangerate} = $self->get_exchangerate($dbh, $self->{currency}, $self->{transdate}, $fld);
    
    # store amounts in {acc_trans}{$key} for multiple accounts
    while (my $ref = $sth->fetchrow_hashref(NAME_lc)) {
      $ref->{exchangerate} = $self->get_exchangerate($dbh, $self->{currency}, $ref->{transdate}, $fld);

      push @{ $self->{acc_trans}{$xkeyref{$ref->{accno}}} }, $ref;
    }

    $sth->finish;

    $query = qq|SELECT d.curr AS currencies,
                  (SELECT c.accno FROM chart c
		   WHERE d.fxgain_accno_id = c.id) AS fxgain_accno,
                  (SELECT c.accno FROM chart c
		   WHERE d.fxloss_accno_id = c.id) AS fxloss_accno
		FROM defaults d|;
    $sth = $dbh->prepare($query);
    $sth->execute || $self->dberror($query);

    $ref = $sth->fetchrow_hashref(NAME_lc);
    map { $self->{$_} = $ref->{$_} } keys %$ref;
    $sth->finish;

  } else {
    # get date
    $query = qq|SELECT current_date AS transdate, current_date + 30 AS duedate,
                d.curr AS currencies,
                  (SELECT c.accno FROM chart c
		   WHERE d.fxgain_accno_id = c.id) AS fxgain_accno,
                  (SELECT c.accno FROM chart c
		   WHERE d.fxloss_accno_id = c.id) AS fxloss_accno
		FROM defaults d|;
    $sth = $dbh->prepare($query);
    $sth->execute || $self->dberror($query);

    my $ref = $sth->fetchrow_hashref(NAME_lc);
    map { $self->{$_} = $ref->{$_} } keys %$ref;
    $sth->finish;
  }

  $dbh->disconnect;

}


sub current_date {
  my ($self, $myconfig, $thisdate, $days) = @_;
  
  my $dbh = $self->dbconnect($myconfig);
  my $query = qq|SELECT current_date AS thisdate
                 FROM defaults|;

  $days *= 1;
  if ($thisdate) {
    $query = qq|SELECT date '$thisdate' + $days AS thisdate
                FROM defaults|;
  }
  
  my $sth = $dbh->prepare($query);
  $sth->execute || $self->dberror($query);

  ($thisdate) = $sth->fetchrow_array;
  $sth->finish;

  $dbh->disconnect;

  $thisdate;

}


sub like {
  my ($self, $string) = @_;
  
  unless ($string =~ /%/) {
    $string = "%$string%";
  }

  $string;
  
}


package Locale;


sub new {
  my ($type, $country, $NLS_file) = @_;
  my $self = {};

  if ($country && -d "locale/$country") {
    $self->{countrycode} = $country;
    eval { require "locale/$country/$NLS_file"; };
  }

  $self->{NLS_file} = $NLS_file;
  
  push @{ $self->{LONG_MONTH} }, ("January", "February", "March", "April", "May ", "June", "July", "August", "September", "October", "November", "December");
  push @{ $self->{SHORT_MONTH} }, (qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec));
  
  bless $self, $type;

}


sub text {
  my ($self, $text) = @_;
  
  return (exists $self->{texts}{$text}) ? $self->{texts}{$text} : $text;
  
}


sub findsub {
  my ($self, $text) = @_;

  if (exists $self->{subs}{$text}) {
    $text = $self->{subs}{$text};
  } else {
    if ($self->{countrycode} && $self->{NLS_file}) {
      Form->error("$text not defined in locale/$self->{countrycode}/$self->{NLS_file}");
    }
  }

  $text;

}


sub date {
  my ($self, $myconfig, $date, $longformat) = @_;

  my $longdate = "";
  my $longmonth = ($longformat) ? 'LONG_MONTH' : 'SHORT_MONTH';

  my $spc;
  if ($date) {
    # get separator
    $spc = $myconfig->{dateformat};
    $spc =~ s/\w//g;
    $spc = substr($spc, 1, 1);

    if ($spc eq '.') {
      $spc = '\.';
    }
    if ($spc eq '/') {
      $spc = '\/';
    }

	my ($yy, $mm, $dd);
    if ($myconfig->{dateformat} =~ /^yy/) {
      ($yy, $mm, $dd) = split /$spc/, $date;
    }
    if ($myconfig->{dateformat} =~ /^mm/) {
      ($mm, $dd, $yy) = split /$spc/, $date;
    }
    if ($myconfig->{dateformat} =~ /^dd/) {
      ($dd, $mm, $yy) = split /$spc/, $date;
    }
    
    $dd *= 1;
    $mm--;
    $yy = ($yy < 70) ? $yy + 2000 : $yy;
    $yy = ($yy >= 70 && $yy <= 99) ? $yy + 1900 : $yy;

    if ($myconfig->{dateformat} =~ /^dd/) {
      $longdate = "$dd. ".&text($self, $self->{$longmonth}[$mm])." $yy";
    } else {
      $longdate = &text($self, $self->{$longmonth}[$mm])." $dd, $yy";
    }

  }

  $longdate;

}

1;

=head1 NAME

Vend::Accounting::SQL-Ledger - SQL-Ledger Accounting Interface for Interchange

=head1 DESCRIPTION

This module is an attempt to create a set of callable routines 
that will allow the easy integration of the SQL-Ledger Accounting 
package with Interchange. 

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

=head1 Schema

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

=cut
