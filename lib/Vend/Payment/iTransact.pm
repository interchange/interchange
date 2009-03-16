# Vend::Payment::iTransact - Interchange iTransact Support
#
# $Id: iTransact.pm,v 2.9 2009-03-16 19:34:01 jon Exp $
#
# Copyright (C) 2002-2007 Interchange Development Group
# Copyright (C) 1999-2002 Red Hat, Inc.
#
# Written by Cameron Prince and Mark Johnson, based on code by Mike Heins.

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

package Vend::Payment::iTransact;

=head1 NAME

Vend::Payment::iTransact - Interchange iTransact Support

=head1 SYNOPSIS

    &charge=itransact
 
        or
 
    [charge mode=itransact param1=value1 param2=value2]

=head1 PREREQUISITES

  Net::SSLeay
 
    or
  
  LWP::UserAgent and Crypt::SSLeay

Only one of these need be present and working.

=head1 DESCRIPTION

The Vend::Payment::iTransact module implements the itransact() routine
for use with Interchange. It is compatible on a call level with the other
Interchange payment modules.

To enable this module, place this directive in C<interchange.cfg>:

    Require module Vend::Payment::iTransact

This I<must> be in interchange.cfg or a file included from it.

Make sure CreditCardAuto is off (default in Interchange demos).

The mode can be named anything, but the C<gateway> parameter must be set
to C<itransact>. To make it the default payment gateway for all credit
card transactions in a specific catalog, you can set in C<catalog.cfg>:

    Variable   MV_PAYMENT_MODE  itransact

It uses several of the standard settings from Interchange payment. Any time
we speak of a setting, it is obtained either first from the tag/call options,
then from an Interchange order Route named for the mode, then finally a
default global payment variable, For example, the C<id> parameter would
be specified by:

    [charge mode=itransact id=YouriTransact]

or

    Route itransact id YouriTransactID

or 

    Variable MV_PAYMENT_ID      YouriTransactID

The active settings are:

=over 4

=item id

Your iTransact account ID, supplied by iTransact when you sign up.
Global parameter is MV_PAYMENT_ID.

=item home_page

The internet address of your site. Defaults to C<http://__SERVER_NAME__> if
not set. Global parameter is MV_PAYMENT_HOME_PAGE.

=item remap 

This remaps the form variable names to the ones needed by iTransact. See
the C<Payment Settings> heading in the Interchange documentation for use.

=back

=head2 Troubleshooting

Try the instructions above, then enable test mode. A test order should complete.

Then move to live mode and try a sale with the card number C<4111 1111 1111 1111>
and a valid expiration date. The sale should be denied, and the reason should
be in [data session payment_error].

If nothing works:

=over 4

=item *

Make sure you "Require"d the module in interchange.cfg:

    Require module Vend::Payment::iTransact

=item *

Make sure either Net::SSLeay or Crypt::SSLeay and LWP::UserAgent are installed
and working. You can test to see whether your Perl thinks they are:

    perl -MNet::SSLeay -e 'print "It works\n"'

or

    perl -MLWP::UserAgent -MCrypt::SSLeay -e 'print "It works\n"'

If either one prints "It works." and returns to the prompt you should be OK
(presuming they are in working order otherwise).

=item *

Check the error logs, both catalog and global.

=item *

Make sure you set your account ID properly.  

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

If all else fails, consultants are available to help with integration for a fee.
See http://www.icdevgroup.org/

=back

=head1 BUGS

There is actually nothing *in* Vend::Payment::iTransact. It changes packages
to Vend::Payment and places things there.

=head1 AUTHORS

Mark Johnson and Cameron Prince, based on original code by Mike Heins.

=cut

BEGIN {

	my $selected;
	eval {
		package Vend::Payment;
		require Net::SSLeay;
		import Net::SSLeay qw(post_https make_form make_headers);
		$selected = "Net::SSLeay";
	};

	$Vend::Payment::Have_Net_SSLeay = 1 unless $@;

	unless ($Vend::Payment::Have_Net_SSLeay) {

		eval {
			package Vend::Payment;
			require LWP::UserAgent;
			require HTTP::Request::Common;
			require Crypt::SSLeay;
			import HTTP::Request::Common qw(POST);
			$selected = "LWP and Crypt::SSLeay";
		};

		$Vend::Payment::Have_LWP = 1 unless $@;
		
	}

	unless ($Vend::Payment::Have_Net_SSLeay or $Vend::Payment::Have_LWP) {
		die __PACKAGE__ . " requires Net::SSLeay or Crypt::SSLeay";
	}

	::logGlobal("%s payment module initialized, using %s", __PACKAGE__, $selected)
		unless $Vend::Quiet or ! $Global::VendRoot;

}

