# Vend::Payment - Interchange payment processing routines
#
# $Id: Payment.pm,v 2.19.2.1 2008-07-16 00:39:24 mheins Exp $
#
# Copyright (C) 2002-2007 Interchange Development Group
# Copyright (C) 1996-2002 Red Hat, Inc.
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

package Vend::Payment;
require Exporter;

$VERSION = substr(q$Revision: 2.19.2.1 $, 10);

@ISA = qw(Exporter);

@EXPORT = qw(
				charge
				charge_param
		);

@EXPORT_OK = qw(
				map_actual
				);

use Vend::Util;
use Vend::Interpolate;
use Vend::Order;
use strict;

use vars qw/%order_id_check/;
use vars qw/$Have_LWP $Have_Net_SSLeay/;

my $pay_opt;

my %cyber_remap = (
	qw/
		configfile CYBER_CONFIGFILE
        id         CYBERCASH_ID
        mode       CYBER_MODE
        host       CYBER_HOST
        port       CYBER_PORT
        remap      CYBER_REMAP
        currency   CYBER_CURRENCY
        precision  CYBER_PRECISION
	/
);

my %ignore_mv_payment = (
	qw/
		gateway 1
	/
);

sub charge_param {
	my ($name, $value, $mode) = @_;
	my $opt;

	if($mode) {
		$opt = $Vend::Cfg->{Route_repository}{$mode} ||= {};
	}
	else {
		$opt = $pay_opt ||= {};
	}

	if($name =~ s/^mv_payment_//i) {
		$name = lc $name;
	}

	if(defined $value) {
		return $pay_opt->{$name} = $value;
	}

	# Find if set in route or options
	return $opt->{$name}		if defined $opt->{$name};

	# "gateway" and possibly other future options
	return undef if $ignore_mv_payment{$name};

	# Now check Variable space as last resort
	my $uname = "MV_PAYMENT_\U$name";

	return $::Variable->{$uname} if defined $::Variable->{$uname};
	return $::Variable->{$cyber_remap{$name}}
		if defined $::Variable->{$cyber_remap{$name}};
	return undef;
}

# Do remapping of payment variables submitted by user
# Can be changed/extended with remap/MV_PAYMENT_REMAP
sub map_actual {
	my ($vref, $cref) = (@_);
	$vref = $::Values		unless $vref;
	$cref = \%CGI::values	unless $cref;
	my @map = qw(

		address
		address1
		address2
		amount
		b_address
		b_address1
		b_address2
		b_city
		b_country
		b_company
		b_fname
		b_lname
		b_name
		b_state
		b_zip
		check_account
		check_acctname
		check_accttype
		check_bankname
		check_checktype
		check_dl
		check_magstripe
		check_number
		check_routing
		check_transit
		city
		comment1
		comment2
		corpcard_type
		country
		cvv2
		email
		company
		fname
		item_code
		item_desc
		lname
		mv_credit_card_cvv2
		mv_credit_card_exp_month
		mv_credit_card_exp_year
		mv_credit_card_number
		mv_order_number
		mv_transaction_id
		name
		origin_zip
		phone_day
		phone_night
		pin
		po_number
		salestax
		shipping
		state
		tax_duty
		tax_exempt
		tender
		zip
	);

	my %map = qw(
		cyber_mode                  mv_cyber_mode
		comment                  giftnote
	);
	@map{@map} = @map;

	# Allow remapping of the variable names
	my $remap;
	if( $remap	= charge_param('remap') ) {
		$remap =~ s/^\s+//;
		$remap =~ s/\s+$//;
		my (%remap) = split /[\s=]+/, $remap;
		for (keys %remap) {
			$map{$_} = $remap{$_};
		}
	}

	my %actual;
	my $key;

	my %billing_set;
	my @billing_set = qw/
							b_address1
							b_address2
							b_address3
							b_city
							b_state
							b_zip
							b_country
						/;

	my @billing_ind = qw/
							b_address1
							b_city
						/;

	if(my $str = $::Variable->{MV_PAYMENT_BILLING_SET}) {
		@billing_set = grep $_ !~ /\W/, split /[\s,\0]+/, $str;
	}
	if(my $str = $::Variable->{MV_PAYMENT_BILLING_INDICATOR}) {
		@billing_ind = grep $_ !~ /\W/, split /[\s,\0]+/, $str;
	}

	@billing_set{@billing_set} = @billing_set;

	my $no_billing_xfer = 1;

	for(@billing_ind) {
		$no_billing_xfer = 0  unless length($vref->{$_});
	}

	# pick out the right values, need alternate billing address
	# substitution
	foreach $key (keys %map) {
		$actual{$key} = $vref->{$map{$key}} || $cref->{$key};
		my $secondary = $key;
		next unless $secondary =~ s/^b_//;
		if ($billing_set{$key}) {
			next if $no_billing_xfer;
			$actual{$key} = $vref->{$secondary};
			next;
		}
		next if $actual{$key};
		$actual{$key} = $vref->{$map{$secondary}} || $cref->{$map{$secondary}};
	}

	$actual{name}		 = "$actual{fname} $actual{lname}"
		if $actual{lname};
	$actual{b_name}		 = "$actual{b_fname} $actual{b_lname}"
		if $actual{b_lname};
	if($actual{b_address1}) {
		$actual{b_address} = "$actual{b_address1}";
		$actual{b_address} .=  ", $actual{b_address2}"
			if $actual{b_address2};
	}
	if($actual{address1}) {
		$actual{address} = "$actual{address1}";
		$actual{address} .=  ", $actual{address2}"
			if $actual{address2};
	}

	# Do some standard processing of credit card expirations
	$actual{mv_credit_card_exp_month} =~ s/\D//g;
	$actual{mv_credit_card_exp_month} =~ s/^0+//;
	$actual{mv_credit_card_exp_year} =~ s/\D//g;
	$actual{mv_credit_card_exp_year} =~ s/\d\d(\d\d)/$1/;

	$actual{mv_credit_card_reference} = $actual{mv_credit_card_number} =~ s/\D//g;
	$actual{mv_credit_card_reference} =~ s/^(\d\d).*(\d\d\d\d)$/$1**$2/;

    $actual{mv_credit_card_exp_all} = sprintf(
                                        '%02d/%02d',
                                        $actual{mv_credit_card_exp_month},
                                        $actual{mv_credit_card_exp_year},
                                      );

	$actual{cyber_mode} = charge_param('transaction')
						||	$actual{cyber_mode}
						|| 'mauthcapture';
	
	return %actual;
}

