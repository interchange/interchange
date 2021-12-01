# Vend::Tax::TaxJar - 3rd-party subclass module for Tax Jar
#
# Copyright (C) 2002-2020 Interchange Development Group
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

package Vend::Tax::TaxJar;

use strict;
use warnings;

use JSON qw//;
use LWP::UserAgent qw//;
use URI qw//;
use Digest::MD5 qw//;

use Vend::Interpolate qw//;

use base qw/Vend::Tax/;

=head1 NAME

Vend::Tax::TaxJar

=head1 DESCRIPTION

Module provides API interface to Tax Jar for the calculation, estimation, and
reporting of sales taxes within the United States.

This module provides the service component required by I<Vend::Tax>. See POD
in that module for more information.

To enable this module, place this directive in C<interchange.cfg>:

    Require module Vend::Tax::TaxJar

This I<must> be in interchange.cfg or a file included from it.

=cut

use constant {
    # Each service must identify itself
    SERVICE => (__PACKAGE__ =~ /^Vend::Tax::(.*)/)[0],

    LIVEHOST => 'api.taxjar.com',
    DEVHOST => 'api.sandbox.taxjar.com',
    LOOKUP_PATH => '/v2/taxes',
    SUMMARY_PATH => '/v2/summary_rates',
    NEXUS_PATH => '/v2/nexus/regions',
    TRANSACTION_PATH => '/v2/transactions/orders',
};

::logGlobal('%s tax module initialized - use service "%s"', __PACKAGE__, __PACKAGE__->SERVICE);

=head1 ATTRIBUTES

This module extends I<Vend::Tax>. Please see documentation in that module for
additional attributes available and used herein.

In addition to those defined in I<Vend::Tax>, the following attributes extend
specifically for use with Tax Jar. Each of the following can be set by adding
as parameters to any call to supported usertags. For convenience, most are set
to have a sensible default based on the strap demo.

=over 4

=item B<token> - default: __TAXTOKEN__

Bearer token supplied by Tax Jar for API authentication.

=item B<cache_timeout> - default: 120 (in minutes)

In order to minimize the overhead and expense of making live API calls, each
call is cached in the user's session according to an assembly of impacting
factors: address, cart composition, and shipping cost. Cache can be disabled
by setting to 0. This is strongly discouraged except for possible need during
troubleshooting.

=item B<product_tax_code_field> - default: "product_tax_code"

Field name in sku's source table for Tax Jar's product tax code for the
product in question. Since the lookup uses the C<item_field()> routine, the
table should be found in I<ProductFiles> directive. Field is
products.product_tax_code in strap demo schema.

List of Tax Jar supported product tax codes:

https://developers.taxjar.com/api/reference/#get-list-tax-categories

=item B<nontaxable_field> - default: $Config->{NonTaxableField}

Field name in sku's source table holding flag for if a product is strictly
non-taxable. This field's use is discouraged and will result in a product tax
code of 99999 sent to Tax Jar. The use of this field will force the item to be
tax exempt, but will preclude the use of AutoFile. See following link for
details:

https://support.taxjar.com/article/362-smartcalcs-product-categories

=item B<load_line_items> - default: undef

Boolean to set to true when sending transaction data to Tax Jar if you want
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

=item B<address> - default: B<address1>

Tax Jar only supports a single address field. Naming reflects that distinction
from standard Interchange procedure of separating out address data into lines
(address1, address2, etc.). To get multiple lines in, set B<address> to a
concatenation of all of them needed.

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

=back

=cut

### accessors
{
    my @acc = (
        json => q{JSON->new->pretty->allow_nonref->canonical},
        ua => q{LWP::UserAgent->new},
        url => q{undef},

        token => q{$::Variable->{TAXTOKEN}},
        cache_timeout => q{120}, # In minutes

        product_tax_code_field => q{'product_tax_code'},
        nontaxable_field => q{$Vend::Cfg->{NonTaxableField}},

        nexus => q{{}},
        load_line_items => q{undef},
        sent_field => q{'tax_sent'},
        sent_success_value => q{1},

        table => q{$::Variable->{TAXAVERAGES_TABLE} || 'tax_averages'},
        address => q{$self->address1},

        nexus_address => q{$::Variable->{NEXUS_ADDRESS}},
        nexus_city => q{$::Variable->{NEXUS_CITY}},
        nexus_state => q{$::Variable->{NEXUS_STATE}},
        nexus_zip => q{$::Variable->{NEXUS_ZIP}},
        nexus_country => q{$::Variable->{NEXUS_COUNTRY}},
    );

    sub init {
        my $self = shift;

        if (my %p = @_) {
            for (my $i = 0; $i < @acc; $i += 2) {
                my $k = $acc[$i];
                next unless exists $p{$k};
                $self->$k($p{$k});
            }
        }

        $self->SUPER::init(@_);
    }

    __PACKAGE__->has(@acc);
}

