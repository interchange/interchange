#!/usr/bin/perl
#
# $Id: UserDB.pm,v 1.13.4.1 2000-11-28 22:33:52 racke Exp $
#
# Copyright (C) 1996-2000 Akopia, Inc. <info@akopia.com>
#
# **** ALL RIGHTS RESERVED ****

package Vend::UserDB;

$VERSION = substr(q$Revision: 1.13.4.1 $, 10);

use vars qw! $VERSION @S_FIELDS @B_FIELDS @P_FIELDS @I_FIELDS %S_to_B %B_to_S!;

use Vend::Data;
use Vend::Util;
use Safe;
use strict;

my $ready = new Safe;

=head1 NAME

UserDB.pm -- Interchange User Database Functions

=head1 SYNOPSIS

userdb $function, %options

=head1 DESCRIPTION

The Interchange user database saves information for users, including shipping,
billing, and preference information.  It allows the user to return to a
previous session without the requirement for a "cookie" or other persistent
session information.

It is object-oriented and called via Perl subroutine. The main software 
is contained in a module, and is called from Interchange with a GlobalSub.
The GlobalSub would take the form:

	GlobalSub <<EOF
	sub userdb {
		my($function, %options) = @_;
		use Vend::UserDB;
		$obj = new Vend::User->DB %options;
		$obj->$function
			or return $obj->{ERROR};
		return $obj->{MESSAGE};
	}

It restores and manipulates the form values normally stored in the user session
values -- the ones set in forms and read through the C<[value variable]> tags.
A special function allows saving of shopping cart contents.

The preference, billing, and shipping information is keyed so that different
sets of information may be saved, providing and "address_book" function that
can save more than one shipping and/or billing address. The set to restore
is selected by the form values C<s_nickname>, C<b_nickname>, and C<p_nickname>.

=cut

=head1 METHODS

User login:

	$obj->login();        # Form values are
	                      # mv_username, mv_password

Create account:

	$obj->new_account();  # Form values are
	                      # mv_username, mv_password, mv_verify

Change password:

	$obj->change_pass();  # Form values are
	                      # mv_username, mv_password_old, mv_password, mv_verify(new)

Get, set user information:

	$obj->get_values();
	$obj->set_values();
	$obj->clear_values();

Save, restore filed user information:

	$obj->get_shipping();
	$obj->set_shipping();

	$obj->get_billing();
	$obj->set_billing();

	$obj->get_preferences();
	$obj->set_preferences();

	$obj->get_cart();
	$obj->set_cart();

=head2 Shipping Address Book

The shipping address book saves information relevant to shipping the
order. In its simplest form, this can be the only address book needed.
By default these form values are included:

	s_nickname
	name
	address
	city
	state
	zip
	country
	phone_day
	mv_shipmode

The values are saved with the $obj->set_shipping() method and restored 
with $obj->get_shipping. A list of the keys available is kept in the
form value C<address_book>, suitable for iteration in an HTML select
box or in a set of links.

=cut

@S_FIELDS = ( 
qw!
	s_nickname
	name
	fname
	lname
	address
	address1
	address2
	address3
	city
	state
	zip
	country	
	phone_day
	mv_shipmode
!
);

=head2 Accounts Book

The accounts book saves information relevant to billing the
order. By default these form values are included:

	b_nickname
	b_name
	b_address
	b_city
	b_state
	b_zip
	b_country
	b_phone
	mv_credit_card_type
	mv_credit_card_exp_month
	mv_credit_card_exp_year
	mv_credit_card_reference

The values are saved with the $obj->set_billing() method and restored 
with $obj->get_billing. A list of the keys available is kept in the
form value C<accounts>, suitable for iteration in an HTML select
box or in a set of links.

=cut

@S_FIELDS = ( 
qw!
	s_nickname
	name
	fname
	lname
	address
	address1
	address2
	address3
	city
	state
	zip
	country	
	phone_day
	mv_shipmode
!
);

@B_FIELDS = ( 
qw!

	b_nickname
	b_name
	b_fname
	b_lname
	b_address
	b_address1
	b_address2
	b_address3
	b_city
	b_state
	b_zip
	b_country	
	b_phone
	purchase_order
	mv_credit_card_type
	mv_credit_card_exp_month
	mv_credit_card_exp_year
	mv_credit_card_reference
	!
);

=head2 Preferences

Preferences are miscellaneous session information. They include
by default the fields C<email>, C<fax>, C<phone_night>,
and C<fax_order>. The field C<p_nickname> acts as a key to select
the preference set.

=cut

@P_FIELDS = qw ( p_nickname email fax email_copy phone_night mail_list fax_order );

%S_to_B = ( 
qw!
s_nickname	b_nickname
name		b_name
address		b_address
city		b_city
state		b_state
zip			b_zip
country		b_country
phone_day	b_phone
!
);

@B_to_S{values %S_to_B} = keys %S_to_B;

