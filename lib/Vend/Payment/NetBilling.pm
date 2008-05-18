# Vend::Payment::NetBilling - Interchange NetBilling support
#
# $Id: NetBilling.pm,v 1.6 2007-08-09 13:40:55 pajamian Exp $
#
# Copyright (C) 2003-2007 Interchange Development Group, http://www.icdevgroup.org/
# Copyright (C) 1999-2002 Red Hat, Inc.
#
# by Peter Ajamian <peter@pajamian.dhs.org> with code reused and inspired by
#	mark@summersault.com
#	Mike Heins <mike@perusion.com>
#	webmaster@nameastar.net
#   Jeff Nappi <brage@cyberhighway.net>
#   Paul Delys <paul@gi.alaska.edu>
#  Edited by Ray Desjardins <ray@dfwmicrotech.com>

# Patches for AUTH_CAPTURE and VOID support contributed by
# nferrari@ccsc.com (Nelson H Ferrari)

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

# Connection routine for NetBilling version 2.1 using the 'NetBilling Direct Mode'
# method.

# Reworked extensively to support new Interchange payment stuff by Mike Heins

# Originally converted to NetBilling use by Peter Ajamian in 07/2003

# Rewritten again by Peter Ajamian in 08/2006

package Vend::Payment::NetBilling;

=head1 Interchange NetBilling Support

Vend::Payment::NetBilling $Revision: 1.6 $

=head1 SYNOPSIS

    &charge=netbilling
 
        or
 
    [charge route=netbilling param1=value1 param2=value2]

=head1 PREREQUISITES

  LWP::UserAgent
  LWP::Protocol::https
  Digest::MD5

All of these need be present and working.

=head1 DESCRIPTION

The Vend::Payment::NetBilling module implements the netbilling() routine
for use with Interchange. It is compatible on a call level with the other
Interchange payment modules.  In theory (and even usually in practice) you
could switch from another payment module to NetBilling with a few
configuration file changes.

=head1 SETUP

To enable this module, place this directive in your C<interchange.cfg>
file:

    Require module Vend::Payment::NetBilling

This I<must> be in interchange.cfg or a file included from it.

Make sure CreditCardAuto is off which is the default in the I<Standard>
ecommerce demo.

The mode can be named anything, but the C<gateway> parameter must be set
to C<netbilling>. To make it the default payment gateway for all credit
card transactions in a specific catalog, you can set in C<catalog.cfg>:

    Variable   MV_PAYMENT_MODE  netbilling

=head1 SETTINGS

Vend::Payment::NetBilling uses several of the standard settings from Interchange payment.
Any time we speak of a setting, it is obtained either first from the tag/call
options, then from an Interchange order Route named for the mode, then finally
a default global payment variable, For example, the C<id> parameter would be
specified by:

    [charge route=netbilling id=YourNetBillingID]

or

    Route netbilling id YourNetBillingID

or 

    Variable MV_PAYMENT_ID      YourNetBillingID

=head2 The settings are:

=over 4

=item amount

Amount for the transaction.  Defaults to the checkout total after all
shipping, taxes discounts, and other levies have been applied.

=item getid

The path to the getid script on the NetBilling secure server.  Defaults to
"/gw/native/getid1.0".

=item host

The domain name of the NetBilling secure server.  Defaults to
"secure.netbilling.com".

=item id

This is your account and sitetag separated by a colon (ACCOUNT:SITETAG).
ACCOUNT is the number of your Netbilling merchant or agent account, as a
12-character string. Required for ALL transactions. SITETAG is the site
tag of your website configured in the Netbilling system. Required for
membership transactions, optional for others.
Global parameter is MV_PAYMENT_ID.

=item poll

The path to the poll script on the NetBilling secure server.  Defaults to
"/gw/native/poll1.0".

=item port

The port to connect to on the NetBilling secure server.  Defaults to the
standard https port (443).

=item remap 

This remaps the form variable names to the ones needed by NetBilling.

=item remote_host

Hostname of customer for NetBilling to record for this transaction.
Defaults to the session remote host.

=item remote_ip

IP address of customer for NetBilling to record for this transaction.
Defaults to the session IP.

