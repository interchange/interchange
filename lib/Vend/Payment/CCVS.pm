# Vend::Payment::CCVS - Interchange CCVS support
#
# $Id: CCVS.pm,v 2.0.2.2 2002-11-26 03:21:12 jon Exp $
#
# Copyright (C) 1999-2002 Red Hat, Inc. and
# Interchange Development Group, http://www.icdevgroup.org/
#
# Author: Mike Heins <mike@perusion.com>

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

package Vend::Payment::CCVS;

=head1 Interchange CCVS support

Vend::Payment::CCVS $Revision: 2.0.2.2 $

=head1 SYNOPSIS

ccvs($mode, $opt);

	or

&charge=ccvs

	or

[charge mode=ccvs param1=value1 param2=value2]

=head1 PREREQUISITES

CCVS libraries
CCVS.pm

=head1 DESCRIPTION

The Vend::Payment::CCVS module implements the ccvs() routine
for use with Interchange. It is compatible on a call level with the other
Interchange payment modules -- in theory (and even usually in practice) you
could switch from CyberCash to CCVS with a few configuration 
file changes.

To enable this module, place this directive in C<interchange.cfg>:

	Require module Vend::Payment::CCVS

This I<must> be in interchange.cfg or a file included from it.

Make sure CreditCardAuto is off (default in Interchange demos).

The mode can be named anything, but the C<gateway> parameter must be set
to C<ccvs>. To make it the default payment gateway for all credit
card transactions in a specific catalog, you can set in C<catalog.cfg>:

	Variable   MV_PAYMENT_MODE  ccvs

It uses several of the standard settings from Interchange payment. Any time
we speak of a setting, it is obtained either first from the tag/call options,
then from an Interchange order Route named for the mode, then finally a
default global payment variable, For example, the C<id> parameter would
be specified by:

	[charge mode=ccvs id=ccvs_configname]

or

	Route ccvs id ccvs_configname

or 

	Variable MV_PAYMENT_ID      ccvs_configname

The active settings are:

=over 4

=item id

Your CCVS configuration name, set up when CCVS was configured/installed on
the machine. Global parameter is MV_PAYMENT_ID.

=item transaction

The type of transaction to be run. Valid values are:

	Interchange mode    CCVS mode
	----------------    -----------------
	auth				auth
	sale				sale
	return				return
	reverse				reverse
	void				void

=item counter, counter_start

You should always use a counter value to generate the order ID for CCVS, as
it is limited to 8 digits. This is a file name -- etc/ccvs_id.counter would
be a good value. Also, you can supply a starting value (default 100000) for
the number if the file doesn't exist.

	Route   ccvs  counter        etc/ccvs_id.counter
	Route   ccvs  counter_start  1234567

=back

=head2 Troubleshooting

Try the instructions above, then enable test mode. A test order should complete.

Disable test mode, then test in various Authorize.net error modes by
using the credit card number 4222 2222 2222 2222.

Then try a sale with the card number C<4111 1111 1111 1111>
and a valid expiration date. The sale should be denied, and the reason should
be in [data session payment_error].

If nothing works:

Make sure you "Require"d the module in interchange.cfg:

	Require module Vend::Payment::CCVS

Make sure CCVS is installed and working.

Check the error logs, both catalog and global.

Make sure you set your payment parameters properly.  

