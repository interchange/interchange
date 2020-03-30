# Vend::Tax - Interchange 3rd-party tax integration
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

package Vend::Tax;

use strict;
use warnings;

use Vend::Tags;
use Scalar::Util qw/reftype/;

use constant {
    SERVICE => undef,
    init => undef,
};

# Build accessors and constructor
{
    # Constructor initializes accessors in array order, so accessors can depend
    # on prior accessors
    my @acc = (
        development => q{$Global::Variable->{INDEV}},
        verbose => q{$Global::Variable->{INDEV}},
        tag => q{Vend::Tags->new},

        table => q{$::Variable->{TAXAVERAGES_TABLE}},
        dbh => q{::database_exists_ref($self->table || 'products')->dbh},
        average_lookup_field => q{$::Variable->{TAXAVERAGES_LOOKUP_FIELD} || 'state'},

        use_billing => q{!$::Values->{zip}},
        fname => q{$self->use_billing ? $::Values->{b_fname} : $::Values->{fname}},
        lname => q{$self->use_billing ? $::Values->{b_lname} : $::Values->{lname}},
        company => q{$self->use_billing ? $::Values->{b_company} : $::Values->{company}},
        address1 => q{$self->use_billing ? $::Values->{b_address1} : $::Values->{address1}},
        address2 => q{$self->use_billing ? $::Values->{b_address2} : $::Values->{address2}},
        city => q{$self->use_billing ? $::Values->{b_city} : $::Values->{city}},
        state => q{$self->use_billing ? $::Values->{b_state} : $::Values->{state}},
        zip => q{$self->use_billing ? $::Values->{b_zip} : $::Values->{zip}},
        country => q{($self->use_billing ? $::Values->{b_country} : $::Values->{country}) || 'US'},

        estimate => q{$::Scratch->{tag_tax_lookup_estimate_mode}},
        taxable_amount => q{Vend::Interpolate::taxable_amount()},
        shipping => q{Vend::Interpolate::tag_shipping()},

        order_number => q{undef},
        order_date => q{$self->tag->time({},'%Y-%m-%d')},
        total_cost => q{0},
        salestax => q{0},
        subtotal => q{0},
        handling => q{0},
    );

    sub orderline {
        my $self = shift;
        my $p = \$self->{_orderline};
        if (@_) {
            my $v = shift;
            die "orderline value '$v' not an ARRAY"
                unless $self->_reftyped($v) eq 'ARRAY';
            for (0 .. $#$v) {
                my $li = $v->[$_];
                die "orderline[$_] value '$li' not a HASH"
                    unless $self->_reftyped($li) eq 'HASH';
            }
            $$p = $v;
        }
        $$p ||= [];
        return @{$$p} if wantarray;
        return $$p;
    }

    sub new {
        my $self = bless ({}, shift);
        my %p = @_;

        return $self unless keys %p;

        for (my $i = 0; $i < @acc; $i += 2) {
            my $k = $acc[$i];
            next unless exists $p{$k};
            $self->$k($p{$k});
        }

        # Allow subclasses to define any useful initializations
        $self->init(@_);

        return $self;
    }

    sub has {
        my $self = shift;

        my $class = ref ($self) || $self;

        my %acc = @_;

        my $sub = q#
            sub %1$s {
                my $self = shift;
                return $self->{_%1$s} = shift
                    if @_;
                return $self->{_%1$s}
                    if exists $self->{_%1$s};
                return $self->{_%1$s} = %2$s;
            }
        #;

        my $str = '';

        $str .= sprintf ($sub, $_, $acc{$_}) for keys %acc;

        if ($str) {
            local $@;
            eval ("package $class;\n$str");
            die $@ if $@;
        }

        return;
    }

    __PACKAGE__->has(@acc);
}

### Define in subclass
sub tax {
    my $self = shift;
    die 'No service has been specified for tax calculation'
        unless $self->SERVICE;
    die 'tax() is not defined for service ' . $self->SERVICE;
}

### Define in subclass if service provides lookup utility
sub load_tax_averages {
    my $self = shift;
    die 'No service has been specified to retrieve tax averages'
        unless $self->SERVICE;
    die 'load_tax_averages() is not defined for service ' . $self->SERVICE;
}

### Define in subclass if service provides API for creating transactions
sub send_tax_transaction {
    my $self = shift;
    die 'No service has been specified to create tax transactions'
        unless $self->SERVICE;
    die 'send_tax_transaction() is not defined for service ' . $self->SERVICE;
}

