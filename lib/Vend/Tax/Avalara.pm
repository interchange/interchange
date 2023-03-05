# Vend::Tax::Avalara - 3rd-party subclass module for Avalara
#
# Copyright (C) 2002-2023 Interchange Development Group
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

package Vend::Tax::Avalara;

use strict;
use warnings;

use JSON qw//;
use LWP::UserAgent qw//;
use URI qw//;
use Digest::MD5 qw//;
use MIME::Base64 qw/encode_base64/;

use Vend::Interpolate qw//;

BEGIN {
    local $@;
    eval {
        require Text::CSV_XS;
        import Text::CSV_XS qw/csv/;
    };

    if ($@) {
        die "Text::CSV_XS is required for Vend::Tax::Avalara. Please install and try again.\n";
    }
}

use base qw/Vend::Tax/;

=head1 NAME

Vend::Tax::Avalara

=head1 DESCRIPTION

Module provides API interface to Avalara for the calculation, estimation, and
reporting of sales taxes within the United States.

This module provides the service component required by I<Vend::Tax>. See POD
in that module for more information.

To enable this module, place this directive in C<interchange.cfg>:

    Require module Vend::Tax::Avalara

This I<must> be in interchange.cfg or a file included from it.

=cut

use constant {
    # Each service must identify itself
    SERVICE => (__PACKAGE__ =~ /^Vend::Tax::(.*)/)[0],

    LIVEHOST => 'rest.avatax.com',
    DEVHOST => 'sandbox-rest.avatax.com',
    TRANSACTION_PATH => '/api/v2/transactions/create',
    SUMMARY_PATH => '/api/v2/taxratesbyzipcode/download/%s',
    NEXUS_PATH => '/api/v2/nexus',
    AVS_PATH => '/api/v2/addresses/resolve',
};

::logGlobal('%s tax module initialized - use service "%s"', __PACKAGE__, __PACKAGE__->SERVICE);

=head1 ATTRIBUTES

This module extends I<Vend::Tax>. Please see documentation in that module for
additional attributes available and used herein.

In addition to those defined in I<Vend::Tax>, the following attributes extend
specifically for use with Avalara. Each of the following can be set by adding
as parameters to any call to supported usertags. For convenience, most are set
to have a sensible default based on the strap demo.

=over 4

=item B<user> - default: __AVALARA_USER__

User for Avalara basic auth account for API authentication.

=item B<password> - default: __AVALARA_PASSWORD__

Password for Avalara basic auth account for API authentication.

=item B<customer> - default: $Session->{username} || 'NONE'

Maps to Avalara required field customerCode.

=item B<transaction_date> - default: Today's date: YYYY-MM-DD

Maps to Avalara required field date. Normally default should be fine, but if
you need to specify the transaction for an alternative date, this can be
overridden.

=item B<product_tax_code_field> - default: "product_tax_code"

Field name in sku's source table for Avalara's product tax code for the
product in question. Since the lookup uses the C<item_field()> routine, the
table should be found in I<ProductFiles> directive. Field is
products.product_tax_code in strap demo schema.

List of Avalara supported product tax codes:

https://taxcode.avatax.avalara.com/

=item B<shipping_tax_code> - default: "FR"

Value to apply to taxCode field for the shipping line item.

=item B<handling_tax_code> - default: "OH010000"

Value to apply to taxCode field for the handling line item, if B<handling> >=
0.01

=item B<load_line_items> - default: undef

Boolean to set to true when sending transaction data to Avalara if you want
the order data to use derived directly from the orderline table based on
B<order_number>. See strap Job "send_tax_transaction" for an example usage.

=item B<sent_field> - default: "tax_sent"

Name of field in transactions table to update to indicate the result of the
attempt to report the transaction. On error (defined as an HTTP response code
in the 400 range), this field will be set to "-1" to indicate that manual
intervention is required to assess the order's situation.

=item B<sent_success_value> - default: 1

Value to update B<sent_field> to on a successful transaction submission.

=item B<table> - default: __TAXAVERAGES_TABLE__ || "tax_averages"

Overrides Vend::Tax::table by adding secondary fallback to "tax_averages".

=item B<nexus_address> - default: __NEXUS_ADDRESS__

Location address used to determine jurisdiction of merchant.

=item B<nexus_city> - default: __NEXUS_CITY__

Location city used to determine jurisdiction of merchant.

