#!/usr/bin/perl
#
# MiniVend version 4.0
#
# $Id: Order.pm,v 1.2 2000-06-05 05:35:59 heins Exp $
#
# Copyright 1996-2000 by Michael J. Heins <mikeh@minivend.com>
#
# This program was originally based on Vend 0.2
# Copyright 1995 by Andrew M. Wilcox <awilcox@world.std.com>
#
# Portions from Vend 0.3
# Copyright 1995 by Andrew M. Wilcox <awilcox@world.std.com>
#
# CyberCash 3 native mode enhancements made by and
# Copyright 1998 by Michael C. McCune <mmccune@ibm.net>
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
# Software Foundation, Inc., 59 Temple Place, Suite 330, Boston,
# MA  02111-1307  USA.

package Vend::Order;
require Exporter;

$VERSION = substr(q$Revision: 1.2 $, 10);

@ISA = qw(Exporter);

@EXPORT = qw (

add_items
check_order
check_required
cyber_charge
encrypt_standard_cc
mail_order
send_mail
onfly
route_order
validate_whole_cc

);

use Vend::Util;
use Vend::Interpolate;
use Vend::Session;
use Vend::Data;
use Text::ParseWords;

my @Errors = ();
my $Fatal = 0;
my $Final = 0;
my $Success;
my $Profile;
my $Fail_page;
my $Success_page;

sub _fatal {
	$Fatal = ( defined($_[1]) && ($_[1] =~ /^[yYtT1]/) ) ? 1 : 0;
}

sub _final {
	$Final = ( defined($_[1]) && ($_[1] =~ /^[yYtT1]/) ) ? 1 : 0;
}

sub _return {
	$Success = ( defined($_[1]) && ($_[1] =~ /^[yYtT1]/) ) ? 1 : 0;
}



sub _format {
	my($ref, $params, $message) = @_;
	no strict 'refs';
	my ($routine, $var, $val) = split /\s+/, $params, 3;

	return (undef, $var, "No format check routine for '$routine'")
		unless defined &{"_$routine"};

	my (@return) = &{'_' . $routine}($ref,$var,$val);
	if(! $return[0] and $message) {
		$return[2] = $message;
	}
	return @return;
}

sub chain_checks {
	my ($or, $ref, $checks, $err) = @_;
	my ($var, $val, $mess);
	my $result = 1;
	$mess = "$checks $err";
	while($mess =~ s/(\S+=\w+)[\s,]*//) {
		my $check = $1;
#::logDebug("chain check $check, remaining '$mess'");
		($val, $var, $message) = do_check($check);
#::logDebug("chain check $check result: var=$var val=$val mess='$mess'");
		return undef if ! defined $var;
		if($val and $or) {
			1 while $mess =~ s/(\S+=\w+)[\s,]*//;
#::logDebug("chain check $check or succeeded, returning '$val'");
			return ($val, $var, $message)
		}
		elsif ($val) {
#::logDebug("chain check $check and succeeded, remaining '$mess'");
			$result = 1;
			next;
		}
		else {
#::logDebug("chain check $check or=$or failed, remaining '$mess'");
			next if $or;
			1 while $mess =~ s/(\S+=\w+)[\s,]*//;
#::logDebug("chain check $check and returning failed, var=$var val=$val mess='$mess'");
			return($val, $var, $mess);
		}
	}
#::logDebug("chain check $check returning, var=$var val=$val mess='$mess'");
	return ($val, $var, $mess);
}

sub _and_check {
	return chain_checks(0, @_);
}

sub _or_check {
	return chain_checks(1, @_);
}

sub _charge {
	my ($ref, $params, $message) = @_;
#::logDebug("called _charge: ref=$ref params=$params message=$message");
	my $result;
	eval {
		$result = charge($params);
	};
	if($@) {
		::logError("Fatal error on charge operation '%s': %s", $params, $@);
		$message = "Error on charge operation.";
	}
	elsif(! $result) {
		$message = "Charge operation '$ref->{mv_cyber_mode}' failed" if ! $message;
	}
#::logDebug("charge result: result=$result params=$params message=$message");
	return ($result, $params, $message);
}

sub _credit_card {
	my($ref, $params) = @_;
	my $sub;
	if($params =~ s/\s+keep//i) {
		my (%cgi) = %$ref;
		$ref = \%cgi;
	}
	if(! $params || $params =~ /^standard$/i ) {
		$sub = \&encrypt_standard_cc;
	}
	elsif(! defined ($sub = $Global::GlobalSub->{$params}) ) {
		::logError("bad credit card check GlobalSub: %s", $params);
		return undef;
	}
	eval {
		@{$::Values}{ qw/
					mv_credit_card_valid
					mv_credit_card_info
					mv_credit_card_exp_month
					mv_credit_card_exp_year
					mv_credit_card_exp_all
					mv_credit_card_type
					mv_credit_card_reference
					mv_credit_card_error
					/}
				= $sub->($ref);
	};
	if($@) {
		::logError("credit card check GlobalSub %s error: %s", $params, $@);
		return undef;
	}
	elsif(! $::Values->{mv_credit_card_valid}) {
		return (0, 'mv_credit_card_valid', $::Values->{mv_credit_card_error});
	}
	else {
		return (1, 'mv_credit_card_valid');
	}
}

my %Parse = (

	'&charge'       =>	\&_charge,
	'&credit_card'  =>	\&_credit_card,
	'&return'       =>	\&_return,
	'&fatal'       	=>	\&_fatal,
	'&and'       	=>	\&_and_check,
	'&or'       	=>	\&_or_check,
	'&format'		=> 	\&_format,
	'&success'		=> 	sub { $Success_page = $_[1] },
	'&fail'         =>  sub { $Fail_page    = $_[1] },
	'&final'		=>	\&_final,
	'&test'			=>	sub {		
								my($ref,$params) = @_;
								$params =~ s/\s+//g;
								return $params;
							},
	'&set'			=>	sub {		
								my($ref,$params) = @_;
								my ($var, $value) = split /\s+/, $params, 2;
								$::Values->{$var} = $value;
							},
	'&setcheck'			=>	sub {		
								my($ref,$params) = @_;
								my ($var, $value) = split /\s+/, $params, 2;
								$::Values->{$var} = $value;
								return ($value, $var, "$var set failed.");
							},
);

sub valid_exp_date {
	my ($expire) = @_;
	my $month;
	my $year;
	if($expire) {
		$expire =~ /(\d\d?)(.*)/;
		$month = $1;
		$year = $2;
		$year =~ s/\D+//;
	}
	else {
		$month = $CGI::values{mv_credit_card_exp_month};
		$year = $CGI::values{mv_credit_card_exp_year};
	}
#::logDebug("check exp: mon=$month year=$year");
	return '' if $month !~ /^\d+$/ || $year !~ /^\d+$/;
	return '' if $month <1 || $month > 12;
	$year += ($year < 70) ? 2000 : 1900 if $year < 1900;
	my (@now) = localtime();
	$now[5] += 1900;
	return '' if ($year < $now[5]) || ($year == $now[5] && $month <= $now[4]);
	return 1;
}

sub validate_whole_cc {
	my($mess) = join " ", @_;
	$mess =~ s:[^\sA-Za-z0-9/]::g ;
	my (@tok) = split /\s+/, $mess;
	my($num,$expire) = ('', '', '');
	for(@tok) {
		next if /^[A-Za-z]/;
		$num .= $_ if /^\d+$/;
		$expire = $_ if m:/: ;
	}
	return 0 unless valid_exp_date($expire);
	return luhn($num);

}

