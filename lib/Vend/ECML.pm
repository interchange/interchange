#!/usr/bin/perl

=head1 NAME

Vend::ECML -- map MiniVend forms/userdb to ECML checkout

=head1 VERSION

Version 0.03, official release.

=head1 SYNOPSIS

Place form boxes on page:

	 [ecml name]
	 [ecml address]

Magic database entry from country database:

	[ecml country]

Map values back to MiniVend variables for saving in UserDB:

	<INPUT TYPE=hidden NAME=mv_click CHECKED VALUE="ECML_map">
	[set ECML_map]
	[ecml function=mapback]
	[/set]

=head1 DESCRIPTION

This package implements the ECML standard for the MiniVend demo.
ECML stands for "Electronic Commerce Modeling Language", but at this 
writing it is a simple standard for naming variables so that "electronic
wallets" can pre-fill-in your checkout form based on users past purchase
from other companies.

It translates into ECML from the following MiniVend variables:

  Ecom_BillTo_Online_Email            b_email
  Ecom_BillTo_Postal_City             b_city
  Ecom_BillTo_Postal_CountryCode      b_country
  Ecom_BillTo_Postal_Name_First       b_fname
  Ecom_BillTo_Postal_Name_Last        b_lname
  Ecom_BillTo_Postal_Name_Middle      b_mname
  Ecom_BillTo_Postal_Name_Prefix      b_title
  Ecom_BillTo_Postal_Name_Suffix      b_name_suffix
  Ecom_BillTo_Postal_PostalCode       b_zip
  Ecom_BillTo_Postal_StateProv        b_state
  Ecom_BillTo_Postal_Street_Line1     b_address1
  Ecom_BillTo_Postal_Street_Line2     b_address2
  Ecom_BillTo_Postal_Street_Line3     b_address3
  Ecom_BillTo_Telecom_Phone_Number    b_phone_day
  Ecom_ConsumerOrderID                mv_order_number
  Ecom_Payment_Card_ExpDate_Day       mv_credit_card_exp_day
  Ecom_Payment_Card_ExpDate_Month     mv_credit_card_exp_month
  Ecom_Payment_Card_ExpDate_Year      mv_credit_card_exp_year
  Ecom_Payment_Card_Name              c_name
  Ecom_Payment_Card_Number            mv_credit_card_number
  Ecom_Payment_Card_Protocol          payment_protocols_available
  Ecom_Payment_Card_Type              mv_credit_card_type
  Ecom_Payment_Card_Verification      mv_credit_card_verify
  Ecom_ReceiptTo_Online_Email         r_email
  Ecom_ReceiptTo_Postal_City          r_city
  Ecom_ReceiptTo_Postal_CountryCode   r_country
  Ecom_ReceiptTo_Postal_Name_First    r_fname
  Ecom_ReceiptTo_Postal_Name_Last     r_lname
  Ecom_ReceiptTo_Postal_Name_Middle   r_mname
  Ecom_ReceiptTo_Postal_Name_Prefix   r_title
  Ecom_ReceiptTo_Postal_Name_Suffix   r_name_suffix
  Ecom_ReceiptTo_Postal_PostalCode    r_zip
  Ecom_ReceiptTo_Postal_StateProv     r_state
  Ecom_ReceiptTo_Postal_Street_Line1  r_address1
  Ecom_ReceiptTo_Postal_Street_Line2  r_address2
  Ecom_ReceiptTo_Postal_Street_Line3  r_address3
  Ecom_ReceiptTo_Telecom_Phone_Number r_phone
  Ecom_SchemaVersion                  ecml_version
  Ecom_ShipTo_Online_Email            email
  Ecom_ShipTo_Postal_City             city
  Ecom_ShipTo_Postal_CountryCode      country
  Ecom_ShipTo_Postal_Name_Combined    name
  Ecom_ShipTo_Postal_Name_First       fname
  Ecom_ShipTo_Postal_Name_Last        lname
  Ecom_ShipTo_Postal_Name_Middle      mname
  Ecom_ShipTo_Postal_Name_Prefix      title
  Ecom_ShipTo_Postal_Name_Suffix      name_suffix
  Ecom_ShipTo_Postal_PostalCode       zip
  Ecom_ShipTo_Postal_StateProv        state
  Ecom_ShipTo_Postal_Street_Line1     address1
  Ecom_ShipTo_Postal_Street_Line2     address2
  Ecom_ShipTo_Postal_Street_Line3     address3
  Ecom_ShipTo_Telecom_Phone_Number    phone
  Ecom_TransactionComplete            end_transaction_flag