=item B<nexus_state> - default: __NEXUS_STATE__

Location state used to determine jurisdiction of merchant.

=item B<nexus_zip> - default: __NEXUS_ZIP__

Location zip used to determine jurisdiction of merchant.

=item B<nexus_country> - default: __NEXUS_COUNTRY__

Location country used to determine jurisdiction of merchant.

=item B<no_nexus_required> - default: undef

When Perly true, allows the post_transaction() routine called from
[send-tax-transaction] to create the tax transaction regardless of nexus for
the order's shipping jurisdiction. Allows for accounting with all orders in
Avalara instead of only those orders that happen to collect tax.

=item B<invoice_number> = default: undef

Invoice number applied to tax transaction created in [send-tax-transaction].
Typically would be set to the Interchange order number (and is set accordingly
in send_tax_transaction job).

=back

=cut

### accessors
{
    my @acc = (
        json => q{JSON->new->pretty->allow_nonref->canonical},
        ua => q{LWP::UserAgent->new},
        url => q{undef},

        user => q{$::Variable->{AVALARA_USER}},
        password => q{$::Variable->{AVALARA_PASSWORD}},
        _basic => q{encode_base64(sprintf ('%s:%s', $self->user, $self->password))},

        product_tax_code_field => q{'product_tax_code'},
        shipping_tax_code => q{'FR'},
        handling_tax_code => q{'OH010000'},

        customer => q{$::Session->{username} || 'NONE'},
        transaction_date => q{$self->tag->time({},'%F')},

        nexus => q{{}},
        load_line_items => q{undef},
        sent_field => q{'tax_sent'},
        sent_success_value => q{1},
        invoice_number => q{undef},
        no_nexus_required => q{undef},

        table => q{$::Variable->{TAXAVERAGES_TABLE} || 'tax_averages'},

        nexus_address => q{$::Variable->{NEXUS_ADDRESS}},
        nexus_city => q{$::Variable->{NEXUS_CITY}},
        nexus_state => q{$::Variable->{NEXUS_STATE}},
        nexus_zip => q{$::Variable->{NEXUS_ZIP}},
        nexus_country => q{$::Variable->{NEXUS_COUNTRY}},

        http_response_stack => q{[]},
    );

    sub summary_rates {
        my $self = shift;
        my $p = \$self->{_summary_rates};
        if (@_) {
            my $v = shift;
            die "summary_rates value '$v' not an ARRAY"
                unless $self->_reftyped($v) eq 'ARRAY';
            $$p = $v;
        }
        $$p ||= [];
        return @{$$p} if wantarray;
        return $$p;
    }

    # Overriding zip since Avalara will only work properly with 5-digit zips
    sub zip {
        my $self = shift;
        local $_ = $self->SUPER::zip(@_);

        return $_ if !defined
            or $self->country ne 'US'
            or /^\d{5}$/;

        my $v = $_;
        s/\D+//g;
        $_ = substr ($_, 0, 5);
        /^\d{5}$/ or return $v;
        return $self->{_zip} = $_;
    }

    sub init {
        my $self = shift;

        # Allow init() calls to run top-down
        $self->SUPER::init(@_);

        if (my %p = @_) {
            for (my $i = 0; $i < @acc; $i += 2) {
                my $k = $acc[$i];
                next unless exists $p{$k};
                $self->$k($p{$k});
            }
        }

        $self->debug('Calling ua->ssl_opts to disable host verification');
        $self->ua->ssl_opts( verify_hostname => 0 , SSL_verify_mode => 0x00);
    }

    __PACKAGE__->has(@acc);
}

=head1 METHODS

=head2 [tax-lookup] related methods

=over 4

=item C<tax>

Top-level routine used by Vend::Tax::tag_tax_lookup for returning the tax
liability based on a live lookup. Required routine to override
C<Vend::Tax::tax()>.

=cut

sub tax {
    my $self = shift;

    # Avalara requires zip, state, and country. country is always present.
    unless ($self->zip && $self->state) {
        $self->debug('tax() returning 0 with no zip and state');
        return 0;
    }

    unless (my $nexus = $self->has_nexus) {
        if (defined $nexus) {
            $self->debug('tax() returning 0 with no nexus in "%s", "%s"', $self->zip, $self->state);
            return 0;
        }
        return $self->invalid_address;
    }

    if (defined (my $cached_tax = $self->cache)) {
        return $cached_tax->{tax};
    }

    my $tax = $self->lookup;

    return $self->cache($tax)->{tax}
        if defined $tax;

    # If Avalara is down, make sure we don't improperly log line-item
    # tax values corresponding with an estimated tax
    delete $_->{salestax} for $self->cart;

    # Setting estimate in cache so we don't run up hits on an invalid
    # address
    return $self->cache({
        tax => $self->estimated_tax,
        taxable_amount => $self->taxable_amount,
    })->{tax};
}

