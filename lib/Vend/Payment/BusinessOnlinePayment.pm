# Vend::Payment::BusinessOnlinePayment
# Interchange wrapper for Business::OnlinePayment modules
#
# $Id: BusinessOnlinePayment.pm,v 1.2 2009-03-22 13:06:02 mheins Exp $
#
# Copyright (C) 2004 Ivan Kohler.  All rights reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
# Ivan Kohler <ivan-interchange@420.am>

package Vend::Payment::BusinessOnlinePayment;

=head1 NAME

Vend::Payment::BusinessOnlinePayment - Interchange wrapper for Business::OnlinePayment

=head1 SYNOPSIS

    &charge=onlinepayment

        or

    [charge mode=onlinepayment param1=value1 param2=value2]

=head1 PREREQUISITES

  Business::OnlinePayment
  Business::OnlinePayment:: gateway module

  See L<http://www.420.am/business-onlinepayment/> or 
  L<http://search.cpan.org/search?query=Business%3A%3AOnlinePayment&mode=module>

=head1 DESCRIPTION

This is a wrapper around Business::OnlinePayment for Interchange.

The Vend::Payment::BusinessOnlinePayment module implements the onlinepayment()
routine for use with Interchange.  It is compatible on a call level with the
other Interchange payment modules.  In theory (and even usually in practice)
you could switch from another gateway to a Business::OnlinePayment supported
gateway (or between different Business::OnlinePayment gateways) with a few
configuration file changes.

Business::OnlinePayment is a set of related Perl modules for processing online
payments (credit cards, electronic checks, and other payment systems).  It
provides a consistant interface for processing online payments, regardless of
the gateway backend being used, in the same way that DBI provides an consistant
interface to different databases.

See L<http://www.420.am/business-onlinepayment/> for more information and
supported gateways.

It is hoped that a future version of Interchange will do all credit card
processing through Business::OnlinePayment, but this is my no means
guaranteed and the timeframe is unknown.  Think ALSA somewhere around
Linux 2.2 and you've got the general idea.

Currently this module is recommended for people with gateway processors
unsupported by a native Interchange Vend::Payment:: module and for the
adventurous.

=head1 USAGE

To enable this module, place this directive in C<interchange.cfg>:

    Require module Vend::Payment::BusinessOnlinePayment

This I<must> be in interchange.cfg or a file included from it.

The mode can be named anything, but the C<gateway> parameter must be set
to C<onlinepayment>. To make it the default payment gateway for all credit
card transactions in a specific catalog, you can set in C<catalog.cfg>:

    Variable   MV_PAYMENT_MODE  onlinepayment

It uses several of the standard settings from Interchange payment. Any time
we speak of a setting, it is obtained either first from the tag/call options,
then from an Interchange order Route named for the mode, then finally a
default global payment variable, For example, the C<setting> parameter would
be specified by:

    [charge mode=onlinepayment setting=value]

or

    Route onlinepayment setting value

or 

    Variable MV_PAYMENT_SETTING      value

The following settings are available:

=over 4

=item processor

Your Business::OnlinePayment processor.

=item id

Your Business::OnlinePayment login.

=item secret

Your Business::OnlinePayment password.

=item transaction

The type of transaction to be run. Valid values are:

    Interchange         Business::OnlinePayment
    ----------------    -----------------------
        auth            Authorization Only
        return          Credit
        reverse
        sale            Normal Authorization
        settle          Post Authorization
        void            Void

=item test

Set this true if you wish to operate in test mode.  Make sure to verify
that your specific Business::OnlinePayment:: gateway module supports a
test mode.

=back

In addition, any other processor options are passed to your gateway.  See
the documentation for your specific Business::OnlinePayment:: gateway module
for details on what options are required, if any.

=head1 AUTHOR

Ivan Kohler <ivan-interchange@420.am>

Initial development of this module was sponsored in part by Simply Marketing,
Inc. <http://www.simplymarketinginc.com/>.

=head1 COPYRIGHT

Copyright 2004 Ivan Kohler.  All rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

package Vend::Payment;
use strict;
use vars qw( $VERSION );
use Business::OnlinePayment;

$VERSION = '0.01';

my $default_avs = q{You must enter the correct billing address of your credit }.
                  q{card.  The bank returned the following error: %s};

my $default_declined = "error: %s. Please call in your order or try again.";