sub new {

	my ($class, %options) = @_;

	my $loc;
	if(	$Vend::Cfg->{UserDB} ) {
		if( $options{profile} ) {
			$loc =	$Vend::Cfg->{UserDB_repository}{$options{profile}};
		}
		else {
			$options{profile} = 'default';
			$loc =	$Vend::Cfg->{UserDB};
		}
		$loc = {} unless $loc;
		my ($k, $v);
		while ( ($k,$v) = each %$loc) {
			$options{$k} = $v unless defined $options{$k};
		}
	}

	if($options{billing}) {
		$options{billing} =~ s/[,\s]+$//;
		$options{billing} =~ s/^[,\s]+//;
		@B_FIELDS = split /[\s,]+/, $options{billing};
	}
	if($options{shipping}) {
		$options{shipping} =~ s/[,\s]+$//;
		$options{shipping} =~ s/^[,\s]+//;
		@S_FIELDS = split /[\s,]+/, $options{shipping};
	}
	if($options{preferences}) {
		$options{preferences} =~ s/[,\s]+$//;
		$options{preferences} =~ s/^[,\s]+//;
		@P_FIELDS = split /[\s,]+/, $options{preferences};
	}
	if($options{ignore}) {
		$options{ignore} =~ s/[,\s]+$//;
		$options{ignore} =~ s/^[,\s]+//;
		@I_FIELDS = split /[\s,]+/, $options{ignore};
	}
	my $self = {
			USERNAME  	=>	$options{username}	||
							$Vend::Session->{username} ||
							$CGI::values{mv_username} || '',
			OLDPASS  	=> $options{oldpass}	|| $CGI::values{mv_password_old} || '',
			PASSWORD  	=> $options{password}	|| $CGI::values{mv_password} || '',
			VERIFY  	=> $options{verify}		|| $CGI::values{mv_verify}	 || '',
			NICKNAME   	=> $options{nickname}	|| '',
			PROFILE   	=> $options{profile}	|| '',
			LAST   		=> '',
			CRYPT  		=> defined $options{'crypt'}
							? $options{'crypt'}
							: ! $::Variable->{MV_NO_CRYPT},
			CGI			=>	( defined $options{cgi} ? is_yes($options{cgi}) : 1),
			PRESENT		=>	{ },
			DB_ID		=>	$options{database} || 'userdb',
			OPTIONS		=>	\%options,
			LOCATION	=>	{
						USERNAME	=> $options{user_field} || 'username',
						BILLING		=> $options{bill_field} || 'accounts',
						SHIPPING	=> $options{addr_field} || 'address_book',
						PREFERENCES	=> $options{pref_field} || 'preferences',
						ORDERS     	=> $options{ord_field}  || 'orders',
						CARTS		=> $options{cart_field} || 'carts',
						PASSWORD	=> $options{pass_field} || 'password',
						LAST		=> $options{time_field} || 'mod_time',
						EXPIRATION	=> $options{expire_field} || 'expiration',
						ACL			=> $options{acl}		|| 'acl',
						FILE_ACL	=> $options{file_acl}	|| 'file_acl',
						DB_ACL		=> $options{db_acl}		|| 'db_acl',
							},
			STATUS		=>		0,
			ERROR		=>		'',
			MESSAGE		=>		'',
		};
	bless $self;

	return $self if $options{no_open};

	set_db($self) or die "user database $self->{DB_ID} does not exist.\n";

	return $self;
}

sub create_db {
	my(%options) = @_;
	my $user = new Vend::UserDB no_open => 1, %options;

	my(@out);
	push @out, $user->{LOCATION}{USERNAME};
	push @out, $user->{LOCATION}{PASSWORD};
	push @out, $user->{LOCATION}{LAST};
	push @out, @S_FIELDS, @B_FIELDS, @P_FIELDS;
	push @out, $user->{LOCATION}{ORDERS};
	push @out, $user->{LOCATION}{SHIPPING};
	push @out, $user->{LOCATION}{BILLING};
	push @out, $user->{LOCATION}{PREFERENCES};

	my $csv = 0;
	my $delimiter = $options{delimiter} || "\t";
	if($delimiter =~ /csv|comma/i) {
		$csv = 1;
		$delimiter = '","';
	}
	my $separator = $options{separator} || "\n";

	print '"' if $csv;
	print join $delimiter, @out;
	print '"' if $csv;
	print $separator;
	if ($options{verbose}) {
		my $msg;
		$msg = "Delimiter=";
		if(length $delimiter == 1) {
			$msg .= sprintf '\0%o', ord($delimiter);
		}
		else {
			$msg .= $delimiter;
		}
		$msg .= " ";
		$msg .= "Separator=";
		if(length $separator == 1) {
			$msg .= sprintf '\0%o', ord($separator);
		}
		else {
			$msg .= $separator;
		}
		$msg .= "\nNicknames: ";
		$msg .= "SHIPPING=$S_FIELDS[0] ";
		$msg .= "BILLING=$B_FIELDS[0] ";
		$msg .= "PREFERENCES=$P_FIELDS[0] ";
		$msg .= "\nFields:\n";
		$msg .= join "\n", @out;
		$msg .= "\n\n";
		my $type;
		my $ext = '.txt';
		SWITCH: {
			$type = 4, $ext = '.csv', last SWITCH if $csv;
			$type = 6, last SWITCH if $delimiter eq "\t";
			$type = 5, last SWITCH if $delimiter eq "|";
			$type = 3, last SWITCH
				if $delimiter eq "\n%%\n" && $separator eq "\n%%%\n";
			$type = 2, last SWITCH
				if $delimiter eq "\n" && $separator eq "\n\n";
			$type = '?';
		}

		my $id = $user->{DB_ID};
		$msg .= "Database line in catalog.cfg should be:\n\n";
		$msg .= "Database $id $id.txt $type";
		warn "$msg\n";
	}
	1;
}