=item C<lookup>

Routine to perform assembly of request and process of response for a live
lookup to the Avalara API.

=cut

sub lookup {
    my $self = shift;

    # Skip on an empty cart
    return { tax => 0, taxable_amount => 0, }
        unless $self->tag->nitems > 0;

    my %args = $self->_basic_args;
    ($args{lines}, $args{discount}) = $self->_assemble_line_items;

    delete $args{discount}
        unless grep { $_->{discounted} } @{$args{lines}};

    $self->debug('lookup() args: %s', ::uneval(\%args));

    $self->set_url(
        TRANSACTION_PATH,
        '$include' => 'Lines',
    );

    my $r =
        $self->ua->post(
            $self->url,
            'Authorization' => $self->authorization,
            'Cache-Control' => 'no-cache',
            'Content-Type' => 'application/json',
            'Content' => $self->json->encode(\%args),
        )
    ;

    $self->debug("lookup() full request\n%s", $r->request->as_string);
    $self->debug("lookup() full response\n%s", $r->as_string);

    my $msg = $self->_handle_json_response($r);

    $self->debug('lookup() parsed response document: %s', ::uneval($msg));

    if ($r->is_success) {
        my $lines = $msg->{lines} || [];
        for (grep { not $_->{lineNumber} < 0 } @$lines) {
            my $item = $self->cart->[$_->{lineNumber}];
            $item->{salestax} = sprintf ('%0.2f', $_->{tax} || 0);
        }
        my $rv = { tax => $msg->{totalTax}, taxable_amount => $msg->{totalTaxable}, code => $msg->{code}, };
        $self->debug("lookup() return on success\n%s", ::uneval($rv));
        return $rv;
    }

    ::logError(
        "Avalara lookup failed: status %s\nfull request:\n%s\n\nfull response:\n%s",
        $r->status_line,
        $r->request->as_string,
        $r->as_string,
    );

    return undef;
}

=item C<estimated_tax_record>

Override routine to pull the right record for Vend::Tax->estimated_tax to use
for calculating tax. Avalara keys off of zip primarily, but US zips can also
span states, making it necessary to key off of (zip, state) combination for
nexus.

=cut

sub estimated_tax_record {
    my $self = shift;
    $self->debug('Using %s::estimated_tax_record method to find tax row', __PACKAGE__);
    
    unless ($self->country eq 'US') {
        $self->debug('estimated_tax_record(): no tax collected for orders to country %s', $self->country);
        return;
    }
    elsif (!($self->zip && $self->state)) {
        ::logError('estimated_tax_record(): missing one or both required fields zip and state.');
        return;
    }

    my ($rv, $row);
    {   
        local $@;
        eval {
            ($rv, $row) = $self->has_nexus;
            $self->invalid_address unless defined $rv;
        };
        if (my $err = $@) {
            ::logError("estimated_tax_record(): has_nexus() lookup failed: $err");
        }
    }
 
    return $row;
}

=item C<_assemble_line_items>

Take an Interchange cart and convert to the line-item format required by
Avalara.

=cut