Try an order, then put this code in a page:

	[calc]
		$Tag->uneval( { ref => $Session->{payment_result} );
	[/calc]

That should show what happened.

=head1 BUGS

There is actually nothing *in* Vend::Payment::CCVS. It changes packages
to Vend::Payment and places things there.

=head1 AUTHORS

Mike Heins <mike@perusion.com>

=head1 CREDITS

Doug DeJulio

=cut

package Vend::Payment;

# Requires CCVS perl libs, get from
#
#	http://www.redhat.com/products/software/ecommerce/ccvs/
#
use CCVS;

sub ccvs {
    my ($opt) = @_;

#::logDebug("ccvs called, args=" . ::uneval(\@_));

	my $sess;
	my %result;

	my $ccvs_die = sub {
		my ($msg, @args) = @_;
		$msg = "CCVS: $msg" unless $msg =~ /^CCVS/;
		$msg = ::errmsg($msg, @args);
		CCVS::done($sess) if $sess;
#::logDebug("ccvs erred, result=$msg");
		die("$msg\n");
	};

	my $actual = $opt->{actual};
	if(! $actual) {
		my %actual = map_actual();
		$actual = \%actual;
	}

    if(! $configname  ) {
        $configname =  $opt->{id} || charge_param('id');
    }
    if(! defined $opt->{precision} ) {
        $opt->{precision} = charge_param('precision');
    }

#::logDebug("ccvs configuration name '$configname'");

    my $exp = sprintf '%02d/%02d',
                        $actual->{mv_credit_card_exp_month},
                        $actual->{mv_credit_card_exp_year};

	my $op = $opt->{transaction} || 'sale';

    my %type_map = (
        qw/
                        mauthcapture  sale
                        mauthonly     auth
                        mauthreturn   return
                        S             sale
                        C             auth
                        V             void
                        sale          sale
                        auth          auth
                        void          void
                        delete        delete
        /
    );

    if (defined $type_map{$op}) {
        $op = $type_map{$op};
    }

    if(! $amount) {
        $amount = $opt->{total_cost} || 
				  Vend::Util::round_to_frac_digits(
				  		Vend::Interpolate::total_cost(),
						$opt->{precision},
					);
    }

    my $invoice;

    unless ($invoice = $opt->{order_id}) {
		if($op ne 'auth' and $op ne 'sale') {
			return $ccvs_die->("must supply order ID for transaction type %s", $op);
		}
		my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(time());

		# We'll make an order ID based on date, time, and Interchange session

		# $mon is the month index where Jan=0 and Dec=11, so we use
		# $mon+1 to get the more familiar Jan=1 and Dec=12
		$invoice = sprintf("%02d%02d%02d%02d%02d%02d%05d%s",
				$year + 1900,$mon + 1,$mday,$hour,$min, $sec, $$);
	}

	$sess = CCVS::init($configname) 
		or
		return $ccvs_die->("failed to init configuration %s", $configname);

	if($op eq 'auth' or $op eq 'sale') {

		CCVS::new($sess, $invoice) == CV_OK
			or return $ccvs_die->("can't create invoice %s", $invoice);
		CCVS::add($sess, $invoice, CV_ARG_AMOUNT, $amount) == CV_OK
			or return $ccvs_die->("can't add amount %s", $amount);
		CCVS::add(
			$sess,
			$invoice,
			CV_ARG_CARDNUM,
			$actual->{mv_credit_card_number},
			)
		  == CV_OK  or do {
						my $num = $actual->{mv_credit_card_number};
						$num =~ s/(\d\d).*(\d\d\d\d)/$1**$2/;
						return $ccvs_die->("CCVS can't add card number %s", $num);
					};

		CCVS::add($sess, $invoice, CV_ARG_EXPDATE, $exp) == CV_OK
			or return $ccvs_die->("can't add expdate %s", $exp);
	
		if($opt->{extended_process}) {
			my %extended = qw/
               address       address
               shipzipcode   zip
               zipcode       b_zip
               accountname   0
               acode         auth_code
               ccv2          ccv2
               purchaseorder po_number
               comment       gift_note
			   /;
			$extended{type}    = sub { 'ecommerce' };
			$extended{tax}     = \&Vend::Interpolate::salestax,
			$extended{product} = sub {
				return join ",", map { $_->{code} } @$Vend::Items;
			};
			$extended{entrysource} = sub { $Vend::admin ? 'merchant' : 'customer' };

			$extended{setmerchant} = sub {
										$opt->{set_merchant} ||
										$::Variable->{SET_MERCHANT}
										};
			$extended{setcardholder} = sub { $opt->{set_cardholder} };
			for(keys %extended) {
				my $val;
				my $ok;
				unless ($val = $opt->{"x_$_"}) {
					my $thing = $opt->{"x_$_"} || $extended{$_};
					if(ref $thing) {
						$val = $thing->($_);
					}
					else {
						$val = $actual->{$thing};
					}
				}
				next unless $val;
				eval {
					$ok = CCVS::add($sess, $invoice, &{"CV_ARG_\U$_"}, $val);
				};
				if($@) {
					::logDebug($@);
					next;
				}
				if($ok != CV_OK) {
					::logDebug(::errmsg("can't add %s", "CV_ARG_\U$_"));
				}
			}
		}


		# Nothing has happened yet.  Let's do the authorization.
		CCVS::auth($sess, $invoice) == CV_OK
			or return $ccvs_die->("couldn't issue auth request");

		# In theory, the background processor is working on this right now.
		# Let's loop until it's done.
		my $status;

		do {
			sleep 1;
			$status = CCVS::status($sess, $invoice);
		} until ($status == CV_AUTH
			 || $status == CV_DENIED
			 || $status == CV_REVIEW);


		# At this point, the status is either "CV_AUTH", "CV_DENIED" or "CV_REVIEW".
		# Let's get the full extended status and unpack it into an associative array.
		%result = split / *{|} */,CCVS::textvalue($sess);

		# If everything was succesful, push through the sale.
		if ($status == CV_AUTH) {
			$result{MStatus} = 'success';
			$result{invoice} = $invoice;
		}
		elsif($status == CV_REVIEW) {
			$result{MStatus} = 'success';
			$result{AVS_message} = $result{result_text};
			$result{invoice} = $invoice;
		}
		elsif($status == CV_DENIED) {
			$result{MStatus} = 'failed';
			my $msg = errmsg(
				"CCVS error: %s %s. Please call in your order or try again.",
				$result{MStatus},
				$result{result_text},
			);
			$Vend::Session->{errors}{mv_credit_card_valid} = $msg;
		}
	}

	if($result{MStatus} =~ /^success/ and $op eq 'sale') {
		CCVS::sale($sess, $invoice) == CV_OK
			or return $ccvs_die->("couldn't issue sale for order ID %s", $invoice);
	}

	# When you're finished, you need to clean up, like this:
	CCVS::done($sess);

    my %result_map = ( qw/

            pop.status            MStatus
            MErrMsg               result_text
            pop.error-message     result_text
            order-id              invoice
            pop.order-id          invoice
            pop.auth-code         AUTHCODE
            pop.avs_code          AVSZIP
            pop.avs_zip           AVSZIP
            pop.avs_addr          AVSADDR
		/
    );

    for (keys %result_map) {
        $result{$_} = $result{$result_map{$_}}
            if defined $result{$result_map{$_}};
    }

#::logDebug("ccvs returns, result=" . ::uneval(\%result));
    return %result;
}