=item retries

Number of times to attempt a connection to the NetBilling secure server before
giving up.  Defaults to 3.

=item script

The path to the NetBilling direct mode 2.1 script on the NetBilling secure
server.  Defaults to "/gw/native/direct2.1".

=item secret

Your NetBilling Order Integrity Key, set in the NetBilling admin interface in
step 11 of 'Fraud Defense'.
Global parameter is MV_PAYMENT_SECRET.

=item trans_id

Netbilling Transaction ID returned from a previous transaction. Used for 'REFUND'
type transactions, the amount of the refund/Void and other relevant data will be
taken from the original transaction data.

=item transaction

The type of transaction to be run. Valid values are:

  Interchange  NetBilling
  -----------  ----------
  avs          AVS         Address verification only, no charges
  auth         AUTH        Pre-Auth a charge card for later capture
  return       CREDIT      Credit the charge/ACH account instead of charging it
  reverse      REFUND      Will attempt a VOID or a Refund of a previous 'SALE'
  sale         SALE        Standard charge/ACH transaction
  settle       CAPTURE     Capture a Pre-Authed charge
  void         REFUND      Will attempt a VOID or a Refund of a previous 'SALE'
  abort        ABORT       Will abort a pending capture

The "reverse" and "void" transactions are both sent as a "REFUND" because
NetBilling determines internally whether to "VOID" or "REFUND" based on if
the original transaction has been batched out yet.  The default is "sale".

=item type

The payment type.  Set to "K" or any string with the word "check" in it
for online checking.  Any other value for charge.  If left unset or blank
will default to the "mv_order_profile" form value or CGI variable which can
be "remap"ped to a different actual form name (see C<remap>).  If
everything is blank this defaults to charge.

=back

=head1 VALUES

Values can be obtained either from processed or raw CGI values.  The CGI
names can be "remap"ped with the C<remap> setting above in case your form
names are different.

=over 4

=item address1

Customer's shipping street address and also the default for b_address1.

=item auth_code

Force code provided by credit card processor. Optional.

=item b_address1

Customer's billing street address.  Required for address verification. Defaults to
address1.

=item b_city

Customer's billing city.  Required for address verification.  Defaults to city.

=item b_country

Customer's billing country.  Required for address verification.  Defaults to
country.

=item b_fname

Customer's billing first name.  Required for address verification.  Defaults to fname.

=item b_lname

Customer's billing last name.  Required for address verification.  Defaults to lname.

=item b_state

Customer's billing state/province.  Required for address verification.  Defaults
to state.

=item b_zip

Customer's billing zip/postal code.  Required for address verification.  Defaults
to zip.

=item check_account

Checking account number. Required for ACH transactions.

=item check_dl

Optional driver's license number field, but necessary for proper online check
fraud screening. In any case, only ONE of SSN, DL or TAXID will be used if
provided, in that order of preference.

=item check_dl_state

The two-character postal code for the state the ID was issued in. Leave blank
if inappropriate, for instance, when using SSN.

=item check_number

An optional check sequence number, provided by the customer.

=item check_routing

Checking account routing code. Required for ACH transactions.

=item check_ssn

Optional social security number field, but necessary for proper online check
fraud screening. In any case, only ONE of SSN, DL or TAXID will be used if
provided, in that order of preference.

=item check_taxid

Optional tax id number field, but necessary for proper online check
fraud screening. In any case, only ONE of SSN, DL or TAXID will be used if
provided, in that order of preference.

=item city

Customer's shipping city and also the default for b_city.

=item comment1

Additional miscellaneous info to accompany the transaction, up to 4000 characters.

=item country

Customer's shipping country and also the default for b_country.

=item email

Customer's email address.  Required for address verification.

=item fname

Customer's first name for shipping and also the default for b_fname.

=item item_desc

An optional description of the product or services paid for. Up to 4000 characters.
Defaults to a summary of the shopping cart contents.

=item lname

Customer's last name for shipping and also the default for b_lname.

=item mv_credit_card_cvv2

Credit Card CVV2 value. This is the three or four digit code on the back
of the customer's credit card. Optional, but often will get a lower rate
on the transaction.

