# Vend::Order - Interchange order routing routines
#
# Copyright (C) 2002-2013 Interchange Development Group
# Copyright (C) 1996-2002 Red Hat, Inc.
#
# This program was originally based on Vend 0.2 and 0.3
# Copyright 1995 by Andrew M. Wilcox <amw@wilcoxsolutions.com>
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

package Vend::Order;
require Exporter;

$VERSION = '2.110';

@ISA = qw(Exporter);

@EXPORT = qw (
	add_items
	do_order
	check_order
	check_required
	encrypt_standard_cc
	mail_order
	onfly
	route_order
	update_quantity
	validate_whole_cc
);

push @EXPORT, qw (
	send_mail
);

use Vend::Util;
use Vend::File;
use Vend::Interpolate;
use Vend::Session;
use Vend::Data;
use Text::ParseWords;
use Errno qw/:POSIX/;
use strict;
no warnings qw(uninitialized numeric);

use autouse 'Vend::Error' => qw/do_lockout/;

# Instance variables
my (
	@Errors,
	$Update,
	$Fatal,
	$And,
	$Final,
	$Success,
	$Profile,
	$Tables,
	$Fail_page,
	$Success_page,
	$No_error,
	$OrderCheck,
);

sub reset_order_vars {
	@Errors = ();
	$Update = 0;
	$Fatal = 0;
	undef $And;
	$Final = 0;
	undef $Success;
	undef $Profile;
	undef $Tables;
	undef $Fail_page;
	undef $Success_page;
	undef $No_error;

	# copy global order check routines
	$OrderCheck = { %{$Global::OrderCheck || {} }};

	# overlay any catalog order check routines
	my $r;
	if ($r = $Vend::Cfg->{CodeDef}{OrderCheck} and $r = $r->{Routine}) {
		for (keys %$r) {
			$OrderCheck->{$_} = $r->{$_};
		}
	}

	return;
}

my %Parse = (

	'&charge'       =>	\&_charge,
	'&credit_card'  =>	\&_credit_card,
	'&return'       =>	\&_return,
	'&update'      	=>	\&_update,
	'&fatal'       	=>	\&_fatal,
	'&and'       	=>	\&_and_check,
	'&or'       	=>	\&_or_check,
	'&format'		=> 	\&_format,
	'&tables'		=> 	sub { $Tables = $_[1]; return 1; },
	'&noerror'		=> 	sub { $No_error = $_[1] },
	'&success'		=> 	sub { $Success_page = $_[1] },
	'&fail'         =>  sub { $Fail_page    = $_[1] },
	'&final'		=>	\&_final,
	'&calc'			=>  sub { Vend::Interpolate::tag_calc($_[1]) },
	'&perl'			=>  sub { Vend::Interpolate::tag_perl($Tables, {}, $_[1]) },
	'&test'			=>	sub {		
								my($ref,$params) = @_;
								$params =~ s/\s+//g;
								return $params;
							},
	'&set'			=>	sub {		
								my($ref,$params) = @_;
								my ($var, $value) = split /\s+/, $params, 2;
								$::Values->{$var} = $value;
								return 1;
							},
	'&setcheck'			=>	sub {		
								my($ref,$params) = @_;
								my ($var, $value) = split /\s+/, $params, 2;
								$::Values->{$var} = $value;
								my $msg = errmsg("%s set failed.", $var);
								return ($value, $var, $msg);
							},
);

sub _update {
	$Update = is_yes($_[1]);
	return 1;
}

sub _fatal {
	$Fatal = ( defined($_[1]) && ($_[1] =~ /^[yYtT1]/) ) ? 1 : 0;
	return 1;
}

sub _final {
	$Final = ( defined($_[1]) && ($_[1] =~ /^[yYtT1]/) ) ? 1 : 0;
	return 1;
}

sub _return {
	$Success = ( defined($_[1]) && ($_[1] =~ /^[yYtT1]/) ) ? 1 : 0;
}

sub _format {
	my($ref, $params, $message) = @_;
	no strict 'refs';
	my ($routine, $var, $val) = split /\s+/, $params, 3;

	my (@return);

#::logDebug("OrderCheck = $OrderCheck routine=$routine");
	my $sub;
	my @args;
	if( $sub = $Parse{$routine}) {
		@args = ($var, $val, $message);
		undef $message;
	}
	elsif ($OrderCheck and $sub = $OrderCheck->{$routine}) {
#::logDebug("Using coderef OrderCheck = $sub");
		@args = ($ref,$var,$val,$message);
		undef $message;
	}
	elsif (defined &{"_$routine"}) {
		$sub = \&{"_$routine"};
		@args = ($ref,$var,$val,$message);
	}
	else {
		return (undef, $var, errmsg("No format check routine for '%s'", $routine));
	}

	@return = $sub->(@args);

	if(! $return[0] and $message) {
		$return[2] = $message;
	}
	return @return;
}

sub chain_checks {
	my ($or, $ref, $checks, $err, $vref) = @_;
	my ($var, $val, $mess, $message);
	my $result = 1;
	$mess = "$checks $err";
	while($mess =~ s/(\S+=\w+)[\s,]*//) {
		my $check = $1;
		($val, $var, $message) = do_check($check, $vref);
		return undef if ! defined $var;
		if($val and $or) {
			1 while $mess =~ s/(\S+=\w+)[\s,]*//;
			return ($val, $var, $message)
		}
		elsif ($val) {
			$result = 1;
			next;
		}
		else {
			next if $or;
			1 while $mess =~ s/(\S+=\w+)[\s,]*//;
			return($val, $var, $mess);
		}
	}
	return ($val, $var, $mess);
}

sub _and_check {
	if(! length($_[1]) ) {
		$And = 1;
		return (1);
	}
	return chain_checks(0, @_);
}

sub _or_check {
	if(! length($_[1]) ) {
		$And = 0;
		return (1);
	}
	return chain_checks(1, @_);
}

sub _charge {
	my ($ref, $params, $message) = @_;
	my $result;
	my $opt;
	if ($params =~ /^custom\s+/) {
		$opt = {};
	}
	else {
		$params =~ s/(\w+)\s*(.*)/$1/s;
		$opt = get_option_hash($2);
	}

	eval {
		$result = Vend::Payment::charge($params, $opt);
	};
	if($result) {
		# do nothing, OK
	}
	elsif($@) {
		my $msg = errmsg("Fatal error on charge operation '%s': %s", $params, $@);
		::logError($msg);
		$message = $msg;
	}
	elsif( $Vend::Session->{payment_error} ) {
		# do nothing, no extended messages
		$message = errmsg(
						"Charge failed, reason: %s",
						$Vend::Session->{payment_error},
					)
			if ! $message;
	}
	else {
		$message = errmsg(
					"Charge operation '%s' failed.",
					($ref->{mv_cyber_mode} || $params),
					)
			if ! $message;
	}
#::logDebug("charge result: result=$result params=$params message=$message");
	return ($result, $params, $message);
}

sub _credit_card {
	my($ref, $params) = @_;
	my $subname;
	my $sub;
	my $opt;

	$params =~ s/^\s+//;
	$params =~ s/\s+$//;

	# Make a copy if we need to keep the credit card number in memory for
	# a while

	# New or Compatibility to get options

	if($params =~ /=/) {		# New
		$params =~ s/^\s*(\w+)(\s+|$)//
			and $subname = $1;
		$subname = 'standard' if ! $subname;
		$opt = get_option_hash($params);
	}
	else {      				# Compat
		$opt = {};
		$opt->{keep} = 1 if $params =~ s/\s+keep//i;
	
		if($params =~ s/\s+(.*)//) {
			$opt->{accepted} = $1;
		}
		$subname = $params;
	}

	$sub = $subname eq 'standard'
		 ? \&encrypt_standard_cc
		 :	$Global::GlobalSub->{$subname};

	if(! $sub) {
		::logError("bad credit card check GlobalSub: '%s'", $subname);
		return undef;
	}

	if($opt->{keep}) {
		my (%cgi) = %$ref;
		$ref = \%cgi;
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
				= $sub->($ref, undef, $opt );
	};

	if($@) {
		::logError("credit card check (%s) error: %s", $subname, $@);
		return undef;
	}
	elsif(! $::Values->{mv_credit_card_valid}) {
		return (0, 'mv_credit_card_valid', $::Values->{mv_credit_card_error});
	}
	else {
		return (1, 'mv_credit_card_valid');
	}
}

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


# Validate credit card routine
# by Jon Orwant, from Business::CreditCard and well-known algorithms

