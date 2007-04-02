# Vend::Email - Handle Interchange email functions
#
# $Id: Email.pm,v 1.1 2007-04-02 17:10:19 docelic Exp $
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
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA  02110-1301  USA.

package Vend::Email;

use MIME::Lite        qw//;
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

$VERSION = substr(q$Revision: 1.1 $, 10);


###########################################################################
# Direct functions
#

# Directly pass input as options to create MIME::Lite object,
# fill it with data, and invoke send. Basically the majority of
# work here is filling unspecified fields with defaults, nothing
# more. We also honor Interchange's setting of SendmailProgram.
sub tag_mime_lite_email {
	my ($opt, $body) = @_;
#logDebug('mime_lite_email invoked with OPT=' .uneval($opt) . ' BODY=' . $body);

#
# See if we'll be sending this email, don't waste time if not.
#
	my $using = $Vend::Cfg->{SendMailProgram};
	if ($using =~ /^none/i ) {
		logError('Unable to send email to "%s", SendMailProgram=none.',$opt->{to});
		return;
	}

#
# Let's work on defaults and rough value verification
#

# Turn all options (which are mostly email header field names)
# to Upper-Case. (for example, message_id into Message-Id).
	while (my($k,$v) = each %$opt ) {
		( my $nk = $k ) =~ s/_(\S)/'-'.ucfirst($1)/ge;
		$nk = ucfirst $nk;

		next if $k eq $nk;
		$opt->{$nk} = $v;
		delete $opt->{$k};
	}

	$opt->{Data} ||= $opt->{Body} || $body;
	delete $opt->{Body};

	if (! $opt->{To} ) {
		logError('mime_lite_email called without the required to= option.');
		return;
	}

	if (! $opt->{Type} ) {
		$opt->{Type} = 'text/plain';
	}

	if (! $opt->{Encoding} ) {
		$opt->{Encoding} = 'quoted-printable';
	}

	if (! $opt->{From} ) {
		$opt->{From} = $::Variable->{MV_MAILFROM} ||
			$Global::Variable->{MV_MAILFROM} ||
			$Vend::Cfg->{MailOrderTo};
	}

	if (! $opt->{Subject} ) {
		$opt->{Subject} = '<no subject>';
	}

	if ($opt->{Reply} ) {
		logError('Both reply and reply-to specified.') if $opt->{'Reply-To'};
		$opt->{'Reply-To'} = $opt->{Reply};
		delete $opt->{Reply};
	}

#
# Support e-mail interception
#

	my $intercept = $::Variable->{MV_EMAIL_INTERCEPT} ||
		$Global::Variable->{MV_EMAIL_INTERCEPT};
	
	if ( $intercept ) {
		local $_;
		for my $field (qw/To Cc Bcc/) {
			if ( $_ = $opt->{$field} ) {
				logDebug("Intercepted $field: $_ in favor of $intercept.");
				$opt->{$field} = $intercept;
				$opt->{"X-Intercepted-$field"} = $_;
			}
		}
	}
	
#
# Now let's work on adjusting fields to adhere to e-mail standards.
#

# All e-mail headers need to be Word-Encoded if they contain
# non-ASCII. Field names themselves must not be encoded, so put through
# encoder only header data that does not include header names.
# header_encoding can be 1|y|none|q|b|a|s . '1' and 'y' are our special
# synonyms for 'q'. 'none' is our special value for no encoding, and
# the rest are actual supported values by MIME::EncWords.

	if (! $opt->{'Header-Encoding'} ) {
		$opt->{'Header-Encoding'} = 'q';

	} elsif ( $opt->{'Header-Encoding'} ne /^none$/i ) {
		if ($opt->{'Header-Encoding'}=~/1|y/i){$opt->{'Header-Encoding'}='q'}

	}

	my $copt; # Will contain full data to pass to MIME::Lite->new
		while (my($k,$v) = each %$opt ) {

# List all hash keys that are not options for MIME::Lite
			next if $k =~ /^(Header\-Encoding|Attachment|Interpolate|Reparse)$/i;

# Encode-word everything except 'Data' which is message body and has its
# own set of rules... (Disabled until I troubleshoot it).
			#if ( $opt->{'Header-Encoding'} and $k ne 'Data' ) {
			#	$v = MIME::EncWords::encode_mimewords($v,
			#			Encoding => $opt->{'Header-Encoding'} );
			#}

			$copt->{$k} = $v;
		}

#
# And finally, prepare for sending the message
#

# Configure Net::SMTP sending if that is requested..
	if ( $using =~ /^Net::SMTP$/i ) {
# Unlike in previous implementations in IC, MV_SMTPHOST is not
# required any more.
		my $smtphost = $::Variable->{MV_SMTPHOST} ||
			$Global::Variable->{MV_SMTPHOST};

		my $timeout = $::Variable->{MV_SMTP_TIMEOUT} ||
			$Global::Variable->{MV_SMTP_TIMEOUT} || 60;

		MIME::Lite->send('smtp', $smtphost ? ($smtphost, $timeout) : ($timeout) );

	} else { # (We know we're sending using sendmail now).

# (-t was implicitly added for sendmail in all variants of this function in IC,
# so let's keep this behavior here too).
		MIME::Lite->send('sendmail', $using . ' -t');
	}

	#logDebug('mime_lite_email will invoke MIME::Lite with ' .uneval($copt));

#
# Finally, send.
#

	my $msg = new MIME::Lite ( %$copt ) or do {
		logError("Can't create MIME::Lite mail ($!).");
		return;
	};

	$msg->send or do {
		logError("Created, but can't send MIME::Lite mail ($!).");
		return;
	}

}

1; 

# TODO:
# Attachments
# Header Word-encoding
# Compatibility functions
