# Vend::CharSet - utility methods for handling character encoding
#
# $Id: CharSet.pm,v 2.6 2008-04-17 10:52:37 racke Exp $
#
# Copyright (C) 2008 Interchange Development Group
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

use strict;
use warnings;

use Encode qw( decode resolve_alias is_utf8 );

sub decode_urlencode {
	my ($class, $octets, $encoding) = (@_);

#::logDebug("decode_urlencode--octets: $octets, encoding: $encoding");

	$octets =~ tr/+/ /;
	$octets =~ s/%([0-9a-fA-F][0-9a-fA-F])/chr(hex $1)/ge;

	unless ($encoding || $class->validate_encoding($encoding)) {
		return $octets;
	}
	
	my $string = $class->to_internal($encoding, $octets);

#::logDebug("decoded string: " . display_chars($string)) if $string;
	return $string;
}

sub to_internal {
	my ($class, $encoding, $octets) = @_;
#::logDebug("to_internal - converting octets from $encoding to internal");
	if (!$encoding || is_utf8($octets)) {
#::logDebug("to_internal - octets are already utf-8 flagged");
		return $octets;
	}

	my $string = eval {	decode($encoding, $octets, Encode::FB_CROAK) };
	if ($@) {
		::logError("Unable to properly decode <%s> with encoding %s: %s", display_chars($octets), $encoding, $@);
		return;
	}
	return $string;
}

sub validate_encoding {
	my ($class, $encoding) = @_;
	return resolve_alias($encoding);
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