sub log {
	my $self = shift;
	my $time = $self->{OPTIONS}{UNIX_TIME} ?  time() :
				POSIX::strftime("%Y%m%d%H%M", localtime());
	my $msg = shift;
	logData( ($self->{OPTIONS}{logfile} || $Vend::Cfg->{LogFile}),
						$time,
						$self->{USERNAME},
						$CGI::remote_host,
						$msg,
						);
	return;
}

sub check_acl {
	my ($self,%options) = @_;

	if(! defined $self->{PRESENT}{$self->{LOCATION}{ACL}}) {
		$self->{ERROR} = 'No ACL field present.';
		return undef;
	}

	if(not $options{location}) {
		$self->{ERROR} = 'No location to check.';
		return undef;
	}

	my $acl = $self->{DB}->field($self->{USERNAME}, $self->{LOCATION}{ACL});
	$acl =~ /(\s|^)$options{location}(\s|$)/;
}


sub set_acl {
	my ($self,%options) = @_;

	if(!$self->{PRESENT}{$self->{LOCATION}{ACL}}) {
		$self->{ERROR} = 'No ACL field present.';
		return undef;
	}

	if(!$options{location}) {
		$self->{ERROR} = 'No location to set.';
		return undef;
	}

	my $acl = $self->{DB}->field($self->{USERNAME}, $self->{LOCATION}{ACL});
	if($options{'delete'}) {
		$acl =~ s/(\s|^)$options{location}(\s|$)/$1$2/;
	}
	else {
		$acl =~ s/(\s|^)$options{location}(\s|$)/$1$2/;
		$acl .= " $options{location}";
	}
	$acl =~ s/\s+/ /g;
	$self->{DB}->set_field( $self->{USERNAME}, $self->{LOCATION}{ACL}, $acl);
	return $acl if $options{show};
	return;
}

sub _check_acl {
	my ($self, $loc, %options) = @_;
	return undef unless $options{location};
	my $acl = $self->{DB}->field( $self->{USERNAME}, $loc);
	my $f = $ready->reval($acl);
	return 0 unless exists $f->{$options{location}};
	return 1 if ! $options{mode};
	if($options{mode} =~ /^\s*expire\b/i) {
		my $cmp = $f->{$options{location}};
		return $cmp < time() ? '' : 1;
	}
	return 1 if $f->{$options{location}} =~ /$options{mode}/i;
	return '';
}

sub _set_acl {
	my ($self, $loc, %options) = @_;
	return undef unless $self->{OPTIONS}{location};
	if($options{mode} =~ /^\s*expire\s+(.*)/i) {
		my $secs = Vend::Config::time_to_seconds($1);
		my $now = time();
		$options{mode} = $secs + $now;
	}
	my $acl = $self->{DB}->field( $self->{USERNAME}, $loc );
	my $f = $ready->reval($acl) || {};
	if($options{'delete'}) {
		delete $f->{$options{location}};
	}
	else {
		$f->{$options{location}} = $options{mode} || 'rw';
	}
	my $return = $self->{DB}->set_field( $self->{USERNAME}, $loc, Vend::Util::uneval_it($f) );
	return $return if $options{show};
	return;
}

sub set_file_acl {
	my $self = shift;
	return $self->_set_acl($self->{LOCATION}{FILE_ACL}, @_);
}

sub set_db_acl {
	my $self = shift;
	return $self->_set_acl($self->{LOCATION}{DB_ACL}, @_);
}

sub check_file_acl {
	my $self = shift;
	return $self->_check_acl($self->{LOCATION}{FILE_ACL}, @_);
}

sub check_db_acl {
	my $self = shift;
	return $self->_check_acl($self->{LOCATION}{DB_ACL}, @_);
}