=head1 METHODS

=head2 [tax-lookup] related methods

=over 4

=cut

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

=item C<tax>

Top-level routine used by Vend::Tax::tag_tax_lookup for returning the tax
liability based on a live lookup. Required routine to override
C<Vend::Tax::tax()>.

=cut

sub tax {
    my $self = shift;

    # Tax Jar requires zip, state, and country. country is always present.
    unless ($self->zip && $self->state) {
        $self->debug('tax() returning 0 with no zip and state');
        return 0;
    }
    elsif (!$self->has_nexus) {
        $self->debug('tax() returning 0 with no nexus in "%s", "%s"', $self->state, $self->country);
        return 0;
    }

    if (defined (my $cached_tax = $self->cache)) {
        return $cached_tax->{tax};
    }

    my $tax = $self->lookup;

    return $self->cache($tax)->{tax}
        if defined $tax;

    # If Tax Jar is down, make sure we don't improperly log line-item
    # tax values from TG corresponding with an estimated tax
    delete $_->{salestax} for $self->cart;

    return $self->estimated_tax;
}

=item C<lookup>

Routine to perform assembly of request and process of response for a live
lookup to the Tax Jar API.

=cut

sub lookup {
    my $self = shift;

    # Skip on an empty cart
    return { tax => 0, taxable_amount => 0, }
        unless $self->tag->nitems > 0;

    my %args = $self->_basic_args;
    $args{line_items} = $self->_assemble_line_items;

    $self->debug('lookup() args: %s', ::uneval(\%args));

    $self->set_url(LOOKUP_PATH);

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
        my $tj_items = $msg->{tax}{breakdown}{line_items} || [];
        for (@$tj_items) {
            my $item = $self->cart->[$_->{id}];
            $item->{salestax} = sprintf ('%0.2f', $_->{tax_collectable} || 0);
        }
        my $rv = { tax => $msg->{tax}{amount_to_collect}, taxable_amount => $msg->{tax}{taxable_amount}, };
        $self->debug("lookup() return on success\n%s", ::uneval($rv));
        return $rv;
    }

    ::logError(
        "Tax Jar lookup failed: status %s\nfull request:\n%s\n\nfull response:\n%s",
        $r->status_line,
        $r->request->as_string,
        $r->as_string,
    );

    return undef;
}

=item C<taxable_amount>

For tax estimates, Interchange cannot know with authority which items are
taxable and which are not. Based on each item's product tax code, and whether
the jurisdiction includes shipping in tax calculations, the taxable amount can
change. If we have a matching cache, indicating the result of the taxable
amount came from Tax Jar explicitly, we'll use that when running tax
estimates. Otherwise, we fall back to the B<taxable_amount> from I<Vend::Tax>.

=cut

sub taxable_amount {
    my $self = shift;

    # We only reliably know the taxable amount from Tax Jar.
    # If we have it in cache, use it.
    if (defined (my $cached_tax = $self->cache)) {
        $self->debug('taxable_amount() found cached value of %s', $cached_tax->{taxable_amount});
        return $cached_tax->{taxable_amount};
    }

    # We are asking for taxable amount but haven't called Tax Jar.
    # Must make do with the Interchange taxable_amount() for now.
    $self->debug('taxable_amount() no cache found. Defaulting to Interchange taxable_amount()');
    return $self->SUPER::taxable_amount;
}

=item C<cache>

Retrieve and optionally set a Tax Jar assessment in cache for taxable amount
and tax liability.

=cut

sub cache {
    my $self = shift;

    my $cache = $self->tax_jar_cache;

    return undef unless @_ || keys (%$cache) > 1;

    $self->debug('current tax_jar_cache: %s', ::uneval($cache));

    my $this_tax;

    if (@_) {
        $this_tax = shift;
        $cache->{ $self->current_tax_hash } = $this_tax;
    }
    else {
        $this_tax = $cache->{ $self->current_tax_hash };
        $self->debug('$this_tax from hash lookup into tax_jar_cache: %s', ::uneval($this_tax));
    }

    return $this_tax;
}

=item C<current_tax_hash>

