# Vend::UserDB - Interchange user database functions
#
# Copyright (C) 2002-2015 Interchange Development Group
# Copyright (C) 1996-2002 Red Hat, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.

package Vend::UserDB;

$VERSION = '2.67';

use vars qw!
	$VERSION
	@S_FIELDS @B_FIELDS @P_FIELDS @I_FIELDS
	%S_to_B %B_to_S
	$USERNAME_GOOD_CHARS
	$Has_Bcrypt
!;

use Vend::Data;
use Vend::Util;
use Vend::Safe;
use strict;
no warnings qw(uninitialized numeric);

{
    local $@;
    eval {
        require Digest::Bcrypt;
        require Crypt::Random;
    };
    unless ($@) {
        $Has_Bcrypt = 1;
    }
}

use constant BCOST => 13;

# Map between bcrypt identifier letter and "pre-digested" encryption type
my %cipher_map = qw/
    s   sha1
    m   md5
    n   md5_salted
    c   default
/;

my $ready = new Vend::Safe;

# The object encryption methods take three arguments: object, password, and
# mystery meat. If called in the context of new_account(), the mystery meat
# is the salt (which is not always used). If called in the context of
# login(), then the mystery meat is the entire password field from the
# database (with salt, if applicable).
my %enc_subs = (
    default => \&enc_default,
    md5 => \&enc_md5,
    md5_salted => \&enc_md5_salted,
    sha1 => \&enc_sha1,
    bcrypt => \&enc_bcrypt,
);

sub enc_default {
    my $obj = shift;
    my ($pwd, $salt) = @_;
    return crypt($pwd, $salt);
}

sub enc_md5 {
    my $obj = shift;
    return Digest::MD5::md5_hex(shift);
}

# This particular md5_salted encryption stores the salt with the password
# in colon-separated format: /.+:(..)/. It is compatible with Zen Cart.
# Detecting context based on the length of the mystery meat is a little
# hokey; it would be more ideal to specify or detect the context 
# explicitly in/from the object itself (or as a named/separate parameter).
sub enc_md5_salted {
    my ($obj, $password, $mystery_meat) = @_;

    my $encrypted;
    my $return_salt;
    my $mystery_meat_length = length $mystery_meat;
    if ($mystery_meat_length == 35) {
        # Extract only the salt; we don't need the database password here.
        my (undef, $db_salt) = split(':', $mystery_meat);
        $encrypted = Digest::MD5::md5_hex($db_salt . $password);
        $return_salt = $db_salt;
    }
    else {
        if ($mystery_meat_length != 2) {
            # Assume the mystery meat is a salt and soldier on anyway.
            ::logError("Unrecognized salt for md5_salted encryption.");
        }
        $return_salt = $mystery_meat;
        $encrypted = Digest::MD5::md5_hex($return_salt . $password);
    }

    return "$encrypted:$return_salt";
}

sub enc_sha1 {
    my $obj = shift;
    unless ($Vend::Util::SHA1) {
        $obj->log_either('SHA passwords unavailable. Is Digest::SHA installed?');
        return;
    }
    return Vend::Util::sha1_hex(shift);
}

sub enc_bcrypt {
    my $obj = shift;
    unless ($Has_Bcrypt) {
        $obj->log_either('Bcrypt passwords unavailable. Are Digest::Bcrypt and Crypt::Random installed?');
        return;
    }
    my ($password, $salt) = @_;
    my $store = bmarshal($salt);
    my $opt = $obj->{OPTIONS} || {};

    my $bcrypt = Digest::Bcrypt->new;

    my $salt =
        $store->{salt}
        ||
        Crypt::Random::makerandom_octet(
            Length   => 16, # bcrypt requirement
            Strength =>  0, # /dev/urandom instead of /dev/random
        )
    ;
    my $cost = bcost($opt, $store);

    $bcrypt->cost($cost);
    $bcrypt->salt($salt);
    $bcrypt->add($obj->brpad($password, $opt, $store->{cipher}));

    return bserialize($bcrypt, $store->{cipher});
}

sub bcost {
    my $opt = shift;
    my $store = shift || {};
    return $store->{cost} || $opt->{cost} || BCOST;
}

sub brpad {
    my $obj = shift;
    my ($data, $opt, $cipher) = @_;

    # If passwords are already stored SHA1, MD5, or crypt(),
    # and there is no desire to allow promote to organically
    # update them, the existing encrypted passwords can be
    # bcrypted wholesale and future submission by users will
    # "pre-digest" to the original encrypted structure
    # for comparison against the bcrypt hashes.
    #
    # This is indicated by the structure of the cipher:
    # * $2c$XX$ - original crypt() password with XX salt
    # * $2m$ - plain MD5 digest on password
    # * $2n$XX$ - salted MD5 digest on password
    # * $2s$ - plain SHA1 digest on password

    $data = $obj->pre_digest($data, $cipher);

    # Increase difficulty to brute force passwords by right padding out
    # to at least 72 character length. Most effective with "pepper" set
    # in catalog config.

    while (length ($data) < 72) {
        my $md5 = Digest::MD5->new;
        $md5->add($opt->{bcrypt_pepper})
            if $opt->{bcrypt_pepper};
        $data .= $md5->add($data)->b64digest;
    }
    return $data;
}

sub bserialize {
    my $bcrypt = shift;
    my $cipher = shift || '$2y$';

    my $encoded_salt = substr (MIME::Base64::encode_base64($bcrypt->salt,''),0,-2);

    return $cipher .
        join (
            '$',
            sprintf ('%02d', $bcrypt->cost),
            $encoded_salt . $bcrypt->b64digest,
        )
    ;
}

sub bmarshal {
    local $_ = shift;

    my $cipher = '';
    s/^(\$2(?:[yms]|[nc]\$..)\$)//
        and $cipher = $1;

    return {} unless $cipher;

    my ($cost, $combined) = grep { /\S/ } split /\$/;
    my ($encoded_salt, $hash) = $combined =~ /^(.{22})(.*)$/;

    return {} if
        $cost < 1
        ||
        $cost > 31
        ||
        $encoded_salt =~ m{[^a-z0-9+/]}i
        ||
        ($hash || '-') =~ m{[^a-z0-9+/]}i
    ;

    return {
        cipher => $cipher,
        salt => MIME::Base64::decode_base64("$encoded_salt=="),
        cost => $cost,
        hash => $hash,
    };
}

sub pre_digest {
    my $obj = shift;
    my $data = shift;
    my $cipher = shift || '';
    my ($id, $salt) = grep { /\S/ } split /\$/, $cipher;

    # Starts with "2" or not bcrypt
    $id =~ s/^2//
        or return $data;

    # Must have routine key defined in %cipher_map
    my $key = $cipher_map{$id}
        or return $data;

    return $enc_subs{$key}->($obj, $data, $salt);
}

sub construct_bcrypt {
    my $opt = shift;

    my $bstruct =
        __PACKAGE__
            -> new(profile => $opt->{profile})
            -> do_crypt($opt->{password})
    ;

    die sprintf (
        q{Encryption type for profile '%s' must be bcrypt},
        $opt->{profile} || 'default'
    )
        unless substr ($bstruct, 0, 4) eq '$2y$';

    return $bstruct unless my $type = $opt->{type};

    my %type_map = (crypt => 'c', reverse %cipher_map);
    my $cipher = $type_map{ $type }
        or die "$type is an unrecognized crypt type";

    my $salt =
        $cipher eq 'n' ? substr ($opt->{password}, -2) :
        $cipher eq 'c' ? substr ($opt->{password}, 0, 2)
                       : ''
    ;
    $salt &&= '$' . $salt;

    $bstruct =~ s/y/$cipher$salt/;

    return $bstruct;
}

# Maps the length of the encrypted data to the algorithm that
# produces it, or the identifier of the format from modular
# crypt format (MCF) in the case of bcrypt.
my %enc_id = qw/
    13      default
    32      md5
    35      md5_salted
    40      sha1
    $2      bcrypt
/;

sub determine_cipher {
    my $hash = shift;
    my ($cipher) = $hash =~ /^(\$\d+)/;
    return $cipher || length ($hash);
}

=head1 NAME

UserDB.pm -- Interchange User Database Functions

=head1 SYNOPSIS

userdb $function, %options

=head1 DESCRIPTION

The Interchange user database saves information for users, including shipping,
billing, and preference information.  It allows the user to return to a
previous session without the requirement for a "cookie" or other persistent
session information.

It is object-oriented and called via the [userdb] usertag, which calls the
userdb subroutine.

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
	company
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

=head2 Locations

There are several database locations that have special purposes. These
fields are not saved as user values.

=over

=item USERNAME				default: username

The username or key field of the database table.

=item BILLING				default: accounts

Billing address hash field.

=item SHIPPING				default: address_book

Shipping address hash field.

=item PREFERENCES			default: preferences

Miscellaneous information hash field.

=item FEEDBACK				default: feedback

Customer feedback hash field.

=item PRICING				default: price_level

Customer pricing level marker.

=item CARTS					default: carts

Saved carts hash field.

=item PASSWORD				default: password

Customer password info. If C<crypt> is set, may be encrypted.

=item LAST					default: mod_time

Last login time

=item EXPIRATION			default: expiration

Expiration of account.

=item OUTBOARD_KEY  		default: (none)

Key information for linking to another table of address or other info.

=item GROUPS				default: groups

Groups they should be logged into.