sub _assemble_line_items {
    my $self = shift;

    my $i = -1;
    my $sum_of_discount_subtotals = 0;
    my $entire_order_discount = 0;

    my @items;

    # Build basic Avalara line items
    for ($self->cart) {
        my $full_subtotal = Vend::Interpolate::item_subtotal($_);
        my $discount_subtotal = Vend::Interpolate::discount_subtotal($_);

        my $discount = $full_subtotal - $discount_subtotal;
        $discount = 0 if abs ($discount) < 0.01;

        my $item = {
            number => sprintf ('%s', ++$i),
            quantity => $_->{quantity} + 0,
            amount => sprintf ('%0.2f', $discount_subtotal) + 0,
            itemCode => $_->{code},
            _discount => $discount,
        };

        if ($discount) {
            $item->{ref1} = sprintf (
                "$_->{code} is discounted %s - original subtotal: %s",
                $self->tag->currency({}, $discount),
                $self->tag->currency({}, $full_subtotal),
            );
        }

        if (my $v = $self->_find_product_tax_code($_)) {
            $item->{taxCode} = $v;
        }
        elsif ($self->_boolean_nontaxable($_)) {
            # Necessary fallback, but strongly discouraged.
            $item->{taxCode} = 'NT';
        }

        $sum_of_discount_subtotals += $discount_subtotal;

        push (@items, $item);
    }

    # Check for entire-order discounts and apply globally
    my $all_discounts_subtotal = $self->tag->subtotal({ noformat => 1, });
    if (abs($sum_of_discount_subtotals - $all_discounts_subtotal) > 0.01) {
        $entire_order_discount = $sum_of_discount_subtotals - $all_discounts_subtotal;
        $_->{discounted} = \1 for @items;
    }

    for (@items) {
        my $item = $self->cart->[$_->{number}];

        delete $item->{product_tax_code};

        $item->{product_tax_code} = $_->{taxCode}
            if $_->{taxCode};

        $item->{tax_line_discount} = sprintf ('%0.2f', delete $_->{_discount});
    }

    # Include shipping and handling line items
    push @items, $self->shipping_handling_items;

    return (\@items, sprintf ('%0.2f', $entire_order_discount) + 0);
}

=back

=head2 [load-tax-averages] related methods

=over 4

=item C<load_tax_averages>

Top-level routine used by Vend::Tax::tag_load_tax_averages. Manages the
provider-specific details for retrieving estimated taxes per jurisdiction,
determining nexus, and writing that data to the database. Required routine to
override C<Vend::Tax::load_tax_averages()>.

=cut

sub load_tax_averages {
    my $self = shift;

    eval {
        $self->get_summary_rates;
        $self->get_nexus;
        $self->update_tax_table;
    };

    if (my $err = $@) {
        ::logError("Avalara load_tax_averages failed:\n$err");
    }

    return undef;
}

=item C<get_summary_rates>

Routine to request, process, and stash rate data as defined for
'/api/v2/taxratesbyzipcode/download/{date}'. See Avalara documentation for
details.

=cut

sub get_summary_rates {
    my $self = shift;

    # Clean it out so empty on error
    $self->summary_rates([]);

    # Get previous day's rates to have better chance they're already published
    $self->set_url(sprintf (SUMMARY_PATH, $self->tag->time({ adjust => '-1 day', }, '%F')));

    my $r =
        $self->ua->get(
            $self->url,
            'Authorization' => $self->authorization,
            'Cache-Control' => 'no-cache',
        )
    ;

    $self->debug("get_summary_rates() full request\n%s", $r->request->as_string);
    $self->debug("get_summary_rates() full response\n%s", $r->as_string);

    my $msg = $self->_handle_json_response($r);
    $self->debug('get_summary_rates() parsed response document: %s', ::uneval($msg));

    if ($r->is_success && $msg->{no_json}) {
        # Assume document returned CSV data
        my $doc = csv(in => \$msg->{content}, headers => 'auto',) || [];
        return $self->summary_rates($doc);
    }

    die sprintf (
        "get_summary_rates() failed: status %s\nfull request:\n%s\n\nfull response:\n%s",
        $r->status_line,
        $r->request->as_string,
        $r->as_string,
    );
}

=item C<get_nexus>

Routine to request, process, and stash nexus for merchant as defined for
'/api/v2/nexus'. See Avalara documentation for details.

=cut

sub get_nexus {
    my $self = shift;

    # Clean it out so empty on error
    my %nexus;
    $self->nexus(\%nexus);

    $self->set_url(
        NEXUS_PATH,
        '$filter',
        q{jurisdictionTypeId eq 'State' and country eq 'US'},
    );

    my $r =
        $self->ua->get(
            $self->url,
            'Authorization' => $self->authorization,
            'Cache-Control' => 'no-cache',
        )
    ;

    $self->debug("get_nexus() full request\n%s", $r->request->as_string);
    $self->debug("get_nexus() full response\n%s", $r->as_string);

    my $msg = $self->_handle_json_response($r);

    $self->debug('get_nexus() parsed response document: %s', ::uneval($msg));

    if ($r->is_success) {
        for (@{ $msg->{value} || []}) {
            next unless $_->{nexusTypeId} =~ /Sales.*Tax/;
            my $hsh = $nexus{ $_->{country} } ||= {};
            $hsh->{ $_->{region} || '' } = 1;
        }
        $self->debug('final value of $self->nexus: %s', ::uneval($self->nexus));
        return;
    }

    die sprintf (
        "get_nexus() failed: status %s\nfull request:\n%s\n\nfull response:\n%s",
        $r->status_line,
        $r->request->as_string,
        $r->as_string,
    );
}