Once the form variables are input and sent to MiniVend, the [ecml function=mapback]
tag will cause the input results to be mapped back from the ECML names to the
MiniVend names.

If you only have a C<name> variable in your UserDB, the module will attempt to
split it into first name and last name for ECML purposes and map the results
back. If you have C<fname> and C<lname>, then it will not.

=cut

package Vend::ECML;

use vars qw/$VERSION $ECML/;

use strict;
$VERSION = '0.02';

sub version {
	return $VERSION;
}

INIT: {

local($^W) = 0;

	my $ecml_field_map;

	my $ecml_map_fn;
	$ecml_map_fn = $Global::Variable->{MV_ECML_FIELD_MAP}
				 || "$Global::ConfigDir/ecml.map";

	$ecml_field_map = -s $ecml_map_fn 
					? Vend::Util::readfile($ecml_map_fn)
					: join "", <DATA>;

	my (@fields) = split /\n/, $ecml_field_map;
	my (@names) = split /\t/, shift @fields;
	
	$ECML = {};

	my $ecml_field;
	my $i = -1;
	for(@names) {
		$i++;
		next unless $_ eq 'ecml';
		$ecml_field = $i;
		last;
	}
	if(! defined $ecml_field) {
		die "No 'ecml' field in ECML map file $ecml_map_fn";
	}
	undef $ecml_field_map;
	my @f;
	for(@fields) {
		@f = split /\t/, $_;
		my $ecml = $f[$ecml_field];
		next unless $ecml;
		$ECML->{$ecml} = {} unless $ECML->{$ecml};
		my $ref = $ECML->{$ecml};
		@{$ref}{@names} = (@f);
		next unless $ref->{map_to};
		$ECML->{$ref->{map_to}} = $ref;
	}

}

=head2 [ecml function=name name=common]

Returns the ECML name for the MiniVend common usage.

=cut

sub name {
	my $self = shift;
	return undef if ! $self->{name};
	return $ECML->{$self->{name}}->{ecml};
}

=head2 [ecml name=common function=map_to]

Returns the common name for the ECML field in question.

=cut

sub map_to {
	my $self = shift;
	return undef if ! $self->{name};
	return $ECML->{$self->{name}}->{map_to};
}


=head2 [ecml name=common function=guess]

Guesses to return the common name or ECML name for the field in question.

=cut

sub guess {
	my $self = shift;
	return $self->{name} =~ /^Ecom_/
		? $ECML->{$self->{name}}->{map_to}
		: $ECML->{$self->{name}}->{map_to};
}

sub output_ecml_database {
	my $self = shift;
	my $out = "ecml\tmap_to\tsize\tcomment\twidget\tdb\tattribute\tname\n";
	
	my %seen;
	for (keys %$ECML) {
		next if $seen{$ECML->{$_}}++;
		$out .= join "\t", @{$ECML->{$_}}{qw/ ecml map_to size comment widget db attribute name/};
		$out .= "\n";
		next unless $self->{all_fields};
		$out .= join "\t", @{$ECML->{$_}}{qw/ map_to ecml size comment widget db attribute name/};
		$out .= "\n";
	}
	return $out;
}

sub text {
	my $self = shift;
	my $def = shift;
	my $value = shift || '';
	my $size = $self->{size} || $def->{size} || '40';
	my $extra = defined $self->{extra} ? " $self->{extra}" : '';
	$value =~ s/"/&quot;/g;
	return qq{<INPUT NAME=$self->{fname} VALUE="$value" SIZE=$size$extra>};
}