=item SUPER					default: super

Whether they are a superuser (admin).

=item ACL					default: acl

=item FILE_ACL				default: file_acl

=item DB_ACL				default: db_acl

Location of access control information.

=item CREATED_DATE_ISO		default: (none)

=item CREATED_DATE_UNIX		default: (none)

=item UPDATED_DATE_ISO		default: (none)

=item UPDATED_DATE_UNIX		default: (none)

Date fields.

=item MERGED_USER			default: (none)

The user id of another account this was merged into. If present, and data (should
be a valid user id) is present in the field, the user will be logged as that username.

=back

=cut

# user name and password restrictions
$USERNAME_GOOD_CHARS = '[-A-Za-z0-9_@.]';

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
			USERNAME  	=> $options{username}	||
						   $Vend::username		||
						   $CGI::values{mv_username} ||
						   '',
			OLDPASS  	=> $options{oldpass}	|| $CGI::values{mv_password_old} || '',
			PASSWORD  	=> $options{password}	|| $CGI::values{mv_password} || '',
			VERIFY  	=> $options{verify}		|| $CGI::values{mv_verify}	 || '',
			NICKNAME   	=> $options{nickname}	|| '',
			PROFILE   	=> $options{profile}	|| '',
			LAST   		=> '',
			USERMINLEN	=> $options{userminlen}	|| 2,
			PASSMINLEN	=> $options{passminlen}	|| 4,
			VALIDCHARS	=> $options{validchars} ? ('[' . $options{validchars} . ']') : $USERNAME_GOOD_CHARS,
			CRYPT  		=> defined $options{'crypt'}
							? $options{'crypt'}
							: ! $::Variable->{MV_NO_CRYPT},
			CGI			=>	( defined $options{cgi} ? is_yes($options{cgi}) : 1),
			PRESENT		=>	{ },
			DB_ID		=>	$options{database} || 'userdb',
			OPTIONS		=>	\%options,
			OUTBOARD	=>  $options{outboard}	|| '',
			LOCATION	=>	{
						USERNAME	=> $options{user_field} || 'username',
						BILLING		=> $options{bill_field} || 'accounts',
						SHIPPING	=> $options{addr_field} || 'address_book',
						PREFERENCES	=> $options{pref_field} || 'preferences',
						FEEDBACK	=> $options{feedback_field}   || 'feedback',
						PRICING		=> $options{pricing_field} || 'price_level',
						ORDERS     	=> $options{ord_field}  || 'orders',
						CARTS		=> $options{cart_field} || 'carts',
						PASSWORD	=> $options{pass_field} || 'password',
						LAST		=> $options{time_field} || 'mod_time',
						EXPIRATION	=> $options{expire_field} || 'expiration',
						OUTBOARD_KEY=> $options{outboard_key_col},
						GROUPS		=> $options{groups_field}|| 'groups',
						MERGED_USER => $options{merged_user},
						SUPER		=> $options{super_field}|| 'super',
						ACL			=> $options{acl}		|| 'acl',
						FILE_ACL	=> $options{file_acl}	|| 'file_acl',
						DB_ACL		=> $options{db_acl}		|| 'db_acl',
						CREATED_DATE_ISO		=> $options{created_date_iso},
						CREATED_DATE_UNIX		=> $options{created_date_epoch},
						UPDATED_DATE_ISO		=> $options{updated_date_iso},
						UPDATED_DATE_UNIX		=> $options{updated_date_epoch},
							},
			STATUS		=>		0,
			ERROR		=>		'',
			MESSAGE		=>		'',
		};
	bless $self;

	return $self if $options{no_open};

	set_db($self) or die errmsg("user database %s does not exist.", $self->{DB_ID}) . "\n";

	return $Vend::user_object = $self;
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

sub log_either {
	my $self = shift;
	my $msg = shift;

	if(! $self->{OPTIONS}{logfile}) {
		return logError($msg);
	}
	$self->log($msg,@_);
	return;
}

sub log {
	my $self = shift;
	my $time = $self->{OPTIONS}{unix_time} ?  time() :
				POSIX::strftime("%Y%m%d%H%M%S", localtime());
	my $msg = shift;
	logData( ($self->{OPTIONS}{logfile} || $Vend::Cfg->{LogFile}),
						$time,
						$self->{USERNAME},
						$CGI::remote_host || $CGI::remote_addr,
						$msg,
						);
	return;
}

sub check_acl {
	my ($self,%options) = @_;

	if(! defined $self->{PRESENT}{$self->{LOCATION}{ACL}}) {
		$self->{ERROR} = errmsg('No ACL field present.');
		return undef;
	}

	if(not $options{location}) {
		$self->{ERROR} = errmsg('No location to check.');
		return undef;
	}

	my $acl = $self->{DB}->field($self->{USERNAME}, $self->{LOCATION}{ACL});
	$acl =~ /(\s|^)$options{location}(\s|$)/;
}