=head1 Validate credit card routine

=head1 AUTHOR

Jon Orwant, from Business::CreditCard and well-known algorithms

=cut

sub luhn {
    my ($number) = @_;
    my ($i, $sum, $weight);

    $number =~ s/\D//g;

    return 0 unless length($number) >= 13 && 0+$number;

    for ($i = 0; $i < length($number) - 1; $i++) {
        $weight = substr($number, -1 * ($i + 2), 1) * (2 - ($i % 2));
        $sum += (($weight < 10) ? $weight : ($weight - 9));
    }

    return 1 if substr($number, -1) == (10 - $sum % 10) % 10;
    return 0;
}


# Encrypts a credit card number with DES or the like
# Prefers internal Des module, if was included
sub encrypt_cc {
	my($enclair) = @_;
	my($encrypted, $status, $cmd);
	my $infile    = 0;

	$cmd = $Vend::Cfg->{EncryptProgram};
	$cmd = '' if "\L$cmd" eq 'none';

	my $tempfile = $Vend::SessionID . '.cry';

	#Substitute the filename
	if ($cmd =~ s/%f/$tempfile/) {
		$infile = 1;
	}

	# Want the whole file
	local($/) = undef;

	# Send the CC to a tempfile if incoming
	if($infile) {
		open(CARD, ">$tempfile") ||
			die "Couldn't write $tempfile: $!\n";
		# Put the cardnumber there, and maybe password first
		$enclair .= "\r\n\cZ\r\n" if $Global::Windows;
		print CARD $enclair;
		close CARD;

		# Encrypt the string, but key on arg line will be exposed
		# to ps(1) for systems that allow it
		open(CRYPT, "$cmd |") || die "Couldn't fork: $!\n";
		chomp($encrypted = <CRYPT>);
		close CRYPT;
		$status = $?;
	}
	else {
		$cmd = "| $cmd " if $cmd;
		open(CRYPT, "$cmd>$tempfile ") || die "Couldn't fork: $!\n";
		print CRYPT $enclair;
		close CRYPT;
		$status = $cmd ? $? : 0;

		open(CARD, $tempfile) || warn "open $tempfile: $!\n";
		$encrypted = <CARD>;
		close CARD;
	}

	unlink $tempfile;

	# This means encryption failed
	if( $status != 0 ) {
		::logGlobal({}, "Encryption error: %s", $!);
		return undef;
	}

	$encrypted;
}

# Takes a reference to a hash (usually %CGI::values) that contains
# the following:
# 
#    mv_credit_card_number      The actual credit card number
#    mv_credit_card_exp_all     A combined expiration MM/YY
#    mv_credit_card_exp_month   Month only, used if _all not present
#    mv_credit_card_exp_year    Year only, used if _all not present
#    mv_credit_card_type        A = Amex, D = Discover, etc. Attempts
#                               to guess from number if not there
#    mv_credit_card_separate    Causes mv_credit_card_info to contain only number, must
#                               then develop expiration from the above

sub encrypt_standard_cc {
	my($ref, $nodelete) = @_;
	my($valid, $info);

	my $month	= $ref->{mv_credit_card_exp_month}	|| '';
	my $type	= $ref->{mv_credit_card_type}		|| '';
	my $num		= $ref->{mv_credit_card_number}		|| '';
	my $year	= $ref->{mv_credit_card_exp_year}	|| '';
	my $all		= $ref->{mv_credit_card_exp_all}	|| '';
	my $force	= $ref->{mv_credit_card_force}		|| '';
	my $separate = $ref->{mv_credit_card_separate}  || '';

	for ( qw (	mv_credit_card_type		mv_credit_card_number
				mv_credit_card_exp_year	mv_credit_card_exp_month
				mv_credit_card_exp_separate mv_credit_card_exp_reference
				mv_credit_card_exp_all  mv_credit_card_force))
	{
		next unless defined $ref->{$_};
		delete $ref->{$_} unless $nodelete;
	}

	# remove unwanted chars from card number
	$num =~ tr/0-9//cd;

#::logDebug ("encrypt_standard_cc: $num $month/$year $type");
	# error will be pushed on this if present
	@return = (
				'',			# 0- Whether it is valid
				'',			# 1- Encrypted credit card information
				'',			# 2- Month
				'',			# 3- Year
				'',			# 4- Month/year
				'',         # 5- type
				'',         # 6- Reference number in form 41**1111
	);

	# Get the expiration
	if ($all =~ m!(\d\d?)[-/](\d\d)(\d\d)?! ){
		$month = $1;
		$year  = "$2$3";
	}
	elsif ($month >= 1  and $month <= 12 and $year) 
	{
		$all = "$month/$year";
	}
	else {
		$all = '';
	}

	if ($all) {
		$return[2] = $month;
		$return[3] = $year;
		$return[4] = $all;
	}
	else {
		my $msg = errmsg("Can't figure out credit card expiration.");
		$Vend::Session->{errors}{mv_credit_card_valid} = $msg;
		push @return, $msg;
		return @return;
	}

	if(! valid_exp_date($all) ) {
		my $msg = errmsg("Card is expired.");
		$Vend::Session->{errors}{mv_credit_card_valid} = $msg;
		push @return, $msg;
		return @return;
	}

	$num =~ s/\D+//g;

	# Get the type
	unless ( $type ) {
		($num =~ /^3/) and $type = 'amex';
		($num =~ /^4/) and $type = 'visa';
		($num =~ /^5/) and $type = 'mc';
		($num =~ /^6/) and $type = 'discover';
	}

	if($type eq 'amex') {
		$type = 'other' if $num !~ /^37/;
	}

	if ($type) {
		$return[5] = $type;
	}
	else {
		my $msg = errmsg("Can't figure out credit card type.");
		$Vend::Session->{errors}{mv_credit_card_valid} = $msg;
		push @return, $msg;
		return @return;
	}

	unless ($valid = luhn($num) || $force ) {
		my $msg = errmsg("Credit card number fails LUHN-10 check.");
		$Vend::Session->{errors}{mv_credit_card_valid} = $msg;
		push @return, $msg;
		return @return;
	}

	$return[0] = $valid;

	my $check_string = $num;
	$check_string =~ s/(\d\d).*(\d\d\d\d)$/$1**$2/;
	my $encrypt_string = $separate ? $num : "$type\t$num\t$all\n";
	
	$info = encrypt_cc ($encrypt_string);

	unless (defined $info) {
		my $msg = errmsg("Credit card encryption failed: %s", $! );
		$Vend::Session->{errors}{mv_credit_card_valid} = $msg;
		push @return, $msg;
		$return[0] = 0;
		return @return;
	}
	$return[1] = $info;
	$return[6] = $check_string;

	return @return;

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
	return ('MStatus', 'success', 'order-id', 1);
}