=item mv_credit_card_exp_month

The month of expiration as a two digit number.

=item mv_credit_card_exp_year

The year of expiration as a two digit number.  This can accept a four digit
number in which case the first two digits will be discarded.

=item mv_credit_card_number

Credit Card Account Number -- required for Credit Card transactions.

=item mv_order_number

The number Interchange assigns to this order.  This gets stored as user data
in the transaction.  This will only come from processed values, not raw values
but it does default to the mv_order_number in session space.

=item phone_day

Stored as the customer phone number for the transaction and required for address
verification.

=item state

Customer's shipping state and also the default for b_state.

=item zip

Customer's shipping zip and also the default for b_zip.

=back

=head1 TROUBLESHOOTING

In order to run a test transaction in NetBilling use the testing credit card
number set in the Setup/Account Config/Credit Cards section of the NetBilling
admin interface.

If nothing works:

=over 4

=item *

Make sure you "Require"d the module in interchange.cfg:

    Require module Vend::Payment::NetBilling

=item *

Make sure LWP::UserAgent LWP::Protocol::https and Digest::MD5 are installed
and working. You can test to see whether your Perl thinks they are:

    perl -MLWP::UserAgent -MLWP::Protocol::https -MDigest::MD5 -e 'print "It works\n"'

If it prints "It works." and returns to the prompt you should be OK
(presuming they are in working order otherwise).

=item *

Check the error logs, both catalog and global.

=item *

Make sure you set your payment parameters properly.  

=item *

