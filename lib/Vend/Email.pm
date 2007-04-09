# Vend::Email - Handle Interchange email functions
# 
# $Id: Email.pm,v 1.2 2007-04-09 21:39:49 docelic Exp $
#
# Copyright (C) 2007 Interchange Development Group
#
# This program was originally based on Vend 0.2 and 0.3
# Copyright 1995 by Andrew M. Wilcox <amw@wilcoxsolutions.com>
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
# Software Foundation, Inc., 59 Temple Place, Suite 330, Boston,
# MA  02111-1307  USA.

package Vend::Email;

use MIME::Lite        qw//; # Main module
use MIME::Types       qw//;
use Mail::Address     qw//;
use MIME::QuotedPrint qw//; # Used by default
use MIME::Base64      qw//; # For user specified encodings
#use MIME::EncWords    qw//; # Word-encode mail headers when non-ascii
#use MIME::Charset     qw//; # Needed for EncWords

use Vend::Util        qw/logError logDebug uneval/;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw (
		);

use strict;
use warnings;

use vars qw/$VERSION/;

$VERSION = substr(q$Revision: 1.2 $, 10);

my @accepted_headers = (qw/
	to               cc              bcc
	sender           from            subject       reply\-to
	content\-[a-z-]+                 x\-[a-z-]+ 
	approved         encrypted       received      
	references       keywords        comments
	message\-id      mime\-version   return\-path
	date             organization  
	resent\-[a-z-]+
/);


###########################################################################
# Direct functions
#