=item C<update_tax_table>

Routine to synthesize data collected by C<get_summary_rates()> and
C<get_nexus()> and use to bring B<table> up to date with current rate averages
per jurisdiction.

=cut

sub update_tax_table {
    my $self = shift;
    my $q_table = $self->dbh->quote_identifier($self->table);

    my $sql = qq{
        INSERT INTO $q_table (
            rate_percent,
            has_nexus,
            tax_shipping,
            state,
            country,
            zip
        )
        VALUES (
            ?,
            ?,
            ?,
            ?,
            ?,
            ?
        )
    };
    my $ins = $self->dbh->prepare($sql);

    $sql = qq{
        UPDATE $q_table
        SET rate_percent = ?,
            has_nexus = ?,
            tax_shipping = ?
        WHERE state = ?
            AND country = ?
            AND zip = ?
    };
    my $upd = $self->dbh->prepare($sql);

    $sql = qq{
        SELECT ?, ?, ?
        FROM $q_table
        WHERE state = ?
            AND country = ?
            AND zip = ?
    };
    my $read = $self->dbh->prepare($sql);

    for ($self->summary_rates) {
        $self->debug('working on record %s', ::uneval($_));
        my $uc_state = "\U$_->{STATE_ABBREV}";
        my $has_nexus = $self->nexus->{US}->{$uc_state} || '0';
        my $tax_shipping = $_->{TAX_SHIPPING_ALONE} eq 'Y' ? '1' : '0';
        my @args = (
            $_->{TOTAL_SALES_TAX} * 100, # rate as a percent
            $has_nexus,                  # '1' when true
            $tax_shipping,               # '1' when true
            $uc_state,                   # state
            'US',                        # Only supports US
            $_->{ZIP_CODE},              # 5-digit zip
        );

        $self->debug('%s update arg list: %s', $self->table, ::uneval(\@args));

        $read->execute(@args);
        my $write = $read->fetch ? $upd : $ins;
        $read->finish;
        $write->execute(@args);
    }

    return;
}

=item C<has_nexus>

Utility routine to return boolean flag of whether merchant has nexus for tax
liability in (B<state>, B<zip>). If there is no nexus, then live lookup
can be skipped altogether.

=cut

sub has_nexus {
    my $self = shift;

    # Avalara only valid in US
    return 0 unless $self->country eq 'US';

    return unless $self->state && $self->zip;

    my $sql = q{
        SELECT *
        FROM %s
        WHERE state = ?
            AND zip = ?
            AND country = 'US'
    };
    $sql = sprintf ($sql, $self->dbh->quote_identifier($self->table));

    my $sth = $self->dbh->prepare($sql);
    $sth->execute($self->state, $self->zip);

    my $row = $sth->fetchrow_hashref('NAME_lc');
    $sth->finish;

    my $rv = $row && ($row->{has_nexus} ? 1 : 0);

    return $rv unless wantarray;
    return ($rv, $row);
}

=back

=head2 [send-tax-transaction] related methods

=over 4

=item C<send_tax_transaction>

Top-level routine used by Vend::Tax::tag_send_tax_transaction. Manages the
provider-specific details for reporting each order for merchant tax liability.
Required routine to override C<Vend::Tax::send_tax_transaction()>.

=cut

sub send_tax_transaction {
    my $self = shift;

    eval {
        $self->post_transaction;
        $self->mark_order_as_sent;
    };

    if (my $err = $@) {
        ::logError("Avalara send_tax_transaction failed:\n$err");
    }

    return undef;
}

=item C<post_transaction>

Assembles tax-transaction data for a given order. Address and order data must
be supplied as parameters in the call to [send-tax-transaction]:

 * country (defaults to 'US')
 * zip
 * state
 * city
 * address1
 * customer (probably transactions.username - blank defaults to 'NONE')
 * order_number
 * order_date (fmt: YYYY-MM-DD)
 * shipping
 * handling
 * salestax
 * subtotal