sub map_actual {

	# Allow remapping of payment variables
    my %map = qw(
		mv_credit_card_number       mv_credit_card_number
		name                        name
		fname                       fname
		lname                       lname
		b_name                      b_name
		b_fname                     b_fname
		b_lname                     b_lname
		address                     address
		address1                    address1
		address2                    address2
		b_address                   b_address
		b_address1                  b_address1
		b_address2                  b_address2
		city                        city
		b_city                      b_city
		state                       state
		b_state                     b_state
		zip                         zip
		b_zip                       b_zip
		country                     country
		b_country                   b_country
		mv_credit_card_exp_month    mv_credit_card_exp_month
		mv_credit_card_exp_year     mv_credit_card_exp_year
		cyber_mode                  mv_cyber_mode
		amount                      amount
    );

	# Allow remapping of the variable names
	my $remap = $::Variable->{MV_PAYMENT_REMAP} || $::Variable->{CYBER_REMAP};
	$remap =~ s/^\s+//;
	$remap =~ s/\s+$//;
	my (%remap) = split /[\s=]+/, $remap;
	for (keys %remap) {
		$map{$_} = $remap{$_};
	}

	my %actual;
	my $key;

	# pick out the right values, need alternate billing address
	# substitution
	foreach $key (keys %map) {
		$actual{$key} = $::Values->{$map{$key}} || $CGI::values{$key}
			and next;
		my $secondary = $key;
		next unless $secondary =~ s/^b_//;
		$actual{$key} = $::Values->{$map{$secondary}} ||
						$CGI::values{$map{$secondary}};
	}
	$actual{name}		 = "$actual{fname} $actual{lname}"
		if ! $actual{name};
	if(! $actual{address}) {
		$actual{address} = "$actual{address1}";
		$actual{address} .=  ", $actual{address2}"
			if $actual{address2};
	}
	return %actual;
}

sub charge {
	my ($charge_type) = @_;
	my (%actual) = map_actual();

#::logDebug ("cyber_charge, mode val=$::Values->{mv_cyber_mode} cgi=$CGI::values{mv_cyber_mode} actual=$actual{cyber_mode}");
    my $currency =  $::Variable->{MV_PAYMENT_CURRENCY}
					|| $::Variable->{CYBER_CURRENCY}
					|| 'usd';
    $actual{mv_credit_card_exp_month} =~ s/\D//g;
    $actual{mv_credit_card_exp_month} =~ s/^0+//;
    $actual{mv_credit_card_exp_year} =~ s/\D//g;
    $actual{mv_credit_card_exp_year} =~ s/\d\d(\d\d)/$1/;

    $actual{mv_credit_card_number} =~ s/\D//g;

    my $exp = $actual{mv_credit_card_exp_month} . '/' .
    		  $actual{mv_credit_card_exp_year};

    $actual{cyber_mode} = 'mauthcapture'
		unless $actual{cyber_mode};

    my($orderID);
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(time());

    # We'll make an order ID based on date, time, and MiniVend session

    # $mon is the month index where Jan=0 and Dec=11, so we use
    # $mon+1 to get the more familiar Jan=1 and Dec=12
    $orderID = sprintf("%02d%02d%02d%02d%02d%05d%s",
            $year + 1900,$mon + 1,$mday,$hour,$min,$Vend::SessionName);

    # The following characters are illegal in an order ID:
    #    : < > = + @ " % = &
    #
    # If you want, you could use a line similar to the following
    # to remove these illegal characters:

    $orderID =~ tr/:<>=+\@\"\%\&/_/d;

    #
    # Or use something like the following line to only allow
    # alphanumeric and dash, converting other characters to underscore:
    #    $orderID =~ tr/A-Za-z0-9\-/_/c;

    # Our test order ID only contains digits, so we don't have
    # to strip any characters here. You might have to if you
    # use a different scheme.

	my $precision = $::Variable->{CYBER_PRECISION} || 2;
    $amount = Vend::Interpolate::total_cost();
	$amount = sprintf("%.${precision}f", $amount);
    $amount = "$currency $amount";

    my %result;

	if($charge_type =~ /^\s*custom\s+(\w+)(?:\s+(.*))?/si) {
		my ($sub, @args);
		@args = Text::ParseWords::shellwords($2) if $2;
		if(! defined ($sub = $Global::GlobalSub->{$1}) ) {
			::logError("bad custom payment GlobalSub: %s", $1);
			return undef;
		}
		%result = $sub->(@args);
		$Vend::Session->{payment_result} =
			$Vend::Session->{cybercash_result} = \%result;
	}
    elsif ($actual{cyber_mode} =~ /^minivend_test(?:_(.*))?/) {
		my $status = $1 || 'success';
		# Minivend test mode
		my %payment = (
			'host' => $::Variable->{CYBER_HOST} || 'localhost',
			'port' => $::Variable->{CYBER_PORT} || 8000,
			'secret' => $::Variable->{CYBER_SECRET} || '',
			'config' => $::Variable->{CYBER_CONFIGFILE} || '',
		);
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
			'Card-Exp'     => $exp,
		);
		$result{MStatus} = $status;
		$Vend::Session->{payment_result} =
			$Vend::Session->{cybercash_result} = \%result;
    }
	else {
		# Live interface operations follow
		unless	(defined	$::Variable->{CYBER_VERSION}
				and			$::Variable->{CYBER_VERSION} >= 3 )
		{
			undef $Vend::CC3;
			undef $Vend::CC3server;
		}
		elsif ( $::Variable->{CYBER_VERSION} >= 3.2 ) {
			$Vend::CC3server = 1;
		}

		if($Vend::CC3){
			# Cybercash 3.x libraries to be used.
			# Initialize the merchant configuration file
			my $status = InitConfig($::Variable->{CYBER_CONFIGFILE});
			if ($status != 0) {
				$Vend::Session->{cybercash_error} = MCKGetErrorMessage($status);
				::logError(
					"Failed to initialize CyberCash from file %s: %s",
					$Variable->{CYBER_CONFIGFILE},
					$Vend::Session->{cybercash_error},
					);
				return undef;
			}
			unless($::Variable->{CYBER_HOST}) {
				$::Variable->{CYBER_HOST} = $Config{CCPS_HOST};
			}
		}
		if($Vend::CC3server) {
			# Cybercash 3.x server and libraries to be used.

			if ($status != 0) {
				$Vend::Session->{cybercash_error} = MCKGetErrorMessage($status);
				return undef;
			}
			$sendurl = $::Variable->{CYBER_HOST} . 'directcardpayment.cgi';

			my %paymentNVList;
			$paymentNVList{'mo.cybercash-id'} = $Config{CYBERCASH_ID};
			$paymentNVList{'mo.version'} = $MCKversion;

			$paymentNVList{'mo.signed-cpi'} = "no";
			$paymentNVList{'mo.order-id'} = $orderID;
			$paymentNVList{'mo.price'} = $amount;

			$paymentNVList{'cpi.card-number'} = $actual{mv_credit_card_number};
			$paymentNVList{'cpi.card-exp'} = $exp;
			$paymentNVList{'cpi.card-name'} = $actual{b_name};
			$paymentNVList{'cpi.card-address'} = $actual{b_address};
			$paymentNVList{'cpi.card-city'} = $actual{b_city};
			$paymentNVList{'cpi.card-state'} = $actual{b_state};
			$paymentNVList{'cpi.card-zip'} = $actual{b_zip};
			$paymentNVList{'cpi.card-country'} = $actual{b_country};

			my (  $POPref, $tokenlistref, %tokenlist );
			($POPref, $tokenlistref ) = 
							  doDirectPayment( $sendurl, \%paymentNVList );
			
			$result{MStatus}    = $POPref->{'pop.status'};
			$result{MErrMsg}     = $POPref->{'pop.error-message'};
			$result{'order-id'} = $POPref->{'pop.order-id'};

			$Vend::Session->{cybercash_result} = $POPref;

			# other values found in POP which might be used in some way:
			#		$POP{'pop.auth-code'};
			#		$POP{'pop.ref-code'};
			#		$POP{'pop.txn-id'};
			#		$POP{'pop.sale_date'};
			#		$POP{'pop.sign'};
			#		$POP{'pop.avs_code'};
			#		$POP{'pop.price'};
		}
		else {
			# Cybercash 2.x server interface follows
			if ($Vend::CC3){
				# Use Cybercash 3.x libraries
				*sendmserver = \&CCMckDirectLib3_2::SendCC2_1Server;
			}
			else {
				# Constants to find the merchant payment server
				#
				my %payment = (
					'host' => $::Variable->{CYBER_HOST} || 'localhost',
					'port' => $::Variable->{CYBER_PORT} || 8000,
					'secret' => $::Variable->{CYBER_SECRET} || '',
				);
				*sendmserver = \&CCLib::sendmserver;
				# Use Cybercash 2.x libraries
				CCLib::SetServer(%payment);
			}
			%result = sendmserver(
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
				'Card-Exp'     => $exp,
			);
			$Vend::Session->{cybercash_result} = \%result;
		}
    }

	if($result{MStatus} !~ /^success/) {
		$Vend::Session->{cybercash_error} = $result{MErrMsg};
		return undef;
	}
	elsif($result{MStatus} =~ /success-duplicate/) {
		$Vend::Session->{cybercash_error} = $result{MErrMsg};
	}
	else {
		$Vend::Session->{cybercash_error} = '';
	}
	$Vend::Session->{payment_id} =
		$Vend::Session->{cybercash_id} = $result{'order-id'};
	if($Vend::Cfg->{EncryptProgram} =~ /(pgp|gpg)/) {
		$CGI::values{mv_credit_card_force} = 1;
		(
			$::Values->{mv_credit_card_valid},
			$::Values->{mv_credit_card_info},
			$::Values->{mv_credit_card_exp_month},
			$::Values->{mv_credit_card_exp_year},
			$::Values->{mv_credit_card_exp_all},
			$::Values->{mv_credit_card_type},
			$::Values->{mv_credit_card_error}
		)	= encrypt_standard_cc(\%CGI::values);
	}
	::logError("Order id: %s\n", $Vend::Session->{cybercash_id});
	return $result{'order-id'};
}