Assemble address, cart, and shipping data to calculate an MD5 hash used to
uniquely identify a specific cache entry used by C<cache()>.

=cut

sub current_tax_hash {
    my $self = shift;

    my $md5 = Digest::MD5->new;

    $md5->add(
        $self->address,
        $self->city,
        $self->state,
        $self->zip,
        $self->country,
        sprintf ('%0.2f', $self->shipping),
    );

    for my $item ($self->cart) {
        $md5->add(
            sprintf ('%0.2f', $self->item_discount_price($item)),
            $item->{quantity},
            $self->_find_product_tax_code($item),
            $self->_boolean_nontaxable($item),
            $item->{salestax},
        );
    }
    my $hash = $md5->hexdigest;
    $self->debug('MD5: %s', $hash);

    return $hash;
}

=item C<tax_jar_cache>

Manage the cache and associated timeout for Tax Jar lookups in the user's
session.

=cut

sub tax_jar_cache {
    my $self = shift;

    my $tjc = $::Session->{tax_jar_cache} ||= { _created => time, };

    # Concerned about stale data on very long-lived sessions
    %$tjc = ( _created => time, )
        if time > $tjc->{_created} + 60 * $self->cache_timeout;

    return $tjc;
}

=item C<item_discount_price>

Local utility function to simplify the process of getting a line item's
discounted price.

=cut

sub item_discount_price {
    my $self = shift;
    my $item = shift;
    my $qty = $item->{quantity};

    my $full_price = Vend::Interpolate::item_price($item, $qty);
    return Vend::Interpolate::discount_price($item, $full_price, $qty);
}

=item C<_assemble_line_items>

Take an Interchange cart and convert to the line-item format required by Tax
Jar.

=cut

sub _assemble_line_items {
    my $self = shift;

    my $i = -1;
    my $sum_of_discount_subtotals = 0;
    my $sum_of_items = 0;
    my @discount_subtotals;

    my @items;

    # Build basic Tax Jar line items
    for ($self->cart) {
        my $unit_price = Vend::Interpolate::item_price($_, $_->{quantity});
        push (
            @discount_subtotals,
            my $discount_subtotal = Vend::Interpolate::discount_subtotal($_)
        );

        my $discount = Vend::Interpolate::item_subtotal($_) - $discount_subtotal;
        $discount = 0 if abs($discount) < 0.01;

        my $item = {
            id => sprintf ('%s', ++$i),
            quantity => int ($_->{quantity}),
            unit_price => sprintf ('%0.2f', $unit_price),
            discount => sprintf ('%0.2f', $discount),
        };

        if (my $v = $self->_find_product_tax_code($_)) {
            $item->{product_tax_code} = $v;
        }
        elsif ($self->_boolean_nontaxable($_)) {
            # Necessary fallback, but strongly discouraged.
            $item->{product_tax_code} = '99999';
        }

        $sum_of_items += $item->{unit_price} * $item->{quantity} - $item->{discount};
        $sum_of_discount_subtotals += $discount_subtotal;

        push (@items, $item);
    }

    # Check for entire-order discounts and apply propotionally over line-item discounts
    my $all_discounts_subtotal = $self->tag->subtotal({ noformat => 1, });
    if (abs($sum_of_discount_subtotals - $all_discounts_subtotal) > 0.01) {
        my $order_discount = $sum_of_discount_subtotals - $all_discounts_subtotal;
        for (@items) {
            my $delta = $discount_subtotals[ $_->{id} ] / $sum_of_items;
            $_->{discount} += sprintf ('%0.2f', $delta * $order_discount);
        }
    }

    for (@items) {
        my $item = $self->cart->[$_->{id}];

        delete $item->{product_tax_code};

        $item->{product_tax_code} = $_->{product_tax_code}
            if $_->{product_tax_code};

        $item->{tax_line_discount} = $_->{discount};
    }

    return \@items;
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
        ::logError("Tax Jar load_tax_averages failed:\n$err");
    }

    return undef;
}

=item C<get_summary_rates>

Routine to request, process, and stash rate data as defined for
'/v2/summary_rates'. See Tax Jar documentation for details.

=cut