%order_id_check = (
	cybercash => sub {
					my $val = shift;
					# The following characters are illegal in a CyberCash order ID:
					#    : < > = + @ " % = &
					$val =~ tr/:<>=+\@\"\%\&/_/d;
					return $val;
				},
);

sub gen_order_id {
	my $opt = shift || {};
	if( $opt->{order_id}) {
		# do nothing, already set
	}
	elsif($opt->{counter}) {
		$opt->{order_id} = Vend::Interpolate::tag_counter(
						$opt->{counter},
						{ start => $opt->{counter_start} || 100000,
						  sql   => $opt->{sql_counter},
						},
					);
	}
	else {
		my(@t) = gmtime(time());
		my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = @t;
		$opt->{order_id} = POSIX::strftime("%y%m%d%H%M%S$$", @t);

	}

	if (my $check = $order_id_check{$opt->{gateway}}) {
		$opt->{order_id} = $check->($opt->{order_id});
	}

	return $opt->{order_id};
}

sub charge {
	my ($charge_type, $opt) = @_;

	my $pay_route;

	### We get the payment base information from a route with the
	### same name as $charge_type if it is there
	if($Vend::Cfg->{Route}) {
		$pay_route = $Vend::Cfg->{Route_repository}{$charge_type} || {};
	}
	else {
		$pay_route = {};
	}

	### Then we take any payment options set in &charge, [charge ...],
	### or $Tag->charge

	# $pay_opt is package-scoped but lexical
	$pay_opt = { %$pay_route };
	for(keys %$opt) {
		$pay_opt->{$_} = $opt->{$_};
	}

	# We relocate these to subroutines to standardize

	### Maps the form variable names to the names needed by the routine
	### Standard names are defined ala Interchange or MV4.0x, b_name, lname,
	### etc. with b_varname taking precedence for these. Falls back to lname
	### if the b_lname is not set
	my (%actual) = map_actual();
	$pay_opt->{actual} = \%actual;

	# We relocate this to a subroutine to standardize. Uses the payment
	# counter if there
	my $orderID = gen_order_id($pay_opt);

	### Set up the amounts. The {amount} key will have the currency prepended,
	### ala CyberCash (i.e. "usd 19.95"). {total_cost} has just the cost.

	# Uses the {currency} -> MV_PAYMENT_CURRENCY options if set
	my $currency =  charge_param('currency')
					|| ($Vend::Cfg->{Locale} && $Vend::Cfg->{Locale}{currency_code})
					|| 'usd';

	# Uses the {precision} -> MV_PAYMENT_PRECISION options if set
	my $precision = charge_param('precision') || 2;
	my $penny     = charge_param('penny_pricing') || 0;

	my $amount = $pay_opt->{amount} || Vend::Interpolate::total_cost();
	$amount = round_to_frac_digits($amount, $precision);
	$amount = sprintf "%.${precision}f", $amount;
	$amount *= 100 if $penny;

	$pay_opt->{total_cost} = $amount;
	$pay_opt->{amount} = "$currency $amount";

	### 
	### Finish setting amounts and currency

	# If we have a previous payment amount, delete it but push it on a stack
	# 
	my $stack = $Vend::Session->{payment_stack} || [];
	delete $Vend::Session->{payment_result}; 
	delete $Vend::Session->{cybercash_result}; ### Deprecated

#::logDebug("Called charge at " . scalar(localtime));
#::logDebug("Charge caller is " . join(':', caller));

#::logDebug("mode=$pay_opt->{gateway}");
#::logDebug("pay_opt=" . ::uneval($pay_opt));
	# Default to the gateway same as charge type if no gateway specified,
	# and set the gateway in the session for logging on completion
	if(! $opt->{gateway}) {
		$pay_opt->{gateway} = charge_param('gateway') || $charge_type;
	}
	#$charge_type ||= $pay_opt->{gateway};
	$Vend::Session->{payment_mode} = $pay_opt->{gateway};

	# See if we are in test mode
	$pay_opt->{test} = charge_param('test');

	# just convenience
	my $gw = $pay_opt->{gateway};

	# See if we are calling a defined GlobalSub payment mode
	my $sub = $Global::GlobalSub->{$gw};

	# Try our predefined modes
	if (! $sub and defined &{"Vend::Payment::$gw"} ) {
		$sub = \&{"Vend::Payment::$gw"};
	}

	# This is the return from all routines
	my %result;

	if($sub) {
#::logDebug("Charge sub");
		# Calling a defined GlobalSub payment mode
		# Arguments are the passed option hash (if any) and the route hash
		eval {
			%result = $sub->($pay_opt);
		};
		if($@) {
			my $msg = errmsg(
						"payment routine '%s' returned error: %s",
						$charge_type,
						$@,
			);
			::logError($msg);
			$result{MStatus} = 'died';
			$result{MErrMsg} = $msg;
		}
	}
	elsif($charge_type =~ /^\s*custom\s+(\w+)(?:\s+(.*))?/si) {
#::logDebug("Charge custom");
		# MV4 and IC4.6.x methods
		my (@args);
		@args = Text::ParseWords::shellwords($2) if $2;
		if(! defined ($sub = $Global::GlobalSub->{$1}) ) {
			::logError("bad custom payment GlobalSub: %s", $1);
			return undef;
		}
		eval {
			%result = $sub->(@args);
		};
		if($@) {
			my $msg = errmsg(
						"payment routine '%s' returned error: %s",
						$charge_type,
						$@,
			);
			::logError($msg);
			$result{MStatus} = $msg;
		}
	}
	elsif (
			$actual{cyber_mode} =~ /^minivend_test(?:_(.*))?/
				or 
			$charge_type =~ /^internal_test(?:[ _]+(.*))?/
		  )
	{
#::logDebug("Internal test");

		# Test mode....

		my $status = $1 || charge_param('result') || undef;
		# Interchange test mode
		my %payment = ( %$pay_opt );
		&testSetServer ( %payment );
		%result = testsendmserver(
			$actual{cyber_mode},
			'Order-ID'     => $orderID,
			'Amount'       => $amount,
			'Card-Number'  => $actual{mv_credit_card_number},
			'Card-Name'    => $actual{b_name},
			'Card-Address' => $actual{b_address},
			'Card-City'    => $actual{b_city},
			'Card-State'   => $actual{b_state},
			'Card-Zip'     => $actual{b_zip},
			'Card-Country' => $actual{b_country},
			'Card-Exp'     => $actual{mv_credit_card_exp_all}, 
		);
		$result{MStatus} = $status if defined $status;
	}
	elsif ($Vend::CC3) {
#::logDebug("Charge legacy cybercash");
		### Deprecated
		eval {
			%result = cybercash($pay_opt);
		};
		if($@) {
			my $msg = errmsg( "CyberCash died: %s", $@ );
			::logError($msg);
			$result{MStatus} = $msg;
		}
	}
	else {
#::logDebug("Unknown charge type");
		my $msg = errmsg("Unknown charge type: %s", $charge_type);
		::logError($msg);
		$result{MStatus} = $msg;
	}

	push @$stack, \%result;
	$Vend::Session->{payment_result} = \%result;
	$Vend::Session->{payment_stack}  = $stack;

	my $svar = charge_param('success_variable') || 'MStatus';
	my $evar = charge_param('error_variable')   || 'MErrMsg';

	if($result{$svar} !~ /^success/) {
		$Vend::Session->{payment_error} = $result{$evar};
		$Vend::Session->{errors}{mv_credit_card_valid} = $result{$evar};
		$result{'invalid-order-id'} = delete $result{'order-id'}
			if $result{'order-id'};
	}
	elsif($result{$svar} =~ /success-duplicate/) {
		$Vend::Session->{payment_error} = $result{$evar};
		$result{'invalid-order-id'} = delete $result{'order-id'}
			if $result{'order-id'};
	}
	else {
		delete $Vend::Session->{payment_error};
	}

	$Vend::Session->{payment_id} = $result{'order-id'};

	my $encrypt = charge_param('encrypt');

	if($encrypt and $CGI::values{mv_credit_card_number} and $Vend::Cfg->{EncryptKey}) {
		my $prog = charge_param('encrypt_program') || $Vend::Cfg->{EncryptProgram};
		if($prog =~ /pgp|gpg/) {
			$CGI::values{mv_credit_card_force} = 1;
			(
				undef,
				$::Values->{mv_credit_card_info},
				$::Values->{mv_credit_card_exp_month},
				$::Values->{mv_credit_card_exp_year},
				$::Values->{mv_credit_card_exp_all},
				$::Values->{mv_credit_card_type},
				$::Values->{mv_credit_card_error}
			)	= encrypt_standard_cc(\%CGI::values);
		}
	}
	::logError(
				"Order id for charge type %s: %s",
				$charge_type,
				$Vend::Session->{cybercash_id},
			)
		if $pay_opt->{log_to_error};

	# deprecated
	for(qw/ id error result /) {
		$Vend::Session->{"cybercash_$_"} = $Vend::Session->{"payment_$_"};
	}

	return \%result if $pay_opt->{hash};
	return $result{'order-id'};
}