sub select {

	my $self = shift;
	my $def = shift;
	my $value = shift || '';
	my $run = qq{<SELECT NAME=$self->{fname}};
	$run .= ' MULTIPLE' if Vend::Util::is_yes($self->{multiple});
	$run .= " SIZE=$self->{size}" if defined $self->{size};
	$run .= '>';
	my @opts;
	if($self->{options}) {
		@opts = split /\s*,\s*/, $self->{options};
	}
	if($def->{db}) {
		my $label = $self->{label_field} || 'name';
		my $args = '';
		$args .= <<EOF;
fi=$def->{db}
ra=yes
rf=0,$label
tf=$label
ml=1000
rd==
EOF
		my $optlist = Vend::Interpolate::tag_search($args);
		$optlist =~ s/\s+$//;
		$optlist =~ s/^\s+//;
		push (@opts, split /\n+/, $optlist);
	}
	if($self->{none}) {
		unshift(@opts, "= -- NONE --");
	}
	my $default = $value;
	for (@opts) {
		$run .= '<OPTION';
		my $select = '';
		s/\*$// and $select = 1;
		if ($default) {
			$select = '';
		}
		my ($value,$label) = split /=/, $_, 2;
		if($label) {
			$value =~ s/"/&quot;/;
			$run .= qq| VALUE="$value"|;
		}
		if ($default) {
			my $regex = quotemeta $value;
			$default =~ /(?:\0|^)$regex(?:\0|$)/ and $select = 1;
		}
		$run .= ' SELECTED' if $select;
		$run .= '>';
		if($label) {
			$run .= $label;
		}
		else {
			$run .= $value;
		}
	}
	$run .= '</SELECT>';
}