sub luhn {
	my ($number,$min_digits) = @_;
	my ($i, $sum, $weight);

	$min_digits ||= 13;
	$min_digits = 2 if $min_digits < 2;

	$number =~ s/\D//g;

	return 0 unless length($number) >= $min_digits && 0+$number;

	for ($i = 0; $i < length($number) - 1; $i++) {
		$weight = substr($number, -1 * ($i + 2), 1) * (2 - ($i % 2));
		$sum += (($weight < 10) ? $weight : ($weight - 9));
	}

	return 1 if substr($number, -1) == (10 - $sum % 10) % 10;
	return 0;
}


sub build_cc_info {
	my ($cardinfo, $template) = @_;

	if (ref $cardinfo eq 'SCALAR') {
		$cardinfo = { MV_CREDIT_CARD_NUMBER => $$cardinfo };
	} elsif (! ref $cardinfo) {
		$cardinfo = { MV_CREDIT_CARD_NUMBER => $cardinfo };
	} elsif (ref $cardinfo eq 'ARRAY') {
		my $i = 0;
		my %c = map { $_ => $cardinfo->[$i++] } qw(
			MV_CREDIT_CARD_NUMBER
			MV_CREDIT_CARD_EXP_MONTH
			MV_CREDIT_CARD_EXP_YEAR
			MV_CREDIT_CARD_CVV2
			MV_CREDIT_CARD_TYPE
		);
		$cardinfo = \%c;
	} elsif (ref $cardinfo ne 'HASH') {
		return;
	}

	if(my $num = $cardinfo->{MV_CREDIT_CARD_NUMBER}) {
		my @quads;
		$num =~ s/\D//g;
		@quads = $num =~ m{(\d\d\d\d)(\d\d\d\d)(\d\d\d\d)(\d+)};
		$cardinfo->{MV_CREDIT_CARD_QUADS} = join "-", @quads;
	}

	$template = $template ||
		$::Variable->{MV_CREDIT_CARD_INFO_TEMPLATE} ||
		join("\t", qw(
			{MV_CREDIT_CARD_TYPE}
			{MV_CREDIT_CARD_NUMBER}
			{MV_CREDIT_CARD_EXP_MONTH}/{MV_CREDIT_CARD_EXP_YEAR}
		)) . "\n";

	$cardinfo->{MV_CREDIT_CARD_TYPE} ||=
		guess_cc_type($cardinfo->{MV_CREDIT_CARD_NUMBER});

	return Vend::Interpolate::tag_attr_list($template, $cardinfo);
}


sub guess_cc_type {
	my ($ccnum) = @_;
	$ccnum =~ s/\D+//g;

	my $country = uc($::Values->{$::Variable->{MV_COUNTRY_FIELD} || 'country'} || '');

	if(my $subname = $Vend::Cfg->{SpecialSub}{guess_cc_type}) {
		my $sub = $Vend::Cfg->{Sub}{$subname} || $Global::GlobalSub->{$subname};
		my $guess;
		if( $sub and $guess = $sub->($ccnum) ) {
			return $guess;
		}
	}

	# based on logic from Business::CreditCard
	if ($ccnum eq '')
	{ return '' }

	elsif ($ccnum =~ /^4(?:\d{12}|\d{15})$/)
	{ return 'visa' }

	elsif ($ccnum =~ /^5[1-5]\d{14}$/)
	{ return 'mc' }

	elsif (
		$ccnum =~ /^30[0-5]\d{11}(?:\d{2})?$/   # Diners Club: 300-305
		or $ccnum =~ /^3095\d{10}(?:\d{2})?$/   # Diners Club: 3095
		or $ccnum =~ /^3[68]\d{12}(?:\d{2})?$/  # Diners Club: 36
		or $ccnum =~ /^6011\d{12}$/
		or $ccnum =~ /^64[4-9]\d{13}$/
		or $ccnum =~ /^65\d{14}$/
		or ( $ccnum =~ /^62[24-68]\d{13}$/ and $country ne 'CN' )  # China Unionpay
		or ( $ccnum =~ /^35(?:2[89]|[3-8]\d)\d{10}$/ and $country eq 'US' )  # JCB
	)
	{ return 'discover' }

	elsif ($ccnum =~ /^3[47]\d{13}$/)
	{ return 'amex' }

	elsif ($ccnum =~ /^3(?:6\d{12}|0[0-5]\d{11})$/)
	{ return 'dinersclub' }

	elsif ($ccnum =~ /^38\d{12}$/)
	{ return 'carteblanche' }

	elsif ($ccnum =~ /^2(?:014|149)\d{11}$/)
	{ return 'enroute' }

	elsif ($ccnum =~ /^(?:3\d{15}|2131\d{11}|1800\d{11})$/)
	{ return 'jcb' }

	elsif (
		$ccnum =~ /^49(?:03(?:0[2-9]|3[5-9])|11(?:0[1-2]|7[4-9]|8[1-2])|36[0-9]{2})\d{10}(?:\d{2,3})?$/
		or $ccnum =~ /^564182\d{10}(?:\d{2,3})?$/
		or $ccnum =~ /^6(?:3(?:33[0-4][0-9])|759[0-9]{2})\d{10}(?:\d{2,3})?$/
	)
	{ return 'switch' }

	elsif ($ccnum =~ /^56(?:10\d\d|022[1-5])\d{10}$/)
	{ return 'bankcard' }

	elsif ($ccnum =~ /^6(?:3(?:34[5-9][0-9])|767[0-9]{2})\d{10}(?:\d{2,3})?$/)
	{ return 'solo' }

	elsif ($ccnum =~ /^62[24-68]\d{13}$/)
	{ return 'chinaunionpay' }

	elsif ($ccnum =~ /^6(?:304|7(?:06|09|71))\d{12,15}$/)
	{ return 'laser' }

	else
	{ return $::Variable->{MV_PAYMENT_OTHER_CARD} || 'other' }
}


# Takes a reference to a hash (usually %CGI::values) that contains
# the following:
# 
#    mv_credit_card_number      The actual credit card number
#    mv_credit_card_exp_all     A combined expiration MM/YY
#    mv_credit_card_exp_month   Month only, used if _all not present
#    mv_credit_card_exp_year    Year only, used if _all not present
#    mv_credit_card_cvv2        CVV2 verification number from back of card
#    mv_credit_card_type        A = Amex, D = Discover, etc. Attempts
#                               to guess from number if not there
#    mv_credit_card_separate    Causes mv_credit_card_info to contain only number, must
#                               then develop expiration from the above

