# Vend::CharSet - utility methods for handling character encoding
#
# $Id: CharSet.pm,v 2.11 2009-03-22 19:32:31 mheins Exp $
#
# Copyright (C) 2008 Interchange Development Group
# Copyright (C) 2008 Sonny Cook <sonny@endpoint.com>
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

package Vend::CharSet;

@ISA = qw( Exporter );

@EXPORT_OK = qw(
				decode_urlencode
				default_charset
				to_internal 
				);

use strict;

use utf8; eval "\$\343\201\257 = 42";  # attempt to automatically load the utf8 libraries.
require "utf8_heavy.pl";

unless( $ENV{MINIVEND_DISABLE_UTF8} ) {
	require Encode;
	import Encode qw( decode is_utf8 find_encoding );
}

sub decode_urlencode {
	my ($octets, $encoding) = (@_);

#::logDebug("decode_urlencode--octets: $octets, encoding: $encoding");

	$$octets =~ tr/+/ /;
	$$octets =~ s/%([0-9a-fA-F][0-9a-fA-F])/chr(hex $1)/ge;

	return $octets unless $encoding and $Global::UTF8 and validate_encoding($encoding);

	to_internal($encoding, $octets);

#::logDebug("decoded string: " . display_chars($string)) if $string;
	return $octets;
}

sub to_internal {
	my ($encoding, $octets) = @_;

#::logDebug("to_internal - no encoding specified"),
    return $octets unless $encoding;
#::logDebug("to_internal - octets are already UTF-8 flagged"),
    return $octets if is_utf8($octets);

#::logDebug("to_internal - converting octets from $encoding to internal");
	$$octets = eval {	decode($encoding, $$octets, Encode::FB_CROAK()) };
	if ($@) {
		::logError("Unable to properly decode <%s> with encoding %s: %s", display_chars($octets), $encoding, $@);
		return;
	}
	return $octets;
}

# returns a true value (the normalized name of the encoding) if the
# specified encoding is recognized by Encode.pm, otherwise return
# nothing.
sub validate_encoding {
	my $encoding = shift;
	my $enc = find_encoding($encoding);

    return unless $enc;
	return $enc->can('mime_name') ? $enc->mime_name : mime_name($enc->name);
}

# fallback routine to provide a pretty-style mime_name in versions of
# Encode which predate the actual method.  The main use would be to
# normalize "utf8-strict" to "utf8", but there are other cases where
# this can/will come in handy.
sub mime_name {
    my $encoding_name = shift;

    $encoding_name =~ s/-strict//i;
    return lc $encoding_name;
}

sub default_charset {
	my $c = $Global::Selector{$CGI::script_name};
	return $c->{Variable}{MV_HTTP_CHARSET} || $Global::Variable->{MV_HTTP_CHARSET};
}

# this sub taken from the perluniintro man page, for diagnostic purposes
sub display_chars {
	return unless $_[0];
	return join("",
		map {
			$_ > 255 ?                  # if wide character...
			sprintf("\\x{%04X}", $_) :  # \x{...}
			chr($_) =~ /[[:cntrl:]]/ ?  # else if control character ...
			sprintf("\\x%02X", $_) :    # \x..
			quotemeta(chr($_))          # else quoted or as themselves
		} unpack("U*", $_[0]));			# unpack Unicode characters
}


1;