sub set_db {
	my($self, $database) = @_;

	$database = $self->{DB_ID}		unless $database;

	$Vend::WriteDatabase{$database} = 1;

	my $db = database_exists_ref($database);
	return undef unless defined $db;

	$db = $db->ref();
	my @fields = $db->columns();
	my %ignore;

	my @final;

	for(@I_FIELDS) {
		$ignore{$_} = 1;
	}

	for(values %{$self->{LOCATION}}) {
		$ignore{$_} = 1;
	}

	if($self->{OPTIONS}{force_lower}) {
		@fields = map { lc $_ } @fields;
	}

	for(@fields) {
		if(defined $ignore{$_}) {
			$self->{PRESENT}->{$_} = 1;
			next;
		}
		push @final, $_;
	}

	$self->{DB_FIELDS} = \@final;
	$self->{DB} = $db;
}

# Sets location map, returns old value
sub map_field {
	my ($self, $location, $field) = @_;
	if(! defined $field) {
		return $self->{LOCATION}->{$location};
	}
	else {
		my $old = $self->{LOCATION}->{$field};
		$self->{LOCATION}->{$location} = $field;
		return $old;
	}
}

sub clear_values {
	my($self, @fields) = @_;

	@fields = @{ $self->{DB_FIELDS} } unless @fields;

	my %scratch;

	if($self->{OPTIONS}->{scratch}) {
		my (@s) = split /[\s,]+/, $self->{OPTIONS}{scratch} ;
		@scratch{@s} = @s;
#::logError("scratch ones: " . join " ", @s);
	}

	for(@fields) {
		if($scratch{$_}) {
			delete $::Scratch->{$_};
		}
		else {
			delete $::Values->{$_};
			delete $CGI::values{$_};
		}
	}

	1;
}

sub get_values {
	my($self, @fields) = @_;

	@fields = @{ $self->{DB_FIELDS} } unless @fields;

	unless ( $self->{DB}->record_exists($self->{USERNAME}) ) {
		$self->{ERROR} = "username $self->{USERNAME} does not exist.";
		return undef;
	}

	my %ignore;
	my %scratch;

	for(values %{$self->{LOCATION}}) {
		$ignore{$_} = 1;
	}

	if($self->{OPTIONS}->{scratch}) {
		my (@s) = split /[\s,]+/, $self->{OPTIONS}{scratch} ;
		@scratch{@s} = @s;
#::logError("scratch ones: " . join " ", @s);
	}
	for(@fields) {
		if($ignore{$_}) {
			$self->{PRESENT}->{$_} = 1;
			next;
		}
		if($scratch{$_}) {
			$::Scratch->{$_} = $self->{DB}->field($self->{USERNAME}, $_);	
			next;
		}
		$::Values->{$_} = $self->{DB}->field($self->{USERNAME}, $_);	
	}

	my $area;
	foreach $area (qw!SHIPPING BILLING PREFERENCES CARTS!) {
		my $f = $self->{LOCATION}->{$area};
		if ($self->{PRESENT}->{$f}) {
			my $s = $self->get_hash($area);
			die "Bad structure in $f: $@" if $@;
			$::Values->{$f} = join "\n", sort keys %$s;
		}
	}
	
	1;
}

sub set_values {
	my($self) = @_;

	my @fields;

	my $user = $self->{USERNAME};

	@fields = @{$self->{DB_FIELDS}};

	unless ( $self->{DB}->record_exists($self->{USERNAME}) ) {
		$self->{ERROR} = "username $self->{USERNAME} does not exist.";
		return undef;
	}
	my %scratch;

	if($self->{OPTIONS}->{scratch}) {
		my (@s) = split /[\s,]+/, $self->{OPTIONS}{scratch} ;
		@scratch{@s} = @s;
	}

	for( @fields ) {
#::logDebug("set_values saving $_ as $::Values->{$_}\n");
		if ($scratch{$_}) {
			$self->{DB}->set_field($user, $_, $::Scratch->{$_})
				if defined $::Scratch->{$_};	
			next;
		}
		$self->{DB}->set_field($user, $_, $::Values->{$_})
			if defined $::Values->{$_};	
	}
	1;
}

sub set_billing {
	my $self = shift;
	my $ref = $self->set_hash('BILLING', @B_FIELDS );
	return $ref;
}

sub set_shipping {
	my $self = shift;
	my $ref = $self->set_hash('SHIPPING', @S_FIELDS );
	return $ref;
}

sub set_preferences {
	my $self = shift;
	my $ref = $self->set_hash('PREFERENCES', @P_FIELDS );
	return $ref;
}

sub get_shipping {
	my $self = shift;
	my $ref = $self->get_hash('SHIPPING', @S_FIELDS );
	return $ref;
}

sub get_billing {
	my $self = shift;
	my $ref = $self->get_hash('BILLING', @B_FIELDS );
	return $ref;
}

sub get_preferences {
	my $self = shift;
	my $ref = $self->get_hash('PREFERENCES', @P_FIELDS );
	return $ref;
}

sub get_shipping_names {
	my $self = shift;
	my $ref = $self->get_hash('SHIPPING');
	return undef unless ref $ref;
	$::Values->{$self->{LOCATION}{SHIPPING}} = join "\n", keys %$ref;
	return $::Values->{$self->{LOCATION}{SHIPPING}} if $self->{OPTIONS}{show};
	return '';
}