sub testSetServer {
	my %options = @_;
	my $out = '';
	for(sort keys %options) {
		$out .= "$_=$options{$_}\n";
	}
	logError("Test CyberCash SetServer:\n%s\n" , $out);
	1;
}

sub testsendmserver {
	my ($type, %options) = @_;
	my $out ="type=$type\n";
	for(sort keys %options) {
		$out .= "$_=$options{$_}\n";
	}
	logError("Test CyberCash sendmserver:\n$out\n");
	my $oid;
	eval {
		$oid = Vend::Interpolate::tag_counter(
					"$Vend::Cfg->{ScratchDir}/internal_test.payment.number"
					);
	};
	return ('MStatus', 'success', 'order-id', $oid || 'COUNTER_FAILED');
}

sub post_data {
	my ($opt, $query) = @_;

	unless ($opt->{use_wget} or $Have_Net_SSLeay or $Have_LWP) {
		die "No Net::SSLeay or Crypt::SSLeay found.\n";
	}

	my $submit_url = $opt->{submit_url};
	my $server;
	my $port = $opt->{port} || 443;
	my $script;
	my $protocol = $opt->{protocol} || 'https';
	if($submit_url) {
		$server = $submit_url;
		$server =~ s{^https://}{}i;
		$server =~ s{(/.*)}{};
		$port = $1 if $server =~ s/:(\d+)$//;
		$script = $1;
	}
	elsif ($opt->{host}) {
		$server = $opt->{host};
		$script = $opt->{script};
		$script =~ s:^([^/]):/$1:;
		$submit_url = join "",
						$protocol,
						'://',
						$server,
						($port ? ":$port" : ''),
						$script,
						;
	}
	my %header = ( 'User-Agent' => "Vend::Payment (Interchange version $::VERSION)");
	if($opt->{extra_headers}) {
		for(keys %{$opt->{extra_headers}}) {
			$header{$_} = $opt->{extra_headers}{$_};
		}
	}

	my %result;
	if($opt->{use_wget}) {
		## Don't worry about OS independence with UNIX wget
		my $bdir = "$Vend::Cfg->{ScratchDir}/wget";

		unless (-d $bdir) {
			mkdir $bdir, 0777
				or do {
					my $msg = "Failed to create directory %s: %s";
					$msg = errmsg($msg, $bdir, $!);
					logError($msg);
					die $msg;
				};
		}

		my $filebase = "$Vend::SessionID.wget";
		my $statfile = Vend::File::get_filename("$filebase.stat", 1, 1, $bdir);
		my $outfile  = Vend::File::get_filename("$filebase.out", 1, 1, $bdir);
		my $infile   = Vend::File::get_filename("$filebase.in", 1, 1, $bdir);
		my $cmd = $opt->{use_wget} =~ m{/} ? $opt->{use_wget} : 'wget';

		my @post;
		while( my ($k,$v) = each %$query ) {
			$k = hexify($k);
			$v = hexify($v);
			push @post, "$k=$v";
		}
		my $post = join "&", @post;
		open WIN, "> $infile"
			or die errmsg("Cannot create wget post input file %s: %s", $infile, $!) . "\n";
		print WIN $post;
		local($/);

		my @args = $cmd;
		push @args, "--output-file=$statfile";
		push @args, "--output-document=$outfile";
		push @args, "--server-response";
		push @args, "--post-file=$infile";
		push @args, $submit_url;
		system @args;
#::logDebug("wget cmd line: " . join(" ", @args));
		if($?) {
			$result{reply_os_error} = $!;
			$result{reply_os_status} = $?;
			$result{result_page} = 'FAILED';
		}
		else {
#::logDebug("wget finished.");
			open WOUT, "< $outfile"
				or die errmsg("Cannot read wget output from %s: %s", $outfile, $!) . "\n";
			$result{result_page} = <WOUT>;
			close WOUT
				or die errmsg("Cannot close wget output %s: %s", $outfile, $!) . "\n";
			unlink $outfile unless $opt->{debug};
		}

		seek(WIN, 0, 0)
			or die errmsg("Cannot seek on wget input file %s: %s", $infile, $!) . "\n";
		unless($opt->{debug}) {
			my $len = int(length($post) / 8) + 1;
			print WIN 'deadbeef' x $len;
		}

		close WIN
			or die errmsg("Cannot close wget post input file %s: %s", $infile, $!) . "\n";
		unlink $infile unless $opt->{debug};
		open WSTAT, "< $statfile"
			or die errmsg("Cannot read wget status from %s: %s", $statfile, $!) . "\n";
		my $err = <WSTAT>;
		close WSTAT
			or die errmsg("Cannot close wget status %s: %s", $statfile, $!) . "\n";

		unlink $statfile unless $opt->{debug};
		$result{wget_output} = $err;
		$err =~ s/.*HTTP\s+request\s+sent,\s+awaiting\s+response[.\s]*//s;
		my @raw = split /\r?\n/, $err;
		my @head;
		for(@raw) {
			s/^\s*\d+\s*//
				or last;
			push @head, $_;
		}
		$result{status_line} = shift @head;
		$result{status_line} =~ /^HTTP\S+\s+(\d+)/
			and $result{response_code} = $1;
		$result{header_string} = join "\n", @head;
	}
	elsif($opt->{use_net_ssleay} or ! $opt->{use_crypt_ssl} && $Have_Net_SSLeay) {
#::logDebug("placing Net::SSLeay request: host=$server, port=$port, script=$script");
#::logDebug("values: " . ::uneval($query) );
		my ($page, $response, %reply_headers)
                = post_https(
					   $server, $port, $script,
                	   make_headers( %header ),
                       make_form(    %$query ),
					);
		my $header_string = '';

		for(keys %reply_headers) {
			$header_string .= "$_: $reply_headers{$_}\n";
		}
#::logDebug("received Net::SSLeay header: $header_string");
		$result{status_line} = $response;
		$result{status_line} =~ /^HTTP\S+\s+(\d+)/
			and $result{response_code} = $1;
		$result{header_string} = $header_string;
		$result{result_page} = $page;
	}
	else {
		my @query = %{$query};
		my $ua = new LWP::UserAgent;
		my $req = POST($submit_url, \@query, %header);
#::logDebug("placing LWP request: " . ::uneval_it($req) );
		my $resp = $ua->request($req);
		$result{status_line} = $resp->status_line();
		$result{status_line} =~ /(\d+)/
			and $result{response_code} = $1;
		$result{header_string} = $resp->as_string();
		$result{header_string} =~ s/\r?\n\r?\n.*//s;
#::logDebug("received LWP header: $header_string");
		$result{result_page} = $resp->content();
	}
#::logDebug("returning thing: " . ::uneval(\%result) );
	return \%result;
}


1;
__END__
