# Vend::Payment::Signio - Interchange support for Payflow Pro SDK versions 2 and 3
#
# $Id: Signio.pm,v 2.20 2009-03-18 01:59:33 jon Exp $
#
# Copyright (C) 2002-2009 Interchange Development Group
# Copyright (C) 1999-2002 Red Hat, Inc.
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
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA  02110-1301  USA.

package Vend::Payment::Signio;

=head1 NAME

Vend::Payment::Signio - Interchange support for Payflow Pro SDK versions 2 and 3

=head1 WARNING: THIS MODULE IS DEPRECATED!

Please note that PayPal purchased the Payflow Pro business from
Verisign, and this payment module is expected to stop functioning in
September 2009, as it uses the v2/v3 pfpro SDK that will no longer be
supported. Details are here:

 https://cms.paypal.com/us/cgi-bin/?cmd=_render-content&content_ID=developer/library_download_sdks
 http://www.pdncommunity.com/pdn/board/message?board.id=payflow&thread.id=5799

It is strongly recommend that you switch to using
Vend::Payment::PayflowPro as soon as possible, and stop using this
module.

=head1 SYNOPSIS

    &charge=signio

        or

    [charge mode=signio param1=value1 param2=value2]

=head1 PREREQUISITES

Verisign/Signio Payflow Pro, Version 2.10 or higher

=head1 VERISIGN SOFTWARE SETUP

Verisign's interface requires a proprietary binary-only shared library;
thus you must download the appropriate package for your platform from Verisign.
On Linux, the archive you download is F<pfpro_linux.tar.gz>. It includes
documentation you should consult. Here's a brief installation guide for
someone using Linux with root access:

=over 4

=item *

Copy the F<payflowpro/linux/certs> directory to VENDROOT,
your Interchange root directory (perhaps /usr/lib/interchange or
/usr/local/interchange). This contains a single file with the client
SSL certificate required to authenticate with Verisign's https server.

=item *

Install F<payflowpro/linux/lib/libpfpro.so> somewhere on your system
fit for shared libraries, such as /usr/lib, or else in VENDROOT/lib.

=item *

Build the F<PFProAPI.pm> Perl module:

=over 4

=item *

cd payflowpro/linux/perl

=item *

If you installed libpfpro.so somewhere other than in a standard location
for shared libraries on your system, edit line 6 of Makefile.PL, so that
"-L." instead reads "-L/path/to/libpfpro.so" with the correct path.

=item *

perl Makefile.PL && make && make test

=item *

As root, make install

=back

=back

Using PFProAPI.pm is the best way to interact with Payflow Pro. However,
if you can't get it to work for whatever reason, you may also use either
of two small wrapper binaries, pfpro and pfpro-file, designed to be
called from the shell. Interchange must fork and execute the binary, then
retrieve the Verisign response from a temporary file. This module will
automatically fall back to using one of them if it can't find PFProAPI.pm
when Interchange is started.

=head1 DESCRIPTION

The Vend::Payment::Signio module implements the signio() payment routine
for use with Interchange. It is compatible on a call level with the other
Interchange payment modules.

To enable this module, place this directive in F<interchange.cfg>:

    Require module Vend::Payment::Signio

This I<must> be in interchange.cfg or a file included from it.

NOTE: Make sure CreditCardAuto is off (default in Interchange demos).

The mode can be named anything, but the C<gateway> parameter must be set
to C<signio>. To make it the default payment gateway for all credit
card transactions in a specific catalog, you can set in F<catalog.cfg>:

    Variable   MV_PAYMENT_MODE  signio

It uses several of the standard settings from Interchange payment. Any time
we speak of a setting, it is obtained either first from the tag/call options,
then from an Interchange order Route named for the mode, then finally a
default global payment variable. For example, the C<id> parameter would
be specified by:

    [charge mode=signio id=YourPayflowProID]

or

    Route signio id YourPayflowProID

or with only PayflowPro as a payment provider

    Variable MV_PAYMENT_ID      YourPayflowProID

The active settings are:

=over 4

=item id

Your account ID, supplied by VeriSign when you sign up.
Global parameter is MV_PAYMENT_ID.

=item secret

Your account password, selected by you or provided by Verisign when you sign up.
Global parameter is MV_PAYMENT_SECRET.

=item partner

Your account partner, selected by you or provided by Verisign when you
sign up. Global parameter is MV_PAYMENT_PARTNER.

=item vendor

Your account vendor, selected by you or provided by Verisign when you
sign up. Global parameter is MV_PAYMENT_VENDOR.

=item transaction

The type of transaction to be run. Valid values are:

    Interchange         Payflow Pro
    ----------------    -----------------
	sale                S
	auth                A
	credit              C
	void                V
	settle              D (from previous A trans)

