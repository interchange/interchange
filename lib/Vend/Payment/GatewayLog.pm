package Vend::Payment::GatewayLog;

use strict;
use warnings;

use Time::HiRes;

sub new {
    my ($class, $opt) = @_;
#::logDebug("Called in class $class, with opt hash %s", ::uneval($opt));
    my $self = bless ({}, $class);
    $self->init($opt);
    $Vend::Payment::Global_Timeout = undef;
    return $self;
}

sub init {
    my $self = shift;
    my $opt = shift;
    $self->{_log_table} = $opt->{LogTable} || 'gateway_log';
    $self->{_enabled} = $opt->{Enabled} || '';
    $self->{_source} = $opt->{Source} || '';

    unless (length ($self->{_source})) {
        my $host = `hostname -s`;
        chomp ($self->{_source} = $host);
    }

    return 1;
}

sub start {
    my $self = shift;
    return unless $self->_enabled;
    my $override = shift;
    $self->{__start} = Time::HiRes::clock_gettime()
        if $override || !$self->{__start};
#::logDebug("Start time: $self->{__start}");
    return $self->{__start};
}

sub stop {
    my $self = shift;
    return unless $self->_enabled;
    my $override = shift;
    $self->{__stop} = Time::HiRes::clock_gettime()
        if $override || !$self->{__stop};
#::logDebug("Stop time: $self->{__stop}");
    return $self->{__stop};
}

sub duration {
    my $self = shift;
    return unless $self->_enabled;
    my $fmt = shift || '%0.3f';
    my $rv = sprintf ($fmt, $self->stop - $self->start);
#::logDebug("Duration calculated at $rv");
    return $rv;
}

sub timestamp {
    my $self = shift;
    return unless $self->_enabled;
    my $fmt = shift || '%Y-%m-%d %T';
    my $rv = POSIX::strftime($fmt, localtime($self->start));
#::logDebug("Start formatted timestamp returned $rv");
    return $rv;
}

sub request {
    my $self = shift;
    return unless $self->_enabled;
    my $request = shift;
    return $self->{__request}
        unless $request;
    unless (UNIVERSAL::isa($request, 'HASH')) {
        ::logDebug(
            'Skipping non-HASH request set: received %s (unevals to %s)',
            $request,
            ::uneval($request)
        );
        return;
    }
#::logDebug('Setting request: %s', ::uneval($request));
    $self->{__request} = { %$request };
}

sub response {
    my $self = shift;
    return unless $self->_enabled;
    my $response = shift;
    return $self->{__response}
        unless $response;
    unless (UNIVERSAL::isa($response, 'HASH')) {
        ::logDebug(
            'Skipping non-HASH response set: received %s (unevals to %s)',
            $response,
            ::uneval($response)
        );
        return;
    }
#::logDebug('Setting response: %s', ::uneval($response));
    $self->{__response} = { %$response };
}

sub clean {
    my $self = shift;
    return unless $self->_enabled;
    delete $self->{$_}
        for grep { /^__/ } keys %$self;
#::logDebug('Cleaned all object data');
    return 1;
}

sub log_it {
    die 'Must override log_it() in subclass';
}

sub write {
    my $self = shift;
    my $data = shift;

    eval {
        my $table = $self->table;
        my $db = ::database_exists_ref($table)
            or die "'$table' not a valid Interchange table";
        $db = $db->ref;

        $db->set_slice(
            [ { dml => 'insert' } ],
            $data
        )
            or die "set_slice for $table failed";
    }; # End eval

    if ($@) {
        my $err = $@;
        ::logGlobal(
            q{Couldn't write to %s: %s -- request: %s -- response: %s},
            $self->table,
            $err,
            ::uneval($self->request),
            ::uneval($self->response)
        );
    }
    else {
#::logDebug('Cleaning out object data after successful write to database');
        $self->clean;
    }

    return 1;
}

sub table {
    return shift->{_log_table};
}

sub _enabled {
    return shift->{_enabled};
}

sub source {
    return shift->{_source};
}

sub DESTROY {
    my $self = shift;

    return 1 unless $self->_enabled;

    # Unexpected order of operations causes any evals
    # within DESTROY to execute after any eval that may
    # contain the DESTROYed object. Effect is that $@ upon
    # exit of the containing eval is *not* controlled by
    # that eval. Localization contains the effect.
    local $@;

    eval { $self->log_it };
    ::logGlobal("log_it eval died: $@")
        if $@;

    1;
}

1;

__END__

=head1 NAME

Vend::Payment::GatewayLog - Basic package and methods for enabling full
transaction logging in any of the gateways within the Vend::Payment::*
namespace.

=head1 VERSION

1.00

=head1 USAGE

From within the normally unused namespace of the payment gateway:

    package Vend::Payment::WhizBang;
 
    use Vend::Payment::GatewayLog
    use base qw/Vend::Payment::GatewayLog/;
 
    sub log_it {
        # Override log_it() with gateway-dependent mapping to a logging table,
        # by default gateway_log
    ...
    }

Then from inside the gateway sub itself:

    ...
    my $gwl =
        Vend::Payment::WhizBang
            -> new({
                Enabled => charge_param('gwl_enabled'),
            });
 
    $gwl->request(\%scrubbed_request_hash);
    $gwl->start;
    ... Code that calls out to gateway's API ...
    $gwl->stop;
    ...
    $gwl->response(\%response_hash);

=head1 DESCRIPTION

Module sets up an object with some utility methods to facilitate full database
logging of all transaction attempts executed through the gateway. Often these
data are either missing or insufficient for proper evaluation of problem events
or general reporting.

It's important to scrub all sensitive data appropriate for permanent storage.
Minimally, this is recommended to include credit card numbers and CVV2 values,
any senstitive gateway credentials (passwords or secret keys), or any personal
data that can be used to exploit a customer's identity (SSN, date of birth,
etc.).