*cyber_charge = \&charge;



sub report_field {
    my($field_name, $seen) = @_;
    my($field_value, $r);

    $field_value = $Vend::Session->{'values'}->{$field_name};
    if (defined $field_value) {
		$$seen{$field_name} = 1;
		$r = $field_value;
    }
	else {
		$r = "<no input box>";
    }
    $r;
}

#sub create_onfly {
#	my $opt = shift;
#	if($opt->{create}) {
#		delete $opt->{create};
#		my $href = $opt->{href} || '';
#		my $secure = $opt->{secure} || '';
#		if(defined $split_fields) {
#			return join $joiner, @{$opt}{ split /[\s,]+/, $split_fields };
#		}
#		else {
#			my @out;
#			my @fly;
#			for(keys %{$opt}) {
#				$opt->{$_} =~ s/[\0\n]/\r/g unless $v;
#				push @fly, "$_=$opt->{$_}";
#			}
#			push @out, "mv_order_fly=" . join $joiner, @fly;
#			push @out, "mv_order_item=$opt->{code}"
#				if ! $opt->{mv_order_item} and $opt->{code};
#			push @out, "mv_order_quantity=$opt->{quantity}"
#				if ! $opt->{mv_order_quantity} and $opt->{quantity};
#			push @out, "mv_todo=refresh"
#				if ! $opt->{mv_todo};
#		}
#		my $form = join "\n", @out;
#		return Vend::Interpolate::form_link( $href, '', $secure, { form => $form } );
#	}
#
#}

sub onfly {
	my ($code, $qty, $opt) = @_;
#::logDebug("called onfly");
	my $item_text;
	if (ref $opt) {
		$item_text = $opt->{text} || '';
	}
	else {
		$item_text = $opt;
		$opt = {};
	}

#	return create_onfly() if $opt->{create};

	my $joiner		= $::Variable->{MV_ONFLY_JOINER} || '|';
	my $split_fields= $::Variable->{MV_ONFLY_FIELDS} || undef;

	$item_text =~ s/\s+$//;
	$item_text =~ s/^\s+//;
	my @parms;
	my @fields;
	$joiner = quotemeta $joiner;
	@parms = split /$joiner/, $item_text;
	my ($k, $v);
	my $item = {};
	if(defined $split_fields) {
		@fields = split /[,\s]+/, $split_fields;
		@{$item}{@fields} = @parms;
	}
	else {
		for(@parms) {
			($k, $v)  = split /=/, $_;
			$item->{$k} = $v;
		}
	}
	$item->{mv_price} = $item->{price}
		if ! $item->{mv_price};
	$item->{code}	  = $code	if ! $item->{code};
	$item->{quantity} = $qty	if ! $item->{quantity};
	return $item;
}

# Email the processed order.

