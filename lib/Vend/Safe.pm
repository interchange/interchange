# Vend::Safe - utility methods for handling character encoding
#
# Copyright (C) 2009 Interchange Development Group
# Copyright (C) 2009 David Christensen <david@endpoint.com>
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

# wrapper around Safe to return pre-inited Safe compartments which are utf-8 friendly.
package Vend::Safe;

use strict;
use warnings;

use Vend::CharSet;
use Safe;

# The L<new> method creates and returns an initialized Safe
# compartment.  This is mainly provided so there is a single point of
# modification for all needed Safe.pm initializations.

sub new {
    my ($invocant, @args) = @_;

    my $safe = Safe->new(@args);
    $invocant->initialize_safe_compartment($safe);

    return $safe;
}

# Initialize and sanity check the provided safe compartment.  Code
# here should be safe (ha, ha) to be run multiple times on the same
# compartment.

sub initialize_safe_compartment {
    my ($class, $compartment) = @_;

#::logDebug("Initializing Safe compartment");

    # force load of the unicode libraries in global perl
    qr{\x{0100}i};

    my $mask = $compartment->mask;
    $compartment->deny_only(); # permit everything

    # add custom shared variables for unicode support
    $compartment->share_from('main', ['&utf8::SWASHNEW', '&utf8::SWASHGET']);

    # preload utf-8 stuff in compartment
    $compartment->reval('qr{\x{0100}}i');
    $@ and ::logError("Failed activating implicit UTF-8 in Safe container: %s", $@);

    # revive original opmask
    $compartment->mask($mask);

    # check and see if it worked, if not, then we might have problems later
    $compartment->reval('qr{\x{0100}}i');

    $@ and ::logError("Failed compiling UTF-8 regular expressions in a Safe compartment with restricted opcode mask.  This may affect code in perl or calc blocks in your pages if you are processing UTF-8 strings in them.  Error: %s", $@);
}

1;