Try an order, then put this code in a page:

    <XMP>
    [calc]
        my $string = $Tag->uneval( { ref => $Session->{payment_result} });
        $string =~ s/{/{\n/;
        $string =~ s/,/,\n/g;
        return $string;
    [/calc]
    </XMP>

That should show what happened.

=item *

If all else fails, consultants are available to help
with integration for a fee.

=back

=head1 BUGS

There is actually nothing *in* Vend::Payment::NetBilling. It changes packages
to Vend::Payment and places things there.

You cannot randomly pick a transaction ID for NetBilling's Direct Mode.  The
ID must be assigned from NetBilling.  It should either be left blank or a
guaranteed unused ID can be retrieved from NetBilling prior to issuing the
transaction.  This module will overwrite any transaction ID supplied it with
the one assigned by NetBilling.

=head1 AUTHORS

Mark Stosberg <mark@summersault.com>, based on original code by Mike Heins
<mike@perusion.com>.  Modified from the AuthorizeNet.pm module for NetBilling
and later rewritten by Peter Ajamian <peter@pajamian.dhs.org>.

=head1 CREDITS

    Jeff Nappi <brage@cyberhighway.net>
    Paul Delys <paul@gi.alaska.edu>
    webmaster@nameastar.net
    Ray Desjardins <ray@dfwmicrotech.com>
    Nelson H. Ferrari <nferrari@ccsc.com>


=head1 SEE ALSO

NetBilling Direct Mode 2.1 documentation is found at:

    http://netbilling.com/direct/direct2.html

=cut

BEGIN {

    my $selected;
    eval {
	package Vend::Payment;
	use LWP::UserAgent;
	use LWP::Protocol::https;
	use Digest::MD5 qw(md5_hex);
	use Socket;
	$selected = "LWP and Crypt::SSLeay";
    };

    $Vend::Payment::Have_LWP = 1 unless $@;

    unless ($Vend::Payment::Have_LWP) {
	die __PACKAGE__ . " requires Crypt::SSLeay";
    }

    ::logGlobal("%s payment module initialized, using %s", __PACKAGE__, $selected)
	unless $Vend::Quiet;

}

package Vend::Payment;

sub netbilling {
    my ($opt) = @_;
    unless (ref $opt) {
	$opt = $_[2] || {};
	@{$opt}{id,total_cost} = @_;
    }

    foreach (qw(
		id
		amount
		total_cost
		secret
		transaction
		type
		host
		script
		port
		getid
		poll
		success_variable
		error_variable
		)) {
	$opt{$_} ||= charge_param($_);
    }

    my $svar = $opt->{success_variable} ||= 'MStatus';
    my $evar = $opt->{error_variable} ||= 'MErrMsg';

    foreach (qw(
		id
		secret
		)) {
	return (
		$svar => 'failure-hard',
		$evar => errmsg("No $_"),
		) unless $opt{$_};
    }

    my $actual = $opt->{actual}	|| {map_actual};
    $actual->{mv_order_number}	||= $::Values->{mv_order_number} ||
				    $Vend::Session->{mv_order_number};
#::logDebug("actual map result: " . ::uneval($actual));

    @{$opt}{account,sitetag} = split (/:/,$opt->{id});

    # Defaults here:
    $opt->{host}	||= 'secure.netbilling.com';
    $opt->{script}	||= '/gw/native/direct2.1';
    $opt->{port}	&&= ':' . $opt->{port};		# add a : to the beginning only if already set.
    $opt->{getid}	||= '/gw/native/getid1.0';
    $opt->{poll}	||= '/gw/native/poll1.0';
    $opt->{retries}	||= 3;
    $opt->{transaction}	||= 'sale';
    $opt->{type}	||= $actual->{mv_order_profile}	||
			    $::Values->{mv_order_profile} ||
			    $CGI::values{mv_order_profile};
    $opt->{total_cost}	||= $opt->{amount} ||
			     Vend::Util::round_to_frac_digits(Vend::Interpolate::total_cost, 2);
    $opt->{total_cost}	=~ s/[^\d\.]//g;

    # Turn script, getid, and poll into full URLs.
    $opt->{host} = sprintf('https://%s%s', @{$opt}{host, port});
    foreach (@{$opt}{script, getid, poll}) {
	$_ = $opt->{host} . $_;
    }

    ## NetBilling does things a bit different, ensure we are OK
    $actual->{mv_credit_card_exp_month} =~ s/\D//g;
    $actual->{mv_credit_card_exp_month} =~ s/^0+//;
    $actual->{mv_credit_card_exp_year} =~ s/\D//g;
    $actual->{mv_credit_card_exp_year} =~ s/\d\d(\d\d)/$1/;
    $actual->{mv_credit_card_number} =~ s/\D//g;
    $actual->{mv_credit_card_exp_all} = sprintf ('%02d%02d', @{$actual}{mv_credit_card_exp_month, mv_credit_card_exp_year});

    my %type_map = (
		    AVS			=> 'AVS',
		    AUTH		=> 'AUTH',
		    CAPTURE		=> 'CAPTURE',
		    SALE		=> 'SALE',
		    CREDIT		=> 'CREDIT',
		    REFUND		=> 'REFUND',
		    NONE		=> 'NONE',
		    ABORT		=> 'ABORT',
		    avs			=> 'AVS',
		    auth		=> 'AUTH',
		    authorize		=> 'AUTH',
		    return		=> 'CREDIT',
		    reverse		=> 'REFUND',
		    sale		=> 'SALE',
		    settle		=> 'CAPTURE',
		    void		=> 'REFUND',
		    abort		=> 'ABORT',
		    );
	
    # Translate transaction code
    $opt->{transaction} = $type_map{$opt->{transaction}} if $type_map{$opt->{transaction}};

    # total cost has to be 0.00 for AVS transactions.
    $opt->{total_cost} = '0.00' if $opt->{transaction} eq 'AVS';

    $opt->{remote_ip} = $Vend::Session->{ohost} || $Vend::Session->{host} || $CGI::remote_addr;
    $opt->{remote_host} = $CGI::remote_host || gethostbyaddr(inet_aton($opt->{remote_ip}), AF_INET) || $opt->{remote_ip};

    # If no description was passed, make one from the shopping cart.
    $actual->{item_desc} ||= <<'EOH' .
Quan  Item No.    Description                          Price   Extension
---- ----------- -------------------------------- ----------- -----------
EOH

    join('', map {
	sprintf("% 4d %-11s %-32.32s %11s %11s\n",
		$_->{quantity},
		$_->{code},
		Vend::Data::item_description($_),
		Vend::Data::item_price($_),
		Vend::Data::item_subtotal($_)
		);
    } @{$Vend::Items}) .
    sprintf(<<'EOF',

SUBTOTAL:    %11s
SALES TAX:   %11s
SHIPPING:    %11s
%sORDER TOTAL: %11s
EOF
	    Vend::Tags->subtotal,
	    Vend::Tags->salestax,
	    Vend::Tags->shipping,
	    $::Values->{mv_handling} ? sprintf("HANDLING:    %11s\n", Vend::Tags->handling) : '',
	    Vend::Tags->total_cost
	    );

    $actual->{comment1} .= $actual->{comment2};
    $actual->{phone_day} ||= $actual->{phone_night};
    $actual->{mv_credit_card_cvv2} ||= $actual->{cvv2};

    # Some fields that are not in the actual hash by default.
    foreach (qw(
		check_ssn
		check_dl_state
		check_taxid
		)) {
	$actual->{$_} ||= $::Values->{$_} || $CGI::values{$_};
    }

    # Any extra data that we want to store with the transaction goes here.
    my $userdata = 'Order Number: ' . $actual->{mv_order_number};

    # Some fields only allow 4000 chars
    foreach (@{$actual}{qw(
			   item_desc
			   comment1
			   )}) {
	eval { substr($_,4000)=''; };
    }

    # Prefetch a transaction ID
    my $ua = new LWP::UserAgent;
    $ua->agent("Vend::Payment::NetBilling (Interchange version $::VERSION)");
    my $req = new HTTP::Request GET => $opt->{getid};
    my $res;
    for (my $i = 0; $i < $opt->{retries}; $i++) {
	$res = $ua->request($req);
	last unless $res->is_error || $res->code != 200;
	::logError(errmsg("Failure fetching a transaction ID on attempt $i: ".
			  ($res->is_error ?
			   $res->status_line :
			   $res->code . ': ' . $res->message . ': ' . $res->content)));
    }

    # give up if we haven't gotten a transaction ID yet.
    return (
	    $svar => 'failure',
	    $evar => errmsg(sprintf("Can't get a transaction ID after %d tries: %s",
				    $opt->{retries},
				    $res->status_line)),
	    ) if ($res->is_error);
    return (
            $svar => 'failure',
            $evar => errmsg(sprintf("Can't get a transaction ID after %d tries: %d: %s: %s",
				    $opt->{retries},
				    $res->code,
				    $res->message,
				    $res->content)),
            ) if ($res->code != 200);

    # It is possible that NetBilling will return more than one transaction ID if a number
    # is appended to the query URL.  We only really want one, so we'll discard the rest.
    # This also gets rid of any trailing newlines or other whitespace (same as chomp).
    my ($xid) = split(/\s+/, $res->content, 2);
#::logDebug("NetBilling: Transaction ID: $xid");

    # Got a transaction ID to use, now fire off the transaction.

    my %query = (
		 GEN_ACCOUNT		=> $opt->{account},
		 GEN_SITETAG		=> $opt->{sitetag},
		 GEN_DESCRIPTION	=> $actual->{item_desc},
		 GEN_AMOUNT		=> $opt->{total_cost},
		 GEN_MISC_INFO		=> $actual->{comment1},
		 GEN_TRANS_TYPE		=> $opt->{transaction},
		 GEN_TRANS_ID		=> $xid,
		 GEN_USER_DATA		=> $userdata,
		 GEN_MASTER_ID		=> $opt->{trans_id},
		 CUST_IP		=> $opt->{remote_ip},
		 CUST_HOST		=> $opt->{remote_host},
		 CUST_NAME1		=> $actual->{b_fname},
		 CUST_NAME2		=> $actual->{b_lname},
		 CUST_ADDR_STREET	=> $actual->{b_address},
		 CUST_ADDR_CITY		=> $actual->{b_city},
		 CUST_ADDR_STATE	=> $actual->{b_state},
		 CUST_ADDR_ZIP		=> $actual->{b_zip},
		 CUST_ADDR_COUNTRY	=> $actual->{b_country},
		 CUST_PHONE		=> $actual->{phone_day},
		 CUST_EMAIL		=> $actual->{email},
		 SHIP_NAME1		=> $actual->{fname},
		 SHIP_NAME2		=> $actual->{lname},
		 SHIP_ADDR_STREET	=> $actual->{address},
		 SHIP_ADDR_CITY		=> $actual->{city},
		 SHIP_ADDR_STATE	=> $actual->{state},
		 SHIP_ADDR_ZIP		=> $actual->{zip},
		 SHIP_ADDR_COUNTRY	=> $actual->{country},
		 OVERRIDE_FRAUD_CHECKS	=> '0',			# Explicitly set these to 0
		 DO_MEMBER		=> '0',			# to prevent man-in-the-middle
		 DO_REBILL		=> '0',			# attacks
		 );

    if ($opt->{type} eq 'K' || $opt->{type} =~ /check/i) {
	$query{GEN_PAYMENT_TYPE}	= 'K';
	$query{ACH_ROUTING}		= $actual->{check_routing};
	$query{ACH_ACCOUNT}		= $actual->{check_account};
	$query{ACH_CHECKNUMBER}		= $actual->{check_number};
	$query{ACH_ID_SSN}		= $actual->{check_ssn};
	$query{ACH_ID_DL}		= $actual->{check_dl};
	$query{ACH_ID_STATE}		= $actual->{check_dl_state};
	$query{ACH_ID_TAXID}		= $actual->{check_taxid};
    } else {
	$query{GEN_PAYMENT_TYPE}	= 'C';
	$query{CARD_NUMBER}		= $actual->{mv_credit_card_number};
	$query{CARD_EXPIRE}		= $actual->{mv_credit_card_exp_all};
	$query{CARD_CVV2}		= $actual->{mv_credit_card_cvv2};
	$query{CARD_FORCE_CODE}		= $actual->{auth_code};
    }

    # Calculate MD5 hash and add it to the query.
    my $hashfields = join(' ', keys %query);
    my $hashvalue = md5_hex($opt->{secret}, values %query);
    $query{GEN_HASHFIELDS} = $hashfields;
    $query{GEN_HASHVALUE_MD5} = $hashvalue;

    # Assemble the content string
    foreach (values %query) { s/([^\w\.])/sprintf("%%%02X",ord($1))/egs; }
#::logDebug("NetBilling query: " . ::uneval(\%query));

    my $content = join ('&', map { "$_=$query{$_}" } keys %query);

    # Send the transaction to the NetBilling server
    $req = new HTTP::Request POST => $opt->{script};
    $req->content_type('application/x-www-form-urlencoded');
    $req->content($content);

    # Also set up a polling request, just in case.
    my $preq = new HTTP::Request POST => $opt->{poll};
    $preq->content_type('application/x-www-form-urlencoded');
    $preq->content(sprintf('account_id=%s&trans_id=%s', $opt->{account}, $xid));
    my $lastresponse;
    for (my $i=0; $i < $opt->{retries}; $i++) {
	$res = $ua->request($req);
	last unless $res->is_error || $res->code != 200;

	$lastresponse = $res->is_error ? $res->status_line : $res->code . ': ' . $res->message . ': ' . $res->content;
	::logError(errmsg("Bad response from NetBilling secure server on attempt $i: $lastresponse"));

	# Got a bad response, or no response.  We need to poll to see if the transaction
	# went through.
	for (my $j=0; $j < $opt->{retries}; $j++) {
	    $res = $ua->request($preq);
	    last unless $res->is_error || $res->code != 200;

	    ::logError(errmsg("Bad response polling NetBilling secure server on attempt $j: ".
			      ($res->is_error ?
			       $res->status_line :
			       $res->code . ': ' . $res->message . ': ' . $res->content)));
	}

	# Got a response from polling, was the transaction processed?
	last unless $res->content eq 'found=N';

	::logError(errmsg("Transaction $xid not found when polling."));
	# Transaction didn't go through so loop back around and try again.
    }

    # Check to make sure the transaction went through
    return (
	    $svar => 'failure',
	    $evar => errmsg(sprintf("Bad response from polling NetBilling secure server after %d tries: %s",
				    $opt->{retries},
				    $res->status_line)),
	    ) if ($res->is_error);
    return (
            $svar => 'failure',
            $evar => errmsg(sprintf("Bad response from polling NetBilling secure server after %d tries: %d: %s: %s",
				    $opt->{retries},
				    $res->code,
				    $res->message,
				    $res->content)),
            ) if ($res->code != 200);
    return (
	    $svar => 'failure',
	    $evar => errmsg(sprintf("Bad response from NetBilling secure server after %d tries: %s",
				    $opt->{retries},
				    $lastresponse))
	    ) if $res->content eq 'found=N';

    # Interchange names are on the left, NetBilling on the right
    my @result_map = (
		      [['pop.status'],			['RET_STATUS','status']],
		      [['pop.error-message'],		['RET_AUTH_MSG','message']],
		      [['order-id', 'pop.order-id'],	['RET_TRANS_ID','trans_id']],
		      [['pop.auth-code'],		['RET_AUTH_CODE']],
		      [['pop.avs_code'],		['RET_AVS_CODE']],
		      [['pop.avs_reason'],		['RET_AVS_MSG']],
		      [['pop.cvv2_code'],		['RET_CVV2_CODE']],
		      [['pop.cvv2_reason'],		['RET_CVV2_MSG']],
		      );

# Parse the results
    my %result = map {
	my ($key, $val) = split(/=/, $_, 2);
	$val =~ s/\%([0-9A-Fa-f]{2})/chr(hex($1))/eg;
	($key,$val);
    } split(/\&/, $res->content);

    foreach my $pair (@result_map) {
	foreach my $to (@{$pair->[0]}) {
	    foreach my $from (@{$pair->[1]}) {
		$result{$to} ||= $result{$from};
	    }
	}
    }

    # Check the return status.  The NetBilling Direct Mode 2.1 Documentation says
    # specifically that any status codes which are unknown should be interpreted as
    # success for future compatibility so we'll just check for failure codes.  If
    # there aren't any failure codes then we automatically assume success (note we
    # do interpret nothing as failure, though).
    if ($result{'pop.status'} =~ /^[^0F]/) {
    	$result{$svar} = 'success';
    } else {
    	$result{$svar} = 'failure';
	delete $result{'order-id'};

	# The transaction failed, so set a nice human readable error message.
	my %error_msg = (
			 'BAD ADDRESS'		=> 'You must enter the correct billing address '.
			 			   'of your credit card.  The bank returned the '.
			 			   'following error: ' . $result{'pop.avs_code'}.
			 			   ': ' . $result{'pop.avs_reason'},
			 'BAD CVV2'		=> 'CVV2 Error: ' . $result{'pop.cvv2_code'} . ': '.
			 			   $result{'pop.cvv2_reason'},
			 'E/DECLINED'		=> 'Your email address was not accepted as valid by '.
			 			   'our system.  Please correct this and try again.',
			 'L/DECLINED'		=> 'The address you supplied failed to pass US '.
			 			   'Location Verification.  Please correct this and '.
			 			   'try again.',
			 'A/QUOTA EXCEEDED'	=> "You've exceeded the maximum daily limit for this ".
			 			   'credit card.  Please try another card or try again '.
			 			   'tomorrow.',
			 'M/QUOTA EXCEEDED'	=> "You've exceeded the maximum amount allowed per ".
			 			   'transaction.  Please contact us directly to make '.
						   'your purchase.',
			 );
	@error_msg{'A/DECLINED', 'C/QUOTA EXCEEDED', 'R/QUOTA EXCEEDED', 'S/QUOTA EXCEEDED'} = map {
	    'Your transaction cannot be processed due to high volumes of traffic.  Please try again later.'
	    } (1..4);
	@error_msg{'B/DECLINED', 'J/DECLINED', 'R/DECLINED'} = map {
	    'Your transaction cannot be processed via our automated web interface.  Please contact us '.
	    'directly to make your purchase and supply us with the following code: ' .
	    $result{'pop.error-message'}
	} (1..3);

	$result{$evar} = errmsg($error_msg{$result{'pop.error-message'}} ||
				"We're sorry but your bank has declined the transaction.");
    }

    return (%result);
}

package Vend::Payment::NetBilling;

1;