sub get_billing_names {
	my $self = shift;
	my $ref = $self->get_hash('BILLING');
	return undef unless ref $ref;
	$::Values->{$self->{LOCATION}{BILLING}} = join "\n", keys %$ref;
	return $::Values->{$self->{LOCATION}{BILLING}} if $self->{OPTIONS}{show};
	return '';
}

sub get_preferences_names {
	my $self = shift;
	my $ref = $self->get_hash('PREFERENCES');
	return undef unless ref $ref;
	$::Values->{$self->{LOCATION}{PREFERENCES}} = join "\n", keys %$ref;
	return $::Values->{$self->{LOCATION}{PREFERENCES}} if $self->{OPTIONS}{show};
	return '';
}

sub get_cart_names {
	my $self = shift;
	my $ref = $self->get_hash('CARTS');
	return undef unless ref $ref;
	$::Values->{$self->{LOCATION}{CARTS}} = join "\n", keys %$ref;
	return $::Values->{$self->{LOCATION}{CARTS}} if $self->{OPTIONS}{show};
	return '';
}

sub delete_billing {
	my $self = shift;
	$self->delete_nickname('BILLING', @B_FIELDS );
	return '';
}

sub delete_cart {
	my $self = shift;
	$self->delete_nickname('CARTS', $self->{NICKNAME});
	return '';
}

sub delete_shipping {
	my $self = shift;
	$self->delete_nickname('SHIPPING', @S_FIELDS );
	return '';
}

sub delete_preferences {
	my $self = shift;
	$self->delete_nickname('PREFERENCES', @P_FIELDS );
	return '';
}

sub delete_nickname {
	my($self, $name, @fields) = @_;

	die ::errmsg("no fields?") unless @fields;
	die ::errmsg("no name?") unless $name;

	$self->get_hash($name) unless ref $self->{$name};

	my $nick_field = shift @fields;
	my $nick = $self->{NICKNAME} || $::Values->{$nick_field};
	$nick =~ s/^[\0\s]+//;
	$nick =~ s/[\0\s]+.*//;

	delete $self->{$name}{$nick};

	my $field_name = $self->{LOCATION}->{$name};
	unless($self->{PRESENT}->{$field_name}) {
		$self->{ERROR} = '$field_name field not present to set $name';
		return undef;
	}

	my $s = ::uneval_it($self->{$name});

	$self->{DB}->set_field( $self->{USERNAME}, $field_name, $s);

	return ($s, $self->{$name});
}

sub set_hash {
	my($self, $name, @fields) = @_;

	die ::errmsg("no fields?") unless @fields;
	die ::errmsg("no name?") unless $name;

	$self->get_hash($name) unless ref $self->{$name};

	my $nick_field = shift @fields;
	my $nick = $self->{NICKNAME} || $::Values->{$nick_field};
	$nick =~ s/^[\0\s]+//;
	$nick =~ s/[\0\s]+.*//;
	$::Values->{$nick_field} = $nick;
	$CGI::values{$nick_field} = $nick if $self->{CGI};

	die ::errmsg("no nickname?") unless $nick;

	$self->{$name}{$nick} = {} unless $self->{OPTIONS}{keep}
							   and    defined $self->{$name}{$nick};

	for(@fields) {
		$self->{$name}{$nick}{$_} = $::Values->{$_}
			if defined $::Values->{$_};
	}

	my $field_name = $self->{LOCATION}->{$name};
	unless($self->{PRESENT}->{$field_name}) {
		$self->{ERROR} = '$field_name field not present to set $name';
		return undef;
	}

	my $s = ::uneval_it($self->{$name});

	$self->{DB}->set_field( $self->{USERNAME}, $field_name, $s);

	return ($s, $self->{$name});
}

sub get_hash {
	my($self, $name, @fields) = @_;

	my $field_name = $self->{LOCATION}->{$name};
	my ($nick, $s);

	eval {
		die ::errmsg("no name?")					unless $name;
		die ::errmsg("%s field not present to get %s", $field_name, $name) . "\n"
										unless $self->{PRESENT}->{$field_name};

		$s = $self->{DB}->field( $self->{USERNAME}, $field_name);

		if($s) {
			$self->{$name} = $ready->reval($s);
			die "Bad structure in $field_name: $@" if $@;
		}
		else {
			$self->{$name} = {};
		}

		die "eval failed?"				unless ref $self->{$name};
	};

	if($@) {
		$self->{ERROR} = $@;
		return undef;
	}

	return $self->{$name} unless @fields;

	eval {
		my $nick_field = shift @fields;
		$nick = $self->{NICKNAME} || $::Values->{$nick_field};
		$nick =~ s/^[\0\s]+//;
		$nick =~ s/[\0\s]+.*//;
		$::Values->{$nick_field} = $nick;
		$CGI::values{$nick_field} = $nick if $self->{CGI};
		die "no nickname?" unless $nick;
	};

	if($@) {
		$self->{ERROR} = $@;
		return undef;
	}

	$self->{$name}->{$nick} = {} unless defined $self->{$name}{$nick};

	for(@fields) {
		delete $::Values->{$_};
		$::Values->{$_} = $self->{$name}{$nick}{$_}
			if defined  $self->{$name}{$nick}{$_};
		next unless $self->{CGI};
		$CGI::values{$_} = $::Values->{$_};
	}
	::update_user() if $self->{CGI};
	return $self->{$name}{$nick};
}