sub mail_order {
	my ($email, $order_no) = @_;
	$email = $Vend::Cfg->{MailOrderTo} unless $email;
    my($body, $ok);
    my($subject);
# LEGACY
    $body = readin($::Values->{mv_order_report})
		if $::Values->{mv_order_report};
# END LEGACY
#::logDebug( sprintf "found body length %s in values->mv_order_report", length($body));
    $body = readfile($Vend::Cfg->{OrderReport})
		if ! $body;
#::logDebug( sprintf "found body length %s in OrderReport", length($body));
    unless (defined $body) {
		::logError(
			q{Cannot find order report in:

			OrderReport=%s
			mv_order_report=%s

trying one more time. Fix this.},
				$Vend::Cfg->{OrderReport},
				$::Values->{mv_order_report},
			);
		$body = readin($Vend::Cfg->{OrderReport});
		return undef if ! $body;
	}
    return undef unless defined $body;

	$order_no = update_order_number() unless $order_no;

	$body = interpolate_html($body);

	$body = pgp_encrypt($body) if $Vend::Cfg->{PGP};

#::logDebug("Now ready to track order, number=$order_no");
	track_order($order_no, $body);
#::logDebug("finished track order, number=$order_no");

	$subject = $::Values->{mv_order_subject} || "ORDER %n";

	if(defined $order_no) {
	    $subject =~ s/%n/$order_no/;
	}
	else { $subject =~ s/\s*%n\s*//g; }

#::logDebug("Now ready to send mail, subject=$subject");

    $ok = send_mail($email, $subject, $body);
    return $ok;
}

sub pgp_encrypt {
	my($body, $key, $cmd) = @_;
	$cmd = $Vend::Cfg->{PGP} unless $cmd;
	if($key) {
		$cmd =~ s/%%/:~PERCENT~:/g;
		$cmd =~ s/%s/$key/g;
		$cmd =~ s/:~PERCENT~:/%/g;
	}
	my $fpre = $Vend::Cfg->{ScratchDir} . "/pgp.$$";
	open(PGP, "|$cmd >$fpre.out 2>$fpre.err")
			or die "Couldn't fork: $!";
	print PGP $body;
	close PGP;
	if($?) {
		logError("PGP failed with status " . $? << 8 . ": $!");
		return 0;
	}
	$body = readfile("$fpre.out");
	unlink "$fpre.out";
	unlink "$fpre.err";
	return $body;
}

sub do_check {
		local($_) = shift;
		$parameter = $_;
		my($var, $val, $m, $message);
		my $ref = \%CGI::values;
		if (/^&/) {
			($var,$val) = split /[\s=]+/, $parameter, 2;
		}
		elsif ($parameter =~ /(\w+)[\s=]+(.*)/) {
			my $k = $1;
			my $v = $2;
			$m = $v =~ s/\s+(.*)// ? $1 : undef;
			($var,$val) =
				('&format',
				  $v . ' ' . $k  . ' ' .  $::Values->{$k}
				  );
		}
		else {
			logError("Unknown order check '%s' in profile %s", $parameter, $profile);
			return undef;
		}
		$val =~ s/&#(\d+);/chr($1)/ge;

#::logDebug("checking profile $Profile: var=$var val=$val Fatal=$Fatal Final=$Final");
		if (defined $Parse{$var}) {
			($val, $var, $message) = &{$Parse{$var}}($ref, $val, $m || undef);
		}
		else {
			logError( "Unknown order check parameter in profile %s: %s=%s",
					$Profile,
					$var,
					$val,
					);
			return undef;
		}
#::logDebug("profile $Profile check result: var=$var val='$val' message='$message' Fatal=$Fatal Final=$Final");
		return ($val, $var, $message);
}

sub check_order {
	my ($profile) = @_;
    my($codere) = '[\w-_#/.]+';
	my $params;
	if(defined $Vend::Cfg->{OrderProfileName}->{$profile}) {
		$profile = $Vend::Cfg->{OrderProfileName}->{$profile};
		$params = $Vend::Cfg->{OrderProfile}->[$profile];
	}
	elsif($profile =~ /^\d+$/) {
		$params = $Vend::Cfg->{OrderProfile}->[$profile];
	}
	elsif(defined $Vend::Session->{scratch}->{$profile}) {
		$params = $Vend::Session->{scratch}->{$profile};
	}
	else { return undef }
	return undef unless $params;
	$Profile = $profile;

	my $ref = \%CGI::values;
	$params = interpolate_html($params);
	@Errors = ();
	$Fatal = $Final = 0;

	my($var,$val);
	my $status = 1;
	my(@param) = split /[\r\n]+/, $params;
	my $m;
	my $join;
	
	for(@param) {
		if($join) {
			$_ = "$join$_";
			undef $join;
		}
		next unless /\S/;
		next if /^\s*#/;
		if(s/\\$//) {
			$join = $_;
			next;
		}
		s/^\s+//;
		s/\s+$//;
		($val, $var, $message) = do_check($_);
#::logDebug("check returned val='$val' var=" . (defined $var ? 'DEFINED' : 'UNDEF'));
		next if ! defined $var;
		if ($val) {
 			$::Values->{"mv_status_$var"} = $message
				if defined $message and $message;
			delete $Vend::Session->{errors}{$var};
 			delete $::Values->{"mv_error_$var"};
		}
		else {
			$status = 0;
# LEGACY
			$::Values->{"mv_error_$var"} = $message;
# END LEGACY
			$Vend::Session->{errors} = {}
				if ! $Vend::Session->{errors};
			$Vend::Session->{errors}{$var} = $message;
			push @Errors, "$var: $message";
		}
#::logDebug("profile status now=$status");
		if (defined $Success) {
			$status = $Success;
			last;
		}
		last if $Fatal && ! $status;
	}
	my $errors = join "\n", @Errors;
	$errors = '' unless defined $errors and ! $Success;
#::logDebug("FINISH checking profile $Profile: Fatal=$Fatal Final=$Final Status=$status");
	if($status) {
		$::Values->{mv_nextpage} = $CGI::values{mv_nextpage} = $Success_page
			if $Success_page;
	}
	elsif ($Fail_page) {
		$::Values->{mv_nextpage} = $CGI::values{mv_nextpage} = $Fail_page;
	}
	if($Final and ! scalar @{$Vend::Items}) {
		$status = 0;
		$::Values->{"mv_error_items"}       =
			$Vend::Session->{error}{items}  =
				errmsg(
					"You might want to order something! No items in cart.",
				);

	}
	return ($status, $Final, $errors);
}

my $state = <<EOF;
| AL AK AZ AR CA CO CT DE FL GA HI ID IL IN IA KS KY LA ME MD |
| MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA PR RI |
| SC SD TN TX UT VT VA WA WV WI WY DC AP FP FPO APO GU VI     |
EOF

my $province = <<EOF;
| AB BC MB NB NF NS NT ON PE QC SK YT YK |
EOF

sub _state_province {
	my($ref,$var,$val) = @_;
	if( $state =~ /\S/ and ($state =~ /\s$val\s/i or $province =~ /\s$val\s/i) ) {
		return (1, $var, '');
	}
	else {
		return (undef, $var, "'$val' not a two-letter state or province code");
	}
}

sub _state {
	my($ref,$var,$val) = @_;
	$state = $::Variable->{MV_VALID_STATE}
		if defined $::Variable->{MV_VALID_STATE};

	if( $state =~ /\S/ and $state =~ /\s$val\s/i ) {
		return (1, $var, '');
	}
	else {
		return (undef, $var, "'$val' not a two-letter state code");
	}
}

sub _province {
	my($ref,$var,$val) = @_;
	$province = $::Variable->{MV_VALID_PROVINCE}
		if defined $::Variable->{MV_VALID_PROVINCE};
	if( $province =~ /\s$val\s/i) {
		return (1, $var, '');
	}
	else {
		return (undef, $var, "'$val' not a two-letter province code");
	}
}

sub _array {
	return undef unless defined $_[1];
	[split /\s*[,\0]\s*/, $_[1]]
}

sub _yes {
	return( defined($_[2]) && ($_[2] =~ /^[yYtT1]/));
}

sub _postcode {
	_zip(@_) or _ca_postcode(@_)
		and return (1, $_[1], '');
	return (undef, $var, 'not a US or Canada postal/zip code');
}

sub _ca_postcode {
	my($ref,$var,$val) = @_;
	$val =~ s/[_\W]+//g;
	defined $val
		and
	$val =~ /^[ABCEGHJKLMNPRSTVXYabceghjklmnprstvxy]\d[A-Za-z]\d[A-Za-z]\d$/
		and return (1, $var, '');
	return (undef, $var, 'not a Canadian postal code');
}

sub _zip {
	my($ref,$var,$val) = @_;
	defined $val and $val =~ /^\s*\d{5}(?:[-]\d{4})?\s*$/
		and return (1, $var, '');
	return (undef, $var, 'not a US zip code');
}

*_us_postcode = \&_zip;

sub _phone {
	my($ref,$var,$val) = @_;
	defined $val and $val =~ /\d{3}.*\d{3}/
		and return (1, $var, '');
	return (undef, $var, 'not a phone number');
}

sub _phone_us {
	my($ref, $var,$val) = @_;
	if($val and $val =~ /\d{3}.*?\d{4}/) {
		return (1, $var, '');
	}
	else {
		return (undef, $var, 'not a US phone number');
	}
}

sub _phone_us_with_area {
	my($ref, $var,$val) = @_;
	if($val and $val =~ /\d{3}\D*\d{3}\D*\d{4}/) {
		return (1, $var, '');
	}
	else {
		return (undef, $var, 'not a US phone number with area code');
	}
}

sub _phone_us_with_area_strict {
	my($ref, $var,$val) = @_;
	if($val and $val =~ /^\d{3}-\d{3}-\d{4}$/) {
		return (1, $var, '');
	}
	else {
		return (undef, $var, 'not a US phone number with area code (strict formatting)');
	}
}

sub _email {
	my($ref, $var, $val) = @_;
	if($val and $val =~ /[\040-\176]+\@[-A-Za-z0-9.]+\.[A-Za-z]+/) {
		return (1, $var, '');
	}
	else {
		return (undef, $var, "$val not an email address");
	}
}

# Contributed by Ton Verhagen -- April 15, 2000
sub _isbn {
	# $ref is to Vend::Session->{'values'} hash (well, actually ref to %CGI::values)
	# $var is the passed name of the variable
	# $val is current value of checked variable
	# This routine will return 1 if isbn is ok, else returns 0
	# Rules:
	# isbn number must contain exactly 10 digits.
	# isbn number:		0   9   4   0   0   1   6   3   3   8
	# weighting factor:	10  9   8   7   6   5   4   3   2   1
	# Values (product)	0 +81 +32 + 0 + 0 + 5 +24 + 9 + 6 + 8 --> sum is: 165
	# Sum must be divisable by 11 without remainder: 165/11=15 (no remainder)
	# Result: isbn 0-940016-33-8 is a valid isbn number.
	
	my($ref, $var, $val) = @_;
	$val =~ s/\D//g;	# weed out non-digits
	if( $val && length($val) == 10 ) {
	  my @digits = split("", $val);
	  my $sum=0;
	  for(my $i=10; $i > 0; $i--) {
		$sum += $digits[10-$i] * $i;
	  }
	  return ( $sum%11 ? 0 : 1, $var, '' );
	}
	else {
	  return (undef, $var, "not a valid isbn number");
	}
}

sub _mandatory {
	my($ref,$var,$val) = @_;
	return (1, $var, '')
		if (defined $ref->{$var} and $ref->{$var} =~ /\S/);
	return (undef, $var, "blank");
}

sub _true {
	my($ref,$var,$val) = @_;
	return (1, $var, '') if is_yes($val);
	return (undef, $var, "false");
}

sub _false {
	my($ref,$var,$val) = @_;
	return (1, $var, '') if is_no($val);
	return (undef, $var, "true");
}

sub _required {
	my($ref,$var,$val) = @_;
	return (1, $var, '')
		if (defined $val and $val =~ /\S/);
	return (1, $var, '')
		if (defined $ref->{$var} and $ref->{$var} =~ /\S/);
	return (undef, $var, "blank");
}

sub counter_number {
	my $file = shift || $Vend::Cfg->{OrderCounter};
	$File::CounterFile::DEFAULT_DIR = $Vend::Cfg->{VendRoot}
		unless $file =~ m!^/!;
	my $c = new File::CounterFile $file, "000000";
	return $c->inc;
}

sub update_order_number {

	my($c,$order_no);

	if($Vend::Cfg->{OrderCounter}) {
		$order_no = counter_number();
	}
	else {
		$order_no = $Vend::SessionID . '.' . time;
	}

	$::Values->{mv_order_number} = $order_no;
	$order_no;
}

# Places the order report in the AsciiTrack file
sub track_order {
	my ($order_no,$order_report) = @_;
	
	if ($Vend::Cfg->{AsciiTrack}) {
		logData ($Vend::Cfg->{AsciiTrack}, <<EndOOrder);
##### BEGIN ORDER $order_no #####
$order_report
##### END ORDER $order_no #####

EndOOrder
	}
}

sub route_profile_check {
	my (@routes) = @_;
	my $failed;
	my $errors = '';
	my ($status, $final, $missing);
	my $value_save = { %{$::Values} };
	local(%SIG);
	undef $SIG{__DIE__};
	foreach my $c (@routes) {
		$::Values = { %$value_save };
#::logDebug("profile: $c");
		eval {
			my $route = $Vend::Cfg->{Route_repository}{$c}
				or do {
					::logError("Non-existent order route %s, skipping.", $c);
					next;
				};
			if($route->{profile}) {
				($status, $final, $missing) = check_order($route->{profile});
				if(! $status) {
					die errmsg(
					"Route %s failed order profile %s. Final=%s. Errors:\n\n%s\n\n",
					$c,
					$route->{profile},
					$final,
					$missing,
					)
				}
			}
		};
		if($@) {
			$errors .= $@;
			$failed = 1;
			last if $final;
		}
	}
#::logDebug("profile=$c status=$status final=$final failed=$failed errors=$errors missing=$missing");
	$::Values = $value_save;
	return (! $failed, $final, $errors);
}

sub route_order {
	my ($route, $save_cart, $check_only) = @_;
	my $cart = [ @$save_cart ];
	if(! $Vend::Cfg->{Route}) {
		$Vend::Cfg->{Route} = {
			report		=> $Vend::Cfg->{OrderReport},
			receipt		=> $::Values->{mv_order_receipt} || find_special_page('receipt'),
			encrypt_program	=> '',
			encrypt		=> 0,
			pgp_key		=> '',
			pgp_cc_key	=> '',
			cyber_mode	=> $CGI::values{mv_cyber_mode} || undef,
			credit_card	=> 1,
			profile		=> '',
			inline_profile		=> '',
			email		=> $Vend::Cfg->{MailOrderTo},
			attach		=> 0,
			counter		=> '',
			increment	=> 0,
			continue	=> 0,
			partial		=> 0,
			supplant	=> 0,
			track   	=> '',
			errors_to	=> $Vend::Cfg->{MailOrderTo},
		};
	}

	my $main = $Vend::Cfg->{Route};

	my $save_mime = $::Instance->{MIME} || undef;

	my $encrypt_program = $main->{encrypt_program} || 'pgpe -fat -r %s';
	my (@routes);
	my $shelf = { };
	my $item;
	foreach $item (@$cart) {
		$shelf = { } unless $shelf;
		next unless $item->{mv_order_route};
		my(@r) = split /[\s\0,]+/, $item->{mv_order_route};
		for(@r) {
			next unless /\S/;
			$shelf->{$_} = [] unless defined $shelf->{$_};
			push @routes, $_;
			push @{$shelf->{$_}}, $item;
		}
	}
	my %seen;

	@routes = grep !$seen{$_}++, @routes;
	my (@main) = grep /\S/, split /[\s\0,]+/, $route;
	for(@main) {
		next unless $_;
		$shelf->{$_} = [ @$cart ];
	}

	push @routes, @main;

	my ($c,@out);
	my $status;
	my $errors = '';
	
	my @route_complete;
	my @route_failed;

	# Here we return if it is only a check
	return route_profile_check(@routes) if $check_only;

	# Careful! If you set it on one order and not on another,
	# you must delete in between.
	$::Values->{mv_order_number} = counter_number($main->{counter})
			unless $Vend::Session->{mv_order_number};

	my $value_save = { %{$::Values} };

		BUILD:
	foreach $c (@routes) {
		my $route = $Vend::Cfg->{Route_repository}{$c};

#::logDebug($Data::Dumper::Indent = 3 and "Route $c:\n" . Data::Dumper::Dumper($route) .	"values:\n" .  Data::Dumper::Dumper($::Values));
		$::Values = { %$value_save };
		my $pre_encrypted;
		my $credit_card_info;

		if($route->{inline_profile}) {
			my $status;
			eval {
				($status, undef, $errors) = check_order($route->{inline_profile});
				die "$errors\n" unless $status;
			};
		}
		if ($CGI::values{mv_credit_card_number}) {
			if(! $CGI::values{mv_credit_card_type} and
				 $CGI::values{mv_credit_card_number} )
			{
				if($CGI::values{mv_credit_card_number} =~ /\s*4/) {
					$CGI::values{mv_credit_card_type} = 'visa';
				}
				elsif($CGI::values{mv_credit_card_number} =~ /\s*5/) {
					$CGI::values{mv_credit_card_type} = 'mc';
				}
				elsif($CGI::values{mv_credit_card_number} =~ /\s*37/) {
					$CGI::values{mv_credit_card_type} = 'amex';
				}
				else {
					$CGI::values{mv_credit_card_type} = 'discover/other';
				}
			}
			$::Values->{mv_credit_card_info} = join "\t", 
								$CGI::values{mv_credit_card_type},
								$CGI::values{mv_credit_card_number},
								$CGI::values{mv_credit_card_exp_month} .
								"/" . $CGI::values{mv_credit_card_exp_year};
		}

		$Vend::Items = $shelf->{$c};
		if(! defined $Vend::Cfg->{Route_repository}{$c}) {
			logError("Non-existent order routing %s", $c);
			next;
		}
	eval {

		if($route->{cyber_mode}) {
			my $save = $CGI::values{mv_cyber_mode};
			$CGI::values{mv_cyber_mode} = $route->{cyber_mode};
			my $glob = {};
			my (@vars) =  (qw/ CYBER_CONFIGFILE CYBER_CURRENCY CYBER_HOST
							CYBER_PORT CYBER_REMAP CYBER_SECRET CYBER_VERSION /);
			for(@vars) {
				next unless $route->{$_};
				$glob->{$_} = $::Variable->{$_};
				$::Variable->{$_} = $route->{$_};
			}
			my $ok;
			eval {
				$ok = _charge(\%CGI::values, $route->{cyber_mode});
			};
			for(@vars) {
				next unless exists $glob->{$_};
				$::Variable->{$_} = $glob->{_};
			}
			$CGI::values{mv_cyber_mode} = $save;
			unless ($ok) {
				die errmsg("Failed online charge for routing %s: %s",
								$c,
								$Vend::Session->{mv_payment_error}
							);
			}
		}
		elsif($route->{credit_card} and ! $pre_encrypted) {
			$::Values->{mv_credit_card_info} = pgp_encrypt(
								$::Values->{mv_credit_card_info},
								($route->{pgp_cc_key} || $route->{pgp_key}),
								($route->{encrypt_program} || $encrypt_program),
							);
		}

		if($Vend::Session->{mv_order_number}) {
			$::Values->{mv_order_number} = $Vend::Session->{mv_order_number};
		}
		elsif($route->{counter}) {
			$::Values->{mv_order_number} = counter_number($route->{counter});
		}
		elsif($route->{increment}) {
			$::Values->{mv_order_number} = counter_number();
		}
		my $page;
		if($route->{empty} and ! $route->{report}) {
			$page = '';
		}
		else {
			$page = readfile($route->{'report'} || $main->{'report'});
		}
		die errmsg(
			"No order report %s or %s found.",
			$route->{'report'},
			$main->{'report'},
			) unless defined $page;

		my $use_mime;
		undef $::Instance->{MIME};
		$page = interpolate_html($page) if $page;

#::logDebug("MIME=$::Instance->{MIME}");
		$use_mime   = $::Instance->{MIME} || undef;
		$::Instance->{MIME} = $save_mime  || undef;

		if($route->{encrypt}) {
			$page = pgp_encrypt($page,
								$route->{pgp_key},
								$route->{encrypt_program} || $encrypt_program,
								);
		}
		my ($address, $reply, $to, $subject, $template);
		if($route->{attach}) {
			$Vend::Items->[0]{mv_order_report} = $page;
		}
		elsif ($address = $route->{email}) {
			$address = $::Values->{$address} if $address =~ /^\w+$/;
			$subject = $::Values->{mv_order_subject} || 'ORDER %s';
			$subject =~ s/%n/%s/;
			$subject = sprintf "$subject", $::Values->{mv_order_number};
			$reply   = $route->{reply} || $main->{reply};
			$reply   = $::Values->{$reply} if $reply =~ /^\w+$/;
			$to		 = $route->{email};
			push @out, [$to, $subject, $page, $reply, $use_mime];
		}
		elsif ($route->{empty}) {
			# Do nothing
		}
		else {
			die "Empty order routing $c (and not explicitly empty)";
		}
		if ($route->{supplant}) {
			track_order($::Values->{mv_order_number}, $page);
		}
		if ($route->{track}) {
			Vend::Util::writefile($route->{track}, $page)
				or ::logError("route tracking error writing $route->{track}: $!");
			if ($route->{track_mode} =~ /^0/) {
				chmod($route->{track_mode}); 
			}
			elsif ($route->{track_mode}) {
				chmod(oct $route->{track_mode}); 
			}
		}
		if ($route->{individual_track}) {
			my $fn = Vend::Util::catfile(
							$route->{individual_track},
							$::Values->{mv_order_number} . 
							$route->{individual_track_ext},
						);
			Vend::Util::writefile( $fn, $page,	)
				or ::logError("route tracking error writing $fn: $!");
			if ($route->{track_mode} =~ /^0/) {
				chmod($route->{track_mode}); 
			}
			elsif ($route->{track_mode}) {
				chmod(oct $route->{track_mode}); 
			}
		}
	};
		if($@) {
			my $err = $@;
			$errors .=  errmsg(
							"Error during creation of order routing %s:\n%s",
							$c,
							$err,
						);
			push @route_failed, $c;
			next BUILD if $route->{continue};
			@route_complete = ();
			last BUILD;
		}

		push @route_complete, $c;

	} #BUILD
	my $msg;

	foreach $msg (@out) {
		eval {
			send_mail(@$msg);
		};
		if($@) {
			my $err = $@;
			$errors .=  errmsg(
							"Error sending mail to %s:\n%s",
							$msg->[0],
							$err,
						);
			$status = 0;
			next;
		}
		else {
			$status = 1;
		}
	}

	$::Instance->{MIME} = $save_mime  || undef;
	$::Values = $value_save;
	$Vend::Items = $save_cart;

	for(@route_failed) {
		my $route = $Vend::Cfg->{Route_repository}{$_};
		next unless $route->{rollback};
		Vend::Interpolate::tag_perl(
					$route->{rollback_tables},
					{},
					$route->{rollback}
		);
	}
	for(@route_complete) {
		my $route = $Vend::Cfg->{Route_repository}{$_};
		next unless $route->{commit};
		Vend::Interpolate::tag_perl(
					$route->{commit_tables},
					{},
					$route->{commit}
		);
	}

	if(! $errors) {
		delete $Vend::Session->{order_error};
	}
	elsif ($main->{errors_to}) {
		$Vend::Session->{order_error} = $errors;
		send_mail(
			$main->{errors_to},
			errmsg("ERRORS on ORDER %s", $::Values->{mv_order_number}),
			$errors
			);
	}
	else {
		$Vend::Session->{order_error} = $errors;
		::logError("ERRORS on ORDER %s:\n%s", $::Values->{mv_order_number}, $errors);
	}

	# If we give a defined value, the regular mail_order routine will not
	# be called
	if($main->{supplant}) {
		return ($status, $::Values->{mv_order_number});
	}
	return (undef, $::Values->{mv_order_number});
}

sub add_items {

	my($items,$quantities) = @_;

	$items = $CGI::values{mv_order_item} if ! defined $items;
	return unless $items;

	my($code,$found,$item,$base,$quantity,$i,$j,$q);
	my(@items);
	my(@quantities);
	my(@bases);
	my(@lines);
	my(@fly);
	my($attr,%attr);

	my $value;
	if ($value = delete $Vend::Session->{scratch}{mv_UseModifier}) {
		$Vend::Cfg->{UseModifier} = [split /[\s\0,]+/, $value];
	}

	::update_quantity() if ! defined $CGI::values{mv_orderline};

	my $cart = Vend::Cart::get_cart($CGI::values{mv_cartname});

	@items      = split /\0/, ($items), -1;
	@quantities = split /\0/, ($quantities || delete $CGI::values{mv_order_quantity} || ''), -1;
	@bases      = split /\0/, delete $CGI::values{mv_order_mv_ib}, -1
		if defined $CGI::values{mv_order_mv_ib};
	@lines      = split /\0/, delete $CGI::values{mv_orderline}, -1
		if defined $CGI::values{mv_orderline};

	if($CGI::values{mv_order_fly} and $Vend::Cfg->{OnFly}) {
		if(scalar @items == 1) {
			@fly = $CGI::values{mv_order_fly};
		}
		else {
			@fly = split /\0/, $CGI::values{mv_order_fly}, -1;
		}
	}

	if ($Vend::Cfg->{UseModifier}) {
		foreach $attr (@{$Vend::Cfg->{UseModifier} || []}) {
			$attr{$attr} = [];
			next unless defined $CGI::values{"mv_order_$attr"};
			@{$attr{$attr}} = split /\0/, $CGI::values{"mv_order_$attr"}, -1;
		}
	}

    my ($group, $found_master, $mv_mi, $mv_si, @group);

    @group = split /\0/, (delete $CGI::values{mv_order_group} || ''), -1;
    for( $i = 0; $i < @group; $i++ ) {
       $attr{mv_mi}->[$i] = $group[$i] ? ++$Vend::Session->{pageCount} : 0;
	}

	my $separate = defined $CGI::values{mv_separate_items}
					? is_yes($CGI::values{mv_separate_items})
					: (
						$Vend::Cfg->{SeparateItems} ||
						(
							defined $Vend::Session->{scratch}->{mv_separate_items}
						 && is_yes( $Vend::Session->{scratch}->{mv_separate_items} )
						 )
						);
	$j = 0;
	my $set;
	foreach $code (@items) {
	   undef $item;
       $quantity = defined $quantities[$j] ? $quantities[$j] : 1;
       ($j++,next) unless $quantity;
	   $set = $quantity =~ s/^=//;
	    if(! $fly[$j]) {
			$base = product_code_exists_tag($code, $bases[$j] || undef);
		}
		else {
			$base = 'mv_fly';
			my $ref;
#::logError("onfly call=$Vend::Cfg->{OnFly} ($code, $quantity, $fly[$j])");
			eval {
				$item = Vend::Parse::do_tag($Vend::Cfg->{OnFly},
												$code,
												$quantity,
												$fly[$j],
											);
			};
			if($@) {
				::logError(
				"failed on-the-fly item add with error %s for: tag=%s sku=%s, qty=%s, passed=%s",
					$@,
					$Vend::Cfg->{OnFly},
					$code,
					$quantity,
					$fly[$j],
				);
				next;
			}
		}
		if (! $base ) {
			logError( "Attempt to order missing product code: %s", $code);
			next;
		}

		INCREMENT: {

			# Check that the item has not been already ordered.
			# But let us order separates if so configured
			$found = -1;
			last INCREMENT if $separate;
			last INCREMENT if defined $lines[$j] and length($lines[$j]);

			foreach $i (0 .. $#$cart) {
				if ($cart->[$i]->{'code'} eq $code) {
					next unless $base eq $cart->[$i]->{mv_ib};
#::logDebug("incrementing line $i");
					$found = $i;
					# Increment quantity. This is different than
					# the standard handling because we are ordering
					# accessories, and may want more than 1 of each
					$cart->[$i]{quantity} = $set ? $quantity : $cart->[$i]{quantity} + $quantity;
				}
			}
		} # INCREMENT

		# And if not, start with a whole new line.
		# If mv_orderline is set, will replace a line.
		if ($found == -1) {
			$item = {'code' => $code, 'quantity' => $quantity, mv_ib => $base}
				if ! $item;

			# Add the master item/sub item ids if appropriate
          if(@group) {
           if($attr{mv_mi}->[$j]) {
              $item->{mv_mi} = $mv_mi = $attr{mv_mi}->[$j];
              $item->{mv_si} = $mv_si = 0;
           }
           else {
              $item->{mv_mi} = $mv_mi;
              $item->{mv_si} = ++$mv_si;
           }
			}

			if($Vend::Cfg->{UseModifier}) {
				foreach $i (@{$Vend::Cfg->{UseModifier}}) {
					$item->{$i} = $attr{$i}->[$j];
				}
			}
			if($Vend::Cfg->{AutoModifier}) {
				foreach $i (@{$Vend::Cfg->{AutoModifier}}) {
					my ($table,$key) = split /:/, $i;
					unless ($key) {
						$key = $table;
						$table = $base;
					}
#::logDebug("AutoModifer fetch $key: $table :: $key :: $code");
					$item->{$key} = tag_data($table, $key, $code);
				}
			}
			if($lines[$j] =~ /^\d+$/ and defined $cart->[$lines[$j]] ) {
#::logDebug("editing line $lines[$j]");
				$cart->[$lines[$j]] = $item;
			}
			else {
#::logDebug("adding to line");
				push @$cart, $item;
			}
		}
		$j++;
	}

	if($Vend::Cfg->{OrderLineLimit} and $#$cart >= $Vend::Cfg->{OrderLineLimit}) {
		@$cart = ();
		my $msg = <<EOF;
WARNING:
Possible bad robot. Cart limit of $Vend::Cfg->{OrderLineLimit} exceeded.  Cart emptied.
EOF
		do_lockout($msg);
	}
	Vend::Cart::toss_cart($cart);
}

sub send_mail {
    my($to, $subject, $body, $reply, $use_mime, @extra_headers) = @_;
    my($ok);
#::logDebug("send_mail: to=$to subj=$subject r=$reply mime=$use_mime\n");

	unless (defined $use_mime) {
		$use_mime = $::Instance->{MIME} || undef;
	}

	if(!defined $reply) {
		$reply = $::Values->{mv_email}
				?  "Reply-To: $::Values->{mv_email}\n"
				: '';
	}
	elsif ($reply) {
		$reply = "Reply-To: $reply\n"
			unless $reply =~ /^reply-to:/i;
		$reply =~ s/\s+$/\n/;
	}

    $ok = 0;
	my $none;

	if("\L$Vend::Cfg->{SendMailProgram}" eq 'none') {
		$none = 1;
		$ok = 1;
	}

    SEND: {
		last SEND if $none;
		open(MVMAIL,"|$Vend::Cfg->{SendMailProgram} $to") or last SEND;
		my $mime = '';
		$mime = Vend::Interpolate::mime('header', {}, '') if $use_mime;
		print MVMAIL "To: $to\n", $reply, "Subject: $subject\n"
	    	or last SEND;
		for(@extra_headers) {
			s/\s*$/\n/;
			print MVMAIL $_
				or last SEND;
		}
		$mime =~ s/\s*$/\n/;
		print MVMAIL $mime
	    	or last SEND;
		print MVMAIL $body
				or last SEND;
		print MVMAIL Vend::Interpolate::do_tag('mime boundary') . '--'
			if $use_mime;
		print MVMAIL "\r\n\cZ" if $Global::Windows;
		close MVMAIL or last SEND;
		$ok = ($? == 0);
    }
    
    if ($none or !$ok) {
		logError("Unable to send mail using %s\nTo: %s\nSubject: %s\n%s\n\n%s",
				$Vend::Cfg->{SendMailProgram},
				$to,
				$subject,
				$reply,
				$body,
		);
    }

    $ok;
}

1;
__END__