sub onlinepayment {
  my ($user, $amount) = @_;

  my $opt = {};
  my $secret;

  if ( ref($user) ) {
    $opt = $user;
    $user = $opt->{id};
    $secret = $opt->{secret};
  }

  my $actual = $opt->{actual} || { map_actual() };

  $user ||= charge_param('id')
    or return ( MStatus => 'failure-hard',
                MErrMsg => errmsg('No account id'),
              );

  $secret ||= charge_param('secret');

  my $precision = $opt->{precision} || 2;

  my $referer = $opt->{referer} || charge_param('referer');

  $actual->{$_} = $opt->{$_}
    foreach grep defined($opt->{$_}), qw(
      order_id
      auth_code
      mv_credit_card_exp_month
      mv_credit_card_exp_year
      mv_credit_card_number
    );

  $actual->{mv_credit_card_exp_month} =~ s/\D//g;
  $actual->{mv_credit_card_exp_year} =~ s/\D//g;
  $actual->{mv_credit_card_exp_year} =~ s/\d\d(\d\d)/$1/;
  $actual->{mv_credit_card_number} =~ s/\D//g;

  my $exp = sprintf '%02d/%02d', $actual->{mv_credit_card_exp_month},
                                 $actual->{mv_credit_card_exp_year};

  my %ic2bop = (
    'auth'    =>  'Authorization Only',
    'return'  =>  'Credit',
    #'reverse' =>
    'sale'    =>  'Normal Authorization',
    'settle'  =>  'Post Authorization',
    'void'    =>  'Void',
  );

  my $action = $ic2bop{$opt->{transaction} || 'sale'};

  $amount = $opt->{total_cost} if $opt->{total_cost};
	
  if ( ! $amount ) {
    $amount = Vend::Interpolate::total_cost();
    $amount = Vend::Util::round_to_frac_digits($amount, $precision);
  }

  my $order_id = gen_order_id($opt);

  my $processor = charge_param('processor');

  #processor options!
  my %ignore = map { $_=>1 } qw(gateway processor id secret transaction );
  my %options = map { $_ => ($opt->{$_} || $main::Variable->{"MV_PAYMENT_" . uc $_ }) }
                grep { !$ignore{$_} } (
                                        keys(%$opt),
                                        map { s/^MV_PAYMENT_//; lc($_); }
                                          grep { /^MV_PAYMENT_/ }
                                            keys %$main::Variable
                                      );

  my $transaction =
    new Business::OnlinePayment ( $processor, %options );

  $transaction->test_transaction($opt->{test} || charge_param('test'));

  $actual->{$_} =~ s/[\n\r]//g foreach keys %$actual;

  my %params = (
    'type'            => 'CC',
    'login'           => $user,
    'password'        => $secret,
    'action'          => $action,
    'amount'          => $amount,
    'card_number'     => $actual->{mv_credit_card_number},
    'expiration'      => $exp,
    'cvv2'            => $actual->{cvv2},
    'order_number'    => $actual->{order_id},
    'auth_code'       => $actual->{auth_code},
    'invoice_number'  => $actual->{mv_order_number},
    'last_name'       => $actual->{b_lname},
    'first_name'      => $actual->{b_fname},
    'name'            => $actual->{b_fname}. ' '. $actual->{b_lname},
    'company'         => $actual->{b_company},
    'address'         => $actual->{b_address},
    'city'            => $actual->{b_city},
    'state'           => $actual->{b_state},
    'zip'             => $actual->{b_zip},
    'country'         => $actual->{b_country},
    'ship_last_name'  => $actual->{lname},
    'ship_first_name' => $actual->{fname},
    'ship_name'       => $actual->{fname}. ' '. $actual->{lname},
    'ship_company'    => $actual->{company},
    'ship_address'    => $actual->{address},
    'ship_city'       => $actual->{city},
    'ship_state'      => $actual->{state},
    'ship_zip'        => $actual->{zip},
    'ship_country'    => $actual->{country},
    'referer'         => $referer,
    'email'           => $actual->{email},
    'phone'           => $actual->{phone_day},
  );

=head1 Extra query parameters

=over

=item extra_query_params "customer_id  their_param=our_param"

This allows you to map a passed parameter to the transaction query
of your module. Obviously the module must support it.

The parameter comes from the parameters passed to the [charge ..] tag
or the route.

The above id passes the customer_id parameter on with a key of the
same name, while the second sets their param C<their_param> with 
C<our_param>.

=back

=cut

  my @extra = split /[\s,\0]+/, $opt->{extra_query_params};
  for (@extra) {
      my ( $k, $v ) = split /=/, $_;
      $v ||= $k;
      $params{$k} = $opt->{$v} || charge_param($v);
  }

  $transaction->content(%params);

  $transaction->submit();

  my %result;
  if ( $transaction->is_success() ) {

    $result{MStatus} = 'success';
    $result{'order-id'} = 
      ( $transaction->can('order_number') && $transaction->order_number ) 
      || $opt->{'order_id'};

  } else {

    $result{MStatus} = 'failure';
    delete $result{'order-id'};

    if ( 0 ) { #need a standard Business::OnlinePayment way to ask about AVS
      $result{MErrMsg} = errmsg(
        $opt->{'message_avs'} || $default_avs,
        $transaction->error_message
      )
    } else {
      $result{MErrMsg} = errmsg(
        $opt->{'message_declined'} || "$processor $default_declined",
         $transaction->error_message
      );
    }

  }

=head1 Extra result parameters

=over

=item extra_result_params "transid=weird.module.name"

This allows you to map a returned parameter to the payment result 
hash of Interchange.

=back

=cut

  my @result_extra = split /[\s,\0]+/, $opt->{extra_result_params};
  for (@result_extra) {
      my ( $k, $v ) = split /=/, $_;
      $v ||= $k;
	  if($transaction->can($v)) {
		  $result{$k} = $transaction->$v;
	  }
	  else {
	  	  ::logError(__PACKAGE__ . " - unsupported method %s called for result params, ignored.", $v);
	  }
  }

  return %result;

}

1;