package Vend::Payment;

sub itransact {
	my ($opt, $amount) = @_;

	my $user = $opt->{id} || charge_param('id');

	my $company = $opt->{company} || "$::Variable->{COMPANY} Order";

	my %actual;
	if($opt->{actual}) {
		%actual = %{$opt->{actual}};
	}
	else {
		%actual = map_actual();
	}

	$actual{mv_credit_card_exp_month} =~ s/\D//g;
	$actual{mv_credit_card_exp_month} =~ s/^0+//;
	$actual{mv_credit_card_exp_year} =~ s/\D//g;

	my $exp_year = $actual{mv_credit_card_exp_year};
	$exp_year += 2000 unless $exp_year =~ /\d{4}/;

	$actual{mv_credit_card_number} =~ s/\D//g;

	my @month = (qw/January
				   February
				   March
				   April
				   May
				   June
				   July
				   August
				   September
				   October
				   November
				   December/);

	my $exp_month = @month[$actual{mv_credit_card_exp_month} - 1];
	my $precision = $opt->{precision} || charge_param('precision') || 2;
   
	$amount = "$opt->{total_cost}" || undef;

    if(! $amount) {
			$amount = Vend::Interpolate::total_cost();
			$amount = Vend::Util::round_to_frac_digits($amount,$precision);
    }

	my $gen;
	if($opt->{test} and $gen = charge_param('generate_error') ) {
#::logDebug("trying to generate error");
		$actual{mv_credit_card_number} = '4111111111111112'
			if $gen =~ /number/;
		$exp_year = '2000'
			if $gen =~ /date/;
	}

	my %values = (
				  vendor_id   =>   $user,
				  ret_addr    =>   "success",
				  '1-qty'     =>   1,
				  '1-desc'    =>   $company,
				  '1-cost'	  =>   $amount,
				  first_name  =>   $actual{b_fname},
				  last_name   =>   $actual{b_lname},
				  address     =>   $actual{b_address},
				  city        =>   $actual{b_city},
				  state       =>   $actual{b_state},
				  zip         =>   $actual{b_zip},
				  country     =>   $actual{b_country},
				  phone       =>   $actual{phone_day},
				  email       =>   $actual{email},
				  ccnum       =>   $actual{mv_credit_card_number},
				  ccmo        =>   $exp_month,
				  ccyr        =>   $exp_year,
				  ret_mode    =>   "redirect",
				 );

	my $hp = $opt->{home_page}
		  || charge_param('home_page')
		  || $::Variable->{SERVER_NAME};
	$hp = "http://$hp" unless $hp =~ /^\w+:/;
	$values{home_page} = $hp;

	$opt->{submit_url} ||= 'https://secure.itransact.com/cgi-bin/rc/ord.cgi';

	my %result;

#::logDebug("sending query: " . ::uneval(\%values));

	my $thing         = post_data($opt, \%values);
	my $header_string = $thing->{header_string};
	my $result_page   = $thing->{result_page};

	## check for errors
	my $error;

#::logDebug("request returned: $result_page");

	if ($header_string =~ m/^Location: success/mi) {
		$result{MStatus} = 'success';
		$result{'order-id'} = $opt->{order_id};
	}
	else {
		if ($result_page =~ m/BEGIN ERROR DESCRIPTION --\>(.*)\<\!-- END ERROR DESCRIPTION/s) {
		  $error = $1;
		  $error =~ s/\<.*?\>//g;
		  $error =~ s/[^-A-Za-z_0-9 ]//g;
		}
		elsif($result_page =~ m{<title>\s*error\s*</title>}i) {
		  $error = $result_page;
		  $error =~ s/.*?<body.*?>//is;
		  $error =~ s/<.*?>//g;
		  $error =~ s/\s+/ /g;
		  $error =~ s/\s+$//;
		  $error =~ s/^\s+$//;
		}
		else {
		  ## something very bad happened
		  $error = ::errmsg("Unknown error");
		}

#::logDebug("iTransact Error: " . $error);
		$result{MStatus} = 'denied';
		$result{MErrMsg} = $error;
	}

	return %result;

}

package Vend::Payment::iTransact;

1;