Line item data can be provided directly as an array of hashes to the
B<orderline> attribute, but it is strongly recommended to set the
B<load_line_items> flag and let the code pull and massage the line-item data
accordingly.

Routine then generates an OrderInvoice transaction with Avalara as defined for
'/api/v2/transactions/create'. See Avalara documentation for details.

If HTTP response code is in the 400 range, routine will set the value of
B<sent_field> in transactions explicitly to -1. Any orders containing -1 in
that field should be examined manually for getting that information reported
to Avalara.

See strap Job "send_tax_transaction" for an example call to
[send-tax-transaction].

=cut

sub post_transaction {
    my $self = shift;

    $self->order_number
        or die "order_number() required";

    unless ($self->no_nexus_required || $self->has_nexus) {
        $self->debug(
            'post_transaction() - skipping order %s from %s %s, %s with no nexus',
            $self->order_number,
            $self->state,
            $self->zip,
            $self->country,
        );
        return;
    }

    $self->subtotal > 0
        or die "subtotal() required";

    my %args = $self->_basic_args;
    $args{code} = $self->invoice_number || $self->order_number;

    $args{type} = 'SalesInvoice';
    $args{date} = $self->order_date;
    $args{commit} = \1;

    $self->get_orderline if $self->load_line_items;

    # Calculating if an ENTIRE_ORDER discount was used.
    my $sum_subtotal = 0;
    $sum_subtotal += $_->{subtotal} for ($self->orderline);

    if ((my $disc = $sum_subtotal - $self->subtotal) >= 0.01) {
        $args{discount} = $disc;
    }

    my @items;
    for my $row ($self->orderline) {
        my %item = (
            number => $row->{mv_ip},
            quantity => $row->{quantity} + 0,
            itemCode => $row->{sku},
            amount => sprintf ('%0.2f', $row->{subtotal}),
        );

        $item{taxCode} = $row->{product_tax_code}
            if $row->{product_tax_code};

        $item{ref1} = sprintf (
            "$row->{sku} is discounted %s - original subtotal: %s",
            $self->tag->currency({}, $row->{tax_line_discount}),
            $self->tag->currency({}, $row->{subtotal} + $row->{tax_line_discount}),
        )
            if $row->{tax_line_discount} >= 0.01;

        $item{discounted} = \1
            if $args{discount};

        push @items, \%item;
    }

    # Include shipping and handling line items
    push @items, $self->shipping_handling_items;

    $args{lines} = \@items
        if @items;

    $self->debug('post_transaction() args: %s', ::uneval(\%args));

    $self->set_url(TRANSACTION_PATH);

    my $r =
        $self->ua->post(
            $self->url,
            'Authorization' => $self->authorization,
            'Cache-Control' => 'no-cache',
            'Content-Type' => 'application/json',
            'Content' => $self->json->encode(\%args),
        )
    ;

    $self->debug("post_transaction() full request\n%s", $r->request->as_string);
    $self->debug("post_transaction() full response\n%s", $r->as_string);

    my $msg = $self->_handle_json_response($r);

    $self->debug('post_transaction() parsed response document: %s', ::uneval($msg));

    if ($r->is_success) {
        if (abs ($msg->{totalTax} - $self->salestax) >= 0.01) {
            ::logError(
                'Sales invoice generated for order %s calculated different tax than amount collected at order time. Invoice tax: %s; Collected tax: %s',
                $self->order_number,
                $self->tag->currency({}, $msg->{totalTax}),
                $self->tag->currency({}, $self->salestax),
            );
        }
        return;
    }

    if ($r->code =~ /^4/) {
        $self->sent_success_value('-1');
        $self->mark_order_as_sent;
    }

    die sprintf (
        "Avalara post_transaction failed: status %s\nfull request:\n%s\n\nfull response:\n%s",
        $r->status_line,
        $r->request->as_string,
        $r->as_string,
    );
}

=item C<mark_order_as_sent>

Mark B<sent_field> in transactions to current value of B<sent_success_value>.
For the error condition described in C<post_transaction()>, this value will be
forced to -1.

=cut