sub login {
	my $self;

	$self = shift
		if ref $_[0];

	my(%options) = @_;
	
	eval {
		unless($self) {
			$self = new Vend::UserDB %options;
		}
		if(
			$Vend::Cfg->{CookieLogin}
			and (! $Vend::Cfg->{DifferentSecure} || ! $CGI::secure)
			)
		{
			$self->{USERNAME} = Vend::Util::read_cookie('MV_USERNAME')
				if ! $self->{USERNAME};
			$self->{PASSWORD} = Vend::Util::read_cookie('MV_PASSWORD')
				if ! $self->{PASSWORD};
		}
		if ($self->{OPTIONS}{ignore_case}) {
			$self->{PASSWORD} = lc $self->{PASSWORD};
			$self->{USERNAME} = lc $self->{USERNAME};
		}
		die ::errmsg("Username does not exist.") . "\n"
			unless $self->{DB}->record_exists($self->{USERNAME});
		my $db_pass = $self->{DB}->field(
						$self->{USERNAME},
						$self->{LOCATION}{PASSWORD},
						);
		my $pw = $self->{PASSWORD};
		if($self->{CRYPT}) {
			$self->{PASSWORD} = crypt($pw,$db_pass);
		}
		die ::errmsg("Password mismatch.") . "\n"
			unless $self->{PASSWORD} eq $db_pass;

		if($self->{PRESENT}->{ $self->{LOCATION}{EXPIRATION} } ) {
			my $now = time();
			my $cmp = $now;
			$cmp = POSIX::strftime("%Y%m%d%H%M", localtime($now))
				unless $self->{OPTIONS}->{unix_time};
			my $exp = $self->{DB}->field(
						$self->{USERNAME},
						$self->{LOCATION}{EXPIRATION},
						);
			die ::errmsg("Expiration date not set.") . "\n"
				if ! $exp and $self->{EMPTY_EXPIRE_FATAL};
			if($exp and $exp < $cmp) {
				die ::errmsg("Expired %s.", $exp) . "\n";
			}
		}

		username_cookies($self->{USERNAME}, $pw) 
			if $Vend::Cfg->{CookieLogin};

		$self->{DB}->set_field( $self->{USERNAME},
								$self->{LOCATION}{LAST},
								time()
								)
			if $self->{LOCATION}{LAST} ne 'none';
		$self->log('login') if $options{'log'};
		
		$self->get_values();
	};

	if($@) {
		if(defined $self) {
			$self->{ERROR} = $@;
#::logDebug( "Vend::UserDB error: %s\n", $@ );
		}
		else {
			::logError( "Vend::UserDB error: %s\n", $@ );
		}
		return undef;
	}

	$Vend::Session->{login_table} = $self->{DB_ID};
	$Vend::username = $Vend::Session->{username} = $self->{USERNAME};
	$Vend::Session->{logged_in} = 1;
	
	1;
}

sub change_pass {

	my $self;

	$self = shift
		if ref $_[0];

	my(%options) = @_;
	
	eval {
		unless($self) {
			$self = new Vend::UserDB %options;
		}

		die "Bad object.\n" unless defined $self;

		die "$self->{USERNAME} not a user\n"
			unless $self->{DB}->record_exists($self->{USERNAME});
		my $db_pass = $self->{DB}->field($self->{USERNAME}, $self->{LOCATION}{PASSWORD});

		if($self->{CRYPT}) {
			$self->{OLDPASS} = crypt($self->{OLDPASS},$db_pass);
		}

		die "Must have old password\n"
			if	$self->{OLDPASS} ne $db_pass;
		die "Must enter at least 4 characters for password.\n"
			unless length($self->{PASSWORD}) > 3;
		die "Password and check value don't match.\n"
			unless $self->{PASSWORD} eq $self->{VERIFY};

		if($self->{CRYPT}) {
			$self->{PASSWORD} = crypt(
									$self->{PASSWORD},
									Vend::Util::random_string(2)
								);
		}
		
		my $pass = $self->{DB}->set_field(
						$self->{USERNAME},
						$self->{LOCATION}{PASSWORD},
						$self->{PASSWORD}
						);
		die "Database access error.\n" unless defined $pass;
		$self->log('change password') if $options{'log'};
	};

	if($@) {
		if(defined $self) {
			$self->{ERROR} = $@;
			$self->log('change password failed') if $options{'log'};
		}
		else {
			logError( "Vend::UserDB error: %s", $@ );
		}
		return undef;
	}
	
	1;
}