sub get_summary_rates {
    my $self = shift;

    # Clean it out so empty on error
    $self->summary_rates([]);

    $self->set_url(SUMMARY_PATH);

    my $r =
        $self->ua->get(
            $self->url,
            'Authorization' => $self->authorization,
            'Cache-Control' => 'no-cache',
        )
    ;

    $self->debug("get_summary_rates() full request\n%s", $r->request->as_string);
    $self->debug("get_summary_rates() full response\n%s", $r->as_string);

    my $msg = $self->_handle_json_response($r) || {};

    $self->debug('get_summary_rates() parsed response document: %s', ::uneval($msg));

    return $self->summary_rates($msg->{summary_rates} || [])
        if $r->is_success;

    die sprintf (
        "get_summary_rates() failed: status %s\nfull request:\n%s\n\nfull response:\n%s",
        $r->status_line,
        $r->request->as_string,
        $r->as_string,
    );
}

=item C<get_nexus>

Routine to request, process, and stash nexus for merchant as defined for
'/v2/nexus/regions'. See Tax Jar documentation for details.

=cut

sub get_nexus {
    my $self = shift;

    # Clean it out so empty on error
    my %nexus;
    $self->nexus(\%nexus);

    $self->set_url(NEXUS_PATH);

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
        for (@{ $msg->{regions} || []}) {
            my $hsh = $nexus{ $_->{country_code} } ||= {};
            $hsh->{ $_->{region_code} || '' } = 1;
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
            state,
            country,
            tax_shipping
        )
        VALUES (
            ?,
            ?,
            ?,
            ?,
            0
        )
    };
    my $ins = $self->dbh->prepare($sql);

    $sql = qq{
        UPDATE $q_table
        SET rate_percent = ?, has_nexus = ?
        WHERE state = ?
            AND country = ?
    };
    my $upd = $self->dbh->prepare($sql);

    $sql = qq{
        SELECT ?, ?
        FROM $q_table
        WHERE state = ?
            AND country = ?
    };
    my $read = $self->dbh->prepare($sql);

    for ($self->summary_rates) {
        $self->debug('working on record %s', ::uneval($_));
        my $has_nexus = $self->nexus->{ $_->{country_code} }->{ $_->{region_code} };
        my @args = (
            $_->{average_rate}{rate} * 100, # rate as a percent
            $has_nexus || '0',              # '1' when true; undef otherwise
            $_->{region_code} || '',        # state, null for non-US or -CA.
            $_->{country_code},             # country, 2-char code
        );

        $self->debug('%s update arg list: %s', $self->table, ::uneval(\@args));

        $read->execute(@args);
        my $write = $read->rows > 0 ? $upd : $ins;
        $read->finish;
        $write->execute(@args);
    }

    return;
}

=item C<has_nexus>

Utility routine to return boolean flag of whether merchant has nexus for tax
liability in (B<state>, B<country>). If there is no nexus, then live lookup
can be skipped altogether.

=cut