Default is C<sale>.

=back 

The following should rarely be used, as the supplied defaults are 
usually correct.

=over 4

=item remap 

This remaps the form variable names to the ones needed by Verisign. See
the C<Payment Settings> heading in the Interchange documentation for use.

=item host

The payment gateway host to use. Default is C<payflow.verisign.com>, and
C<test-payflow.verisign.com> when in test mode.

=item check_sub

Name of a Sub or GlobalSub to be called after the result hash has been
received from Verisign. A reference to the modifiable result hash is
passed into the subroutine, and it should return true (in the Perl truth
sense) if its checks were successful, or false if not.

This can come in handy since, strangely, Verisign has no option to decline
a charge when AVS or CSC data come back negative. See Verisign knowledge
base articles vs2365, vs7779, vs12717, and vs22810 for more details.

If you want to fail based on a bad AVS check, make sure you're only
doing an auth -- B<not a sale>, or your customers would get charged on
orders that fail the AVS check and never get logged in your system!

Add the parameters like this:

	Route  signio  check_sub  avs_check

This is a matching sample subroutine you could put in interchange.cfg:

	GlobalSub <<EOR
	sub avs_check {
		my ($result) = @_;
		my ($addr, $zip) = @{$result}{qw( AVSADDR AVSZIP )};
		return 1 if $addr eq 'Y' or $zip eq 'Y';
		return 1 if $addr eq 'X' and $zip eq 'X';
		return 1 if $addr !~ /\S/ and $zip !~ /\S/;
		$result->{RESULT} = 112;
		$result->{RESPMSG} = "The billing address you entered does not match the cardholder's billing address";
		return 0;
	}
	EOR

That would work equally well as a Sub in catalog.cfg. It will succeed if
either the address or zip is 'Y', or if both are unknown. If it fails,
it sets the result code and error message in the result hash using
Verisign's own (otherwise unused) 112 result code, meaning "Failed AVS
check".

Of course you can use this sub to do any other post-processing you
want as well.

=back

=head2 Troubleshooting

Try the instructions above, then enable test mode. A test order should complete.

Then move to live mode and try a sale with the card number C<4111 1111
1111 1111> and a valid future expiration date. The sale should be denied,
and the reason should be in [data session payment_error].

If it doesn't work:

=over 4

=item *

Make sure you "Require"d the module in interchange.cfg:

    Require module Vend::Payment::Signio

=item *

Make sure the Verisign C<libpfpro.so> shared library was available to
PFProAPI.xs when you built and installed the PFProAPI.pm module, and that
you haven't moved C<libpfpro.so> since then.

If you're not using the PFProAPI Perl interface, make sure the Verisign
C<pfpro> or C<pfpro-file> executable is available either in your path or
in /path_to_interchange/lib.

=item *

Check the error logs, both catalog and global.

=item *

Make sure you set your account ID and secret properly.  

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

If all else fails, consultants are available to help with
integration for a fee. You can find consultants by asking on the
C<interchange-biz@icdevgroup.org> mailing list.

=back

=head1 SECURITY CONSIDERATIONS

Because this library may call an executable, you should ensure that no
untrusted users have write permission on any of the system directories
or Interchange software directories.

=head1 BUGS

There is actually nothing *in* Vend::Payment::Signio. It changes packages
to Vend::Payment and places things there.

=head1 AUTHORS

	Cameron Prince <cameronbprince@yahoo.com>
	Mark Johnson <mark@endpoint.com>
	Mike Heins <mike@perusion.com>
	Jon Jensen <jon@icdevgroup.org>

=cut

package Vend::Payment;

my $PFProAPI_found;
BEGIN {
	eval {
		require PFProAPI;
		$PFProAPI_found = 1;
	};
	if ($PFProAPI_found) {
		print STDERR "PFProAPI module found.\n";
	}
	else {
		print STDERR "PFProAPI module not found; will try to use pfpro binary.\n";
	}
}