### [tax-lookup]
sub tag_tax_lookup {
    my $opt = shift;

    local $@;
    my $amount = eval {
        my $class = __PACKAGE__;
        $class .= "::$opt->{service}"
            if $opt->{service};
        my $obj = $class->new(%$opt);
        return $obj->estimate ? $obj->estimated_tax : $obj->tax;
    };

    if (my $err = $@) {
        ::logError('[tax-lookup] died: %s', $err);
    }

    return $amount;
}

sub estimated_tax {
    my $self = shift;
    return 0 unless $self->table;

    $self->debug('Tax is estimated, using table %s', $self->table);

    my $lookup_field = $self->average_lookup_field;
    unless ($self->can($lookup_field)) {
        ::logError("Invalid average_lookup_field, no such accessor");
        return 0;
    }

    my $sql = q{
        SELECT *
        FROM %s
        WHERE %s = ?
            AND country = ?
            AND has_nexus
        LIMIT 1
    };
    my $row;
    {
        local $@;
        eval {
            my $sth = $self->dbh->prepare(
                sprintf (
                    $sql,
                    $self->dbh->quote_identifier($self->table),
                    $self->dbh->quote_identifier($self->average_lookup_field)
                )
            );
            $sth->execute($self->$lookup_field, $self->country);
            $row = $sth->fetchrow_hashref('NAME_lc');
            $sth->finish;
        };
        if (my $err = $@) {
            ::logError("estimated_tax() database lookup failed: $err");
        }
    }
    # Stop right here if we can't find a tax record with nexus.
    return 0 unless $row;

    my $rate = ($row->{rate_percent} // 0) / 100;

    if (defined (my $adj = $row->{rate_adjust_percent})) {
        $rate *= (1 + $adj / 100);
    }

    my $amount = $self->taxable_amount;
    $amount += $self->shipping
        if $row->{tax_shipping};

    return $amount * $rate;
}

### [load-tax-averages]
sub tag_load_tax_averages {
    my $opt = shift;

    local $@;
    eval {
        # Tag only works with a service.
        $opt->{service} or die 'Must specify which tax service to use';
        my $class = __PACKAGE__ . "::$opt->{service}";
        my $obj = $class->new(%$opt);
        $obj->load_tax_averages;
    };

    if (my $err = $@) {
        ::logError('[load-tax-averages] died: %s', $err);
        return;
    }

    return 1;
}

### [send-tax-transaction]
sub tag_send_tax_transaction {
    my $opt = shift;

    local $@;
    eval {
        # Tag only works with a service.
        $opt->{service} or die 'Must specify which tax service to use';
        my $class = __PACKAGE__ . "::$opt->{service}";
        my $obj = $class->new(%$opt);
        $obj->send_tax_transaction;
    };

    if (my $err = $@) {
        ::logError('[send-tax-transaction] died: %s', $err);
        return;
    }

    return 1;
}

sub cart {
    my $self = shift;
    return @$Vend::Items if wantarray;
    return $Vend::Items;
}

sub debug {
    my $self = shift;
    return unless $self->verbose;
    my $msg = shift;
    ::logError("DEBUG: $msg", @_);
    return;
}

# Always-defined reftype test.
sub _reftyped {
    reftype(pop) // '';
}

# Always-defined ref test.
sub _refd {
    ref (pop) // '';
}

1;

__END__

=head1 NAME

Vend::Tax - Base class for interface into support for 3rd-party tax APIs.

=head1 DESCRIPTION

Module sets up interface to Interchange through the establishment of 3
usertags and generalized attributes needed for tax calculation. The 3 tags
provide for the calculation of a tax amount, facility to query and load tax
averages for supported jurisdictions, and ability for merchants to upload a
tax transaction per order to the provider.

For convenience, the module makes some assumptions about the table name and
form input names based on long-established demo patterns, but all of these
attributes can be overridden by parameters set in the usertags themselves.

To facilitate tax estimates, the code assumes greater structure about the
database table used to hold averages. While the name and full structure of
this table is flexible, there are certain fields it must have in order to
function generally across any number of providers. The strap demo comes with a
table definition for "tax_averages" that meets these criteria.

In order to use Vend::Tax, you must enable and specify a supported tax
service. Without doing so, any calls to its supported usertags will produce an
error.

Conceptually, Vend::Tax is patterned off of Vend::Payment for payment
transactions. It provides the defined interface that Interchange will use, via
the 3 tags described below, but must delegate to vendor-specific
implementations through tax gateway modules.

=head1 USERTAGS

Vend::Tax defines these tags to support each of the above identified
functions:

=over 4

=item [tax-lookup]

Returns calculated tax amount determined by specific 3rd-party provider. Tax
may be estimated or live lookup, depending on settings. Data required to
calculate tax will be provider dependent.

=item [load-tax-averages]

Requests and stores tax averages for running in estimate mode, for providers
that support it. Stores estimates by default in "tax_averages" table. Further,
allows for local tracking of jurisdictions with nexus, which can be used by
live lookups to determine if a particular lookup can be skipped entirely. See
load_tax_averages Job and "tax_averages" table definition in strap demo.

=item [send-tax-transaction]

Report to provider the resulting tax transaction for a given order, for
providers that support it. By default, operates based on transactions.tax_sent
field. 0/empty indicates transaction not reported.  1 indicates transaction
successfully reported. -1 indicates an error attempting to report transaction,
requiring manual intervention. See send_tax_transactions Job in strap demo.

=back

=head1 ATTRIBUTES

Each of the following attributes can be set by adding as parameters to any
call to the usertags listed above. For convenience, most are set to have a
sensible default based on the strap demo.

=over 4

=item B<development> - default: @@INDEV@@

Boolean value to direct activity to sandbox, if supported by provider.

=item B<verbose> - default: @@INDEV@@

Boolean value to allow any debug() calls internally to write to the catalog
error log.

=item B<table> - default: __TAXAVERAGES_TABLE__

Name of table to hold tax averages data.

=over 4

* For Tax Jar specifically, default will fall back to "tax_averages" if __TAXAVERAGES_TABLE__ is empty.

=back

=item B<average_lookup_field> - default: 'state'

Which field in B<table> is authoritative for applying estimated tax. If the
provided value does not correspond to a known attribute to the service, an
error will be written to the catalog error log and estimates will be
unavailable.

=item B<use_billing> - default: !$Values->{zip}

Boolean true will cause address data defaults out of Values space to use their
billing-address components. See below.

=item B<fname, lname, company, address1, address2, address, city, state, zip, country>

Address data sent to provider for determining tax.

Defaults for most correspond to their names in Values space, unless
B<use_billing> is set, in which case to their "b_*" counterparts.

E.g.: fname => B<use_billing> ? $Values->{b_fname} : $Values->{fname}

Exception for B<country>, which will fall back to 'US' if its corresponding
key in $Values is not set.

=item B<estimate> - default: $Scratch->{tag_tax_lookup_estimate_mode}

Boolean to force tax estimates to be used. Will only function if data in
B<table> are properly available.

=item B<taxable_amount> - default: Vend::Interpolate::taxable_amount().

Amount to use for determining tax liability.

=item B<shipping> - default: Vend::Interpolate::tag_shipping().

Shipping amount for order, which may be required for tax liability depending
on jurisdiction.

=item B<order_number> - default: undef

Order number defined typically in transactions.code.

=item B<order_date> - default: current date (format: YYYY-MM-DD)

Date of B<order_number>.

=item B<total_cost> - default: 0

Total amount collected for B<order_number>.

=item B<salestax> - default: 0

Total sales tax collected for B<order_number>.

=item B<subtotal> - default: 0

Subtotal of B<order_number>.

=item B<handling> - default: 0

Handling charge for B<order_number>.

=back

=head1 Tax Averages Table

While any table can be made available for calculating averages, there are
certain fields it must have:

=over 4

=item B<average_lookup_field>

This is the field specified in the attribute described above. This field is
canonical, and ideally with the span of a specific country unique. Thus, the
specific name of this field is flexible, but it must exist and be specified in
B<average_lookup_field>, and it must correspond to an existing attribute. If a
particular provider uses a field name not supported as an attribute in
I<Vend::Tax>, it must be provided as an attribute in that service's
I<Vend::Tax::Service> module.

=item country

Will be set to the value of attribute B<country>.

=item has_nexus

Boolean field to indicate if the merchant has tax liability for the
jurisdiction in question.

=item rate_percent

Average rate of tax for the jurisdiction in question in percent.

=item rate_adjust_percent

Percent amount to increase/decrease the value in rate_percent. Value can be
negative to decrease or positive to increase the effective tax rate.

E.g.: assume a rate of 8.5%. To adjust this rate up by 3%, set
rate_adjust_percent to 3, creating an effective rate of 8.755%. To adjust down
by 2%, set rate_adjust_percent to -2, creating an effective rate of 8.33%.

Why? It's expected that the rate_percent will be set automatically by a
provider, and the merchant may find through experience that the average rate
percent is not accurate enough with respect to actual tax rates. The
adjustment field gives the merchant an extra tool to fine tune tax estimates
per jurisdiction.

=item tax_shipping

Boolean field to indicate if the merchant has tax liability on the amount of
shipping for the jurisdiction in question.

=back

=head1 AUTHOR

Mark Johnson (mark@endpoint.com), End Point Corp.

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