sub mark_order_as_sent {
    my $self = shift;

    return unless $self->sent_field && defined ($self->sent_success_value);

    my $sql = q{
        UPDATE transactions
        SET %s = ?
        WHERE code = ?
    };

    my $sth = $self->dbh->prepare(sprintf ($sql, $self->dbh->quote_identifier($self->sent_field)));

    $sth->execute(
        $self->sent_success_value,
        $self->order_number,
    );

    if ($sth->rows == 0) {
        ::logError(
            "WARNING - Attempt to set transactions.%s to '%s' after posting tax transaction failed. Database reports no row updated for order %s.",
            $self->sent_field,
            $self->sent_success_value,
            $self->order_number,
        );
    }

    return;
}

=item C<get_orderline>

Routine invoked when the B<load_line_items> flag is true. Loads all line items
for B<order_number> and makes modifications for it to match the structure of
an Interchange cart to align with the line item data sent to Avalara.
Specifically, this means taking the standard form of the orderline.code (e.g.,
999999-1) and subtracting 1 from the sequence value to map to the original
value of "mv_ip" in the cart (e.g., 0).

=cut

sub get_orderline {
    my $self = shift;

    die "Request to load line items requires order_number()"
        unless $self->order_number;

    my $sql = q{
        SELECT
            code,
            quantity,
            sku,
            subtotal,
            tax_line_discount,
            product_tax_code
        FROM orderline
        WHERE order_number = ?
    };

    my $sth = $self->dbh->prepare($sql);
    $sth->execute($self->order_number);

    my $ol = $sth->fetchall_arrayref({});
    die sprintf ('No orderline data found for order %s', $self->order_number)
        unless @$ol;

    for my $o (@$ol) {
        local $_ = delete $o->{code};
        my ($mv_ip) = /-(\d+)$/;
        $o->{mv_ip} = $mv_ip - 1;
    }

    $self->orderline($ol);

    return;
}

=back

=head2 Address Verification methods

=over 4

=item C<avs_lookup>

Given user address input, call Avalara's address verification service so it
can confirm the address. This method is supported outside of Vend::Tax since
it doesn't directly pertain to the calculation or reporting of taxes. Access
directly via usertag or actionmap.

=cut

sub avs_lookup {
    my $self = shift;

    local $@;
    my $rv = eval {
        my %args = $self->avs_arg_validate;

        $self->debug('avs_lookup() args: %s', ::uneval(\%args));

        $self->set_url(
            AVS_PATH,
            %args
        );

        my $r =
            $self->ua->get(
                $self->url,
                'Authorization' => $self->authorization,
                'Cache-Control' => 'no-cache',
                'Accept' => 'application/json',
            )
        ;

        $self->debug("avs_lookup() full request\n%s", $r->request->as_string);
        $self->debug("avs_lookup() full response\n%s", $r->as_string);

        my $msg = $self->_handle_json_response($r);

        $self->debug('avs_lookup() parsed response document: %s', ::uneval($msg));

        die sprintf (
            "Avalara address verification lookup failed: status %s\nfull request:\n%s\n\nfull response:\n%s",
            $r->status_line,
            $r->request->as_string,
            $r->as_string,
        )
            unless $r->is_success;

        if (my $arr = $msg->{messages}) {
            if (grep { $_->{severity} eq 'Error' } @$arr) {
                die sprintf (
                    'Avalara address verification failed: response messages: %s',
                    ::uneval($arr),
                );
            }
        }
        return $msg->{validatedAddresses}
    };

    if (my $err = $@) {
        ::logError($err);
    }

    return $rv;
}

=item C<avs_arg_validate>

Validate and construct the argument needed for Address Verification lookup.
Dies on validation error.

=cut

sub avs_arg_validate {
    my $self = shift;
    my @errors;

    for (qw/address1 city state zip country/) {
        $self->$_()
            or push @errors, $_;
    }

    @errors
        and die sprintf (
            'Missing required attributes for address verification: %s',
            ::uneval(\@errors),
        )
    ;

    return (
        textCase => 'Mixed',
        country => $self->country,
        region => $self->state,
        postalCode => $self->zip,
        city => $self->city,
        line1 => $self->address,
    );
}

=back

=head2 Utility methods

=over 4

=item C<shipping_handling_items>

Avalara requires shipping and handling (when present) to be accounted for as
line items, rather than stand-alone values. Routine will construct and return
an array of shipping and (optionally) handling line items that can be pushed
onto the items array after all real line items are accounted for.

=cut