my $GOOD_CHARS = '[-A-Za-z0-9_@.]';

sub assign_username {
	my $self = shift;
	my $file = shift || $self->{OPTIONS}{'counter'};
	my $start = $self->{OPTIONS}{username} || 'U00000';
	$file = './etc/username.counter' if ! $file;
	my $ctr = File::CounterFile->new($file, $start);
	return $ctr->inc();
}

sub new_account {

	my $self;

	$self = shift
		if ref $_[0];

	my(%options) = @_;
	
	eval {
		unless($self) {
			$self = new Vend::UserDB %options;
		}
		die "Bad object.\n" unless defined $self;

		die "Already logged in. Log out first.\n"
			if $Vend::Session->{logged_in};
		die "Sorry, reserved user name.\n"
			if $self->{OPTIONS}{username_mask} 
				and $self->{USERNAME} =~ m!$self->{OPTIONS}{username_mask}!;
		die "Must enter at least 4 characters for password.\n"
			unless length($self->{PASSWORD}) > 3;
		die "Password and check value don't match.\n"
			unless $self->{PASSWORD} eq $self->{VERIFY};

		if ($self->{OPTIONS}{ignore_case}) {
			$self->{PASSWORD} = lc $self->{PASSWORD};
			$self->{USERNAME} = lc $self->{USERNAME};
		}

		my $pw = $self->{PASSWORD};
		if($self->{CRYPT}) {
			eval {
				$self->{PASSWORD} = crypt(
										$pw,
										Vend::Util::random_string(2)
									);
			};
		}
	
		if($self->{OPTIONS}{assign_username}) {
			$self->{USERNAME} = $self->assign_username();
			$self->{USERNAME} = lc $self->{USERNAME}
				if $self->{OPTIONS}{ignore_case};
		}
		die "Must have longer username.\n" unless length($self->{USERNAME}) > 1;
		die "Can't have '$1' as username, unsafe characters.\n"
			if $self->{USERNAME} !~ m{^$GOOD_CHARS+$};
#::logDebug("new_account username: '$self->{USERNAME}'");
		if ($self->{DB}->record_exists($self->{USERNAME})) {
#::logDebug("new_account username: '$self->{USERNAME}' exists");
			die "Username already exists.\n"
		}
#::logDebug("new_account username: '$self->{USERNAME}' doesn't exist");
		my $pass = $self->{DB}->set_field(
						$self->{USERNAME},
						$self->{LOCATION}{PASSWORD},
						$self->{PASSWORD}
						);
		die "Database access error.\n" unless defined $pass;

		username_cookies($self->{USERNAME}, $pw) 
			if $Vend::Cfg->{CookieLogin};

		$self->log('new account') if $options{'log'};
		$self->set_values();
		$self->login()
			or die "Cannot log in after new account creation: $self->{ERROR}";
	};

	if($@) {
		if(defined $self) {
			$self->{ERROR} = $@;
		}
		else {
			logError( "Vend::UserDB error: %s\n", $@ );
		}
		return undef;
	}
	
	1;
}

sub username_cookies {
		my ($user, $pw) = @_;
		return if $Vend::Cfg->{DifferentSecure} && $CGI::secure;
		return unless
			 $CGI::values{mv_cookie_password}		or
			 $CGI::values{mv_cookie_username}		or
			 Vend::Util::read_cookie('MV_PASSWORD')	or
			 Vend::Util::read_cookie('MV_USERNAME');
		$::Instance->{Cookies} = [] unless defined $::Instance->{Cookies};
		my $exp = time() + $Vend::Cfg->{SaveExpire};
		push @{$::Instance->{Cookies}},
			['MV_USERNAME', $user, $exp];
		return unless
			$CGI::values{mv_cookie_password}		or
			Vend::Util::read_cookie('MV_PASSWORD');
		push @{$::Instance->{Cookies}},
			['MV_PASSWORD', $pw, $exp];
		return;
}

sub get_cart {
	my($self, %options) = @_;

	my $from = $self->{NICKNAME};
	my $to;
	if ($options{target}) {
		$to = ($::Carts->{$options{target}} ||= []);
	}
	else {
		$to = $Vend::Items;
	}

#::logDebug ("to=$to nick=$options{target} from=$from cart=" . ::uneval($from));

	my $field_name = $self->{LOCATION}->{CARTS};
	my $cart = [];

	eval {
		die "no from cart name?"				unless $from;
		die "$field_name field not present to get $from\n"
										unless $self->{PRESENT}->{$field_name};

		my $s = $self->{DB}->field( $self->{USERNAME}, $field_name);

		die "no saved carts.\n" unless $s;

		my @carts = split /\0/, $from;
		my $d = $ready->reval($s);
#::logDebug ("saved carts=" . ::uneval($d));

		die "eval failed?"				unless ref $d;

		for(@carts) {
			die "source cart '$from' does not exist.\n" unless ref $d->{$_};
			push @$cart, @{$d->{$_}};
		}

	};

	if($@) {
		$self->{ERROR} = $@;
		return undef;
	}
#::logDebug ("to=$to nick=$options{target} from=$from cart=" . ::uneval($cart));
	@$to = @$cart;

}