sub has_nexus {
    my $self = shift;

    return unless $self->state;

    my $sql = q{
        SELECT 1
        FROM %s
        WHERE state = ?
            AND country = ?
            AND has_nexus
    };
    $sql = sprintf ($sql, $self->dbh->quote_identifier($self->table));

    my ($rv) = $self->dbh->selectrow_array($sql, undef, $self->state, $self->country);

    return $rv;
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
        ::logError("Tax Jar send_tax_transaction failed:\n$err");
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
 * address
 * shipping
 * order_number
 * total_cost
 * salestax
 * order_date (fmt: YYYY-MM-DD)

Line item data can be provided directly as an array of hashes to the
B<orderline> attribute, but it is strongly recommended to set the
B<load_line_items> flag and let the code pull and massage the line-item data
accordingly.

Routine then processes report to Tax Jar as defined for
'/v2/transactions/orders'. See Tax Jar documentation for details.

If HTTP response code is in the 400 range, routine will set the value of
B<sent_field> in transactions explicitly to -1. Any orders containing -1 in
that field should be examined manually for getting that information reported
to Tax Jar.

See strap Job "send_tax_transaction" for an example call to
[send-tax-transaction].

=cut

sub post_transaction {
    my $self = shift;

    $self->state
        or die "state() required";

    $self->country
        or die "country() required";

    unless ($self->has_nexus) {
        $self->debug('post_transaction() - skipping transaction from "%s", "%s" with no nexus', $self->state, $self->country);
        return;
    }

    my %args = $self->_basic_args;

    $args{transaction_id} = $self->order_number
        or die "order_number() required";

    $self->total_cost > 0
        or die "total_cost() required";

    $args{amount} = sprintf ('%0.2f', $self->total_cost - $self->salestax);

    $args{sales_tax} = sprintf ('%0.2f', $self->salestax);

    $args{transaction_date} = $self->order_date;

    $self->get_orderline if $self->load_line_items;

    my @items;
    for my $row ($self->orderline) {
        my %item = (
            id => $row->{mv_ip},
            quantity => $row->{quantity},
            product_identifier => $row->{sku},
            description => $row->{description},
            unit_price => $row->{full_price},
            discount => $row->{tax_line_discount},
            sales_tax => $row->{salestax},
        );
        $item{product_tax_code} = $row->{product_tax_code}
            if $row->{product_tax_code};
        push @items, \%item;
    }

    $args{line_items} = \@items
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

    return if $r->is_success;

    if ($r->code =~ /^4/) {
        $self->sent_success_value('-1');
        $self->mark_order_as_sent;
    }

    die sprintf (
        "Tax Jar post_transaction failed: status %s\nfull request:\n%s\n\nfull response:\n%s",
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
an Interchange cart to align with the line item data sent to Tax Jar.
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
            description,
            full_price,
            tax_line_discount,
            salestax,
            product_tax_code
        FROM orderline
        WHERE order_number = ?
    };

    my $sth = $self->dbh->prepare($sql);
    $sth->execute($self->order_number);

    die sprintf ('No orderline data found for order %s', $self->order_number)
        unless $sth->rows > 0;

    my $ol = $sth->fetchall_arrayref({});
    for (@$ol) {
        my $code = delete $_->{code};
        my ($mv_ip) = $code =~ /-(\d+)$/;
        $_->{mv_ip} = $mv_ip - 1;
    }

    $self->orderline($ol);

    return;
}

=back

=head2 Utility methods

=over 4

=item C<authority>

Set the B<authority> attribute of a URI object to either the sandbox or
production Tax Jar host, depending on the value of the flag B<development>.

=cut

sub authority {
    my $self = shift;
    $self->development ? DEVHOST : LIVEHOST;
}

=item C<authorization>

Construct the bearer-token value for the Authorization header.

=cut

sub authorization {
    my $self = shift;
    return sprintf ('Bearer %s', $self->token);
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

    return $self->url($url);
}

=item C<_find_product_tax_code>

Given a line item as an argument, find the corresponding Tax Jar product tax
code. Using field B<product_tax_code_field> to look up first as a hash key in
the line item, if exists, or fall back to C<item_field()> to find the field in
the sku's source table from that same field name.

=cut

sub _find_product_tax_code {
    my $self = shift;
    my $item = shift;
    my $k = $self->product_tax_code_field;

    return $item->{$k} || Vend::Interpolate::item_field($item, $k) || '';
}

=item C<_boolean_nontaxable>

Return boolean indicating if the product is in any of 3 ways identified to
Interchange as always nontaxable:

=over 2

=item *

$item->{mv_nontaxable} passes C<is_yes()>

=item *

$item->{ B<nontaxable_field> } passes C<is_yes()>

=item *
C<item_field()> for attribute B<nontaxable_field> passes C<is_yes()>

=back

If all above tests fail, returns false.

=cut

sub _boolean_nontaxable {
    my $self = shift;
    my $item = shift;

    return 1 if Vend::Interpolate::is_yes( $item->{mv_nontaxable} );

    my $k = $self->nontaxable_field;
    # Check if field is an automodifier
    return 1 if Vend::Interpolate::is_yes( $item->{$k} );
    # Finally check database
    return 1 if Vend::Interpolate::is_yes( Vend::Interpolate::item_field($item, $k) );

    return 0;
}

=item C<_basic_args>

Returns array mapping the standard Tax Jar attributes for any request to their
corresponding Vend::Tax::TaxJar attributes.

=cut

sub _basic_args {
    my $self = shift;
    return (
        from_country => $self->nexus_country,
        from_zip => $self->nexus_zip,
        from_state => $self->nexus_state,
        from_city => $self->nexus_city,
        from_street => $self->nexus_address,
        to_country => $self->country,
        to_zip => $self->zip,
        to_state => $self->state,
        to_city => $self->city,
        to_street => $self->address,
        shipping => sprintf ('%0.2f', $self->shipping),
    );
}

sub _handle_json_response {
    my $self = shift;
    my $resp = shift;

    my $msg = $resp->decoded_content;

    if ($resp->header('Content-Type') =~ /\bjson\b/) {
        my $ref = $self->json->decode($msg);
        _thin_booleans(\$ref);
        return $ref;
    }

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

Mark Johnson (mark@endpointdev.com), End Point Corp.

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2002-2020 Interchange Development Group

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
