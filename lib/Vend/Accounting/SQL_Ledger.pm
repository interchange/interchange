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
use HTML::TokeParser;
use Vend::Util;
use Vend::Accounting;

use vars qw/$VERSION @ISA/;
@ISA = qw/ Vend::Accounting /;

# HARD-CODED GLOBALS.
# >>>>> Here are some globals that you might want to adjust <<<<<<

    # The current SQL-Ledger install directory
    our $SL_DIR = '/usr/local/sql-ledger/'; 

    # The SQL-Ledger path to use for transactions
    #our $SL_PATH = Vend::Util::escape_chars_url('bin/mozilla'); 
    our $SL_PATH = 'bin/mozilla'; 

    # The SQL-Ledger user-id to use for transactions
    our $SL_USER = 'mike'; 

    # The SQL-Ledger password to use for transactions
    our $SL_PASS = 'flange'; 

    # The SQL-Ledger service item name to use for transactions
    our $SL_ITEM_NAME = 'test-service'; 

    # The SQL-Ledger service item id to use for transactions
    our $SL_ITEM_ID = '10073'; 

sub new {
    my $class = shift;
	my $opt = shift;

	if(ref($opt) ne 'HASH') {
		my $tmp = $opt;
		$opt = { $tmp, @_ };
	}

	my $self = new Vend::Accounting;

	$self->{Config} = {};
	while (my ($k, $v) = each %{$Vend::Cfg->{Accounting}}) {
		$self->{Config}{$k} = $v;
	}
	while (my ($k, $v) = each %$opt) {
		$self->{Config}{$k} = $v;
	}

    bless $self, $class;
#::logDebug("Accounting self=" . ::uneval($self) );
	return $self;
}

# ------------------ START OF THE LIBRARY ------------

sub push_parms {
	my($k, $v, $ary) = @_;
	if( ref($v) eq 'ARRAY') {
		my $ary = $v;
		for(@$ary) {
			push @$ary, "$k=" . Vend::Util::escape_chars_url($_);
		}
		return;
	}
	$v = Vend::Util::escape_chars_url($v);
	push @$ary, "$k=$v";
	return;
}

sub split_name_value_pairs {

    my $htmlstring = shift;
    my $obj = HTML::TokeParser->new(doc => "$htmlstring");
    my ($token, $urlstring, $pair, @pairs, $name, $value, $data, %data);

    while ($token = $obj->get_tag("a")) {

        $urlstring = $token->[1]{href};

	#Split the name-value pairs
	@pairs = split(/&/, $urlstring);

	#Loop through each pair
		foreach $pair (@pairs) {

			#Create a Name/Value pair set
			($name, $value) = split(/=/, $pair);

			#Assign the value to an associative array using the name as its hash
			$data{$name} = Vend::Util::unescape_full($value);
		}
    }
    return %data;
}

sub call_sl_script {
	my ($sname, $opt) = @_;
	my $dir = $Vend::Cfg->{SQL_Ledger}{dir} || $SL_DIR;
	$dir =~ s:/+$::;
	my $cmd = "$dir/$sname";
	local($ENV{PERL5LIB});
	$ENV{PERL5LIB} = $dir;
#	if($opt->{path} !~ m:^/:) {
#		$opt->{path} = "$dir/$opt->{path}";
#	}
	if(! -f $cmd) {
		logError(
			"SQL-Ledger script '%s' does not exist in SL_DIR '%s'",
			$sname,
			$dir,
			);
		return undef;
	}

	# Build the option string. Keys beginning with sl_* override other
	# passed parameters, meaning that even if the function parameter
	# is needed in a standard opt string a 'function' parameter can
	# be passed with sl_function=something.

	my @parms;
	my @override;

	for my $k (keys %$opt) {
		if($k =~ /^sl_/) {
			push @override, $_;
			next;
		}

		my $v = $opt->{$k};
		push_parms($k, $v, \@parms);
	}

	for my $k (@override) {
		my $v = $opt->{$k};
		push_parms($k, $v, \@parms);
	}

	my $arg = join "&", @parms;
	logDebug("calling $cmd with arg=$arg");
	my $result = `$cmd "$arg"`;
	chomp($result);
	if($? != 0) {
		my $err = $? >> 8;
		logError(
			"SQL-Ledger error status '%s' returned on call to '%s': %s",
			$err,
			$sname,
			$!,
		);
	}
	return $result;
}

sub hash_line_params {
	my $body = shift
		or return undef;
	my $o;
	if($body =~ /=/) {
		$o = {};
		$body =~ s/^\s+//;
		$body =~ s/\s+$//;
		$body =~ s/^\s+//mg;
		$body =~ s/\s+$//mg;
		my @in = grep /=/, split /\n/, $body;
		for(@in) {
			my ($k, $v) = split /\s*=\s*/, $_;

			if($o->{$k}) {
				my $val = delete $o->{$k};
				if ( ref($val) eq 'ARRAY' ) {
					push @$val, $v;
				}
				else {
					$val = [ $val ];
				}
				$v = $val;
			}

			$o->{$k} = $v;
		}
	}
	return $o;
}