sub set_cart {
	my($self, %options) = @_;

	my $from;
	my $to   = $self->{NICKNAME};
	if ($self->{OPTIONS}{source}) {
		$from = $::Carts->{$self->{OPTIONS}{source}} || [];
	}
	else {
		$from = $Vend::Items;
	}

	my $field_name = $self->{LOCATION}->{CARTS};
	my ($cart,$s,$d);

	eval {
		die "no to cart name?\n"					unless $to;
		die "$field_name field not present to save $from\n"
										unless $self->{PRESENT}->{$field_name};

		$d = $ready->reval( $self->{DB}->field( $self->{USERNAME}, $field_name) );

		$d = {} unless $d;

		die "eval failed?"				unless ref $d;

		if($options{merge}) {
			$d->{$to} = [] unless ref $d->{$to};
			push(@{$d->{$to}}, @{$from});
		}

		$d->{$to} = $from;

		$s = uneval $d;

	};

	if($@) {
		$self->{ERROR} = $@;
		return undef;
	}

	$self->{DB}->set_field( $self->{USERNAME}, $field_name, $s);

}

sub userdb {
	my $function = shift;
	my $opt = shift;

	my %options;

#::logDebug("Called userdb function=$function opt=$opt " .  Data::Dumper::Dumper($opt));

	if(ref $opt) {
		%options = %$opt;
	}
	else {
		%options = ($opt, @_);
	}

	my $status = 1;
	my $user;

	if($function eq 'login') {
		$Vend::Session->{logged_in} = 0;
		delete $Vend::Session->{username};
		undef $Vend::username;
		undef $Vend::admin;
		::put_session();
		$user = new Vend::UserDB %options;
		unless (defined $user) {
			$Vend::Session->{failure} = "Unable to access user database.";
			return undef;
		}
		if ($status = $user->login(%options) ) {
			if(
				! $Vend::Cfg->{AdminUserDB} or
				$Vend::Cfg->{AdminUserDB}{$user->{PROFILE}}
				)
			{
::logDebug("logged in $Vend::username via $user->{DB_ID} -- ADMIN");
				$Vend::admin = 1;
			}
::logDebug("logged in $Vend::username via $user->{DB_ID} $Vend::Cfg->{AdminUserDB}");
			undef $Vend::Cookie
				unless $Vend::Cfg->{StaticLogged};
			::update_user();
		}
	}
	elsif($function eq 'new_account') {
		$user = new Vend::UserDB %options;
		unless (defined $user) {
			$Vend::Session->{failure} = "Unable to access user database.";
			return undef;
		}
		if($status = $user->new_account(%options)) {
			$Vend::Session->{logged_in} = 1;
			$Vend::Session->{username} = $user->{USERNAME};
			undef $Vend::Cookie
				unless $Vend::Cfg->{StaticLogged};
		}
	}
	elsif($function eq 'logout') {
		$user = new Vend::UserDB %options;
		unless (defined $user) {
			$Vend::Session->{failure} = "Unable to access user database.";
			return undef;
		}
		if( is_yes($options{clear}) ) {
			$user->clear_values();
		}
		delete $Vend::Session->{logged_in};
		delete $Vend::Session->{login_table};
		delete $Vend::Session->{username};
		delete $CGI::values{mv_username};
		undef $Vend::username;
		delete $::Values->{mv_username};
		$user->log('logout') if $options{'log'};
		$user->{MESSAGE} = 'Logged out.';
	}
	elsif (! $Vend::Session->{logged_in}) {
		$Vend::Session->{failure} = "Not logged in.";
		return undef;
	}
	elsif($function eq 'save') {
		$user = new Vend::UserDB %options;
		unless (defined $user) {
			$Vend::Session->{failure} = "Unable to access user database.";
			return undef;
		}
		$status = $user->set_values();
	}
	elsif($function eq 'load') {
		$user = new Vend::UserDB %options;
		unless (defined $user) {
			$Vend::Session->{failure} = "Unable to access user database.";
			return undef;
		}
		$status = $user->get_values();
	}
	else {
		$user = new Vend::UserDB %options;
		unless (defined $user) {
			$Vend::Session->{failure} = "Unable to access user database.";
			return undef;
		}
		$status = $user->$function(%options);
	}
	
	if(defined $status) {
		delete $Vend::Session->{failure};
#::logDebug("userdb success=$user->{ERROR}\n");
		$Vend::Session->{success} = $user->{MESSAGE};
		if($options{show_message}) {
			$status = $user->{MESSAGE};
		}
	}
	else {
#::logDebug("userdb failure=$user->{ERROR}\n");
		$Vend::Session->{failure} = $user->{ERROR};
		if($options{show_message}) {
			$status = $user->{ERROR};
		}
	}
	return $status unless $options{hide};
	return;
}

1;