# Pass input as options (data + headers) to create MIME::Lite object and send.
# Work to do here is filling unspecified fields with defaults, and making
# sure that all given options are valid.
sub tag_mime_lite_email {
	my ($opt, $body) = @_;
	#logDebug('mime_lite_email invoked, OPT=' .uneval($opt) . ' BODY=' . $body);

	local $_;

	#
	# See if we'll be sending this email, don't waste time if not.
	#
	my $using = $Vend::Cfg->{SendMailProgram};
	if ($using =~ /^none$/i ) {
		logError('Unable to send email, config option SendMailProgram=none.');
		return;
	}

	#
	# Quickly make sure that all options and header names satisfy basic regex.
	# (We need to do this in any case, so let's do it up-front.)
	#
	for my $key ( keys %$opt ) {
		$key = lc $key; # MIME::Lite does proper uppercasing later
		$key =~ /^[a-z-]+$/ or do {
			logError('Header name passed that does not match /^[a-zA-Z_-]+$/');
			return;
		};
	}

	#
	# Deal with tag-specific options that are not to be understood as headers.
	# (Save them to variables and delete them from $opt so that after this
	# block, only headers are left in $opt).
	#

	my $intercept;
	my $hdr_encoding;
	my ($interpolate, $reparse);
	my ($data, $encoding, $type);

	# Intercept
	if ( $_ = delete $opt->{intercept} ) {
		$intercept = $_;
	}

	# All e-mail headers need to be Word-Encoded if they contain non-ASCII.
	# Field names themselves must not be encoded, they're always in English.
	# Header_encoding can be 1|y|none|q|b|a|s:
	# - '1' and 'y' are our special synonyms for 'q'.
	# - 'none' is our special value for no encoding
	# - the rest are actual supported values by MIME::EncWords.
	if ( $_ = delete $opt->{'header_encoding'} ) {
		$hdr_encoding = $_;
	}
	if (! $hdr_encoding or $hdr_encoding =~ /1|y/i ) {
		$hdr_encoding = 'q';
	}
	$hdr_encoding eq 'none' and $hdr_encoding = '';

	# Interpolate/reparse
	($interpolate, $reparse) = (
		delete $opt->{interpolate},
		delete $opt->{reparse},
	);

	# Data (msg body), encoding and type
	($data, $encoding, $type) = (
		delete $opt->{data},
		delete $opt->{encoding},
		delete $opt->{type},
	);
	$data     ||= $opt->{body} || $body;    delete $opt->{body};
	$encoding ||= 'quoted-printable';
	$type     ||= 'text/plain';

	!(ref $data or ref $encoding or ref $type) or do {
		logError('Only scalar value accepted for options '.
				'data (body), encoding and type.');
		return;
	};

	#
	# Let's see specified headers, check them and/or associate defaults.
	# Headers can be specified as array (to.0=person1, to.1=person2), or
	# simply as to=person1. (Some can be multi-value, some can't. Sensible
	# check is performed.)
	#

	# Convert scalars to array refs (to=person1 -> to.0=person1) where allowed.
	for my $key (keys %$opt ) {

		# For options or header names that can only be scalars, make
		# sure they are scalars.
		if ( $key =~ /^(subject|from)$/ ) {
			! ref $opt->{$key} or do {
				logError('Only scalar value accepted for option or '.
					'header name "%s"', $key);
				return;
			};
			next;
		}

		# While for others that can be arrays, make sure they are
		# arrays by converting them from scalars if needed.
		if ( ! ref $opt->{$key} ) {
			$opt->{$key} = [ $opt->{$key} ];
		} elsif (ref $opt->{$key} ne 'ARRAY' ) {
			logError('Only scalars or array refs supported as options ' .
				'to tag_mime_lite_email().');
			return;
		}
	}

	#
	# Now check specific headers for specific values, and/or give defaults.

	# TO
	if (!( $opt->{to} and @{ $opt->{to} } )) {
		logError('mime_lite_email called without the required to= option.');
		return;
	}

	# FROM
	if (! $opt->{from} ) {
		$opt->{from} =
			$::Variable->{MV_MAILFROM}       ||
			$Global::Variable->{MV_MAILFROM} ||
			$Vend::Cfg->{MailOrderTo};
	}
	$opt->{from} or do {
		logError('Cannot find value for From: header. Make sure ' .
			'that MailOrderTo config directive or MV_MAILFROM variable ' .
			'is specified.');
	};

	# SUBJECT
	if (! $opt->{subject} ) {
		$opt->{subject} = '<no subject>';
	}

	# REPLY
	if (!( $opt->{reply_to} and @{ $opt->{reply_to} } )) {
		@{ $opt->{reply_to} } = 
			( ref $opt->{reply} ? @{ $opt->{reply} } : $opt->{reply} ) ||
			$::Values->{mv_email};
	}
	delete $opt->{reply};

	#
	# Support e-mail interception (re-writing to/cc/bcc to specified
	# address(es)).
	#
	$intercept ||= $::Variable->{MV_EMAIL_INTERCEPT} ||
		$Global::Variable->{MV_EMAIL_INTERCEPT};

	if ( $intercept ) {
		for my $field (qw/to cc bcc/) {
			if ( $opt->{$field} ) {
				for $_ ( @{ $opt->{$field} } ) {
					logDebug('Intercepting outgoing email (%s: %s) ' .
							'and instead sending to "%s"',
							$field, $_, $intercept);

					$opt->{$field} = $intercept;
					push @{ $opt->{"x-intercepted-$field"} }, $_;
				}
			}
		}
	}

	#
	# Now let's work on adjusting fields to adhere to e-mail standards.
	#

	#
	# Deal with attachments
	#

	#
	# Prepare for sending the message
	#

	# Configure Net::SMTP sending if that is requested..
	if ( $using =~ /^Net::SMTP$/i ) {
		# Unlike in previous implementations in IC, MV_SMTPHOST is not
		# required any more.
		my $smtphost = $::Variable->{MV_SMTPHOST} ||
			$Global::Variable->{MV_SMTPHOST};

		my $timeout = $::Variable->{MV_SMTP_TIMEOUT} ||
			$Global::Variable->{MV_SMTP_TIMEOUT} || 60;

		MIME::Lite->send('smtp', $smtphost ?
				($smtphost, $timeout) :
				($timeout) );

	} else { # (We know we're sending using sendmail now).

		# (-t was implicitly added for sendmail in all variants of this function
		# in IC, so let's keep this behavior here too).
		MIME::Lite->send('sendmail', $using . ' -t');
	}

	#logDebug('mime_lite_email will invoke MIME::Lite with ' .uneval($opt));

	#
	# Create message just with body, and add headers later.
	my $msg = new MIME::Lite (
		Data     => $data,
		Encoding => $encoding,
		Type     => $type,
	  ) or do {

		logError("Can't create MIME::Lite mail ($!).");
		return;
	};

	#
	# Fill in @headers with [ hdr_name, value ]
	my @headers;
	while (my($hdr,$values) = each %$opt ) {
		if (! ref $values ) {
			push @headers, [ $hdr, $values ];

		} elsif ( ref $values eq 'ARRAY' ) {
			for my $value (@$values ) { push @headers, [ $hdr, $value ] }

		} else {
			logError('Only scalars and array refs supported as header values.');
			return;
		}
	}

	#
	# Sanitize headers and add them to $msg object
	for my $hdr (@headers) {

		# [0] is name, [1] is value. Let's first work on header names
		$$hdr[0] =~ s/_/-/g;

		for my $template ( @accepted_headers ) {
			if ( $$hdr[0] =~ /^$template$/ ) {
				goto HEADER_NAME_VERIFIED;
			}
		}

		logError('Unknown email header name passed: ' . $$hdr[0]);
		return;

		# We jump here if header name is valid
		HEADER_NAME_VERIFIED: 

		# Now work on header value
	
		# Finally, header can go in.
		$msg->add($$hdr[0], $$hdr[1]);
	}

	#
	# Finally, send the whole message.
	#

	$msg->send;

	1;
}

###########################################################################
# Helper functions

1; 

# TODO:
# Attachments
# Header Word-encoding
# Compatibility functions