You do not want to call log_it() yourself. It is set up to execute
automatically on destruction to help ensure that unexpected exits or aborts are
still logged.

=head2 Options

Pass hashref to the constructor to include the following options:

=over 4

=item Enabled

Boolean to indicate that actual logging should be performed. Default is false;
thus logging must be explicitly requested. Can be set in the constructor with
Route param "gwl_enabled" or globally with MV_PAYMENT_GWL_ENABLED in
catalog.cfg.

=item LogTable

Name of table to which logging should be directed. Default is gateway_log.  Can
be set in the constructor with Route param "gwl_table" or globally with
MV_PAYMENT_GWL_TABLE in catalog.cfg.

=item Source

Maps to the request_source field in the log table. Value is most meaningful in
a distributed environment, where multiple servers running the Interchange
application may be handling requests behind a load balancer. Default value
obtained from `hostname -s`. Can be set in the constructor with Route param
"gwl_source" or globally with MV_PAYMENT_GWL_SOURCE in catalog.cfg.

=back

=head1 METHODS

=over 4

=item new()

Constructor with optional hash ref indicating any of the above Options. Note
that when Enabled, it will trigger a log write as soon as it goes out of scope,
so consider when and where you want to call the constructor.

=item start()

Return, and optionally set, the Time::HiRes::clock_gettime() of the beginning
of the call to the gateway's API. When called for the first time, it will set
the value in the object and return said value; otherwise, it simply returns the
previously set value. The set can be overridden by calling the method with a
perly true arg.

=item stop()

Return, and optionally set, the Time::HiRes::clock_gettime() of the end of the
call to the gateway's API. Same conditions apply as do for start()

=item duration()

Returns the delta of stop() - start(). Be aware that calling this method
prior to calling either start() or stop() will cause the current time to
be used for each and frozen.

Default format is '%0.3f', but can be overriden passed as an arg.

=item timestamp()

Returns the timestamp of the value of start(). Again, calling this method
prior to calling start() will cause the current time to be used and frozen.

Default format is '%Y-%m-%d %T', but can be overriden passed as an arg.

=item request()

Freeze the hash request sent to the payment gateway if passed as an arg. Code
will freeze a copy of the hash (though not a deep copy, if that impacts your
particular gateway's request structure) so that any post-request processing on
the original hash will not affect the stored request.

Method only accepts a hash reference and will skip any other data structure
that is attempted to be saved and logs the issue to the debug log, along with
an ::uneval() of whatever was passed in.

Calling with no args will only return the currently stored request hash
reference.

=item response()

Freeze the hash response from the payment gateway if passed as an arg. Code
will freeze a copy of the hash (though not a deep copy, if that impacts your
particular gateway's response structure) so that any post-response processing
on the original hash will not affect the stored response.

Method only accepts a hash reference and will skip any other data structure
that is attempted to be saved and logs the issue to the debug log, along with
an ::uneval() of whatever was passed in.

Calling with no args will only return the currently stored response hash
reference.

=item clean()

Will purge all stored data from the object.

=item log_it()

Stub that must be overridden in the subclass. Invoking the object when
log_it() has failed to be overridden will cause the code to die.

=item table()

Returns the name of the table against which the database update is to be
performed. Default is 'gateway_log', but can be overridden in the constructor
using the LogTable option.

=item source()

Returns the value set in the constructor for the Source option.

=back

=head1 AUTHOR

Mark Johnson (mark@endpoint.com), End Point Corp.

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2017 Interchange Development Group and others

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