sub assign_customer_number {

    my ($self, $opt) = @_;
    my $result;

	my $call = {
		path		=> $self->{Config}{path} || $SL_PATH,
		login		=> $self->{Config}{login} || $SL_USER,
		password	=> $self->{Config}{password} || $SL_PASS,
	};

    $call->{action} = "Save Customer";
    $call->{db}			= "customer";
    $call->{name}		= $opt->{username} || $::Values->{email};
    $call->{contact}	= $opt->{email} || $::Values->{email};
    $call->{email}		= $opt->{email} || $::Values->{email};

	call_sl_script('ct.pl', $call);

    $call->{action} = "Search for Customer";
    $call->{l_contact} = "Y";
    $call->{l_name} = "Y";

    $result = call_sl_script('ct.pl', $call);
	logDebug("call_sl_script result was: $result");

    my %data = split_name_value_pairs($result);

	my $datastuff = ::uneval(\@_);
	logDebug("This is a assign_customer_number test(result '$data{id}') ... $datastuff");

    return $data{id};
}

sub save_customer_data {

    my ($self, $userid, $hashdata) = @_;

	my $datastuff = uneval(\$self);
#::logDebug( "This is a save_customer_data self... $datastuff");
	$datastuff = uneval($hashdata);
#::logDebug("This is a save_customer_data fnv... $datastuff");
	$datastuff = uneval(\$userid);
#::logDebug("This is a save_customer_data userid .. $datastuff");
	`echo "This is a save_customer_data userid... $datastuff" >> testlog.txt`;

    my $result;

    my %fnv = %$hashdata;
    my $name;

	my $call = {
		path		=> $self->{Config}{path} || $SL_PATH,
		login		=> $self->{Config}{login} || $SL_USER,
		password	=> $self->{Config}{password} || $SL_PASS,
	};


    $call->{action} = "Save Customer";
    $call->{db} = "customer";
    $call->{id} = $userid;
    $call->{name} = $fnv{company} || "$fnv{lname}, $fnv{fname}";
    $call->{addr1} = $fnv{b_address1} || $fnv{address1};
    $call->{addr2} = $fnv{b_address2} || $fnv{address2};
    $call->{addr3} = $fnv{b_address3} || $fnv{address3};
    if($fnv{b_city}) {
		$call->{addr4} = "$fnv{b_city}, $fnv{b_state} $fnv{b_zip} $fnv{b_country}";
	}
	else {
		$call->{addr4} = "$fnv{city}, $fnv{state} $fnv{zip} $fnv{country}";
	}
    if($fnv{b_lname}) {
		$call->{contact} = "$fnv{b_lname}, $fnv{b_fname}";
	}
	else {
		$call->{contact} = "$fnv{lname}, $fnv{fname}";
	}
    $call->{phone} = $fnv{phone_night} || $fnv{phone_day};
    $call->{fax} = $fnv{fax};
    $call->{email} = $fnv{email};
    $call->{shiptoname} = $fnv{company} || "$fnv{lname}, $fnv{fname}";
    $call->{shiptoaddr1} = $fnv{address1};
    $call->{shiptoaddr2} = $fnv{address2};
    $call->{shiptoaddr3} = $fnv{address3};
    $call->{shiptoaddr4} = "$fnv{city} $fnv{state} $fnv{zip} $fnv{country}";
    $call->{shiptocontact} = "$fnv{lname}, $fnv{fname}";
    $call->{shiptophone} = $fnv{phone_day};
    $call->{shiptofax} = $fnv{fax};
    $call->{shiptoemail} = $fnv{email};
    $call->{creditlimit} = $fnv{credit_limit};

    $result = call_sl_script('ct.pl', $call);

    return 1;
}

sub create_vendor_purchase_order {
    my ($self, $string) = @_;
    return $string;
}


sub create_order_entry {

    my $self = shift;
    my $order = shift;

	unless(ref $order) {
		my $ary = { $order, @_ };
		$order = $ary;
	}

    my $result;

    my $lineitem;
    
	my $call = {
		path		=> $self->{Config}{path} || $SL_PATH,
		login		=> $self->{Config}{login} || $SL_USER,
		password	=> $self->{Config}{password} || $SL_PASS,
	};


    $call->{action} = "Save Order";
    $call->{type} = "sales_order";

    $call->{new_form} = "1";
    $call->{vc} = "customer";
    $call->{title} = "Add Sales Order";

    $call->{customer_id} = $order->{username};
    $call->{discount}  = "0";
    $call->{customer}  = $order->{compuser};
    $call->{ordnumber} = $order->{orderno};
    $call->{shippingpoint} = $order->{shipping};
    $call->{currency} = "USD";
    $call->{orddate} = $order->{date};
    $call->{reqdate} = $order->{date};

    $lineitem = 1;

    for ( my $ln = 1; $ln <= $order->{lineitems}; $ln++ ) {

		my $ref = $order->{orderitem}{$ln};
        $call->{"qty_$ln"}				= $ref->{quantity};
        $call->{"unit_$ln"}				= $ref->{uom} || 'each';
        $call->{"partnumber_$ln"}		= $ref->{part_number} || $SL_ITEM_NAME;
        $call->{"description_$ln"}		= $ref->{description};
        $call->{"sellprice_$ln"}		= $ref->{price};
        $call->{"id_$ln"}				= $ref->{part_id} || $SL_ITEM_ID;
        $call->{"income_accno_$ln"}		= $ref->{income_accno} || '4020';
        $call->{"expense_accno_$ln"}	= $ref->{expense_accno} || '5020';
        $call->{"listprice_$ln"}		= $ref->{price};
        $call->{"assembly_$ln"}			= 0;
    }

    $call->{notes} = $order->{notes} || "Notes";
    $call->{rowcount} = $order->{lineitem};

    $result = call_sl_script('oe.pl', $call);

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