sub unfix {
	my $def = shift;
	return unless $def->{attribute};
	my $pre = '';
	my $ecml = $def->{ecml};
	if($ecml =~ /^Ecom_ShipTo_/) {
		# do nothing
	}
	elsif($ecml =~ /^Ecom_BillTo_/) {
		$pre = 'b_';
	}
	elsif($ecml =~ /^Ecom_ReceiptTo_/) {
		$pre = 'r_';
	}
	my($var,$split,$index) = split /:/, $def->{attribute};
	my $join = $split;
#::logError("ECML unfix: attribute=$def->{attribute}, join=|$join|, split=$split, index=$index var=$var");
	if ($join eq '<CRLF>') {
		($join, $split) = ("\r", '[\r\n]+');
	}
	$join = '' if $join =~ /^[[\\]/;
	my $pos = $ecml;
	if($pos =~ /(\d+)$/) {
		$pos = $1;
		$pos--;
	}
	elsif ($pos =~ /Name_Last/) {
		$pos = 2;
	}
	elsif ($pos =~ /Name_First/) {
		$pos = 0;
	}
	elsif ($pos =~ /Name_Middle/) {
		$pos = 1;
	}
	else {
		$pos = 0;
	}
	$pre = '' if index($var, $pre) == 0;
#::logError("ECML unfix: join=|$join|, split=$split, index=$index var=$var");
	my @value;
	@value = split /$split/, $::Values->{"$pre$var"};
	$value[$pos] = $CGI::values{$ecml};
	$::Values->{"$pre$var"} = join($join, @value);
	$::Values->{"$pre$var"} =~ s/$join+/$join/g
		if $::Values->{"$pre$var"};
	return $::Values->{"$pre$var"};
}

sub fieldfix {
	my $self = shift;
	my $def = shift;
	my $value;
	return $value if $value;
	return unless $def->{attribute};
	my $pre = '';
	if($self->{ecml} =~ /^Ecom_ShipTo_/) {
		# do nothing
	}
	elsif($self->{ecml} =~ /^Ecom_BillTo_/) {
		$pre = 'b_';
	}
	elsif($self->{ecml} =~ /^Ecom_ReceiptTo_/) {
		$pre = 'r_';
	}
	my($var,$split,$index) = split /:/, $def->{attribute};
	my $join = $split;
#::logError("ECML fieldfix: attribute=$def->{attribute}, join=|$join|, split=$split, index=$index var=$var");
	if ($join eq '<CRLF>') {
		($join, $split) = ('', '[\r\n]+');
	}
	$join = '' if $join =~ /^[[\\]/;
	my (@index) = map {$_ - 1} split /\s*,\s*/, $index;
	$pre = '' if index($var, $pre) == 0;
#::logError("ECML fieldfix: join=|$join|, split=$split, index=$index var=$var");
	$value = join $join, (split /$split/, $::Values->{"$pre$var"})[@index]; 
}

sub widget {
	my ($self) = @_;
	if(! $self->{name}) {
		$self->{ecml_error} = "no name passed for widget";
		return undef;
	}
	my $def = defined $ECML->{$self->{name}}
				? $ECML->{$self->{name}}
				: {};
#::logDebug(Vend::Util::uneval($def));
	my $name = defined $def->{ecml}
				? $def->{ecml}
				: $self->{name};

	my ($value, $size, $fname);

	$fname = $name;
	if($fname =~ /\W/) {
		$fname =~ s/"/&quot;/g;
		$fname = qq{"$fname"};
	}

	$self->{fname} = $fname;

	unless($self->{clear}) {
		$value = $self->{value}	|| $::Values->{$name}
								|| $::Values->{$self->{name}}
								|| '';
		$value = $self->fieldfix($def, $value) if $def->{attribute};
	}
	else {
		$value = '';
	}

	my $widget = $self->{widget} || $def->{widget} || 'text';

#::logDebug ("ECML proposed widget='$widget' " . Vend::Util::uneval($def) );
	$widget = 'text' if ! $self->can($widget);
#::logDebug ("ECML actual widget=$widget\n");

	my $w = $self->$widget($def, $value);
#::logDebug ("ECML widget returns: $w\n");
	return $w;
}

sub mapback {
	my $self = shift;
	my @targets = grep /^Ecom_/, keys %$ECML;
	for (@targets) {
		next unless defined $CGI::values{$_};
		if($ECML->{$_}{attribute}) {
			unfix($ECML->{$_});
			next;
		}
		$CGI::values{$ECML->{$_}{map_to}} = $CGI::values{$_};
	}
	return '';
}

sub new {
	my ($class, $opt) = @_;
	$opt = {} unless $opt;
	return bless $opt, $class;
}

sub ecml {
	my ($name, $function, $opt) = @_;
#::logDebug("ecml name=$name func=$function opt=$opt");
	my $self = new Vend::ECML $opt;
	$self->{name} = $name if $name;
	$function = 'widget' unless $function;
	$self->{function} = $function;
	unless ($self->can($function) ) {
		::logError("unknown ECML function $function");
		$::Scratch->{mv_ecml_error} = logError("unknown ECML function $function");
		undef $::Scratch->{mv_ecml_status};
		return undef unless $opt->{show};
		return $::Scratch->{mv_ecml_error};
	}
#::logDebug(Vend::Util::uneval($self));
	my $status = $self->$function();
	if(! $status) {
		$::Scratch->{mv_ecml_error} = $self->{failure}
									|| $self->{ecml_error}
									|| "$function failed";
		return $::Scratch->{mv_ecml_error} if $self->{show};
		return $status unless $self->{hide};
		return '';
	}
	$::Scratch->{mv_ecml_message} = $self->{success};
	return $self->{success} if $self->{show};
	return '' if $self->{hide};
	return $status;
}

=head1 AUTHOR

Mike Heins

=head1 BUGS

Not really tested in real life yet. 8-)

=cut

1;

__DATA__
ecml	map_to	size	comment	widget	db	attribute	name
Ecom_BillTo_Online_Email	b_email	40	email				
Ecom_BillTo_Postal_City	b_city	22	city				
Ecom_BillTo_Postal_CountryCode	b_country	2	country				
Ecom_BillTo_Postal_Name_First	b_fname	15	first name				
Ecom_BillTo_Postal_Name_Last	b_lname	15	last name				
Ecom_BillTo_Postal_Name_Middle	b_mname	15	middle name				
Ecom_BillTo_Postal_Name_Prefix	b_title	4	title				
Ecom_BillTo_Postal_Name_Suffix	b_name_suffix	4	name suffix				
Ecom_BillTo_Postal_PostalCode	b_zip	14	zip or postal code				
Ecom_BillTo_Postal_StateProv	b_state	2	state or province				
Ecom_BillTo_Postal_Street_Line1	b_address1	20	street1				
Ecom_BillTo_Postal_Street_Line2	b_address2	20	street2				
Ecom_BillTo_Postal_Street_Line3	b_address3	20	street3				
Ecom_BillTo_Telecom_Phone_Number	b_phone_day	14	phone				
Ecom_ConsumerOrderID	mv_order_number	20					
Ecom_Payment_Card_ExpDate_Day	mv_credit_card_exp_day	2					
Ecom_Payment_Card_ExpDate_Month	mv_credit_card_exp_month	2					
Ecom_Payment_Card_ExpDate_Year	mv_credit_card_exp_year	4					
Ecom_Payment_Card_Name	c_name	30	card				
Ecom_Payment_Card_Number	mv_credit_card_number	19					
Ecom_Payment_Card_Protocol	payment_protocols_available	20					
Ecom_Payment_Card_Type	mv_credit_card_type	4					
Ecom_Payment_Card_Verification	mv_credit_card_verify	4					
Ecom_ReceiptTo_Online_Email	r_email	40	email				
Ecom_ReceiptTo_Postal_City	r_city	22	city				
Ecom_ReceiptTo_Postal_CountryCode	r_country	2	country				
Ecom_ReceiptTo_Postal_Name_First	r_fname	15	first name				
Ecom_ReceiptTo_Postal_Name_Last	r_lname	15	last name				
Ecom_ReceiptTo_Postal_Name_Middle	r_mname	15	middle name				
Ecom_ReceiptTo_Postal_Name_Prefix	r_title	4	title				
Ecom_ReceiptTo_Postal_Name_Suffix	r_name_suffix	4	name suffix				
Ecom_ReceiptTo_Postal_PostalCode	r_zip	14	zip or postal code				
Ecom_ReceiptTo_Postal_StateProv	r_state	2	state or province				
Ecom_ReceiptTo_Postal_Street_Line1	r_address1	20	street1				
Ecom_ReceiptTo_Postal_Street_Line2	r_address2	20	street2				
Ecom_ReceiptTo_Postal_Street_Line3	r_address3	20	street3				
Ecom_ReceiptTo_Telecom_Phone_Number	r_phone	10	phone				
Ecom_SchemaVersion	ecml_version	30					
Ecom_ShipTo_Online_Email	email	40	email				
Ecom_ShipTo_Postal_City	city	22	city				
Ecom_ShipTo_Postal_CountryCode	country	2	country	select	country		
Ecom_ShipTo_Postal_Name_Combined	name	40				name: :Ecom_ShipTo_Postal_Name_First,Ecom_ShipTo_Postal_Name_First,	
Ecom_ShipTo_Postal_Name_First	fname	20	first name			name: :1
Ecom_ShipTo_Postal_Name_Last	lname	20	last name			name: :0
Ecom_ShipTo_Postal_Name_Middle	mname	3	middle name				
Ecom_ShipTo_Postal_Name_Prefix	title	4	title				
Ecom_ShipTo_Postal_Name_Suffix	name_suffix	4	name suffix				
Ecom_ShipTo_Postal_PostalCode	zip	14	zip or postal code				
Ecom_ShipTo_Postal_StateProv	state	2	state or province				
Ecom_ShipTo_Postal_Street_Line1	address1	30	street1			address:, :1	
Ecom_ShipTo_Postal_Street_Line2	address2	30	street2			address:, :2	
Ecom_ShipTo_Postal_Street_Line3	address3	30	street3			address:, :3	
Ecom_ShipTo_Telecom_Phone_Number	phone	14	phone				
Ecom_TransactionComplete	end_transaction_flag	1					
