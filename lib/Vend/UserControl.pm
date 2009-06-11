# Vend::UserControl - Enhanced Interchange user database functions
#
# $Id: UserControl.pm,v 2.6 2007-08-09 13:40:54 pajamian Exp $
#
# Copyright (C) 2003-2007 Interchange Development Group
# Copyright (C) 2003 Mike Heins, <mikey@heins.net>
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

package Vend::UserControl;

$VERSION = substr(q$Revision: 2.6 $, 10);

require Vend::UserDB;
use Vend::Data;
use Vend::Util;
use Vend::Safe;

@ISA = qw/ Vend::UserDB /;

use strict;

=head1 NAME

UserControl.pm -- Enhanced Interchange User Database Functions

=head1 SYNOPSIS

userdb $function, %options

=head1 DESCRIPTION

This module uses Vend::UserDB as a base class and changes the address
functions to use an external database.

=cut

my %s_map = qw/
	company		company
	fname		fname
	lname		lname
	address1	address1
	address2	address2
	address3	address3
	city		city
	state		state
	zip			zip
	country		country
	phone_day	phone_day
	phone_night	phone_night
	email		email

/;

my %b_map = qw/
	b_company	company
	b_fname		fname
	b_mname		lname
	b_lname		lname
	b_address1	address1
	b_address2	address2
	b_address3	address3
	b_city		city
	b_state		state
	b_zip		zip
	b_country	country
	b_phone		phone_day
	b_email		email
/;

sub new {
	my $class = shift;
	my %options;
	if(ref $_[0]) {
		%options = %{$_[0]};
	}
	else {
		%options = @_;
	}

	my $self = new Vend::UserDB %options;
	bless $self, $class;
}

sub get_values {
	my($self, @fields) = @_;

	@fields = @{ $self->{DB_FIELDS} } unless @fields;

	my $db = $self->{DB}
		or die ::errmsg("No user database found.");

	unless ( $db->record_exists($self->{USERNAME}) ) {
		$self->{ERROR} = ::errmsg("username %s does not exist.", $self->{USERNAME});
		return undef;
	}

	my $o = $self->{OPTIONS};
	my $present  = $self->{PRESENT} || {};
	my $location = $self->{LOCATION} || {};

	my %ignore;
	my %scratch;

	for(values %$location) {
		$ignore{$_} = 1;
	}

	my %outboard;
	if($self->{OUTBOARD}) {
		%outboard = split /[\s=,]+/, $self->{OUTBOARD};
		push @fields, keys %outboard;
	}

	if($o->{scratch}) {
		my (@s) = split /[\s,]+/, $o->{scratch} ;
		@scratch{@s} = @s;
#::logError("scratch ones: " . join " ", @s);
	}

	my @needed;
	my $row = $db->row_hash($self->{USERNAME});
	my $outkey = $location->{OUTBOARD_KEY}
				 ? $row->{$location->{OUTBOARD_KEY}}
				 : $self->{USERNAME};


	my $adb = dbref($o->{address_table} || 'address');
	my $srec;
	if($adb and $::Values->{s_nickname}) {
		my $tname = $adb->name();
		my $nf = $o->{address_nickname_field} || 'nickname';
		my $nv = $adb->quote($::Values->{s_nickname}, $nf);
		my $uf = $o->{address_username_field} || 'username';
		my $uv = $adb->quote($Vend::username, $uf);
		my %o = (
			hashref => 1,
			sql => "select * from $tname where $uf = $uv and $nf = $nv",
		);
		my $ary = $adb->query(\%o);
		$ary and $srec = $ary->[0];
	}

	my $brec;
	if($adb and $::Values->{b_nickname}) {
		my $tname = $adb->name();
		my $nf = $o->{address_nickname_field} || 'nickname';
		my $nv = $adb->quote($::Values->{s_nickname}, $nf);
		my $uf = $o->{address_username_field} || 'username';
		my $uv = $adb->quote($Vend::username, $uf);
		my %o = (
			hashref => 1,
			sql => "select * from $tname where $uf = $uv and $nf = $nv",
		);
		my $ary = $adb->query(\%o);
		$ary and $brec = $ary->[0];
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
		elsif ($srec and $s_map{$_}) {
			$val = $srec->{$s_map{$_}};
		}
		elsif ($brec and $b_map{$_}) {
			$val = $brec->{$b_map{$_}};
		}
		else {
			$val = $row->{$_};
		}

		if($scratch{$_}) {
			$::Scratch->{$_} = $val;
			next;
		}
		$::Values->{$_} = $val;
	}

	my $area;
	foreach $area (qw!PREFERENCES CARTS!) {
		my $f = $location->{$area};
		if ($present->{$f}) {
			my $s = $self->get_hash($area);
			die ::errmsg("Bad structure in %s: %s", $f, $@) if $@;
			$::Values->{$f} = join "\n", sort keys %$s;
		}
	}

	return 1;

}