sub signio {
#::logDebug("signio called, PFProAPI_found=$PFProAPI_found");
	my ($user, $amount) = @_;

	my $opt;
	my $secret;
	if(ref $user) {
		$opt = $user;
		$user = $opt->{id} || undef;
		$secret = $opt->{secret} || undef;
	}
	else {
		$opt = {};
	}

	my $bin_path = Vend::File::make_absolute_file(charge_param('bin_path'), 1);

	my ($exe, $stdin);
	unless ($PFProAPI_found) {
		my @try;
		push @try, $bin_path if $bin_path;
		push @try,
				"$Global::VendRoot/lib",
				"$Global::VendRoot/bin",
				$Global::VendRoot,
				(grep /\S/, split /:/, $ENV{PATH}),
				;

		for(@try) {
			if(-f "$_/pfpro" and -x _) {
				$exe = "$_/pfpro";
				last;
			}
			next unless -f "$_/pfpro-file" and -x _;
			$exe = "$_/pfpro-file";
			$stdin = 1;
			last;
		}

		if(! $exe ) {
			return (
				MStatus => 'failure-hard',
				MErrMsg => errmsg('pfpro executable not found.'),
				);
		}

		# set loadable module path so not needed in /etc/ld.so.conf
		@try = ();
		$_ = Vend::File::make_absolute_file(charge_param('library_path'), 1);
		push @try, $_ if $_;
		push @try,
				"$Global::VendRoot/lib",
				"$Global::VendRoot/bin",
				$Global::VendRoot,
				charge_param('bin_path') . "/../lib",
				(grep /\S/, split /:/, $ENV{LD_LIBRARY_PATH}),
				;
		$ENV{LD_LIBRARY_PATH} = join ':', @try;
	}

	# set certificate path for modern pfpro
	my $cert_path = charge_param('cert_path');
	if($cert_path) {
		$cert_path = Vend::File::make_absolute_file($cert_path, 1);
		$ENV{PFPRO_CERT_PATH} ||= $cert_path;
	}

	if(! -d $ENV{PFPRO_CERT_PATH} ) {
		my @try;
		push @try, $cert_path if $cert_path;
		push @try,
			$Global::VendRoot,
			"$Global::VendRoot/lib",
			'/usr/local/ssl',
			'/usr/lib/ssl',
			"$bin_path/..",
		;
		for(@try) {
			next unless  -d "$_/certs";
			$ENV{PFPRO_CERT_PATH} = "$_/certs";
			last;
		}
	}

	my %actual;
	if($opt->{actual}) {
		%actual = %{$opt->{actual}};
	}
	else {
		%actual = map_actual();
	}

    if(! $user  ) {
        $user    =  charge_param('id')
						or return (
							MStatus => 'failure-hard',
							MErrMsg => errmsg('No account id'),
							);
    }
#::logDebug("signio user $user");
    if(! $secret) {
        $secret    =  charge_param('secret')
						or return (
							MStatus => 'failure-hard',
							MErrMsg => errmsg('No account password'),
							);
    }

#::logDebug("signio secret $secret");

	my $server;
	my $port;
	if(! $opt->{host} and charge_param('test')) {
		$server = 'test-payflow.verisign.com';
		$port   = 443;
	}
	else {
		# We won't read from MV_PAYMENT_SERVER because that would rarely
		# be right and might often be wrong
		$server  =   $opt->{host}  || 'payflow.verisign.com';
		$port    =   $opt->{port}  || '443';
	}

    $actual{mv_credit_card_exp_month} =~ s/\D//g;
    $actual{mv_credit_card_exp_month} =~ s/^0+//;
    $actual{mv_credit_card_exp_year} =~ s/\D//g;
    $actual{mv_credit_card_exp_year} =~ s/\d\d(\d\d)/$1/;

    $actual{mv_credit_card_number} =~ s/\D//g;

    my $exp = sprintf '%02d%02d',
                        $actual{mv_credit_card_exp_month},
                        $actual{mv_credit_card_exp_year};

    my %type_map = (
        qw/
                        sale          S
                        auth          A
                        authorize     A
                        void          V
                        settle        D
                        settle_prior  D
                        credit        C
                        mauthcapture  S
                        mauthonly     A
                        mauthdelay    D
                        mauthreturn   C
                        S             S
                        C             C
                        D             D
                        V             V
                        A             A
        /
    );

    my $transtype = $opt->{transaction} || charge_param('transaction') || 'S';
	
	$transtype = $type_map{$transtype}
		or return (
				MStatus => 'failure-hard',
				MErrMsg => errmsg('Unrecognized transaction: %s', $transtype),
			);
	

	my $orderID = $opt->{order_id};
	$amount = $opt->{total_cost} if ! $amount;

    if(! $amount) {
		my $precision = $opt->{precision} || charge_param('precision') || 2;
        my $cost      = Vend::Interpolate::total_cost();
        $amount = Vend::Util::round_to_frac_digits($cost, $precision);
    }

    my %varmap = ( qw/
						ACCT		mv_credit_card_number
						CVV2		mv_credit_card_cvv2
						ZIP			b_zip
						STREET		b_address
						SHIPTOZIP	zip
						EMAIL    	email
						COMMENT1	comment1
						COMMENT2	comment2
        /
    );

    my %query = (
                    AMT         => $amount,
                    EXPDATE     => $exp,
                    TENDER      => 'C',
                    PWD         => $secret,
                    USER        => $user,
					TRXTYPE		=> $transtype,
    );

	$query{PARTNER} = $opt->{partner} || charge_param('partner');
	$query{VENDOR}  = $opt->{vendor}  || charge_param('vendor');
	$query{ORIGID} = $orderID if $orderID;

	$orderID ||= gen_order_id($opt);

    for (keys %varmap) {
        $query{$_} = $actual{$varmap{$_}};
    }

    # Force postal codes to upper case and strip everything except
    # upper case + digits, as the Payflow specification requires
    # in p. 23 of PayflowPro_Guide.pdf (00000013/Rev. 7). Stripping
    # here means values can keep spaces or dashes as they really should.
    for my $key (qw( ZIP SHIPTOZIP )) {
        $query{$key} =~ s/[^A-Za-z0-9]//g;
        $query{$key} = uc $query{$key};
    }

#{
#my %munged_query = %query;
#$munged_query{PWD} = 'X';
#$munged_query{ACCT} =~ s/^(\d{4})(.*)/$1 . ('X' x length($2))/e;
#$munged_query{CVV2} =~ s/./X/g;
#$munged_query{EXPDATE} =~ s/./X/g;
#::logDebug("signio query: " . ::uneval(\%munged_query));
#}

	my $timeout = $opt->{timeout} || 10;
	$timeout =~ s/\D//g
		and die "Bad timeout value, security violation.";
	$port =~ s/\D//g
		and die "Bad port value, security violation.";
	$server =~ s/[^-\w.]//g
		and die "Bad server value, security violation.";

	my $resultstr;
	my $result = {};
	my $decline;

	if ($PFProAPI_found) {
		($result, $resultstr) = PFProAPI::pfpro(\%query, $server, $port, $timeout);
#::logDebug("signio PFProAPI call server=$server port=$port timeout=$timeout");
		$decline = $result->{RESULT} != 0;
	}
	else {
		my @query;
		for my $key (keys %query) {
			my $val = $query{$key};
			$val =~ s/["\$\n\r]//g;
			if($val =~ /[&=]/) {
				my $len = length($val);
				$key .= "[$len]";
			}
			push @query, "$key=$val";
		}
		my $string = join '&', @query;

		my $tempfile = "$Vend::Cfg->{ScratchDir}/signio.$orderID";

		if($stdin) {
#::logDebug(qq{signio STDIN call: $exe $server $port - $timeout > $tempfile});
			open(PFPRO, "| $exe $server $port - $timeout > $tempfile")
				or die "exec pfpro-file: $!\n";
			print PFPRO $string;
			close PFPRO;
		}
		else {
#::logDebug(qq{signio call: $exe $server $port "$string" $timeout > $tempfile});
			system(qq{$exe $server $port "$string" $timeout > $tempfile});
		}

		$decline = $? >> 8;

		open(CONNECT, "< $tempfile")
			or die ::errmsg("open %s: %s\n", $tempfile, $!);

		$resultstr = join "", <CONNECT>;
		close CONNECT;

		unlink $tempfile;

    	%$result = split /[&=]/, $resultstr;
	}
#::logDebug(qq{signio decline=$decline result: $resultstr});

	if (
		! $decline and 
		my $check_sub_name = $opt->{check_sub} || charge_param('check_sub')
	) {
		my $check_sub = $Vend::Cfg->{Sub}{$check_sub_name}
			|| $Global::GlobalSub->{$check_sub_name};
		if (ref $check_sub eq 'CODE') {
			$decline = ! $check_sub->($result);
#::logDebug(qq{signio called check_sub sub=$check_sub_name decline=$decline});
		}
		else {
			logError("signio: non-existent check_sub routine %s.", $check_sub_name);
		}
	}

    my %result_map = ( qw/
            MStatus               ICSTATUS
            pop.status            ICSTATUS
            order-id              PNREF
            pop.order-id          PNREF
            pop.auth-code         AUTHCODE
            pop.avs_code          AVSZIP
            pop.avs_zip           AVSZIP
            pop.avs_addr          AVSADDR
    /
    );

    if ($decline) {
        $result->{ICSTATUS} = 'failed';
		my $msg = errmsg("Charge error: %s Reason: %s. Please call in your order or try again.",
			$result->{RESULT} || 'no details available',
			$result->{RESPMSG} || 'unknown error',
		);
		$result->{MErrMsg} = $result{'pop.error-message'} = $msg;
    }
    else {
        $result->{ICSTATUS} = 'success';
    }

    for (keys %result_map) {
        $result->{$_} = $result->{$result_map{$_}}
            if defined $result->{$result_map{$_}};
    }

#::logDebug(qq{signio decline=$decline result: } . ::uneval($result));

    return %$result;
}

*verisign = \&signio;

package Vend::Payment::Signio;

1;