sub encrypt_standard_cc {
	my($ref, $nodelete, $opt) = @_;
	my($valid, $info);

	$opt = {} unless ref $opt;
	my @deletes = qw /
					mv_credit_card_type		mv_credit_card_number
					mv_credit_card_exp_year	mv_credit_card_exp_month
					mv_credit_card_force	mv_credit_card_exp_reference
					mv_credit_card_exp_all	mv_credit_card_exp_separate  
					mv_credit_card_cvv2
					/;

	my $month	= $ref->{mv_credit_card_exp_month}	|| '';
	my $type	= $ref->{mv_credit_card_type}		|| '';
	my $num		= $ref->{mv_credit_card_number}		|| '';
	my $year	= $ref->{mv_credit_card_exp_year}	|| '';
	my $all		= $ref->{mv_credit_card_exp_all}	|| '';
	my $cvv2	= $ref->{mv_credit_card_cvv2}		|| '';
	my $force	= $ref->{mv_credit_card_force}		|| '';
	my $separate = $ref->{mv_credit_card_separate}  || $opt->{separate} || '';

	delete @$ref{@deletes}        unless ($opt->{nodelete} or $nodelete);

	# remove unwanted chars from card number
	$num =~ tr/0-9//cd;

	# error will be pushed on this if present
	my @return = (
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
	elsif ($month >= 1  and $month <= 12 and $year) {
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

	unless ($num) {
		my $msg = errmsg("Missing credit card number");
		$Vend::Session->{errors}{mv_credit_card_valid} = $msg;
		push @return, $msg;
		return @return;
	}
	
	$type = guess_cc_type($num) unless $type;

	if ($type and $opt->{accepted} and $opt->{accepted} !~ /\b$type\b/i) {
		my $msg = errmsg("Sorry, we don't accept credit card type '%s'.", $type);
		$Vend::Session->{errors}{mv_credit_card_valid} = $msg;
		push @return, $msg;
		return @return;
	}
	elsif ($type) {
		$return[5] = $type;
	}
	elsif(! $opt->{any}) {
		my $msg = errmsg("Can't figure out credit card type from number.");
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
	
	my $encrypt_string = $separate ? $num :
		build_cc_info( [$num, $month, $year, $cvv2, $type] );
	$info = pgp_encrypt ($encrypt_string);

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

sub onfly {
	my ($code, $qty, $opt) = @_;
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
	@parms = split /$joiner|\0/, $item_text;
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

# Email the processed order. This is a legacy routine, not normally used
# any more. Order email is normally sent via Route.
sub mail_order {
	my ($email, $order_no) = @_;
	$email = $Vend::Cfg->{MailOrderTo} unless $email;
	my($body, $ok);
	my($subject);
# LEGACY
	if ($::Values->{mv_order_report}) {
		unless( allowed_file($::Values->{mv_order_report}) ) {
			log_file_violation ($::Values->{mv_order_report}, 'mail_order');
			return undef;
		}
		$body = readin($::Values->{mv_order_report})
	}
# END LEGACY
	$body = readfile($Vend::Cfg->{OrderReport})
		if ! $body;
	unless (defined $body) {
		::logError(
			q{Cannot find order report in:

			OrderReport=%s
			mv_order_report=%s

trying one more time. Fix this.},
				$Vend::Cfg->{OrderReport},
				$::Values->{mv_order_report},
			);
		unless( allowed_file($Vend::Cfg->{OrderReport}) ) {
			log_file_violation($Vend::Cfg->{OrderReport}, 'mail_order');
			return undef;
		}
		$body = readin($Vend::Cfg->{OrderReport});
		return undef if ! $body;
	}
	return undef unless defined $body;

	$order_no = update_order_number() unless $order_no;

	$body = interpolate_html($body);

	$body = pgp_encrypt($body) if $Vend::Cfg->{PGP};

	track_order($order_no, $body);

	$subject = $::Values->{mv_order_subject} || "ORDER %n";

	if(defined $order_no) {
		$subject =~ s/%n/$order_no/;
	}
	else { $subject =~ s/\s*%n\s*//g; }

	$ok = send_mail($email, $subject, $body);
	return $ok;
}

sub pgp_encrypt {
	my($body, $key, $cmd) = @_;
#::logDebug("called pgp_encrypt key=$key cmd=$cmd");
	$cmd = $Vend::Cfg->{EncryptProgram} unless $cmd;
	$key = $Vend::Cfg->{EncryptKey}	    unless $key;
#::logDebug("pgp_encrypt using key=$key cmd=$cmd");

	$key =~ s/,/ /g;	# turn commas to spaces
	$key =~ s/^\s+//;	# strip leading spaces
	$key =~ s/\s+$//;	# strip trailing spaces
	$key =~ s/\s+/ /g;	# convert multiple spaces to single spaces

	my @keys = split /\s/, $key;		

	my $keyparam;

	if("\L$cmd" eq 'none') {
		return ::errmsg("NEED ENCRYPTION ENABLED.");
	}
	elsif(! $key) {
		return ::errmsg("NEED ENCRYPTION KEY POINTER.");
	}
	elsif($cmd =~ m{^(?:/\S+/)?\bgpg$}) {
		$cmd .= " --batch --always-trust -e -a ";
		$keyparam = ' -r ';
	}
	elsif($cmd =~ m{^(?:/\S+/)?pgpe$}) {
		$cmd .= " -fat ";
		$keyparam = ' -r ';
	}
	elsif($cmd =~ m{^(?:/\S+/)?\bpgp$}) {
		$cmd .= " -fat - ";
		$keyparam = ' ';
	}

	if($cmd =~ /[;|]/) {
		die ::errmsg("Illegal character in encryption command: %s", $cmd);
	}


	$cmd =~ s/%%/:~PERCENT~:/g;

	foreach my $thiskey (@keys) {
		$thiskey =~ s/'/\\'/g;
		$cmd .= "$keyparam '$thiskey' ";
	}  
	$cmd =~ s/:~PERCENT~:/%/g;

#::logDebug("after  pgp_encrypt key=$key cmd=$cmd");

	my $fpre = $Vend::Cfg->{ScratchDir} . "/pgp.$Vend::Session->{id}.$$";
	$cmd .= " >$fpre.out";
	$cmd .= " 2>$fpre.err" unless $cmd =~ /2>/;
	open(PGP, "|$cmd")
			or die "Couldn't fork: $!";
	print PGP $body;
	close PGP;

	if($?) {
		my $errno = $?;
		my $status = $errno;
		if($status > 255) {
			$status = $status >> 8;
			$! = $status;
		}
		logError("PGP failed with error level %s, status %s: $!", $?, $status);
		if($status) {
			logError("PGP hard failure, command that failed: %s", $cmd);
			return;
		}
	}
	$body = readfile("$fpre.out");
	unlink "$fpre.out";
	unlink "$fpre.err";
	return $body;
}

sub do_check {
		local($_) = shift;
		my $ref = \%CGI::values;
		my $vref = shift || $::Values;

		my $conditional_update;
		my $parameter = $_;
		my($var, $val, $m, $message);
		if (/^&/) {
			($var,$val) = split /[\s=]+/, $parameter, 2;
		}
		elsif ($parameter =~ /(\w+)[\s=]+(.*)/) {
			my $k = $1;
			my $v = $2;
			$conditional_update = $Update;
			$m = $v =~ s/\s+(.*)// ? $1 : undef;
			($var,$val) =
				('&format',
				  $v . ' ' . $k  . ' ' .  $vref->{$k}
				  );
		}
		else {
			logError("Unknown order check '%s' in profile %s", $parameter, $Profile);
			return undef;
		}
		$val =~ s/&#(\d+);/chr($1)/ge;

		if ($Parse{$var}) {
			## $vref added for chained checks only
			($val, $var, $message) = $Parse{$var}->($ref, $val, $m, $vref);
		}
		else {
			logError( "Unknown order check parameter in profile %s: %s=%s",
					$Profile,
					$var,
					$val,
					);
			return undef;
		}
#::logDebug("&Vend::Order::do_check returning val=$val, var=$var, message=$message");
		if($conditional_update and $val) {
			::update_values($var);
		}
		return ($val, $var, $message);
}

sub check_order {
	my ($profiles, $vref, $individual) = @_;
	reset_order_vars();
	my $status;
	$Vend::Session->{errors} = {}
		unless ref $Vend::Session->{errors} eq 'HASH';

	## Must have some security on mv_individual_profile because data
	## lookups can be done via filter and/or unique
	if($individual and ! delete($::Scratch->{mv_individual_profile})) {
		::logError("Individual profile supplied without scratch authorization");
		undef $individual;
	}

#::logDebug("nextpage=$CGI::values{mv_nextpage}");
	for my $profile (split /\0+/, $profiles) {

		$status = check_order_each($profile, $vref, $individual);
		
		# only do the individual checks once
		undef $individual;

		my $np = $CGI::values{mv_nextpage};
		if ($status) {
			if($Success_page) {
				$np = $CGI::values{mv_nextpage} = $Success_page;
			}
			elsif ($CGI::values{mv_success_href}) {
				$np = $CGI::values{mv_nextpage} = $CGI::values{mv_success_href};
			}

			my $f = $CGI::values{mv_success_form};

			if($CGI::values{mv_success_zero}) {
				%CGI::values = ();
				$CGI::values{mv_nextpage} ||= $np;
			}

			if($f) {
				my $r = Vend::Util::scalar_to_hash($f);
				while (my ($k, $v) = each %$r) {
					$CGI::values{$k} = $v;
				}
			}
		}
		else {
#::logDebug("Got to status=$status on profile=$profile");
			if($Fail_page) {
				$np = $CGI::values{mv_nextpage} = $Fail_page;
			}
			elsif ($CGI::values{mv_fail_href}) {
				$np = $CGI::values{mv_nextpage} = $CGI::values{mv_fail_href};
			}

			my $f = $CGI::values{mv_fail_form};

			if($CGI::values{mv_fail_zero}) {
				%CGI::values = ();
				$CGI::values{mv_nextpage} ||= $np;
			}

			if($f) {
				my $r = Vend::Util::scalar_to_hash($f);
				while (my ($k, $v) = each %$r) {
					$CGI::values{$k} = $v;
				}
			}
		}

		if ($Final and ! scalar @{$Vend::Items}) {
			$status = 0;
			$::Values->{"mv_error_items"}		=
				$Vend::Session->{errors}{items}	=
					errmsg(
						"You might want to order something! No items in cart.",
					);
		}
#::logDebug("FINISH checking profile $profile: Fatal=$Fatal Final=$Final Status=$status");

		# first profile to fail prevents all other profiles from running
		last unless $status;

	}

	my $errors = join "\n", @Errors;
#::logDebug("Errors after checking profile(s):\n$errors") if $errors;
	$errors = '' unless defined $errors and ! $Success;
#::logDebug("status=$status nextpage=$CGI::values{mv_nextpage}");
	return ($status, $Final, $errors);
}

sub check_order_each {
	my ($profile, $vref, $individual) = @_;
	my $params;
	$Profile = $profile;
	if(defined $Vend::Cfg->{OrderProfileName}->{$profile}) {
		$profile = $Vend::Cfg->{OrderProfileName}->{$profile};
		$params = $Vend::Cfg->{OrderProfile}->[$profile];
	}
	elsif($profile =~ /^\d+$/) {
		$params = $Vend::Cfg->{OrderProfile}->[$profile];
	}
	elsif(defined $::Scratch->{$profile}) {
		$params = $::Scratch->{$profile};
	}
	else {
		::logError("Order profile %s not found", $profile);
		return undef;
	}
	return undef unless $params;

	$params = interpolate_html($params);
	$params =~ s/\\\n//g;

	$And = 1;
	$Fatal = $Final = 0;

	my($var,$val,$message);
	my $status = 1;
	my(@param) = split /[\r\n]+/, $params;

	## Find marker for individual insertion
	if($individual) {
		my $mark;
		my $i = -1;
		for(@param) {
			$i++;
			next unless /^\s*\&fatal\s*=\s*(.*)/i and is_yes($1);
			$mark = $i;
			last;
		}
		if(! defined  $mark) {
			$i = -1;
			for(@param) {
				$i++;
				next unless /^\s*\&update\s*=\s*(.*)/i and is_yes($1);
				$mark = $i + 1;
				last;
			}
		}
		$mark = 0 unless defined $mark;
		my @newparams = split /\0/, $individual;
		splice(@param, $mark, 0, @newparams);
	}

#::logDebug("Total profile:\n" . join ("\n", @param));
	my $m;
	my $join;
	my $here;
	my $last_one = 1;

	for(@param) {
		if(/^$here$/) {
			$_ = $join;
			undef $here;
			undef $join;
		}
		($join .= "$_\n", next) if $here;
		if($join) {
			$_ = "$join$_";
			undef $join;
		}
		if(s/<<(\w+);?\s*$//) {
			$here = $1;
			$join = "$_\n";
			next;
		}
		next unless /\S/;
		next if /^\s*#/;
		if(s/\\$//) {
			$join = $_;
			next;
		}
		s/^\s+//;
		s/\s+$//;
		($val, $var, $message) = do_check($_, $vref);

		# no actual check on this line, skip to next
		next if /^&(?:and|or)\s*$/i;

		if(defined $And) {
			if($And) {
				$val = ($last_one && $val);
			}
			else {
				$val = ($last_one || $val);
			}
			undef $And;
		}
		$last_one = $val;
		$status = 0 unless $val;
		if ($var) {
			if ($val) {
				$::Values->{"mv_status_$var"} = $message
					if defined $message and $message;
				delete $Vend::Session->{errors}{$var};
				delete $::Values->{"mv_error_$var"};
			}
			else {
# LEGACY
				$::Values->{"mv_error_$var"} = $message;
# END LEGACY
				if( $No_error ) {
					# do nothing
				}
				elsif( $Vend::Session->{errors}{$var} ) {
					if ($message and $Vend::Session->{errors}{$var} !~ /\Q$message/) {
						$Vend::Session->{errors}{$var} = errmsg(
							'%s and %s',
							$Vend::Session->{errors}{$var},
							$message
						);
					}
				}
				else {
					$Vend::Session->{errors}{$var} = $message ||
						errmsg('%s: failed check', $var);
				}
				push @Errors, "$var: $message";
			}
		}
		if (defined $Success) {
			$status = $Success;
			last;
		}
		last if $Fatal && ! $status;
	}
	return $status;
}

use vars qw/ %state_template %state_error %zip_routine %zip_error /;
$state_error{US} = "'%s' not a two-letter state code";
$state_error{CA} = "'%s' not a two-letter province code";
$state_template{US} = <<EOF;
| AL AK AZ AR CA CO CT DE FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO |
| MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY |
| PR DC AA AE GU VI AS MP FM MH PW AP FP FPO APO |
EOF

# NF = Newfoundland is deprecated and will be removed at some point;
# use NL instead
$state_template{CA} = <<EOF;
| AB BC MB NB NF NL NS NT NU ON PE QC SK YT YK |
EOF

$zip_error{US} = "'%s' not a US zip code";
$zip_routine{US} = sub { $_[0] =~ /^\s*\d\d\d\d\d(?:-?\d\d\d\d)?\s*$/ };

$zip_error{CA} = "'%s' not a Canadian postal code";
$zip_routine{CA} = sub {
	my $val = shift;
	return undef unless defined $val;
	$val =~ s/[_\W]+//g;
	$val =~ /^[ABCEGHJKLMNPRSTVXYabceghjklmnprstvxy]\d[A-Za-z]\d[A-Za-z]\d$/;
};

sub _state_province {
	my($ref,$var,$val) = @_;
	my $error;
	if(length($val) != 2) {
		$error = 1;
	}
	else {
		my $pval	= $::Variable->{MV_VALID_PROVINCE}
					? " $::Variable->{MV_VALID_PROVINCE} "
					: $state_template{CA};
		my $sval	= $::Variable->{MV_VALID_STATE}
					? " $::Variable->{MV_VALID_STATE} "
					: $state_template{US};
		$error = 1
			unless  $sval =~ /\s$val\s/i or $pval =~ /\s$val\s/i ;
	}
	if($error) {
		return (undef, $var,
			errmsg( "'%s' not a two-letter state or province code", $val )
		);
	}
	return (1, $var, '');
}

sub _state {
	my($ref,$var,$val) = @_;
	my $sval	= $::Variable->{MV_VALID_STATE}
				? " $::Variable->{MV_VALID_STATE} "
				: $state_template{US};

	if( $val =~ /\S/ and $sval =~ /\s$val\s/i ) {
		return (1, $var, '');
	}
	else {
		return (undef, $var,
			errmsg( $state_error{US}, $val )
		);
	}
}

sub _province {
	my($ref,$var,$val) = @_;
	my $pval	= $::Variable->{MV_VALID_PROVINCE}
				? " $::Variable->{MV_VALID_PROVINCE} "
				: $state_template{CA};
	if( $val =~ /\S/ and $pval =~ /\s$val\s/i) {
		return (1, $var, '');
	}
	else {
		return (undef, $var,
			errmsg( $state_error{CA}, $val )
		);
	}
}

sub _get_cval {
	my ($ref, $var) = @_;
	my $cfield = $::Variable->{MV_COUNTRY_FIELD} || 'country';
	my $cval = $ref->{$cfield} || $::Values->{$cfield};

	if($var =~ /^b_/ and $ref->{"b_$cfield"} || $::Values->{"b_$cfield"}) {
		$cval = $ref->{"b_$cfield"} || $::Values->{"b_$cfield"};
	}
	return $cval;
}

sub _multizip {
	my($ref,$var,$val) = @_;

	$val =~ s/^\s+//;
	my $error;
	my $cval = _get_cval($ref, $var);

	if (my $sub = $zip_routine{$cval}) {
		$sub->($val) or $error = 1;
	}
	elsif($::Variable->{MV_ZIP_REQUIRED}) {
	    " $::Variable->{MV_ZIP_REQUIRED} " =~ /\s$cval\s/
			and
		length($val) < 4 and $error = 1;
	}

	if($error) {
		my $tpl = $zip_error{$cval} || "'%s' not a valid post code for country '%s'";
		my $msg = errmsg( $tpl, $val, $cval );
		return (undef, $var, $msg );
	}
	return (1, $var, '');
}

sub _multistate {
	my($ref,$var,$val) = @_;

	my $error;
	my $cval = _get_cval($ref, $var);

	if(my $sval = $state_template{$cval}) {
		$error = 1 unless $sval =~ /\s$val\s/;
	}
	elsif($::Variable->{MV_STATE_REQUIRED}) {
	    " $::Variable->{MV_STATE_REQUIRED} " =~ /\s$cval\s/
			and
		length($val) < 2 and $error = 1;
	}

	if($error) {
		my $tpl = $state_error{$cval} || "'%s' not a valid state for country '%s'";
		my $msg = errmsg( $tpl, $val, $cval );
		return (undef, $var, $msg );
	}
	return (1, $var, '');
}

sub _array {
	return undef unless defined $_[1];
	[split /\s*[,\0]\s*/, $_[1]]
}

sub _yes {
	return( defined($_[2]) && ($_[2] =~ /^[yYtT1]/));
}

sub _postcode {
	my($ref,$var,$val) = @_;
	((_zip(@_))[0] or (_ca_postcode(@_))[0])
		and return (1, $var, '');
	return (undef, $var, errmsg("'%s' not a US zip or Canadian postal code", $val));
}

sub _ca_postcode {
	my($ref,$var,$val) = @_;
	$val =~ s/[_\W]+//g;
	defined $val
		and
	$val =~ /^[ABCEGHJKLMNPRSTVXYabceghjklmnprstvxy]\d[A-Za-z]\d[A-Za-z]\d$/
		and return (1, $var, '');
	return (undef, $var, errmsg("'%s' not a Canadian postal code", $val));
}

sub _zip {
	my($ref,$var,$val) = @_;
	defined $val and $val =~ /^\s*\d{5}(?:-?\d{4})?\s*$/
		and return (1, $var, '');
	return (undef, $var, errmsg("'%s' not a US zip code", $val));
}

*_us_postcode = \&_zip;

sub _phone {
	my($ref,$var,$val) = @_;
	defined $val and $val =~ /\d{3}.*\d{3}/
		and return (1, $var, '');
	return (undef, $var, errmsg("'%s' not a phone number", $val));
}

sub _phone_us {
	my($ref, $var,$val) = @_;
	if($val and $val =~ /\d{3}.*?\d{4}/) {
		return (1, $var, '');
	}
	else {
		return (undef, $var, errmsg("'%s' not a US phone number", $val));
	}
}

sub _phone_us_with_area {
	my($ref, $var,$val) = @_;
	if($val and $val =~ /\d{3}\D*\d{3}\D*\d{4}/) {
		return (1, $var, '');
	}
	else {
		return (undef, $var, errmsg("'%s' not a US phone number with area code", $val));
	}
}

sub _phone_us_with_area_strict {
	my($ref, $var,$val) = @_;
	if($val and $val =~ /^\d{3}-\d{3}-\d{4}$/) {
		return (1, $var, '');
	}
	else {
		return (undef, $var,
			errmsg("'%s' not a US phone number with area code (strict formatting)", $val)
		);
	}
}

sub _email {
	my($ref, $var, $val) = @_;
	if($val and $val =~ /[\040-\077\101-\176]+\@[-A-Za-z0-9.]+\.[A-Za-z]+/) {
		return (1, $var, '');
	}
	else {
		return (undef, $var,
			errmsg( "'%s' not an email address", $val )
		);
	}
}

sub _mandatory {
	my($ref,$var,$val) = @_;
	return (1, $var, '')
		if (defined $ref->{$var} and $ref->{$var} =~ /\S/);
	return (undef, $var, errmsg("blank"));
}

sub _true {
	my($ref,$var,$val) = @_;
	return (1, $var, '') if is_yes($val);
	return (undef, $var, errmsg("false"));
}

sub _false {
	my($ref,$var,$val) = @_;
	return (1, $var, '') if is_no($val);
	return (undef, $var, errmsg("true"));
}

sub _defined {
	my($ref,$var,$val) = @_;
	return (1, $var, '')
		if defined $::Values->{$var};
	return (undef, $var, errmsg("undefined"));
}

sub _required {
	my($ref,$var,$val) = @_;
	return (1, $var, '')
		if (defined $val and $val =~ /\S/);
	return (1, $var, '')
		if (defined $ref->{$var} and $ref->{$var} =~ /\S/);
	return (undef, $var, errmsg("blank"));
}

sub _luhn {
	my($ref, $var, $val) = @_;

	return (1, $var, '') if luhn($val,2);
	return (undef, $var, errmsg('failed the LUHN-10 check'));
}

sub counter_number {
	my $file = shift || $Vend::Cfg->{OrderCounter};
	my $sql = shift;
	my $start = shift || '000000';
	my $date = shift;
	return Vend::Interpolate::tag_counter(
											$file,
											{
												sql => $sql,
												start => $start,
												date => $date
											}
										);
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
		$Vend::Interpolate::Values = $::Values = { %$value_save };
		eval {
			my $route = $Vend::Cfg->{Route_repository}{$c}
				or do {
					# Change to ::logDebug because of dynamic routes
					::logDebug("Non-existent order route %s, skipping.", $c);
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
#::logDebug("check_only -- profile=$c status=$status final=$final failed=$failed errors=$errors missing=$missing");
	$Vend::Interpolate::Values = $::Values = { %$value_save };
	return (! $failed, $final, $errors);
}

sub route_order {
	my ($route, $save_cart, $check_only) = @_;
	my $main = $Vend::Cfg->{Route};
	return unless $main;
	$route = 'default' unless $route;

	my $cart = [ @$save_cart ];

	my $save_mime = $::Instance->{MIME} || undef;

	my $encrypt_program = $main->{encrypt_program};

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

	# We empty @main so that we can push more routes on with cascade option
	push @routes, splice @main;

	my ($c,@out);
	my $status;
	my $errors = '';
	
	my @route_complete;
	my @route_failed;
	my @route_done;
	my $route_checked;
	$Vend::Session->{routes_run} = [];

	# Careful! If you set it on one order and not on another,
	# you must delete in between.

	my $no_increment = $check_only
						|| $main->{no_increment}
						|| $main->{counter_tid}
						|| $Vend::Session->{mv_order_number};
		
	unless($no_increment) {
		$::Values->{mv_order_number} = counter_number(
											$main->{counter},
											$main->{sql_counter},
											$main->{first_order_number},
											$main->{date_counter},
										);
	}

	my $value_save = { %{$::Values} };

	# We aren't going to allow encrypt_program setting from database as
	# that is a security problem
	my %override_key = qw/
		encrypt_program 1
	/;

	# Settable by user to indicate failure
	delete $::Scratch->{mv_route_failed};

	## Allow setting of a master transaction route. This allows 
	## setting tables in transaction mode, then only committing
	## once all routes have completed.
	my $master_transactions;

	ROUTES: {
		BUILD:
	foreach $c (@routes) {
		my $route = $Vend::Cfg->{Route_repository}{$c} || {};
		$main = $route if $route->{master};
		my $old;

		## Record the routes run
		push @{$Vend::Session->{routes_run}}, $c;

#::logDebug("route $c is: " . ::uneval($route));
		##### OK, can put variables in DB all the time. It can be dynamic
		##### from the database if $main->{dynamic_routes} is set. ITL only if
		##### $main->{expandable}.
		#####
		##### The encrypt_program key cannot be dynamic. You can set the
		##### key substition value instead.

		if($Vend::Cfg->{RouteDatabase} and $main->{dynamic_routes}) {
			my $ref = tag_data( $Vend::Cfg->{RouteDatabase},
								undef,
								$c, 
								{ hash => 1 }
								);
#::logDebug("Read dynamic route %s from database, got: %s", $c, $ref );
			if($ref) {
				$old = $route;
				$route = $ref;
				for(keys %override_key) {
					$route->{$_} = $old->{$_};
				}
			}
		}

		if(! %$route) {
			::logError("Non-existent order routing %s, skipping.", $c);
			next;
		}

		# Tricky, tricky
		if($route->{extended}) {
			my $ref = get_option_hash($route->{extended});
			if(ref $ref) {
				for(keys %$ref) {
#::logDebug("setting extended $_ = $ref->{$_}");
					$route->{$_} = $ref->{$_}
						unless $override_key{$_};
				}
			}
		}

		for(keys %$route) {
			$route->{$_} =~ s/^\s*__([A-Z]\w+)__\s*$/$::Variable->{$1}/;
			next unless $main->{expandable};
			next if $override_key{$_};
			next unless $route->{$_} =~ /\[/;
			$route->{$_} = ::interpolate_html($route->{$_});
		}
		#####
		#####
		#####

		## Make route available to subsidiary files
		$Vend::Session->{current_route} = $route;

		# Compatibility 
		if($route->{cascade}) {
			my @extra = grep /\S/, split /[\s,\0]+/, $route->{cascade};
			for(@extra) {
				$shelf->{$_} = [ @$cart ];
				push @main, $_;
			}
		}

		if($Vend::Session->{mv_order_number}) {
			$value_save->{mv_order_number} =
				$::Values->{mv_order_number} =
					$Vend::Session->{mv_order_number};
		}

		$Vend::Interpolate::Values = $::Values = { %$value_save };
		$::Values->{mv_current_route} = $c;
		my $pre_encrypted;
		my $credit_card_info;

		$Vend::Items = $shelf->{$c};

		Vend::Interpolate::flag( 'write', {}, $route->{write_tables})
			if $route->{write_tables};

		Vend::Interpolate::flag( 'transactions', {}, $route->{transactions})
			if $route->{transactions};

	eval {

	  PROCESS: {
		if(! $check_only and $route->{inline_profile}) {
			my $status;
			my $err;
			($status, undef, $err) = check_order($route->{inline_profile});
#::logDebug("inline profile returned status=$status errors=$err");
			die "$err\n" unless $status;
		}

		if ($CGI::values{mv_credit_card_number}) {
			$CGI::values{mv_credit_card_type} ||=
				guess_cc_type($CGI::values{mv_credit_card_number});
			my %attrlist = map { uc($_) => $CGI::values{$_} } keys %CGI::values;
			$::Values->{mv_credit_card_info} = build_cc_info(\%attrlist);
		}
		elsif ($::Values->{mv_credit_card_info}) {
			$::Values->{mv_credit_card_info} =~ /BEGIN\s+[PG]+\s+MESSAGE/
				and $pre_encrypted = 1;
		}

		if ($check_only and $route->{profile}) {
			$route_checked = 1;
			my ($status, $final, $missing) = check_order($route->{profile});
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

	  	last PROCESS if $check_only;

		if($route->{payment_mode}) {
			my $ok;
			$ok = Vend::Payment::charge($route->{payment_mode});
			if (! $ok) {
				die errmsg("Failed online charge for routing %s: %s",
								$c,
								$Vend::Session->{mv_payment_error}
							);
			}
			else {
				$Vend::Session->{route_payment_id} ||= {};
				$Vend::Session->{route_payment_id}{$c} = $Vend::Session->{payment_id};
			}
		}
		if(  $route->{credit_card}
				and ! $pre_encrypted
			    and $::Values->{mv_credit_card_info}
				)
		{
			$::Values->{mv_credit_card_info} = pgp_encrypt(
								$::Values->{mv_credit_card_info},
								($route->{pgp_cc_key} || $route->{pgp_key}),
								($route->{encrypt_program} || $main->{encrypt_program} || $encrypt_program),
							);
		}

		if($route->{counter_tid}) {
			## This is designed to allow order number setting in
			## the report code file
			$Vend::Session->{mv_transaction_id} = counter_number(
												$route->{counter_tid},
												$route->{sql_counter},
												$route->{first_order_number},
												$route->{date_counter},
											);
		}
		elsif($Vend::Session->{mv_order_number}) {
			$::Values->{mv_order_number} = $Vend::Session->{mv_order_number};
		}
		elsif(defined $route->{increment}) {
			$::Values->{mv_order_number} = counter_number(
												$main->{counter},
												$main->{sql_counter},
												$main->{first_order_number},
												$main->{date_counter},
											)
				if $route->{increment};
		}
		elsif($route->{counter}) {
			$::Values->{mv_order_number} = counter_number(
												$route->{counter},
												$route->{sql_counter},
												$route->{first_order_number},
												$route->{date_counter},
											);
		}

		# Pick up transaction ID if already set
		if($Vend::Session->{mv_transaction_id}) {
			$::Values->{mv_transaction_id} = $Vend::Session->{mv_transaction_id};
		}

		my $pagefile;
		my $page;
		if($route->{empty} and ! $route->{report}) {
			$page = '';
		}
		else {
			$pagefile = $route->{'report'} || $main->{'report'};
			$page = readfile($pagefile);
		}
		unless (defined $page) {
			my $msg = errmsg("No order report %s or %s found.",
							 $route->{'report'},
							 $main->{'report'});
			::logError("$msg\n");
			die("$msg\n");
		}

		my $use_mime;
		undef $::Instance->{MIME};
		if(not ($pre_encrypted || $route->{credit_card} || $route->{encrypt}) ) {
		    unless ($::Values->{mv_credit_card_info}
			    =~ s/^(\s*\w+\s+)(\d\d)[\d ]+(\d\d\d\d.*?)(?:\s+\d{3,4})?$/$1$2 NEED ENCRYPTION $3/) {
			$::Values->{mv_credit_card_info} = 'NEED ENCRYPTION';
		    }
		}
		eval {
			$page = interpolate_html($page) if $page;
		};
		if ($@) {
			die "Error while interpolating page $pagefile:\n $@";
		}
		$use_mime   = $::Instance->{MIME} || undef;
		$::Instance->{MIME} = $save_mime  || undef;

		if($route->{encrypt}) {
			$page = pgp_encrypt($page,
								$route->{pgp_key},
								($route->{encrypt_program} || $main->{encrypt_program} || $encrypt_program),
								);
		}
		my ($address, $reply, $to, $subject, $template);
		if($route->{attach}) {
			$Vend::Items->[0]{mv_order_report} = $page;
		}
		elsif ($route->{empty}) {
			# Do nothing
		}
		elsif ($address = $route->{email}) {
			$address = $::Values->{$address} if $address =~ /^\w+$/;
			$subject = $route->{subject} || $::Values->{mv_order_subject} || 'ORDER %s';
			$subject =~ s/%n/%s/;
			$subject = sprintf "$subject", $::Values->{mv_order_number};
			$reply   = $route->{reply} || $main->{reply};
			$reply   = $::Values->{$reply} if $reply =~ /^\w+$/;
			$to		 = $route->{email};
			my $ary = [$to, $subject, $page, $reply, $use_mime];
			for (qw/from bcc cc/) {
				if ($route->{$_}) {
					push @$ary, ucfirst($_) . ": $route->{$_}";
				}
			}
			push @out, $ary;
		}
		else {
			die "Empty order routing $c (and not explicitly empty).\nEither attach or email are required in the route setting.\n";
		}
		if ($route->{supplant}) {
			track_order($::Values->{mv_order_number}, $page);
		}
		if ($route->{track}) {
			my $fn = escape_chars($route->{track});
			Vend::Util::writefile($fn, $page)
				or ::logError("route tracking error writing %s: %s", $fn, $!);
			my $mode = $route->{track_mode} || '';
			if ($mode =~ s/^0+//) {
				chmod oct($mode), $fn;
			}
			elsif ($mode) {
				chmod $mode, $fn;
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
			my $mode = $route->{track_mode} || '';
			if ($mode =~ s/^0+//) {
				chmod oct($mode), $fn;
			}
			elsif ($mode) {
				chmod $mode, $fn;
			}
		}
		if($::Scratch->{mv_route_failed}) {
			my $msg = delete $::Scratch->{mv_route_error}
					|| ::errmsg('Route %s failed.', $c);
			::logError($msg);
			die $msg;
		}
	  } # end PROCESS
	};
		if($@) {
#::logDebug("route failed: $c");
			my $err = $@;
			$errors .=  errmsg(
							"Error during creation of order routing %s:\n%s",
							$c,
							$err,
						);
			if ($route->{error_ok}) {
				push @route_complete, $c;
				next BUILD;
			}
			next BUILD if $route->{continue};
			push @route_failed, $c;
			@out = ();
			@route_done = @route_complete;
			@route_complete = ();
			last ROUTES;
		}

		push @route_complete, $c;

	} #BUILD

	if(@main and ! @route_failed) {
		@routes = splice @main;
		redo ROUTES;
	}

  } #ROUTES

	my $msg;

	if($check_only) {
		$Vend::Interpolate::Values = $::Values = $value_save;
		$Vend::Items = $save_cart;
		if(@route_failed) {
			return (0, 0, $errors);
		}
		elsif($route_checked) {
			return (1, 1, '');	
		}
		else {
			return (1, undef, '');	
		}
	}

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
	$Vend::Interpolate::Values = $::Values = $value_save;
	$Vend::Items = $save_cart;

	for(@route_failed) {
		my $route = $Vend::Cfg->{Route_repository}{$_};

#::logDebug("checking route $_ for transactions");
		## We only want to roll back the master at the end
		next if $route->{master};


		if($route->{transactions}) {
#::logDebug("rolling back route $_");
			Vend::Interpolate::flag( 'rollback', {}, $route->{transactions})
		}
		next unless $route->{rollback};
		Vend::Interpolate::tag_perl(
					$route->{rollback_tables},
					{},
					$route->{rollback}
		);
	}

	for(@route_complete) {
		my $route = $Vend::Cfg->{Route_repository}{$_};
#::logDebug("checking route $_ for transactions");
		## We only want to commit the master if nothing failed
		next if $route->{master};

		if($route->{transactions}) {
#::logDebug("committing route $_");
			Vend::Interpolate::flag( 'commit', {}, $route->{transactions})
		}
		next unless $route->{commit};
		Vend::Interpolate::tag_perl(
					$route->{commit_tables},
					{},
					$route->{commit}
		);
	}

	if(! $errors) {
		delete $Vend::Session->{order_error};
#::logDebug("no errors, commiting main route");
		if($main->{transactions}) {
			Vend::Interpolate::flag( 'commit', {}, $main->{transactions})
		}
		if($main->{commit}) {
			Vend::Interpolate::tag_perl(
						$main->{commit_tables},
						{},
						$main->{commit}
			);
		}
	}
	else {
		if($main->{transactions}) {
#::logDebug("errors, rolling back main route");
			Vend::Interpolate::flag( 'rollback', {}, $main->{transactions})
		}
		if($main->{rollback}) {
			Vend::Interpolate::tag_perl(
						$main->{rollback_tables},
						{},
						$main->{rollback}
			);
		}
        $Vend::Session->{order_error} = $errors;
        ::logError("ERRORS on ORDER %s:\n%s", $::Values->{mv_order_number}, $errors);

		if ($main->{errors_to}) {
			send_mail(
				$main->{errors_to},
				errmsg("ERRORS on ORDER %s", $::Values->{mv_order_number}),
				$errors
				);
		}
	}

	# Get rid of this puppy
	$::Values->{mv_credit_card_info}
			=~ s/^(\s*\w+\s+)(\d\d)[\d ]+(\d\d\d\d)/$1$2 NEED ENCRYPTION $3/;

	# Clear these, we are done with them
	delete $Vend::Session->{mv_transaction_id};
	delete $Vend::Session->{current_route};

	# If we give a defined value, the regular mail_order routine will not
	# be called
#::logDebug("route errors=$errors supplant=$main->{supplant}");
	if($main->{supplant}) {
		return ($status, $::Values->{mv_order_number}, $main);
	}
	return (undef, $::Values->{mv_order_number}, $main);
}

## DO ORDER

# Order an item
sub do_order {
	$::Instance->{Volatile} = 1 if ! defined $::Instance->{Volatile}; # Allow non-volatility if previously defined

    my($path) = @_;
	my $code        = $CGI::values{mv_arg};
#::logDebug("do_order: path=$path");
	my $cart;
	my $page;
# LEGACY
	if($path =~ s:/(.*)::) {
		$cart = $1;
		if($cart =~ s:/(.*)::) {
			$page = $1;
		}
	}
# END LEGACY
	if(defined $CGI::values{mv_pc} and $CGI::values{mv_pc} =~ /_(\d+)/) {
		$CGI::values{mv_order_quantity} = $1;
	}
	$CGI::values{mv_cartname} = $cart if $cart;
	$CGI::values{mv_nextpage} = $page if $page;
# LEGACY
	$CGI::values{mv_nextpage} = $CGI::values{mv_orderpage}
								|| find_special_page('order')
		if ! $CGI::values{mv_nextpage};
# END LEGACY
	add_items($code);
    return 1;
}

my @Scan_modifiers = qw/
		mv_ad
		mv_an
		mv_bd
		mv_bd
/;

# Returns undef if interaction error
sub update_quantity {
    return 1 unless defined  $CGI::values{"quantity0"}
		|| $CGI::values{mv_quantity_update};
	my ($h, $i, $quantity, $modifier, $cart, $cartname, %altered_items, %old_items);

	if ($CGI::values{mv_cartname}) {
		$cart = $::Carts->{$cartname = $CGI::values{mv_cartname}} ||= [];
	}
	else {
		$cart = $Vend::Items;
		$cartname = $Vend::CurrentCart;
	}

	my ($raise_event, $quantity_raise_event)
		= @{$Vend::Cfg}{qw/CartTrigger CartTriggerQuantity/};
	$quantity_raise_event = $raise_event && $quantity_raise_event;

	my @mods;
	@mods = @{$Vend::Cfg->{UseModifier}} if $Vend::Cfg->{UseModifier};

#::logDebug("adding modifiers");
	push(@mods, (grep $_ !~ /^mv_/, split /\0/, $CGI::values{mv_item_option}))
		if defined $CGI::values{mv_item_option};

	my %seen;
	push @mods, grep defined $CGI::values{"${_}0"}, @Scan_modifiers;
	@mods = grep ! $seen{$_}++, @mods;

	foreach $h (@mods) {
		delete @{$::Values}{grep /^$h\d+$/, keys %$::Values};
		foreach $i (0 .. $#$cart) {
#::logDebug("updating line $i modifiers: " . ::uneval($cart->[$i]));
#::logDebug(qq{CGI value=$CGI::values{"$h$i"}});
			next if
				!   defined $CGI::values{"$h$i"}
				and defined $cart->[$i]{$h};
			$old_items{$i} ||= { %{$cart->[$i]} } if $raise_event;
			$modifier = $CGI::values{"$h$i"}
					  || (defined $cart->[$i]{$h} ? '' : undef);
#::logDebug("line $i modifier $h now $modifier");
			if (defined($modifier)) {
				$modifier =~ s/\0+/\0/g;
				$modifier =~ s/\0$//;
				$modifier =~ s/^\0//;
				$modifier =~ s/\0/, /g;
				$altered_items{$i} = 1
					if $raise_event
					and $cart->[$i]->{$h} ne $modifier;
				$cart->[$i]->{$h} = $modifier;
				$::Values->{"$h$i"} = $modifier;
				delete $CGI::values{"$h$i"};
			}
		}
	}

	foreach $i (0 .. $#$cart) {
#::logDebug("updating line $i quantity: " . ::uneval($cart->[$i]));
		my $line = $cart->[$i];
		$line->{mv_ip} = $i;
    	$quantity = $CGI::values{"quantity$i"};
    	next unless defined $quantity;
		my $do_update;
		my $old_item = $old_items{$i} ||= { %$line } if $raise_event;
    	if ($quantity =~ m/^\d*$/) {
        	$line->{'quantity'} = $quantity || 0;
			$do_update = 1;
			$altered_items{$i} = 1
				if $quantity_raise_event
				and $line->{quantity} != $old_item->{quantity};
    	}
    	elsif ($quantity =~ m/^[\d.]+$/
				and $Vend::Cfg->{FractionalItems} ) {
        	$line->{'quantity'} = $quantity;
			$do_update = 1;
			$altered_items{$i} = 1
				if $quantity_raise_event
				and $line->{quantity} != $old_item->{quantity};
    	}
		# This allows a last-positioned input of item quantity to
		# remove the item
		elsif ($quantity =~ s/.*\00$/0/) {
			$CGI::values{"quantity$i"} = $quantity;
			redo;
		}
		# This allows a multiple input of item quantity to
		# pass -- FIRST ONE CONTROLS
		elsif ($quantity =~ s/\0.*//) {
			$CGI::values{"quantity$i"} = $quantity;
			redo;
		}
		else {
			my $item = $line->{'code'};
			$line->{quantity} = int $line->{quantity};
        	$Vend::Session->{errors}{mv_order_quantity} =
				errmsg("'%s' for item %s is not numeric/integer", $quantity, $item);
    	}

		if($do_update and my $oe = $Vend::Cfg->{OptionsAttribute}) {
		  eval {
			my $loc = $Vend::Cfg->{Options_repository}{$line->{$oe}};
			if($loc and $loc->{item_update_routine}) {
				no strict 'refs';
				my $sub = \&{"$loc->{item_update_routine}"}; 
				if(defined $sub) {
					$sub->($line, $loc);
				}
			}
		  };
		  if($@) {
			::logError(
				"error during %s (option type %s) item_update_routine: %s",
				$line->{code},
				$line->{$oe},
				$@,
			);
		  }
		}

    	$::Values->{"quantity$i"} = delete $CGI::values{"quantity$i"};
		SKUSET: {
			my $sku;
			my $found_option;
			last SKUSET unless $sku = delete $CGI::values{"mv_sku$i"};
			my @sku = split /\0/, $sku, -1;
			for(@sku[1..$#sku]) {
				if (not length $_) {
				$_ = $::Variable->{MV_VARIANT_JOINER} || '0';
				next;
				}
				$found_option++;
			}

			if(@sku > 1 and ! $found_option) {
				splice @sku, 1;
			}

			$sku = join "-", @sku;

			my $ib;
			unless($ib 	= ::product_code_exists_tag($sku)) {
				push @{$Vend::Session->{warnings} ||= []},
					errmsg("Not a valid option combination: %s", $sku);
					last SKUSET;
			}

			$line->{mv_ib} = $ib;

			if($sku ne $line->{code}) {
				if($line->{mv_mp}) {
					$line->{mv_sku} = $line->{code} = $sku;
				}
				elsif (! $line->{mv_sku}) {
					$line->{mv_sku} = $line->{code};
					$line->{code} 	= $sku;
				}
				else {
					$line->{code}	= $sku;
				}
				$altered_items{$i} = 1 if $raise_event;
			}
		}
	}

	Vend::Cart::trigger_update(
			$cart,
			$cart->[$_], # new item version
			$old_items{$_}, # old item version
			$cartname
		) for sort { $a <=> $b } keys %altered_items;
#::logDebug("after update, cart is: " . ::uneval($cart));

	# If the user has put in "0" for any quantity, delete that item
    # from the order list. Handles sub-items.
    Vend::Cart::toss_cart($cart, $CGI::values{mv_cartname});

#::logDebug("after toss, cart is: " . ::uneval($cart));

	1;

}

## This routine loads AutoModifier values
## The $recalc parameter indicates it is a recalc load and not 
## an initial load, so that you don't reload all parameters only ones
## that should change based on an option setting (different SKU)

sub auto_modifier {
	my ($item, $recalc) = @_;
	my $code = $item->{code};
	for my $mod (@{$Vend::Cfg->{AutoModifier}}) {
		my $attr;
		my ($table,$key,$foreign) = split /:+/, $mod, 3;

		if($table =~ s/^!\s*//) {
			# This is an auto-recalculating attribute
		}
		elsif($recalc) {
			# Don't want to reload non-auto-recalculating attributes
			next;
		}

		if($table =~ /=/) {
			($attr, $table) = split /\s*=\s*/, $table, 2;
		}

		if(! $key and ! $foreign) {
			$attr ||= $table;
			$item->{$attr} = item_common($item, $table);
			next;
		}

		unless ($key) {
			$key = $table;
			$table = $item->{mv_ib};
		}

		$attr ||= $key;


		my $select = $foreign ? $item->{$foreign} : $code;
		$select ||= $code;

		$item->{$attr} = ::tag_data($table, $key, $select);
	}
}

sub add_items {
	my($items,$quantities) = @_;

	$items = delete $CGI::values{mv_order_item} if ! defined $items;
	return unless $items;

	my($code,$found,$item,$base,$quantity,$i,$j,$q);
	my(@items);
	my(@skus);
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

	my ($cart, $cartname);
	if ($cartname = $CGI::values{mv_cartname}) {
		$cart = $::Carts->{$cartname} ||= [];
	}
	else {
		$cart = $Vend::Items;
		$cartname = $Vend::CurrentCart;
	}

	my ($raise_event,$track_quantity)
		= @{$Vend::Cfg}{qw/CartTrigger CartTriggerQuantity/};
	$raise_event = @$raise_event if ref $raise_event eq 'ARRAY';

	@items      = split /\0/, ($items);
	@quantities = split /\0/, ($quantities || delete $CGI::values{mv_order_quantity} || '');
	@bases      = split /\0/, delete $CGI::values{mv_order_mv_ib}
		if defined $CGI::values{mv_order_mv_ib};
	@lines      = split /\0/, delete $CGI::values{mv_orderline}
		if defined $CGI::values{mv_orderline};

	if($CGI::values{mv_order_fly} and $Vend::Cfg->{OnFly}) {
		if(scalar @items == 1) {
			@fly = $CGI::values{mv_order_fly};
		}
		else {
			@fly = split /\0/, $CGI::values{mv_order_fly};
		}
	}

	if(defined $CGI::values{mv_item_option}) {
		$Vend::Cfg->{UseModifier} = [] if ! $Vend::Cfg->{UseModifier};
		my %seen;
		my @mods = (grep $_ !~ /^mv_/, split /\0/, $CGI::values{mv_item_option});
		@mods = grep ! $seen{$_}++, @mods;
		push @{$Vend::Cfg->{UseModifier}}, @mods;
	}

	if($CGI::values{mv_sku}) {
		my @sku = split /\0/, $CGI::values{mv_sku};
		for (@sku) {
			$_ = $::Variable->{MV_VARIANT_JOINER} || '0' if ! length($_);
		}
		$items[0] = join '-', @sku;
		my $sku_field = $Vend::Cfg->{Options_repository}{Matrix}->{sku} || 'sku';
		$skus[0] = Vend::Data::product_field($sku_field, $items[0]);
	}

	if ($Vend::Cfg->{UseModifier}) {
		foreach $attr (@{$Vend::Cfg->{UseModifier} || []}) {
			$attr{$attr} = [];
			next unless defined $CGI::values{"mv_order_$attr"};
			@{$attr{$attr}} = split /\0/, $CGI::values{"mv_order_$attr"};
		}
	}

	my ($group, $found_master, $mv_mi, $mv_si, $mv_mp, @group, @modular);

	my $separate;
	if( $CGI::values{mv_order_modular} ) {
		@modular = split /\0/, delete $CGI::values{mv_order_modular};
		for( my $i = 0; $i < @modular; $i++ ) {
		   $attr{mv_mp}->[$i] = $modular[$i] if $modular[$i];
		}
		$separate = 1;
	}
	else {
		$separate = defined $CGI::values{mv_separate_items}
					? is_yes($CGI::values{mv_separate_items})
					: (
						$Vend::Cfg->{SeparateItems} ||
						(
							defined $Vend::Session->{scratch}->{mv_separate_items}
						 && is_yes( $Vend::Session->{scratch}->{mv_separate_items} )
						 )
						);
	}

	@group   = split /\0/, (delete $CGI::values{mv_order_group} || '');
	
	my $inc;
	for( my $i = 0; $i < @group; $i++ ) {
#::logDebug("processing order group=$group[$i]");
		if($group[$i]) {
			$inc ||= time();
			my $add = sprintf('%06d', ++$Vend::Session->{pageCount});
			$attr{mv_mi}->[$i] = $inc . $add;
		}
		else {
			$attr{mv_mi}->[$i] = 0;
		}
	}

	$j = 0;
	my $set;
	my %group_seen;

	foreach $code (@items) {
		undef $item;
		$quantity = defined $quantities[$j] ? $quantities[$j] : 1;
		$set = $quantity =~ s/^=//;
		$quantity =~ s/^(-?)\D+/$1/;
		$quantity =~ s/^(-?\d*)\D.*/$1/
			unless $Vend::Cfg->{FractionalItems};
		($j++,next) unless $quantity;
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
			my ($subname, $sub, $ret);
			
			if ($subname = $Vend::Cfg->{SpecialSub}{order_missing}) {
				$sub = $Vend::Cfg->{Sub}{$subname} || $Global::GlobalSub->{$subname};
				eval {
					$ret = $sub->($code, $quantity);
				};

				if ($@) {
					::logError("Error running %s subroutine %s: %s", 'order_missing', $subname, $@);
				}
			}

			unless ($ret) {
				logError( "Attempt to order missing product code: %s", $code);
			}

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
					next if $cart->[$i]->{mv_free_item};
					$found = $i;
					# Increment quantity. This is different than
					# the standard handling because we are ordering
					# accessories, and may want more than 1 of each
					my %old_item = %{$cart->[$i]} if $raise_event and $track_quantity;
					$cart->[$i]{quantity} = $set ? $quantity : $cart->[$i]{quantity} + $quantity;
					Vend::Cart::trigger_update(
							$cart,
							$cart->[$i], # new row
							\%old_item, # old row
							$cartname
						) if $raise_event and $track_quantity;
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
#::logDebug("processing order_group");
				if(! $group_seen{ $group[$j] }++ ) {
					$item->{mv_mi} = $mv_mi = $attr{mv_mi}->[$j];
#::logDebug("processing new master item=$mv_mi");
					$item->{mv_mp} = $mv_mp = $attr{mv_mp}->[$j];
					$item->{mv_si} = $mv_si = 0;
				}
				else {
					$item->{mv_mi} = $mv_mi;
					$item->{mv_si} = ++$mv_si;
#::logDebug("processing sub item=$mv_si");
					$item->{mv_mp} = $attr{mv_mp}->[$j] || $mv_mp;
				}
			}

			$item->{mv_sku} = $skus[$i] if defined $skus[$i];

			if($Vend::Cfg->{UseModifier}) {
				foreach $i (@{$Vend::Cfg->{UseModifier}}) {
					$item->{$i} = $attr{$i}->[$j];
				}
			}

			auto_modifier($item) if $Vend::Cfg->{AutoModifier};

			if(my $oe = $Vend::Cfg->{OptionsAttribute}) {
			  eval {
				my $loc = $Vend::Cfg->{Options_repository}{$item->{$oe}};
				if($loc and $loc->{item_add_routine}) {
					no strict 'refs';
					my $sub = \&{"$loc->{item_add_routine}"}; 
					if(defined $sub) {
						$sub->($item, $loc);
					}
				}
			  };
			  if($@) {
			  	::logError(
					"error during %s (option type %s) item_add_routine: %s",
					$code,
					$item->{$oe},
					$@,
				);
			  }
			}

			if($lines[$j] =~ /^\d+$/ and defined $cart->[$lines[$j]] ) {
				my %old = %{$cart->[$lines[$j]]} if $raise_event;
				$cart->[$lines[$j]] = $item;
				Vend::Cart::trigger_update(
						$cart,
						$item, # new item
						\%old, # old item
						$cartname,
					) if $raise_event;
			}
			else {
# TRACK
				$Vend::Track->add_item($cart,$item) if $Vend::Track;
# END TRACK
				push @$cart, $item;
				Vend::Cart::trigger_add(
						$cart,
						$item, # new item
						$cartname,
					) if $raise_event;
			}
		}
		$j++;
	}

	if($Vend::Cfg->{OrderLineLimit} and $#$cart >= $Vend::Cfg->{OrderLineLimit}) {
		@$cart = ();
		my $msg = errmsg(
			"WARNING:\n" .
			"Possible bad robot. Cart limit of %s exceeded. Cart emptied.\n",
			$Vend::Cfg->{OrderLineLimit}
		);
		do_lockout($msg);
	}
	Vend::Cart::toss_cart($cart, $CGI::values{mv_cartname});
}


# Compatibility with old globalsub payment
*send_mail = \&Vend::Util::send_mail;

# Compatibility with old globalsub payment
*map_actual = \&Vend::Payment::map_actual;

1;
__END__
