# Vend::SessionRedis - Stores Interchange sessions in Redis
#
# Copyright © 2002–2026 Interchange Development Group, Jon Jensen, and Mark
# Johnson
# Copyright © 1996–2002 Red Hat, Inc.
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
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

package Vend::SessionRedis;

use strict;
use warnings;

require Tie::Hash;
use parent 'Tie::Hash';

use Vend::Util;
use Vend::Util::Compress qw(compress uncompress);
use Redis;

# Limit new sessions to 30 minutes.
use constant NEW_SESSION_EXP => 30 * 60;

our $VERSION = '1.0';

sub TIEHASH {
    my ($class, $server) = @_;
    #::logDebug("$class tiehash server=$server (pid=$$)");

    my %args = (server => $server,);
    my $redis = Redis->new(%args);

    my $self = {
        REDIS => $redis,
        LOCK_VALUE => {},
        LOCK_VALUE_NX => '',
        SESSION_VALUE => {},
        _ARGS => \%args,
    };
    #::logDebug("self=" . ::uneval($self));

    return bless $self, $class;
}

sub UNTIE {
    my $self = shift;
    #::logDebug('UNTIE called - ref ($self->{REDIS}): %s - $self->{LOCK_VALUE}: %s', ref ($self->{REDIS}), ::uneval($self->{LOCK_VALUE} || {}));
    #::logDebug("$self untie (pid=$$)");
    if (my $redis = $self->{REDIS}) {
        my ($k, $v) = %{ delete ($self->{LOCK_VALUE}) || {} };
        if ($k) {
            my $val = $redis->get($k);
            #::logDebug('$val: %s', $val);
            $redis->del($k)
                if $v eq $val;
        }
        $redis->quit;
    }
    %$self = ();
    return;
}

sub DESTROY {
    my $self = shift;
    #::logDebug('DESTROY called - ref ($self->{REDIS}): %s - $self->{_ARGS}: %s - $self->{LOCK_VALUE}: %s', ref ($self->{REDIS}), ::uneval($self->{_ARGS}), ::uneval($self->{LOCK_VALUE}));
    #::logDebug("$self destroy (pid=$$)");
    local $@;
    eval {
        my ($k, $v) = %{ delete ($self->{LOCK_VALUE}) || {} };
        #::logDebug('($k, $v): (%s, %s)', $k, $v);
        if ($k) {
            my $redis = ref ($self->{REDIS}) ? $self->{REDIS} : Redis->new(%{ $self->{_ARGS} });
            #::logDebug(q{calling $redis->get('%s')}, $k);
            my $val = $redis->get($k);
            #::logDebug('$redis->get returned: %s - cached value: %s', $val, $v);
            $redis->del($k)
                if $v eq $val;
            $redis->quit;
        }
    };
    if (my $err = $@) {
        #::logDebug('Caught sumt-in! %s', $err);
    }
    return 1;
}

sub FETCH {
    my ($self, $key) = @_;
    if (!defined($key)) {
    #::logDebug("$self fetch called with no \$key");
        return;
    }
    #::logDebug("$self fetch: $key (pid=$$)");

    my $redis = $self->{REDIS};

    if ($key =~ /^LOCK_/) {
    #::logDebug("$self LOCK_VALUE=" . ($self->{LOCK_VALUE}{$key} // '∅') . " (pid=$$)");
        #::logDebug('Fetching lock key %s', $key);
        return $self->{LOCK_VALUE}{$key}
            if $self->{LOCK_VALUE}{$key};
        return $self->{LOCK_VALUE}{$key} = $redis->get($key);
    }

    #::logDebug("$self SESSION_VALUE=" . ($self->{SESSION_VALUE}{$key} // '∅') . " (pid=$$)");
    return $self->{SESSION_VALUE}{$key}
        if $self->{SESSION_VALUE}{$key};

    my $val = $redis->get($key);
    #::logDebug("$self val=" . ($val // '∅') . " (pid=$$)");
    return undef unless defined $val;

    if (my $c_type = $Vend::Cfg->{SessionDBCompression}) {
        my ($ref, $time, $alert) = uncompress(\$val, $c_type);
        ::logError("$c_type uncompression response alert: $alert")
            if $alert;
        ::logDebug('%s time to uncompress: %fs', $c_type, $time);
        $val = $$ref;
    }

    return $self->{SESSION_VALUE}{$key} = $val;
}