sub shipping_handling_items {
    my $self = shift;
    my $i = shift || 0;
    my @i;

    # Can't let positive values of "number" interfere with line-item matchup
    # in the response.
    $i = 0 if $i > 0;

    # Handle Avalara shipping as line item
    push @i, {
        number => sprintf ('%s', --$i),
        quantity => 1,
        amount => sprintf ('%0.2f', $self->shipping) + 0,
        itemCode => 'Shipping',
        taxCode => $self->shipping_tax_code,
    };

    # And Avalara handling as line item, if present
    if ((my $h = $self->handling) >= 0.01) {
        push @i, {
            number => sprintf ('%s', --$i),
            quantity => 1,
            amount => sprintf ('%0.2f', $h) + 0,
            itemCode => 'Handling',
            taxCode => $self->handling_tax_code,
        };
    }

    return @i;
}

=item C<authority>

Set the B<authority> attribute of a URI object to either the sandbox or
production Avalara host, depending on the value of the flag B<development>.

=cut

sub authority {
    my $self = shift;
    $self->development ? DEVHOST : LIVEHOST;
}

=item C<authorization>

Construct the basic-auth value for the Authorization header.

=cut

sub authorization {
    my $self = shift;
    return sprintf ('Basic %s', $self->_basic);
}

=item C<set_url>

Given a path argument, construct a full URI object and set into the B<url>
attribute.

=cut

sub set_url {
    my $self = shift;
    my $path = shift;

    my $url = URI->new($path);
    $url->authority($self->authority);
    $url->scheme('https');

    if (@_) {
        $url->query_form(@_);
    }

    return $self->url($url);
}

=item C<invalid_address>

Handle case where the requested address involved in the lookup (internal or
otherwise) is invalid.

=cut

sub invalid_address {
    my $self = shift;
    my $err = ::errmsg('%s %s is not a valid state/zip combination', $self->state, $self->zip);
    ::logError('Request for tax returning 0 because %s', $err);
    return 0;
}

=item C<_find_product_tax_code>

Given a line item as an argument, find the corresponding Avalara product tax
code. Using field B<product_tax_code_field> to look up first as a hash key in
the line item, if exists, or fall back to C<item_field()> to find the field in
the sku's source table from that same field name.

=cut

sub _find_product_tax_code {
    my $self = shift;
    my $item = shift;
    my $k = $self->product_tax_code_field;

    return $k && ($item->{$k} || Vend::Interpolate::item_field($item, $k)) || '';
}

=item C<_basic_args>

Returns array mapping the standard Avalara attributes for any request to their
corresponding Vend::Tax::Avalara attributes.

=cut

sub _basic_args {
    my $self = shift;

    return (
        date => $self->transaction_date,
        addresses => {
            shipFrom => {
                country => $self->nexus_country,
                postalCode => $self->nexus_zip,
                region => $self->nexus_state,
                city => $self->nexus_city,
                line1 => $self->nexus_address,
            },
            shipTo => {
                country => $self->country,
                postalCode => $self->zip,
                region => $self->state,
                city => $self->city,
                line1 => $self->address1,
            },
        },
        customerCode => $self->customer,
    );
}

sub _handle_json_response {
    my $self = shift;
    my $resp = shift;

    my $msg = $resp->decoded_content;

    if ($resp->header('Content-Type') =~ /\bjson\b/) {
        my $ref = $self->json->decode($msg);
        _thin_booleans(\$ref);
        push (@{ $self->http_response_stack }, { obj => $resp, doc => $ref }, );
        return $ref;
    }

    push (@{ $self->http_response_stack }, { obj => $resp, content => $msg }, );

    return { no_json => 1, content => $msg };
}

# Convert JSON::PP::Booleans to integer 1/0 recursively
sub _thin_booleans {
    my $ref = shift;

    my $type = __PACKAGE__->_refd($$ref)
        or return;

    if ( $type eq 'JSON::PP::Boolean' ) {
        $$ref = $$ref + 0;
        return;
    }

    my $rtype = __PACKAGE__->_reftyped($$ref);
    if ( $rtype eq 'HASH' ) {
        _thin_booleans(\$_) for values %$$ref;
    }
    elsif ( $rtype eq 'ARRAY' ) {
        _thin_booleans(\$_) for @$$ref;
    }

    return;
}

1;

__END__

=back

=head1 AUTHOR

Mark Johnson (mark@endpoint.com), End Point Corp.

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2002-2023 Interchange Development Group

Copyright (C) 1996-2002 Red Hat, Inc.

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program; if not, see: http://www.gnu.org/licenses/

=cut