sub set_values {
	my($self) = @_;

	my @fields;

	my $user = $self->{USERNAME};

#::logDebug("Saving in Vend::UserControl");

	@fields = @{$self->{DB_FIELDS}};

	my $db = $self->{DB};

	my $o = $self->{OPTIONS};
	my $present  = $self->{PRESENT} || {};
	my $location = $self->{LOCATION} || {};

	unless ( $db->record_exists($self->{USERNAME}) ) {
		$self->{ERROR} = ::errmsg("username %s does not exist.", $self->{USERNAME});
		return undef;
	}
	my %scratch;

	if($o->{scratch}) {
		my (@s) = split /[\s,]+/, $o->{scratch} ;
		@scratch{@s} = @s;
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
	for( @fields ) {
#::logDebug("set_values saving $_ as $::Values->{$_}\n");
		my $val;
		if ($scratch{$_}) {
			$val = $::Scratch->{$_}
				if defined $::Scratch->{$_};	
		}
		else {
			$val = $::Values->{$_}
				if defined $::Values->{$_};	
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
			::logDebug( ::errmsg(
							"cannot set unknown userdb field $_ to: %s",
							$_,
							$val,
						)
					);
		}
	}
	
	if(@bfields) {
		$db->set_slice($user, \@bfields, \@bvals);
	}
  };

	if($@) {
	  my $msg = ::errmsg("error saving values in userdb: %s", $@);
	  $self->{ERROR} = $msg;
	  ::logError($msg);
	  return undef;
	}

	if($::Values->{s_nickname}) {
#::logDebug("set_shipping in Vend::UserControl");
		$self->set_shipping($::Values->{s_nickname});
	}
	if($::Values->{b_nickname}) {
#::logDebug("set_billing in Vend::UserControl");
		$self->set_billing($::Values->{b_nickname});
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

sub make_field_map {
	my $maptext = shift
		or return;
	$maptext =~ s/^\s+//;
	$maptext =~ s/\s+$//;

	my $map = {};
	my @pairs = split /[,\r\n]+/, $maptext;
	for(@pairs) {
		s/^\s+//;
		s/\s+$//;
		my ($k, $v) = split /\s*=\s*/, $_, 2;
		$map->{$k} = $v;
	}
	return $map;
}

sub get_shipping {
	my $self = shift;

	my $o = $self->{OPTIONS} || {};

	my $nick = $o->{nickname} || $::Values->{s_nickname};

	my $map = make_field_map($o->{shipping_map}) || \%s_map;

	return $self->get_address($nick, $map, 's');
}

sub get_billing {
	my $self = shift;

	my $o = $self->{OPTIONS} || {};

	my $nick = $o->{nickname} || $::Values->{b_nickname};

	my $map = make_field_map($o->{billing_map}) || \%b_map;

	return $self->get_address($nick, $map, 'b');
}

sub get_address {
	my ($self, $nickname, $map, $prefix, $vref) = @_;

	$vref ||= $::Values;
	$prefix ||= 's';
	my $nick_field = $prefix . '_nickname';
	my $nick_lab_field = $nick_field . '_description';

	my $o = $self->{OPTIONS} || {};

	$nickname ||= $o->{nickname};
	return unless $nickname;

	my $nf = $o->{address_nickname_field} || 'nickname';
	my $uf = $o->{address_username_field} || 'username';
	my $lf = $o->{address_label_field}    || 'label';

	my $adb = dbref($o->{address_table} || 'address')
		or do {
			my $atab =  $o->{address_table} || 'address';
			::logError("unable to find address table", $atab);
			return;
		};

	my $tname = $adb->name();
	my $tcode = $adb->config('KEY');

	my $uv = $adb->quote($self->{USERNAME}, $uf);
	my $nv = $adb->quote($nickname, $nf);

	my @where;
	push @where, "$uf = $uv";
	push @where, "$nf = $nv";
	my $pf = $o->{address_profile_field} || 'profile';
	if($adb->column_exists($pf)) {
		my $pv = $adb->quote($o->{profile} || 'default', $pf);
		push @where, "$pf = $pv";
	}
	else {
		undef $pf;
	}

	my $qual = join " AND ", @where;

	my $cq = "select * from $tname where $qual";
#::logDebug("Running $cq");

	my $ary;
	my $rec;

	$ary = $adb->query({ sql => $cq, hashref => 1} )
		and $rec = $ary->[0];

#::logDebug("Ready to return " . ::uneval($rec));

	for(keys %$map) {
		$vref->{$_} = $rec->{$map->{$_}};
	}

	unless($o->{no_update}) {
		$vref->{$nick_lab_field} = $rec->{$lf};
		$vref->{$nick_field} = $rec->{$nf};
	}

	return $rec->{$tcode};
}

sub get_names {
	my $self = shift;
	my $nick = shift;
	my $o = $self->{OPTIONS} || {};

	my $adb = dbref($o->{address_table} || 'address');
	my $tname = $adb->name();
	my $nf = $o->{address_nickname_field} || 'nickname';
	my $uf = $o->{address_username_field} || 'username';
	my $uv = $adb->quote($self->{USERNAME}, $uf);
	my $q = "select $nf from $tname where $uf = $uv";
	my $ary = $adb->query($q);
	my @names;
	if($ary and @$ary) {
		for(@$ary) {
			push @names, $_->[0];
		}
	}

	$o->{joiner} ||= "\n";
	return join $o->{joiner}, @names;
}

sub set_shipping {
	my $self = shift;

	my $o = $self->{OPTIONS} || {};

	my $nick = $o->{nickname} || $::Values->{s_nickname} || 'shipping';

	my $map = make_field_map($o->{shipping_map}) || \%s_map;

	$self->set_address($nick, $map, 's');
}

sub set_billing {
	my $self = shift;

	my $o = $self->{OPTIONS} || {};

	my $nick = $o->{nickname} || $::Values->{b_nickname} || 'billing';

	my $map = make_field_map($o->{billing_map}) || \%b_map;

	$self->set_address($nick, $map, 'b');
}

sub set_address {
	my ($self, $nickname, $map, $prefix, $vref) = @_;

	$vref ||= $::Values;
	$prefix ||= 's';
	my $nick_lab_field = $prefix . '_nickname_description';

	my $o = $self->{OPTIONS} || {};

	$nickname ||= $o->{nickname};
	return unless $nickname;

	my $nf = $o->{address_nickname_field} || 'nickname';
	my $uf = $o->{address_username_field} || 'username';
	my $lf = $o->{address_label_field}    || 'label';

	my $adb = dbref($o->{address_table} || 'address')
		or do {
			my $atab =  $o->{address_table} || 'address';
			::logError("unable to find address table", $atab);
			return;
		};

	my $tname = $adb->name();
	my $tcode = $adb->config('KEY');

	my $uv = $adb->quote($self->{USERNAME}, $uf);
	my $nv = $adb->quote($nickname, $nf);

	my @where;
	push @where, "$uf = $uv";
	push @where, "$nf = $nv";
	my $pf = $o->{address_profile_field} || 'profile';
	if($adb->column_exists($pf)) {
		my $pv = $adb->quote($o->{profile} || 'default', $pf);
		push @where, "$pf = $pv";
	}
	else {
		undef $pf;
	}

	my $qual = join " AND ", @where;

	my $cq = "select $tcode from $tname where $qual";
#::logDebug("Running $cq");
	my $code;
	my $ary;
	$ary = $adb->query($cq) and $ary->[0] and $code = $ary->[0][0];

	my $rec;
	for(keys %$map) {
		$rec->{$map->{$_}} = $vref->{$_};
	}
	$rec->{$lf} = $vref->{$nick_lab_field} if $vref->{$nick_lab_field};

	$rec->{$uf} ||= $self->{USERNAME};
	$rec->{$nf} ||= $nickname;

	if($pf) {
		$rec->{$pf} = $o->{profile} || 'default';
	}
#::logDebug("Ready to save " . ::uneval($rec));
	$adb->set_slice($code, $rec);
}

sub get_names {
	my $self = shift;
	my $nick = shift;
	my $o = $self->{OPTIONS} || {};

	my $adb = dbref($o->{address_table} || 'address');
	my $tname = $adb->name();
	my $nf = $o->{address_nickname_field} || 'nickname';
	my $lf = $o->{address_label_field} || 'label';
	my $uf = $o->{address_username_field} || 'username';
	my $uv = $adb->quote($self->{USERNAME}, $uf);

	my $fields = $nf;

	if($o->{acclist} and $adb->column_exists($lf)) {
		$fields .= ",$lf";
	}
	my @where;
	push @where, "$uf = $uv";
	my $pf = $o->{address_profile_field} || 'profile';
	if($adb->column_exists($pf)) {
		my $pv = $adb->quote($o->{profile} || 'default', $pf);
		push @where, "$pf = $pv";
	}
	else {
		undef $pf;
	}

	my $qual = join " AND ", @where;
	my $q = "select $fields from $tname where $qual";

	my $ary = $adb->query($q);
	my @names;
	my @labels;
	if($ary and @$ary) {
		for(@$ary) {
			push @names, $_->[0];
			push @labels, $_->[1];
		}
	}

	if($o->{acclist}) {
		$o->{joiner} ||= ',';
		for(my $i = 0; $i < @names; $i++) {
			next unless $labels[$i];
			$labels[$i] =~ s/,/&#44;/g;
			$names[$i] = "$names[$i]=$names[$i] -- $labels[$i]";
		}
	}

	$o->{joiner} ||= "\n";
	return join $o->{joiner}, @names;
}

sub delete_address {
	my $self = shift;
	my $o = $self->{OPTIONS} || {};

	my $nick = $o->{nickname}
		or return;

	my $adb = dbref($o->{address_table} || 'address');
	my $tname = $adb->name();
	my $nf = $o->{address_nickname_field} || 'nickname';
	my $uf = $o->{address_username_field} || 'username';
	my $uv = $adb->quote($self->{USERNAME}, $uf);
	my $nv = $adb->quote($nick, $nf);
	my $q = "delete from $tname where $uf = $uv and $nf = $nv";
	return $adb->query($q);
}

*delete_billing = \&delete_address;
*delete_shipping = \&delete_address;
*get_billing_names = \&get_names;
*get_shipping_names = \&get_names;

1;