sub FIRSTKEY {
    my ($self) = @_;
    #::logDebug("$self firstkey (pid=$$)");
}

sub NEXTKEY {
    my ($self) = @_;
    #::logDebug("$self nextkey (pid=$$)");
}

sub EXISTS {
    my ($self, $key) = @_;
    #::logDebug("$self exists: $key (pid=$$)");
    my $redis = $self->{REDIS};
    return 1 if defined $redis->get($key);
    return undef;
}

sub DELETE {
    my ($self, $key) = @_;
    #::logDebug("$self delete: $key (pid=$$)");
    my $redis = $self->{REDIS};
    $redis->del($key);
    if ($key =~ /^LOCK_/) {
        delete $self->{LOCK_VALUE};
        delete $self->{LOCK_VALUE_NX};
    }
    return;
}

sub STORE {
    my ($self, $key, $val) = @_;
    #::logDebug("$self store: $key (pid=$$)");
    my $redis = $self->{REDIS};
    if ($key =~ /^LOCK_/) {
        $self->{LOCK_VALUE_NX} = '';
        if ($redis->set($key => $val, EX => $Global::HammerLock, 'NX')) {
            #::logDebug('set lock NX for key %s returned true with value %s', $key, $val);
            %{ $self->{LOCK_VALUE} ||= {} } = ();
            $self->{LOCK_VALUE}{$key} = $val;
            $self->{LOCK_VALUE_NX} = '1';
            return;
        }
        #::logDebug('set lock NX for key %s returned false with value %s', $key, $val);
        return;
    }
    else {
        $self->{SESSION_VALUE}{$key} = $val;
        my $store = \$val;
        if (my $c_type = $Vend::Cfg->{SessionDBCompression}) {
            my ($ref, $before, $after, $time, $alert) = compress($store, $c_type);
            ::logError("$c_type compression response alert: $alert")
                if $alert;
            ::logDebug('%s compression impact - before: %dB; after: %dB; %%reduced: %s', $c_type, $before, $after, $before ? sprintf ('%.2f', (1-$after/$before)*100) : 'undefined');
            ::logDebug('%s time to compress: %fs', $c_type, $time);
            $store = $ref;
        }
        my $exp = $Vend::new_session ? NEW_SESSION_EXP : $Vend::Cfg->{SessionExpire};
        $redis->set($key => $$store, EX => $exp);
        return 1;
    }
}

sub race_delay {
    my $self = shift;

    # Something is occasionally allowing multiple access to the session,
    # opening the door for unique requests for the same order succeeding.
    # Calling this routine will put a small delay in place before testing the
    # lock to make sure, if for some reason 2 concurrent setnx calls for the
    # same lock "succeed", only one of them can have its value ultimately
    # preserved and the other should then fail the has_lock() test afterward.

    return unless $self->{LOCK_VALUE_NX};
    select (undef, undef, undef, 0.05);
    return;
}

sub has_lock {
    my $self = shift;
    my $arg = shift || {};

    my %lock = %{ $self->{LOCK_VALUE} || {} };

    my ($key) = $arg->{k} ? ($arg->{k}) : keys %lock;

    defined ($key)
        or return '';

    $key =~ /^LOCK_/
        or return '';

    my $val = $arg->{v} || $lock{$key};

    defined ($val) && length ($val)
        or return '';

    return ($self->{REDIS}->get($key) // '') eq $val;
}

1;

__END__