sub set_acl {
	my ($self,%options) = @_;

	if(!$self->{PRESENT}{$self->{LOCATION}{ACL}}) {
		$self->{ERROR} = errmsg('No ACL field present.');
		return undef;
	}

	if(!$options{location}) {
		$self->{ERROR} = errmsg('No location to set.');
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
	$options{mode} = 'r' if ! defined $options{mode};
	my $acl = $self->{DB}->field( $self->{USERNAME}, $loc);
	my $f = $ready->reval($acl);
	return undef unless exists $f->{$options{location}};
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
	if($options{mode} =~ /^\s*expires?\s+(.*)/i) {
		$options{mode} = adjust_time($1);
	}
	my $acl = $self->{DB}->field( $self->{USERNAME}, $loc );
	my $f = $ready->reval($acl) || {};
	if($options{'delete'}) {
		delete $f->{$options{location}};
	}
	else {
		$f->{$options{location}} = $options{mode} || 'rw';
	}
	my $return = $self->{DB}->set_field( $self->{USERNAME}, $loc, uneval_it($f) );
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

	if($self->{OPTIONS}{username_email}) {
		$ignore{$self->{OPTIONS}{username_email_field} || 'email'} = 1;
	}

	for(values %{$self->{LOCATION}}) {
		$ignore{$_} = 1;
	}

	if($self->{OPTIONS}{force_lower}) {
		@fields = map { lc $_ } @fields;
	}

	for(@fields) {
		if($ignore{$_}) {
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

	my %constant;
	my %scratch;
	my %session_hash;

	if($self->{OPTIONS}->{constant}) {
		my (@s) = grep /\w/, split /[\s,]+/, $self->{OPTIONS}{constant} ;
		for(@s) {
			my ($k, $v) = split /=/, $_;
			$v ||= $k;
			$constant{$k} = $v;
		}
	}

	if($self->{OPTIONS}->{scratch}) {
		my (@s) = grep /\w/, split /[\s,]+/, $self->{OPTIONS}{scratch} ;
		for(@s) {
			my ($k, $v) = split /=/, $_;
			$v ||= $k;
			$scratch{$k} = $v;
		}
	}

	if($self->{OPTIONS}->{session_hash}) {
		my (@s) = grep /\w/, split /[\s,]+/, $self->{OPTIONS}{session_hash} ;
		for(@s) {
			my ($k, $v) = split /=/, $_;
			$v ||= $k;
			$session_hash{$k} = $v;
		}
	}

	for(@fields) {
		if(my $s = $scratch{$_}) {
			if (exists $Vend::Cfg->{ScratchDefault}->{$s}) {
				$::Scratch->{$s} = $Vend::Cfg->{ScratchDefault}->{$s};
			}
			else {
				delete $::Scratch->{$s};
			}
		}
		elsif($constant{$_}) {
			delete $Vend::Session->{constant}{$constant{$_}};
		}
		elsif($session_hash{$_}) {
			delete $Vend::Session->{$session_hash{$_}};
		}
		else {
			if (exists $Vend::Cfg->{ValuesDefault}->{$_}) {
				$::Values->{$_} = $Vend::Cfg->{ValuesDefault}->{$_};
			}
			else{
				delete $::Values->{$_};
			}
			delete $CGI::values{$_};
		}
	}

	1;
}

sub get_values {
	my($self, $valref, $scratchref) = @_;

	my $same;
	if($valref eq $scratchref) {
		$same = 1;
	}

	if(ref($valref) eq 'HASH') {
		## do nothing
	}
	elsif($valref and ! ref($valref) ) {
		my @things = split /:+/, $valref;
		$valref = $Vend::Session;
		for(@things) {
			my $clear = s/\*+$//;
			if($clear) {
				$valref = $valref->{$_} = {};
			}
			else {
				$valref = $valref->{$_} ||= {};
			}
		}
	}
	else {
		$valref = $::Values;
	}

	if($same) {
		$scratchref = $valref;
	}
	elsif(ref($scratchref) eq 'HASH') {
		## do nothing
	}
	elsif($scratchref and ! ref($scratchref) ) {
		my @things = split /:+/, $scratchref;
		$scratchref = $Vend::Session;
		for(@things) {
			my $clear = s/\*+$//;
			if($clear) {
				$scratchref = $scratchref->{$_} = {};
			}
			else {
				$scratchref = $scratchref->{$_} ||= {};
			}
		}
	}
	else {
		$scratchref = $::Scratch;
	}
	
	my $constref = $Vend::Session->{constant} ||= {};

	my @fields = @{ $self->{DB_FIELDS} };

	if($self->{OPTIONS}{username_email}) {
		push @fields, $self->{OPTIONS}{username_email_field} || 'email';
	}

	my $db = $self->{DB}
		or die errmsg("No user database found.");

	unless ( $db->record_exists($self->{USERNAME}) ) {
		$self->{ERROR} = errmsg("username %s does not exist.", $self->{USERNAME});
		return undef;
	}

	my %ignore;
	my %scratch;
	my %constant;
	my %session_hash;

	for(values %{$self->{LOCATION}}) {
		$ignore{$_} = 1;
	}

	my %outboard;
	if($self->{OUTBOARD}) {
		%outboard = split /[\s=,]+/, $self->{OUTBOARD};
		push @fields, keys %outboard;
	}

	if($self->{OPTIONS}->{constant}) {
		my (@s) = grep /\w/, split /[\s,]+/, $self->{OPTIONS}{constant} ;
		for(@s) {
			my ($k, $v) = split /=/, $_;
			$v ||= $k;
			$constant{$k} = $v;
		}
#::logDebug("constant ones: " . join " ", @s);
	}

	if($self->{OPTIONS}->{session_hash}) {
		my (@s) = grep /\w/, split /[\s,]+/, $self->{OPTIONS}{session_hash} ;
		for(@s) {
			my ($k, $v) = split /=/, $_;
			$v ||= $k;
			$session_hash{$k} = $v;
		}
#::logDebug("session_hash ones: " . join " ", @s);
	}

	if($self->{OPTIONS}->{scratch}) {
		my (@s) = grep /\w/, split /[\s,]+/, $self->{OPTIONS}{scratch} ;
		for(@s) {
			my ($k, $v) = split /=/, $_;
			$v ||= $k;
			$scratch{$k} = $v;
		}
#::logDebug("scratch ones: " . join " ", @s);
	}

	my @needed;
	my $row = $db->row_hash($self->{USERNAME});
	my $outkey = $self->{LOCATION}->{OUTBOARD_KEY}
				 ? $row->{$self->{LOCATION}->{OUTBOARD_KEY}}
				 : $self->{USERNAME};

	if(my $ef = $self->{OPTIONS}->{extra_fields}) {
		my @s = grep /\w/, split /[\s,]+/, $ef;
		my $field = $self->{LOCATION}{PREFERENCES};
		my $loc   = $self->{OPTIONS}{extra_selector} || 'default';
		my $hash = get_option_hash($row->{$field});
		if($hash and $hash = $hash->{$loc} and ref($hash) eq 'HASH') {
			for(@s) {
				if($scratch{$_} ) {
					$::Scratch->{$_} = $hash->{$_};
				}
				else {
					$::Values->{$_} = $hash->{$_};
				}
			}
		}
	}

	for(@fields) {
		if($ignore{$_}) {
			$self->{PRESENT}->{$_} = 1;
			next;
		}
		my $val;
		if ($outboard{$_}) {
			my ($t, $c, $k) = split /:+/, $outboard{$_};
			$val = ::tag_data($t, ($c || $_), $outkey, { foreign => $k });
		}
		else {
			$val = $row->{$_};
		}

		my $k;
		if($k = $scratch{$_}) {
			$scratchref->{$k} = $val;
			next;
		}
		elsif($k = $constant{$_}) {
			$constref->{$k} = $val;
			next;
		}
		elsif($k = $session_hash{$_}) {
			$Vend::Session->{$k} = string_to_ref($val) || {};
			next;
		}
		$valref->{$_} = $val;

	}

	my $area;
	foreach $area (qw!SHIPPING BILLING PREFERENCES CARTS!) {
		my $f = $self->{LOCATION}->{$area};
		if ($self->{PRESENT}->{$f}) {
			my $s = $self->get_hash($area);
			die errmsg("Bad structure in %s: %s", $f, $@) if $@;
			$::Values->{$f} = join "\n", sort keys %$s;
		}
	}
	
	1;
}

sub set_values {
	my($self, $valref, $scratchref) = @_;

	$valref = $::Values unless ref($valref);
	$scratchref = $::Scratch unless ref($scratchref);

	my $user = $self->{USERNAME};

	my @fields = @{$self->{DB_FIELDS}};

	my $db = $self->{DB};

	unless ( $db->record_exists($self->{USERNAME}) ) {
		$self->{ERROR} = errmsg("username %s does not exist.", $self->{USERNAME});
		return undef;
	}
	my %scratch;
	my %constant;
	my %session_hash;
    my %read_only;

	if ($self->{OPTIONS}{read_only}) {
		my (@s) = grep /\w/, split /[\s,]+/, $self->{OPTIONS}{read_only} ;
		$read_only{$_} = 1 for @s;
	}

	if($self->{OPTIONS}->{scratch}) {
		my (@s) = grep /\w/, split /[\s,]+/, $self->{OPTIONS}{scratch} ;
		for(@s) {
			my ($k, $v) = split /=/, $_;
			$v ||= $k;
			$scratch{$k} = $v;
		}
	}

	if($self->{OPTIONS}->{constant}) {
		my (@s) = grep /\w/, split /[\s,]+/, $self->{OPTIONS}{constant} ;
		for(@s) {
			my ($k, $v) = split /=/, $_;
			$v ||= $k;
			$constant{$k} = $v;
		}
	}

	if($self->{OPTIONS}->{session_hash}) {
		my (@s) = grep /\w/, split /[\s,]+/, $self->{OPTIONS}{session_hash} ;
		for(@s) {
			my ($k, $v) = split /=/, $_;
			$v ||= $k;
			$session_hash{$k} = $v;
		}
	}

	my $val;
	my %outboard;
	if($self->{OUTBOARD}) {
		%outboard = split /[\s=,]+/, $self->{OUTBOARD};
		push @fields, keys %outboard;
	}

	my @bfields;
	my @bvals;

  eval {

	my @extra;

	if(my $ef = $self->{OPTIONS}->{extra_fields}) {
		my $row = $db->row_hash($user);
		my @s = grep /\w/, split /[\s,]+/, $ef;
		my $field = $self->{LOCATION}{PREFERENCES};
		my $loc   = $self->{OPTIONS}{extra_selector} || 'default';
		my $hash = get_option_hash( $row->{$field} ) || {};

		my $subhash = $hash->{$loc} ||= {};
		for(@s) {
			$subhash->{$_} = $scratch{$_} ? $scratchref->{$_} : $valref->{$_};
		}

		push @extra, $field;
		push @extra, uneval_it($hash);
	}

	for( @fields ) {
#::logDebug("set_values saving $_ as $valref->{$_}\n");
		my $val;
		my $k;
        if ($read_only{$_}) {
            # Pull from get_values only; never write through set_values
            next;
        }
		if ($k = $scratch{$_}) {
			$val = $scratchref->{$k}
				if defined $scratchref->{$k};	
		}
		elsif ($constant{$_}) {
			# we never store constants
			next;
		}
		elsif ($k = $session_hash{$_}) {
			$val = uneval_it($Vend::Session->{$k});
		}
		else {
			$val = $valref->{$_}
				if defined $valref->{$_};	
		}

		next if ! defined $val;

		if($outboard{$_}) {
			my ($t, $c, $k) = split /:+/, $outboard{$_};
			::tag_data($t, ($c || $_), $self->{USERNAME}, { value => $val, foreign => $k });
		}
		elsif ($db->test_column($_)) {
			push @bfields, $_;
			push @bvals, $val;
		}
		else {
			::logDebug( errmsg(
							"cannot set unknown userdb field %s to: %s",
							$_,
							$val,
						)
					);
		}
	}

	my $dfield;
	my $dstring;
	if($dfield = $self->{OPTIONS}{updated_date_iso}) {
		if($self->{OPTIONS}{updated_date_gmtime}) {
			$dstring = POSIX::strftime('%Y-%m-%d %H:%M:%SZ', gmtime());
		}
		elsif($self->{OPTIONS}{updated_date_showzone}) {
			$dstring = POSIX::strftime('%Y-%m-%d %H:%M:%S %z', localtime());
		}
		else {
			$dstring = POSIX::strftime('%Y-%m-%d %H:%M:%S', localtime());
		}
	}
	elsif($dfield = $self->{OPTIONS}{updated_date_epoch}) {
		$dstring = time;
	}

	if($dfield and $dstring) {
		if($db->test_column($dfield)) {
			push @bfields, $dfield;
			push @bvals, $dstring;
		}
		else {
			my $msg = errmsg("updated field %s doesn't exist", $dfield);
			Vend::Tags->warnings($msg);
		}
	}
	
	while(@extra) {
		push @bfields, shift @extra;
		push @bvals, shift @extra;
	}

#::logDebug("bfields=" . ::uneval(\@bfields));
#::logDebug("bvals=" . ::uneval(\@bvals));
	if(@bfields) {
		$db->set_slice($user, \@bfields, \@bvals);
	}
  };

	if($@) {
	  my $msg = errmsg("error saving values in userdb: %s", $@);
	  $self->{ERROR} = $msg;
	  logError($msg);
	  return undef;
	}

# Changes made to support Accounting Interface.

	if(my $l = $Vend::Cfg->{Accounting}) {
		my %hashvar;
		my $indexvar = 0;
		while ($indexvar <= (scalar @bfields)) {
			$hashvar{ $bfields[$indexvar] } = $bvals[$indexvar];
			$indexvar++;
		};
		my $obj;
		my $class = $l->{Class};
		eval {
			$obj = $class->new;
		};

		if($@) {
			die errmsg(
				"Failed to save customer data with accounting system %s: %s",
				$class,
				$@,
				);
		}
		my $returnval = $obj->save_customer_data($user, \%hashvar);
	}

	return 1;
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
	$::Values->{$self->{LOCATION}{SHIPPING}} = join "\n", sort keys %$ref;
	return $::Values->{$self->{LOCATION}{SHIPPING}} if $self->{OPTIONS}{show};
	return '';
}

sub get_shipping_hashref {
	my $self = shift;
	my $ref = $self->get_hash('SHIPPING');
	return $ref if ref($ref) eq 'HASH';
	return undef;
}

sub get_billing_names {
	my $self = shift;
	my $ref = $self->get_hash('BILLING');
	return undef unless ref $ref;
	$::Values->{$self->{LOCATION}{BILLING}} = join "\n", sort keys %$ref;
	return $::Values->{$self->{LOCATION}{BILLING}} if $self->{OPTIONS}{show};
	return '';
}

sub get_billing_hashref {
	my $self = shift;
	my $ref = $self->get_hash('BILLING');
	return $ref if ref($ref) eq 'HASH';
	return undef;
}

sub get_preferences_names {
	my $self = shift;
	my $ref = $self->get_hash('PREFERENCES');
	return undef unless ref $ref;
	$::Values->{$self->{LOCATION}{PREFERENCES}} = join "\n", sort keys %$ref;
	return $::Values->{$self->{LOCATION}{PREFERENCES}} if $self->{OPTIONS}{show};
	return '';
}

sub get_cart_names {
	my $self = shift;
	my $ref = $self->get_hash('CARTS');
	return undef unless ref $ref;
	$::Values->{$self->{LOCATION}{CARTS}} = join "\n", sort keys %$ref;
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

	die errmsg("no fields?") unless @fields;
	die errmsg("no name?") unless $name;

	$self->get_hash($name) unless ref $self->{$name};

	my $nick_field = shift @fields;
	my $nick = $self->{NICKNAME} || $::Values->{$nick_field};

	delete $self->{$name}{$nick};

	my $field_name = $self->{LOCATION}->{$name};
	unless($self->{PRESENT}->{$field_name}) {
		$self->{ERROR} = errmsg('%s field not present to set %s', $field_name, $name);
		return undef;
	}

	my $s = uneval_it($self->{$name});

	$self->{DB}->set_field( $self->{USERNAME}, $field_name, $s);

	return ($s, $self->{$name});
}

sub set_hash {
	my($self, $name, @fields) = @_;

	die errmsg("no fields?") unless @fields;
	die errmsg("no name?") unless $name;

	$self->get_hash($name) unless ref $self->{$name};

	my $nick_field = shift @fields;
	my $nick = $self->{NICKNAME} || $::Values->{$nick_field};
	$nick =~ s/^[\0\s]+//;
	$nick =~ s/[\0\s]+.*//;
	$::Values->{$nick_field} = $nick;
	$CGI::values{$nick_field} = $nick if $self->{CGI};

	die errmsg("no nickname?") unless $nick;

	$self->{$name}{$nick} = {} unless $self->{OPTIONS}{keep}
							   and    defined $self->{$name}{$nick};

	for(@fields) {
		$self->{$name}{$nick}{$_} = $::Values->{$_}
			if defined $::Values->{$_};
	}

	my $field_name = $self->{LOCATION}->{$name};
	unless($self->{PRESENT}->{$field_name}) {
		$self->{ERROR} = errmsg('%s field not present to set %s', $field_name, $name);
		return undef;
	}

	my $s = uneval_it($self->{$name});

	$self->{DB}->set_field( $self->{USERNAME}, $field_name, $s);

	return ($s, $self->{$name});
}

sub get_hash {
	my($self, $name, @fields) = @_;

	my $field_name = $self->{LOCATION}->{$name};
	my ($nick, $s);

	eval {
		die errmsg("no name?")					unless $name;
		die errmsg("%s field not present to get %s", $field_name, $name) . "\n"
										unless $self->{PRESENT}->{$field_name};

		$s = $self->{DB}->field( $self->{USERNAME}, $field_name);

		if($s) {
			$self->{$name} = string_to_ref($s);
			die errmsg("Bad structure in %s: %s", $field_name, $@) if $@;
		}
		else {
			$self->{$name} = {};
		}

		die errmsg("eval failed?") . "\n"		unless ref $self->{$name};
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
		die errmsg("no nickname?") unless $nick;
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

=over 4

=item enclair_db

Using set_enclair() allows logging of enclair password to separate
database table. Designed to allow administration personnel to look
at passwords, without allowing access to web-connected systems. Or
perhaps more properly, to check prior MD5-encrypted password values 
for repeat passwords.

Designed to log to an insert-only handle on a table, with a database
structure such as:

  create table enclair (
    username varchar(32),
     password varchar(32),
     update_date timestamp
    )

Then a program on a secure behind-firewall no-select write-only
database can access the table, logged via request and username.

Configured:

	UserDB   default  enclair_db   some_table

You can set the following, which have the defaults shown in the
setting. You can also insert %M, which is the MD5 of the password, or
%D which is a datetime localtime value in the form YYYYmmddHHMMSS.

	#UserDB   default  enclair_key_field   username
	#UserDB   default  enclair_field       password
	#UserDB   default  enclair_query_template "INSERT INTO %t (%U,%P) values (%u,%p)"

String substitutions:

	%u  value of username
	%p  value of password
	%U  field of username
	%P  field of password
	%t  enclair table name
	%D  datetime value of form YYYYmmddHHMMSS
	%M  MD5 hashed value of password

=back

=cut

sub set_enclair {
	my $self = shift;
	if( my $tab = $self->{OPTIONS}{enclair_db} ) {
		eval {
			my $dbh = dbref($tab)->dbh();
			my $field = $self->{OPTIONS}{enclair_field} || 'password';
			my $key   = $self->{OPTIONS}{enclair_key_field} || 'username';
			my $datetime = POSIX::strftime('%Y%m%d%H%M%S', localtime());
			my $md5 = generate_key($self->{PASSWORD});
			my $q = $self->{OPTIONS}{enclair_query_template} || "INSERT INTO %t (%U,%P) values (%u,%p)";
			$q =~ s/\%M/$dbh->quote($md5)/eg;
			$q =~ s/\%D/$dbh->quote($datetime)/eg;
			$q =~ s/\%t/$tab/g;
			$q =~ s/\%U/$key/g;
			$q =~ s/\%P/$field/g;
			$q =~ s/\%u/$dbh->quote($self->{USERNAME})/eg;
			$q =~ s/\%p/$dbh->quote($self->{PASSWORD})/eg;
			$dbh->do($q);
		};
		if($@) {
			$self->log_either("Failed to set enclair password for $self->{USERNAME}: $@");
		}
	}
}


sub login {
	my $self;

	$self = shift
		if ref $_[0];

	my(%options) = @_;
	my ($user_data, $pw);

	# Show this generic error message on login page to avoid
	# helping would-be intruders
	my $stock_error = errmsg("Invalid user name or password.");
	
	eval {
		unless($self) {
			$self = new Vend::UserDB %options;
		}

		if($Vend::Cfg->{CookieLogin}) {
			$self->{USERNAME} = Vend::Util::read_cookie('MV_USERNAME')
				if ! $self->{USERNAME};
			$self->{PASSWORD} = Vend::Util::read_cookie('MV_PASSWORD')
				if ! $self->{PASSWORD};
		}

		if ($self->{VALIDCHARS} !~ / /) {
			# If space isn't a valid character in usernames,
			# be nice and strip leading and trailing whitespace.
			$self->{USERNAME} =~ s/^\s+//;
			$self->{USERNAME} =~ s/\s+$//;
		}

		if ($self->{OPTIONS}{ignore_case}) {
			$self->{PASSWORD} = lc $self->{PASSWORD};
			$self->{USERNAME} = lc $self->{USERNAME};
		}

		# We specifically check for login attempts with group names to see if
		# anyone is trying to exploit a former vulnerability in the demo catalog.
		if ($self->{USERNAME} =~ /^:/) {
			$self->log_either(errmsg("Denied attempted login with group name '%s'",
				$self->{USERNAME}));
			die $stock_error, "\n";
		}

		# Username must be long enough
		if (length($self->{USERNAME}) < $self->{USERMINLEN}) {
			$self->log_either(errmsg("Denied attempted login for user name '%s'; must have at least %s characters",
				$self->{USERNAME}, $self->{USERMINLEN}));
			die $stock_error, "\n";
		}

		# Username must contain only valid characters
		if ($self->{USERNAME} !~ m{^$self->{VALIDCHARS}+$}) {
			$self->log_either(errmsg("Denied attempted login for user name '%s' with illegal characters",
				$self->{USERNAME}));
			die $stock_error, "\n";
		}

		# Fail if password is too short
		if (length($self->{PASSWORD}) < $self->{PASSMINLEN}) {
			$self->log_either(errmsg("Denied attempted login with user name '%s' and password less than %s characters",
				$self->{USERNAME}, $self->{PASSMINLEN}));
			die $stock_error, "\n";
		}

		my $udb = $self->{DB};
		my $foreign = $self->{OPTIONS}{indirect_login};

		if($foreign) {
			my $uname = ($self->{PASSED_USERNAME} ||= $self->{USERNAME});
			my $ufield = $self->{LOCATION}{USERNAME};
			$uname = $udb->quote($uname);
			my $q = "select $ufield from $self->{DB_ID} where $foreign = $uname";
#::logDebug("indirect login query: $q");
			my $ary = $udb->query($q)
				or do {
					my $msg = errmsg( "Database access error for query: %s", $q);
					die "$msg\n";
				};
			@$ary == 1
				or do {
					$self->log_either(errmsg(
						@$ary ? "Denied attempted login with ambiguous (indirect from %s) user name %s" : "Denied attempted login with nonexistent (indirect from %s) user name %s",
						$foreign,
						$uname,
						$self->{USERNAME},
					));
					die $stock_error, "\n";
				};
			$self->{USERNAME} = $ary->[0][0];
		}

		# If not superuser, an entry must exist in access database
		unless ($Vend::superuser) {
			unless ($udb->record_exists($self->{USERNAME})) {
				$self->log_either(errmsg("Denied attempted login with nonexistent user name '%s'",
					$self->{USERNAME}));
				die $stock_error, "\n";
			}
			unless ($user_data = $udb->row_hash($self->{USERNAME})) {
				$self->log_either(errmsg("Login denied after failed fetch of user data for user '%s'",
					$self->{USERNAME}));
				die $stock_error, "\n";
			}
			my $db_pass = $user_data->{ $self->{LOCATION}{PASSWORD} };
			unless ($db_pass) {
				$self->log_either(errmsg("Refusing to use blank password from '%s' database for user '%s'", $self->{DB_ID}, $self->{USERNAME}));
				die $stock_error, "\n";
			}
			$pw = $self->{PASSWORD};

			if ( $self->{CRYPT} && $self->{OPTIONS}{promote} ) {
				my ($cur_method) = grep { $self->{OPTIONS}{ $_ } } keys %enc_subs;
				$cur_method ||= 'default';

				my $stored_by = $enc_id{ determine_cipher($db_pass) };
				my $from_sub = $self->{OPTIONS}{from_plain} ? sub {$_[1]} : $enc_subs{$stored_by};

				if (
					$cur_method ne $stored_by
					||
					$cur_method eq 'bcrypt'
					&&
					bcost($self->{OPTIONS}) != bcost($self->{OPTIONS}, bmarshal($db_pass))
					and
					$db_pass eq $from_sub->($self, $pw, $db_pass)
				) {

					my $newpass = $enc_subs{$cur_method}->($self, $pw, Vend::Util::random_string(2));
					my $db_newpass = eval {
						$self->{DB}->set_field(
							$self->{USERNAME},
							$self->{LOCATION}{PASSWORD},
							$newpass,
						);
					};

					if ($db_newpass ne $newpass) {
						# Usually, an error in the update will cause $db_newpass to be set to a
						# useful error string. The usefulness is dependent on DB store itself, though.
						my $err_msg = qq{Could not update database "%s" field "%s" with promoted password due to error:\n}
							. "%s\n"
							. qq{Check that field "%s" is at least %s characters wide.\n};
						$err_msg = ::errmsg(
							$err_msg,
							$self->{DB_ID},
							$self->{LOCATION}{PASSWORD},
							$DBI::errstr,
							$self->{LOCATION}{PASSWORD},
							length($newpass),
						);
						::logError($err_msg);
						die $err_msg;
					} 
					$db_pass = $newpass;
				}
			}

			if ($self->{CRYPT}) {
				$self->{PASSWORD} = $self->do_crypt($pw, $db_pass);
			}
			else {
				$db_pass = lc $db_pass if $self->{OPTIONS}{ignore_case};
			}
#::logDebug(errmsg("crypt: %s", $self->{CRYPT}));
#::logDebug(errmsg("ignore_case: %s", $self->{OPTIONS}{ignore_case}));
#::logDebug(errmsg("given password: %s", $self->{PASSWORD}));
#::logDebug(errmsg("stored password: %s", $db_pass));
			unless ($self->{PASSWORD} eq $db_pass) {
				$self->log_either(errmsg("Denied attempted login by user '%s' with incorrect password",
					$self->{USERNAME}));
				die $stock_error, "\n";
			}
			$self->log_either(errmsg("Successful login by user '%s'", $self->{USERNAME}));
		}

		if($self->{PRESENT}->{ $self->{LOCATION}{EXPIRATION} } ) {
			my $now = time();
			my $cmp = $now;
			$cmp = POSIX::strftime("%Y%m%d%H%M", localtime($now))
				unless $self->{OPTIONS}->{unix_time};
			my $exp = $udb->field(
						$self->{USERNAME},
						$self->{LOCATION}{EXPIRATION},
						);
			die errmsg("Expiration date not set.") . "\n"
				if ! $exp and $self->{EMPTY_EXPIRE_FATAL};
			if($exp and $exp < $cmp) {
				die errmsg("Expired %s.", $exp) . "\n";
			}
		}

		if($self->{PRESENT}->{ $self->{LOCATION}{MERGED_USER} } ) {
			my $old = $self->{USERNAME};
			my $new = $udb->field(
						$self->{USERNAME},
						$self->{LOCATION}{MERGED_USER},
						);
			if($new) {
				$self->{USERNAME} = $new;
				my $msg = errmsg('%s logged in as user %s, merged.', $old, $new);
				Vend::Tags->warnings($msg);
				$self->log_either($msg);
			}
		}

		if($self->{PRESENT}->{ $self->{LOCATION}{GROUPS} } ) {
			$Vend::groups
			= $Vend::Session->{groups}
			= $udb->field(
						$self->{USERNAME},
						$self->{LOCATION}{GROUPS},
						);
		}

		username_cookies($self->{PASSED_USERNAME} || $self->{USERNAME}, $pw, $self->{OPTIONS}{secure_cookies}) 
			if $Vend::Cfg->{CookieLogin};

		if ($self->{LOCATION}{LAST} ne 'none') {
			my $now = time();
			my $login_time;
			unless($self->{OPTIONS}{null_time}) {
				$login_time = $self->{OPTIONS}{iso_time}
						? POSIX::strftime("%Y-%m-%d %H:%M:%S", localtime($now))
						: $now;
			}
			eval {
				$udb->set_field( $self->{USERNAME},
									$self->{LOCATION}{LAST},
									$login_time
									);
			};
			if ($@) {
				my $msg = errmsg("Failed to record timestamp in UserDB: %s", $@);
				logError($msg);
				die $msg, "\n";
			}
		}
		$self->log('login') if $options{'log'};
		
		$self->get_values($self->{OPTIONS}{valref}, $self->{OPTIONS}{scratchref}) unless $self->{OPTIONS}{no_get};
	};

	scrub();

	if($@) {
		if(defined $self) {
			$self->{ERROR} = $@;
		}
		else {
			logError( "Vend::UserDB error: %s\n", $@ );
		}
		return undef;
	}

	PRICING: {
		my $pprof;
		last PRICING
			unless	$self->{LOCATION}{PRICING}
			and		$pprof = $user_data->{ $self->{LOCATION}{PRICING} };

		Vend::Interpolate::tag_profile(
								$pprof,
								{ tag => $self->{OPTIONS}{profile} },
								);
	}

	$Vend::login_table = $Vend::Session->{login_table} = $self->{DB_ID};
	$Vend::username = $Vend::Session->{username} = $self->{USERNAME};
	$Vend::Session->{logged_in} = 1;

	if (my $macros = $self->{OPTIONS}{postlogin_action}) {
		eval {
			Vend::Dispatch::run_macro $macros;
		};
		if ($@) {
			logError("UserDB postlogin_action execution error: %s\n", $@);
		}
	}

	1;
}

sub scrub {
	for(qw/ mv_password mv_verify mv_password_old /) {
		delete $CGI::values{$_};
		delete $::Values->{$_};
	}
}

sub logout {
	my $self = shift or return undef;
	scrub();

	my $opt = $self->{OPTIONS};

	if( is_yes($opt->{clear}) ) {
		$self->clear_values();
	}

	Vend::Interpolate::tag_profile("", { restore => 1 });
	no strict 'refs';

	my @dels = qw/
					groups
					admin
					superuser
					login_table
					username
					logged_in
				/;

	for(@dels) {
		delete $Vend::Session->{$_};
		undef ${"Vend::$_"};
	}

	delete $CGI::values{mv_username};
	delete $::Values->{mv_username};
	$self->log('logout') if $opt->{log};
	$self->{MESSAGE} = errmsg('Logged out.');
	if ($opt->{clear_cookie}) {
		my @cookies = split /[\s,\0]+/, $opt->{clear_cookie};
		my $exp = 10;
		for(@cookies) {
			Vend::Util::set_cookie($_, '', $exp);
		}
	}
	if ($opt->{clear_session}) {
		Vend::Session::init_session();
	}
	return 1;
}

sub change_pass {

	my ($self, $original_self);

	$self = shift
		if ref $_[0];

	my(%options) = @_;
	
	if ($self->{OPTIONS}{ignore_case}) {
	   $self->{USERNAME} = lc $self->{USERNAME};
	   $self->{OLDPASS} = lc $self->{OLDPASS};
	   $self->{PASSWORD} = lc $self->{PASSWORD};
	   $self->{VERIFY} = lc $self->{VERIFY};
	}

	eval {
		# Create copies so that ignore_case doesn't lc the originals.
		my $vend_username = $Vend::username;
		my $cgi_mv_username = $CGI::values{mv_username};
		if ($self->{OPTIONS}{ignore_case}) {
			$vend_username = lc $vend_username;
			$cgi_mv_username = lc $cgi_mv_username
				if defined $cgi_mv_username;
		}

		# Database operations still use the mixed-case original.
		my $super = $Vend::superuser || (
			$Vend::admin and
			$self->{DB}->field($Vend::username, $self->{LOCATION}{SUPER})
		);

		if ($self->{USERNAME} ne $vend_username or
			defined $cgi_mv_username and
			$self->{USERNAME} ne $cgi_mv_username
		) {
			if ($super) {
				if ($cgi_mv_username and
					$cgi_mv_username ne $self->{USERNAME}) {
					$original_self = $self;
					$options{username} = $cgi_mv_username;
					undef $self;
				}
			} else {
				errmsg("Unprivileged user '%s' attempted to change password of user '%s'",
					$vend_username, $self->{USERNAME}) if $options{log};
				die errmsg("You are not allowed to change another user's password.");
			}
		}

		unless($self) {
			$self = new Vend::UserDB %options;
		}

		die errmsg("Bad object.") unless defined $self;

		die errmsg("'%s' not a user.", $self->{USERNAME}) . "\n"
			unless $self->{DB}->record_exists($self->{USERNAME});

		unless ($super and $self->{USERNAME} ne $Vend::username) {
			my $db_pass = $self->{DB}->field($self->{USERNAME}, $self->{LOCATION}{PASSWORD});
			if ($self->{CRYPT}) {
				$self->{OLDPASS} = $self->do_crypt($self->{OLDPASS}, $db_pass);
			}
			die errmsg("Must have old password.") . "\n"
				if $self->{OLDPASS} ne $db_pass;
		}

		die errmsg("Must enter at least %s characters for password.",
			$self->{PASSMINLEN}) . "\n"
			if length($self->{PASSWORD}) < $self->{PASSMINLEN}; 
		die errmsg("Password and check value don't match.") . "\n"
			unless $self->{PASSWORD} eq $self->{VERIFY};

		$self->{OPTIONS}{enclair_db} and $self->set_enclair();

		if ( $self->{CRYPT} ) {
			$self->{PASSWORD} = $self->do_crypt(
				$self->{PASSWORD},
				Vend::Util::random_string(2),
			);
		}
		
		my $pass = $self->{DB}->set_field(
						$self->{USERNAME},
						$self->{LOCATION}{PASSWORD},
						$self->{PASSWORD}
						);
		die errmsg("Database access error.") . "\n" unless defined $pass;
		$self->log(errmsg('change password')) if $options{'log'};
	};

	scrub();

	$self = $original_self if $original_self;

	if($@) {
		if(defined $self) {
			$self->{ERROR} = $@;
			$self->log(errmsg('change password failed')) if $options{'log'};
		}
		else {
			logError( "Vend::UserDB error: %s", $@ );
		}
		return undef;
	}
	
	1;
}

sub assign_username {
	my $self = shift;
	my $file = shift || $self->{OPTIONS}{counter};
	my $start = $self->{OPTIONS}{username} || 'U00000';
	$file = './etc/username.counter' if ! $file;

	my $o = { start => $start, sql => $self->{OPTIONS}{sql_counter} };

	my $custno;

	if(my $l = $Vend::Cfg->{Accounting}) {

		my $class = $l->{Class};

		my $assign = defined $l->{assign_username} ? $l->{assign_username} : 1;

		if($assign) {
#::logDebug("Accounting class is $class");
		my $obj;
		eval {
				$obj = $class->new;
		};
#::logDebug("Accounting object is $obj");

		if($@) {
			die errmsg(
				"Failed to assign new customer number with accounting system %s",
				$class,
				);
		}
		$custno = $obj->assign_customer_number();
		}
#::logDebug("assigned new customer number $custno");
	}

	return $custno || Vend::Interpolate::tag_counter($file, $o);
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

		delete $Vend::Session->{auto_created_user};

		die errmsg("Bad object.") . "\n" unless defined $self;

		die errmsg("Already logged in. Log out first.") . "\n"
			if $Vend::Session->{logged_in} and ! $options{no_login};
		die errmsg("Sorry, reserved user name.") . "\n"
			if $self->{OPTIONS}{username_mask} 
				and $self->{USERNAME} =~ m!$self->{OPTIONS}{username_mask}!;
		die errmsg("Sorry, user name must be an email address.") . "\n"
			if $self->{OPTIONS}{username_email} 
				and $self->{USERNAME} !~ m!^[[:alnum:]]([.]?([[:alnum:]._-]+)*)?@([[:alnum:]\-_]+\.)+[a-zA-Z]{2,4}$!;
		die errmsg("Must enter at least %s characters for password.",
			$self->{PASSMINLEN}) . "\n"
			if length($self->{PASSWORD}) < $self->{PASSMINLEN};
		die errmsg("Password and check value don't match.") . "\n"
			unless $self->{PASSWORD} eq $self->{VERIFY};

		if ($self->{OPTIONS}{ignore_case}) {
			$self->{PASSWORD} = lc $self->{PASSWORD};
			$self->{USERNAME} = lc $self->{USERNAME};
		}

		my $pw = $self->{PASSWORD};
		if($self->{CRYPT}) {
			eval {
				$pw = $self->do_crypt($pw, Vend::Util::random_string(2));
			};
		}
	
		my $udb = $self->{DB};

		if($self->{OPTIONS}{assign_username}) {
			$self->{PASSED_USERNAME} = $self->{USERNAME};
			$self->{USERNAME} = $self->assign_username();
			$self->{USERNAME} = lc $self->{USERNAME}
				if $self->{OPTIONS}{ignore_case};
		}
		# plain error message without user-supplied username
		# to avoid XSS exploit (RT #306)
		die errmsg("Username contains illegal characters.") . "\n"
			if $self->{USERNAME} !~ m{^$self->{VALIDCHARS}+$};
		die errmsg("Must have at least %s characters in username.",
			$self->{USERMINLEN}) . "\n"
			if length($self->{USERNAME}) < $self->{USERMINLEN};

		if($self->{OPTIONS}{captcha}) {
			my $status = Vend::Tags->captcha( { function => 'check' });
			die errmsg("Must input captcha code correctly.") . "\n"
				unless $status;
		}

		# Here we put the username in a non-primary key field, checking
		# for existence
		my $foreign = $self->{OPTIONS}{indirect_login};
		if ($foreign) {
			my $uname = ($self->{PASSED_USERNAME} ||= $self->{USERNAME});
			$uname = $udb->quote($uname);
			my $q = "select $foreign from $self->{DB_ID} where $foreign = $uname";
			my $ary = $udb->query($q)
				or do {
					my $msg = errmsg( "Database access error for query: %s", $q);
					die "$msg\n";
				};
			@$ary == 0
				or do {
					my $msg = errmsg( "Username already exists (indirect).");
					die "$msg\n";
				};
		}

		if ($udb->record_exists($self->{USERNAME})) {
			die errmsg("Username already exists.") . "\n";
		}

		if($foreign) {
			 $udb->set_field(
						$self->{USERNAME},
						$foreign,
						$self->{PASSED_USERNAME},
						)
				or die errmsg("Database access error.");
		}

		$self->{OPTIONS}{enclair_db} and $self->set_enclair();

		my $pass = $udb->set_field(
						$self->{USERNAME},
						$self->{LOCATION}{PASSWORD},
						$pw,
						);

		die errmsg("Database access error.") . "\n" unless defined $pass;

		if($self->{OPTIONS}{username_email}) {
			my $field_name = $self->{OPTIONS}{username_email_field} || 'email';
			$::Values->{$field_name} ||= $self->{USERNAME};
			$udb->set_field(
						$self->{USERNAME},
						$field_name,
						$self->{USERNAME},
						)
				 or die errmsg("Database access error: %s", $udb->errstr) . "\n";
		}

		my $dfield;
		my $dstring;
		if($dfield = $self->{OPTIONS}{created_date_iso}) {
			if($self->{OPTIONS}{created_date_gmtime}) {
				$dstring = POSIX::strftime('%Y-%m-%d %H:%M:%SZ', gmtime());
			}
			elsif($self->{OPTIONS}{created_date_showzone}) {
				$dstring = POSIX::strftime('%Y-%m-%d %H:%M:%S %z', localtime());
			}
			else {
				$dstring = POSIX::strftime('%Y-%m-%d %H:%M:%S', localtime());
			}
		}
		elsif($dfield = $self->{OPTIONS}{created_date_epoch}) {
			$dstring = time;
		}

		if($dfield and $dstring) {
			$udb->set_field(
						$self->{USERNAME},
						$dfield,
						$dstring,
						)
				or do { 
					my $msg = errmsg('Failed to set new account creation date: %s', $udb->errstr);
					Vend::Tags->warnings($msg);
				};
		}

		if($options{no_login}) {
			$Vend::Session->{auto_created_user} = $self->{USERNAME};
		}
		else {
			$self->set_values() unless $self->{OPTIONS}{no_set};
			$self->{USERNAME} = $foreign if $foreign;
			username_cookies($self->{USERNAME}, $pw, $self->{OPTIONS}{secure_cookies}) 
				if $Vend::Cfg->{CookieLogin};

			$self->log('new account') if $options{'log'};
			$self->login()
				or die errmsg(
							"Cannot log in after new account creation: %s",
							$self->{ERROR},
						);
		}
	};

	scrub();

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
		my ($user, $pw, $secure) = @_;
		return unless
			 $CGI::values{mv_cookie_password}		or
			 $CGI::values{mv_cookie_username}		or
			 Vend::Util::read_cookie('MV_PASSWORD')	or
			 Vend::Util::read_cookie('MV_USERNAME');
		$::Instance->{Cookies} = [] unless defined $::Instance->{Cookies};
		my $exp = time() + $Vend::Cfg->{SaveExpire};
		$secure ||= $CGI::secure;
		push @{$::Instance->{Cookies}},
			['MV_USERNAME', $user, $exp];
		return unless
			$CGI::values{mv_cookie_password}		or
			Vend::Util::read_cookie('MV_PASSWORD');
		push @{$::Instance->{Cookies}},
			['MV_PASSWORD', $pw, $exp, undef, undef, $secure];
		return;
}

sub get_cart {
	my($self, %options) = @_;

	my $from = $self->{NICKNAME};
	my $to;

	my $opt = $self->{OPTIONS};

	if ($opt->{target}) {
		$to = ($::Carts->{$opt->{target}} ||= []);
	}
	else {
		$to = $Vend::Items;
	}

#::logDebug ("to=$to nick=$opt->{target} from=$from cart=" . ::uneval_it($from));

	my $field_name = $self->{LOCATION}->{CARTS};
	my $cart = [];

	eval {
		die errmsg("no from cart name?")				unless $from;
		die errmsg("%s field not present to get %s", $field_name, $from) . "\n"
										unless $self->{PRESENT}->{$field_name};

		my $s = $self->{DB}->field( $self->{USERNAME}, $field_name);

		die errmsg("no saved carts.") . "\n" unless $s;

		my @carts = split /\0/, $from;
		my $d = string_to_ref($s);
#::logDebug ("saved carts=" . ::uneval_it($d));

		die errmsg("eval failed?")				unless ref $d;

		for(@carts) {
			die errmsg("source cart '%s' does not exist.", $from) . "\n" unless ref $d->{$_};
			push @$cart, @{$d->{$_}};
		}

	};

	if($@) {
		$self->{ERROR} = $@;
		return undef;
	}
#::logDebug ("to=$to nick=$opt->{target} from=$from cart=" . ::uneval_it($cart));

	if($opt->{merge}) {
		$to = [] unless ref $to;
		my %used;
		my %alias;
		my $max;

		for(@$to) {
			my $master;
			next unless $master = $_->{mv_mi};
			$used{$master} = 1;
			$max = $master if $master > $max;
		}

		$max++;

		my $rename;
		my $alias = 100;
		for(@$cart) {
			my $master;
			next unless $master = $_->{mv_mi};
			next unless $used{$master};

			if(! $_->{mv_si}) {
				$alias{$master} = $max++;
				$_->{mv_mi} = $alias{$master};
			}
			else {
				$_->{mv_mi} = $alias{$master};
			}
		}

		push(@$to,@$cart);

	}
	else {
		@$to = @$cart;
	}
}

sub set_cart {
	my($self, %options) = @_;

	my $from;
	my $to   = $self->{NICKNAME};

	my $opt = $self->{OPTIONS};

	if ($opt->{source}) {
		$from = $::Carts->{$opt->{source}} || [];
	}
	else {
		$from = $Vend::Items;
	}

	my $field_name = $self->{LOCATION}->{CARTS};
	my ($cart,$s,$d);

	eval {
		die errmsg("no to cart name?") . "\n"					unless $to;
		die errmsg('%s field not present to set %s', $field_name, $from) . "\n"
										unless $self->{PRESENT}->{$field_name};

		$d = string_to_ref( $self->{DB}->field( $self->{USERNAME}, $field_name) );

		$d = {} unless $d;

		die errmsg("eval failed?")				unless ref $d;

		if($opt->{merge}) {
			$d->{$to} = [] unless ref $d->{$to};
			push(@{$d->{$to}}, @{$from});
		}
		else {
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


=head2 The [userdb ...] tag

Interchange provides a C<[userdb ...]> tag to access the UserDB functions.

 [userdb
        function=function_name
        username="username"
        assign_username=1
        username_mask=REGEX
        password="password"
        verify="password"
        oldpass="old password"
        crypt="1|0"
		bcrypt=1
		promote=1
		md5=1
		md5_salted=1
		sha1=1
		valref=user_record
		scratchref=user_record
        shipping="fields for shipping save"
        billing="fields for billing save"
        preferences="fields for preferences save"
        ignore_case="1|0"
        force_lower=1
        param1=value
        param2=value
        ...
        ]

All parameters are optional except for the function. Normally, parameters 
are set in catalog.cfg with the I<UserDB> directive.

It is normally called in an C<mv_click> or C<mv_check> setting, as in:

    [set Login]
    mv_todo=return
    mv_nextpage=welcome
    [userdb function=login]
    [/set]

    <FORM ACTION="[process-target]" METHOD=POST>
    <INPUT TYPE=hidden NAME=mv_click VALUE=Login>
    Username <INPUT NAME=mv_username SIZE=10>
    Password <INPUT NAME=mv_password SIZE=10>
    </FORM>

There are several global parameters that apply to any use of
the C<userdb> functions. Most importantly, by default the database
table is set to be I<userdb>. If you must use another table name,
then you should include a C<database=table> parameter with any
call to C<userdb>. The global parameters (default in parens):

    database     Sets user database table (userdb)
    show         Show the return value of certain functions
                 or the error message, if any (0)
    force_lower  Force possibly upper-case database fields
                 to lower case session variable names (0)
    billing      Set the billing fields (see Accounts)
    shipping     Set the shipping fields (see Address Book)
    preferences  Set the preferences fields (see Preferences)
    bill_field   Set field name for accounts (accounts)
    addr_field   Set field name for address book (address_book)
    pref_field   Set field name for preferences (preferences)
    cart_field   Set field name for cart storage (carts)
    pass_field   Set field name for password (password)
    time_field   Set field for storing last login time (time)
    expire_field Set field for expiration date (expire_date)
    acl          Set field for simple access control storage (acl)
    file_acl     Set field for file access control storage (file_acl)
    db_acl       Set field for database access control storage (db_acl)

By default the system crypt() call will be used to compare the
password. This is minimal security, but at least the passwords in the user
database will not be human readable. For better security, in descending
order of security, use:

	bcrypt    Bcrypt, most secure
	sha1      SHA1 digest, more secure than MD5
	md5       Not so easily stored in cracklib as md5 unsalted
	md5       Better security than crypt

If you don't keep actual user information, don't have users creating
accounts and setting the passwords themselvs, and don't do Interchange
administration via the C<UserDB> capability, then you may
wish to use the <UserDB> directive (described below) to set
encryption off by default:

    UserDB   default   crypt   0

That will set encryption off by default. You can still set encryption
on by passing C<crypt=1> with any call to a C<new_account>, C<change_pass>,
or C<login> call.

WARNING: Using unencrypted passwords is never recommended if you have users
setting their passwords. They will use the same passwords as other systems,
possibly compromising important information.

=head2 Setting defaults with the UserDB directive

The I<UserDB> directive provides a way to set defaults for
the user database. For example, if you always wanted to save
and recall the scratch variable C<tickets> in the user database
instead of the form variable C<tickets>, you could set:

    UserDB   default   scratch  tickets

That makes every call to C<[userdb function=login]> be equivalent
to C<[userdb function=login scratch=tickets]>.

If you wish to override that default for one call only, you can
use C<[userdb function=login scratch="passes"]>.

If you wish to log failed access authorizations, set the C<UserDB>
profile parameter C<log_failed> true:

    UserDB  default  log_failed 1

To disable logging of failed access authorizations (the default), set
the C<UserDB> profile parameter C<log_failed> to 0:

    UserDB  default  log_failed 0

The I<UserDB> directive uses the same key-value pair settings
as the I<Locale> and I<Route> directives, and you may have more
than one set of defaults. You can set them in a hash structure:

    UserDB  case_crypt  scratch     tickets
    UserDB  case_crypt  bcrypt	    1
    UserDB  case_crypt  ignore_case 0

    UserDB  default     scratch     tickets
    UserDB  default     sha1	    1
    UserDB  default     ignore_case 1

The last one to be set becomes the default.

The option C<profile> selects the set to use. So if you wanted
usernames and passwords to be case sensitive with bcrypt encryption,
you could pass this call:

    [userdb function=new_account profile=case_crypt]

The username and password will be stored as typed in, and the
password will be encrypted in the database.

=head2 User Database functions

The user database features are implemented as a series of functions
attached to the C<userdb> tag. The functions are:

=over 4

=item login

Log in to Interchange. By default, the username is contained in the
form variable C<mv_username> and the password in C<mv_password>.
If the login is successful, the session value C<username>
(C<[data session username]>) will be set to the user name.

This will recall the values of all non-special fields in the user
database and place them in their corresponding user form variables.

=item logout

Log out of Interchange. No additional parameters are needed.

=item new_account

Create a new account. It requires the C<username>, C<password>, and
C<verify> parameters, which are by default contained in the form
variables C<mv_username>, C<mv_password>, C<mv_verify> respectively.

If you set the C<assign_username> parameter, then UserDB will assign
a sequential username. The C<counter> parameter can be used to set
the filename (must be absolute), or you can accept the default of
CATALOG_DIR/etc/username.counter. The first username will be "U0001"
if the counter doesn't exist already.

The C<ignore_case> parameter forces the username and password to
lower case in the database, in effect rendering the username and
password case-insensitive.

If you set C<username_mask> to a valid Perl regular expression (without
the surrounding / /) then any username containing a matching string will
not be allowed for use. For example, to screen out order numbers from
being used by a random user:

    [userdb function=new_account
            username_mask="^[A-Z]*[0-9]"
            ]

The I<CookieLogin> directive (catalog.cfg) allows users to save
their username/password in a cookie. Expiration time is set by
I<SaveExpire>, renewed every time they log in. To cause the cookie to
be generated originally, the form variable C<mv_cookie_password> or
C<mv_cookie_username> must be set in the login form. The former causes
both username and password to be saved, the latter just the username.

If you want to automatically create an account for every order,
you can do in the I<OrderReport> file:

    [userdb function=new_account
            username="[value mv_order_number]"
            password="[value zip]"
            verify="[value zip]"
            database="orders"
            ]

This would be coupled with a login form that asked for order number and
zip code; thereupon allowing you to display the contents of a transaction
database with (presumably updated) order status information or a shipping
company tracking number.

=item change_pass

Change the password on the currently logged-in account. It requires
the C<username>, C<password>, C<verify>, and C<oldpass> parameters,
which are by default contained in the form variables C<mv_username>,
C<mv_password>, C<mv_verify>, C<mv_password_old> respectively.

=item set_shipping

Active parameters: nickname, shipping, ship_field

Place an entry in the shipping Address book. Example:

    [userdb function=set_shipping nickname=Dad]

See I<Address Book> below.

=item get_shipping

Active parameters: nickname, shipping, ship_field

Recall an entry from the shipping Address book. Example:

    [userdb function=get_shipping nickname=Dad]

See I<Address Book> below.

=item get_shipping_names

Active parameters: ship_field

Gets the names of shipping address book entries and places
them in the variable C<address_book>. By default, it does not return
the values; if you wish them to be returned you can set
the parameter C<show> to 1, as in:

    [set name=shipping_nicknames
         interpolate=1]
      [userdb function=get_shipping_names show=1]
    [/set]

=item set_billing

Active parameters: nickname, billing, bill_field

Place an entry in the billing accounts book. Example:

    [userdb function=set_billing nickname=discover]

See I<Accounts Book> below.

=item get_billing

Active parameters: nickname, billing, bill_field

Recall an entry from the billing accounts book. Example:

    [userdb function=get_billing nickname=visa]

See I<Accounts Book> below.

=item save

Saves all non-special form values that have columns in the user database.

=item load

Performs the transfer of user values to the values space, scratch space, and
constant space. Performed automatically upon login.

If you pass the C<valref> option, that will be used instead of C<$Values> for
the values space. It can either be a real hash reference, or a scalar that
will be a key directly in C<$Vend::Session>. If it contains a colon (C<:>), it
will be a subreference in C<$Vend::Session>. For example:

	[userdb function=load valref=`$Session->{user_record} ||= {}`]

Will store the values in C<$Vend::Session->{user_record}>, clearing it first.
The below accomplishes the same thing:

	[userdb function=load valref=user_record]

If you want to place it a couple of levels down, do:

	[userdb function=load valref=`$Session->{values_repository}{userdb} ||= {}`]

or

	[userdb function=load valref="values_repository:userdb"]

To clear the record instead of add to the existing values, add an
asterisk at the end:

	[userdb function=load valref="values_repository:userdb*"]

Which is equivalent to:

	[userdb function=load valref=`$Session->{values_repository}{userdb} = {}`]

The C<scratchref> option is the same as C<valref>, but for the scratch values
passed with C<UserDB scratch>.

=item set_cart

Save the contents of a shopping cart.

    [userdb function=set_cart nickname=christmas]

See I<Carts> below.

=item get_cart

Active parameters: nickname, carts_field, target

Recall a saved shopping cart. 

    [userdb function=get_cart nickname=mom_birthday]

Setting C<target> saves to a different shopping cart than the
default main cart. The C<carts_field> controls the database
field used for storage.

=item set_acl

Active parameters: location, acl_field, delete

Set a simple acl. Example:

    [userdb function=set_acl location=cartcfg/editcart]

This allows the current user to access the page "cartcfg/editcart" if 
it is access-protected.

To delete access, do:

    [userdb function=set_acl location=cartcfg/editcart delete=1]

To display the setting at the same time as setting use the
C<show> attribute:

    [userdb function=set_acl location=cartcf/editcart show=1]

=item check_acl

Active parameters: location, acl_field

Checks the simple access control listing for a location, returning
1 if allowed and the empty string if not allowed.

    [if type=explicit
        compare="[userdb
                    function=check_acl
                    location=cartcfg/editcart]"
    ]
    [page cartcfg/editcart]Edit your cart configuration[/page]
    [/if]

=item set_file_acl, set_db_acl

Active parameters: location, mode, db_acl_field, file_acl_field, delete

Sets a complex access control value. Takes the form:

    [userdb function=set_file_acl
            mode=rw
            location=products/inventory.txt]

where mode is any value you wish to check for with check_file_acl. As
with the simple ACL, you can use delete=1 to delete the location entirely.

=item check_file_acl, check_db_acl

Active parameters: location, mode, db_acl_field, file_acl_field

Checks a complex access control value and returns a true/false (1/0)
value. Takes the form:

    [userdb function=check_db_acl
            mode=w
            location=inventory]

where mode is any value you wish to check for with check_file_acl. It
will return true if the mode string is contained within the entry
for that location. Example:

    [if type=explicit
        compare="[userdb
                    function=check_db_acl
                    mode=w
                    location=inventory]"
    ]
    [userdb function=set_acl location=cartcfg/edit_inventory]
    [page cartcfg/edit_inventory]You may edit the inventory database[/page]
    [else]
    [userdb function=set_acl location=cartcfg/edit_inventory delete=1]
    Sorry, you can't edit inventory.
    [/if]

=back

=cut

sub userdb {
	my $function = shift;
	my $opt = shift;

	my %options;

	if(ref $opt) {
		%options = %$opt;
	}
	else {
		%options = ($opt, @_);
	}

	my $status = 1;
	my $user;

	my $module = $Vend::Cfg->{UserControl} ? 'Vend::UserControl' : 'Vend::UserDB';

	if($function eq 'login') {
		$Vend::Session->{logged_in} = 0;
		delete $Vend::Session->{username};
		delete $Vend::Session->{groups};
		undef $Vend::username;
		undef $Vend::groups;
		undef $Vend::admin;
		$user = $module->new(%options);
		unless (defined $user) {
			$Vend::Session->{failure} = errmsg("Unable to access user database.");
			return undef;
		}
		if ($status = $user->login(%options) ) {
			if( $Vend::ReadOnlyCfg->{AdminUserDB}{$user->{PROFILE}} ) {
				$Vend::admin = 1;
			}
			::update_user();
		}
	}
	elsif($function eq 'new_account') {
		$user = $module->new(%options);
		unless (defined $user) {
			$Vend::Session->{failure} = errmsg("Unable to access user database.");
			return undef;
		}
		$status = $user->new_account(%options);
		if($status and ! $options{no_login}) {
			$Vend::Session->{logged_in} = 1;
			$Vend::Session->{username} = $user->{USERNAME};
		}
	}
	elsif($function eq 'logout') {
		$user = $module->new(%options)
			or do {
				$Vend::Session->{failure} = errmsg("Unable to create user object.");
				return undef;
			};
		$user->logout();
	}
	elsif (! $Vend::Session->{logged_in}) {
		$Vend::Session->{failure} = errmsg("Not logged in.");
		return undef;
	}
	elsif($function eq 'save') {
		$user = $module->new(%options);
		unless (defined $user) {
			$Vend::Session->{failure} = errmsg("Unable to access user database.");
			return undef;
		}
		$status = $user->set_values();
	}
	elsif($function eq 'load') {
		$user = $module->new(%options);
		unless (defined $user) {
			$Vend::Session->{failure} = errmsg("Unable to access user database.");
			return undef;
		}
		$status = $user->get_values($opt->{valref}, $opt->{scratchref});
	}
	else {
		$user = $module->new(%options);
		unless (defined $user) {
			$Vend::Session->{failure} = errmsg("Unable to access user database.");
			return undef;
		}
		eval {
			$status = $user->$function(%options);
		};
		$user->{ERROR} = $@ if $@;
	}
	
	if(defined $status) {
		delete $Vend::Session->{failure};
		$Vend::Session->{success} = $user->{MESSAGE};
		if($options{show_message}) {
			$status = $user->{MESSAGE};
		}
	}
	else {
		$Vend::Session->{failure} = $user->{ERROR};
		if($options{show_message}) {
			$status = $user->{ERROR};
		}
	}
	return $status unless $options{hide};
	return;
}

sub do_crypt {
	my ($self, $password, $salt) = @_;
	my $sub = $self->{ENCSUB};
	unless ($sub) {
		for (grep { $self->{OPTIONS}{$_} } keys %enc_subs) {
			$sub = $enc_subs{$_};
			last;
		}
		$self->{ENCSUB} = $sub ||= $enc_subs{default};
	}
	return $sub->($self, $password, $salt);
}

1;
