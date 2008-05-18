# Vend::Email - Handle Interchange email functions
# 
# $Id: Email.pm,v 1.11 2007-12-28 11:47:51 racke Exp $
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

#
# This module consists of the main e-mail sending function
# (tag_mime_lite_email) and wrappers which preserve compatibility and
# make traditional Interchange's mail functions use it, instead of 
# sending mail in the old way(s).
#
# Copies of some of the old functions are also included (and modified
# to fit the picture), to be called when no useful wrapper code
# can be made.
#
# TODO:
# Header Word-encoding
#

package Vend::Email;

my $Have_MIME_Lite;

BEGIN {
	eval {
		require MIME::Lite;
		$Have_MIME_Lite = 1;
	};
}

use Mail::Address     qw//;
use MIME::QuotedPrint qw//; # Used by default
use MIME::Base64      qw//; # For user-specified encodings

use Vend::Util        qw/logError logDebug uneval/;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw (
		);

use strict;
use warnings;

use vars qw/$VERSION/;

$VERSION = substr(q$Revision: 1.11 $, 10);


###########################################################################
# Direct functions
#

#
# The main mail-sending function. You will mostly use it through
# sub send_mail() and tag email, but you can also call it directly:
#
# tag_mime_lite_email({
#   option-name => option-val, ...,
#   hdr-name => hdr-val, ...,
#
#   data => $body, OR
#   body => $body, OR
# }, $body);
#
# Valid options are:
#   interpolate, reparse, intercept, header_encoding, encoding, type
#
# Data (message body) can be specified as one of:
#   $opt->{data} || $opt->{body} || $_[1] (arg 2)
#
sub tag_mime_lite_email {
	my ($optin, $body) = @_;
	my ($opt);
	
	#::logDebug('mime_lite_email invoked, OPT=' .uneval($optin) . ' BODY=' . $body);

	local $_;

	#
	# See if we'll be sending this email, don't waste time if not.
	#
	my $using = $Vend::Cfg->{SendMailProgram};
	if ($using =~ /^none$/i ) {
		::logError('Unable to send email, config option SendMailProgram=none.');
		return;
	}
	#
	# Copy option hash to avoid messing with caller's data
	#

	%$opt = %$optin;

	#
	# Quickly make sure that all options and header names satisfy basic rules.
	# (We need to do this in any case, so let's do it up-front). Also turn
	# them all to lowercase. (Mime-Lite does proper reformatting before sending).
	# And also weed out hash keys with empty values.
	#
	for my $key ( keys %$opt ) {
		my $lckey = lc $key;

		# Remove empty options/headers and lowercase options/headers
		# that should be preserved.
		if (!defined $opt->{$key} or !length( $opt->{$key} )) {
			delete $opt->{$key};
			next;
		} elsif ( $lckey eq $key ) {
			next;
		} else {
			$opt->{$lckey} = $opt->{$key};
			delete $opt->{$key};
		}
	}

	#
	# Deal with tag-specific options that are not to be understood as headers.
	# (Save them to variables and delete them from $opt so that after this
	# block, only headers are left in $opt).
	#
	# This also includes the extra_headers= option, which must process here
	# if we want to allow its values to influence the to/from/subject/reply-to
	# options. Normally this does not happen since those fields are specified
	# standalone as options to tag_mime_lite_email, but for compatibility
	# it is useful that those values can come from @extra_headers as well.
	# (Values from @extra_headers are included only if standalone options
	# are empty, otherwise a warning in error log is produced).
	#

	my $intercept;
	my $hdr_encoding;
	my ($interpolate, $reparse, $hide);
	my ($data, $encoding, $type, $charset);
	my @extra_headers;

	# Intercept
	if ( $_ = delete $opt->{intercept} ) {
		$intercept = $_;
	}

	# XXX Header word-encoding: currently inactive block.
	# All e-mail headers need to be Word-Encoded if they contain non-ASCII.
	# Field names themselves must not be encoded, they're always in English.
	# Header_encoding can be 1|y|none|q|b|a|s:
	# - '1' and 'y' are our special synonyms for 'q'.
	# - 'none' is our special value for no encoding
	# - the rest are actual supported values by MIME::EncWords.
	#if ( $_ = delete $opt->{'header_encoding'} ) {
	#	$hdr_encoding = $_;
	#}
	#if (! $hdr_encoding or $hdr_encoding =~ /1|y/i ) {
	#	$hdr_encoding = 'q';
	#}
	#$hdr_encoding eq 'none' and $hdr_encoding = '';

	# Interpolate/reparse
	($interpolate, $reparse, $hide) = (
		delete $opt->{interpolate},
		delete $opt->{reparse},
		delete $opt->{hide},
	);

	# Data (msg body), encoding and type
	($data, $encoding, $type, $charset) = (
		delete $opt->{data},
		delete $opt->{encoding},
		delete $opt->{type},
		delete $opt->{charset},
	);
	$data     ||= $opt->{body} || $body;    delete $opt->{body};
	$encoding ||= 'quoted-printable';
	$type     ||= 'text/plain';
	$charset  ||= $::Variable->{MV_EMAIL_CHARSET} || $Global::Variable->{MV_EMAIL_CHARSET};

	if ($charset) {
		$type .= "; charset=$charset";
	}
	
	!(ref $data or ref $encoding or ref $type) or do {
		::logError('Only scalar value accepted for options '.
				'"data" ("body"), "encoding" and "type".');
		return;
	};

	# Extra e-mail headers. Turn them into array first.
	if ( $_ = delete $opt->{extra_headers} ) {
		if (! ref ) {
			for (grep /\S/, split /[\r\n]+/, $_) {
				push @extra_headers, $_
			}
		} elsif ( ref eq 'ARRAY' ) {
			@extra_headers = @$_
		} else {
			::logError('Only a scalar or an array reference accepted as '.
				'extra_headers value.');
			return;
		}
	}

	# Then perform general sanity checks.
	for ( my $i =0; $i < @extra_headers; $i++ ) {
		$_ = $extra_headers[$i];

		# require header conformance with RFC 2822 section 2.2
		unless ( /^([\x21-\x39\x3b-\x7e]+):[\x00-\x09\x0b\x0c\x0e-\x7f]+$/ ) {
			::logError("Invalid header given to tag_mime_lite_email: %s", $_);
			return;
		}

		# Allow the four specific headers to influence values which
		# are usually passed as standalone options, outside of text headers.
		if ( $1 =~ /^(to|from|subject|reply-to)$/i ) {
			my $lchdr = lc $1; $lchdr =~ s/-/_/g;

			if (! $opt->{$lchdr} ) {
				$opt->{$lchdr} = $_;
			} else {
				::logError("Value for '$lchdr' already provided (= %s). " .
					'Ignoring new value %s.', $opt->{$lchdr}, $_);
			}
		}
	}

	#
	# Let's see specified headers now, check them and/or associate defaults.
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
				::logError('Only scalar value accepted for option or '.
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
			::logError('Only scalars or array refs supported as options ' .
				'to tag_mime_lite_email().');
			return;
		}
	}

	#
	# Now check specific headers for specific values, and/or give defaults.

	# TO
	if (!( $opt->{to} and @{ $opt->{to} } )) {
		::logError('mime_lite_email called without the required to= option.');
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
		::logError('Cannot find value for From: header. Make sure ' .
			'that MailOrderTo config directive or MV_MAILFROM variable ' .
			'is specified.');
	};

	# SUBJECT
	if (! $opt->{subject} ) {
		$opt->{subject} = '<no subject>';
	}

	# REPLY
	if (!( $opt->{reply_to} and @{ $opt->{reply_to} } )) {
		$opt->{reply_to} = [$::Values->{email}];
		
		if (ref($opt->{reply})) {
			$opt->{reply_to} = $opt->{reply};
		} elsif ($opt->{reply}) {
			$opt->{reply_to} = [$opt->{reply}];
		}
	}
	delete $opt->{reply};

	#
	# Now let's work on adjusting headers to adhere to e-mail standards.
	#

	# Prevent header injections from spammers' hostile content
	for ( @{ $opt->{to} }, @{ $opt->{reply_to} },
			  $opt->{subject}, $opt->{from}           ) {

		# unfold valid RFC 2822 "2.2.3. Long Header Fields"
		s/\r?\n([ \t]+)/$1/g;
		# now remove any invalid extra lines left over
		s/[\r\n](.*)//s and do {
			::logError("Header injection attempted in tag_mime_lite_email: %s", $1);
			return;
		};
	}

	#
	# Support e-mail interception (re-writing to/cc/bcc to specified
	# address(es)).
	#
	$intercept ||= $::Variable->{MV_EMAIL_INTERCEPT} ||
		$Global::Variable->{MV_EMAIL_INTERCEPT};

	if ( $intercept && $Have_MIME_Lite) {
		for my $field (qw/to cc bcc/) {
			if ( $opt->{$field} ) {
				for $_ ( @{ $opt->{$field} } ) {
					::logError('Intercepting outgoing email (%s: %s) ' .
							'and instead sending to "%s"',
							$field, $_, $intercept);

					$opt->{$field} = $intercept;
					push @{ $opt->{"x-intercepted-$field"} }, $_;
				}
			}
		}
	}

	#
	# Deal with attachments
	# (For the moment, only attach= option is supported, which should be
	# either a scalar (filename), or a hashref (data for one attachment),
	# or an arrayref (list of hashrefs - multiple attachments). Internally,
	# whatever you pass will be converted to a list of hashrefs.
	#

	my $att = $opt->{attach};
	if ( $att ) {

		# Make sure $att is list of hashrefs
		if(! ref($att) ) {
			my $fn = $att;
			$att = [ { path => $fn } ];
		}
		elsif( ref($att) eq 'HASH' ) {
			$att = [ $att ];
		}

		$att ||= [];

		my %encoding_types = (
			'text/plain' => '8bit',
			'text/html' => 'quoted-printable',
			);

		# Now each hashref is suitable to be passed to $msg->attach(...).
		for (my $i = 0; $i < @$att; $i++) {
			my $ref = $$att[$i];

			if (! $ref ) {
				delete $$att[$i];
				next;
			};

			unless ( $ref->{path} or $ref->{data} ) {
				::logError('Attachment specified without path or data. Skipping.');
				delete $$att[$i];
				next;
			};

			unless ($ref->{filename}) {
				my $fn = $ref->{path};
				$fn =~ s:.*[\\/]::;
				$ref->{filename} = $fn;
			}

			$ref->{type} ||= 'AUTO';
			$ref->{disposition} ||= 'attachment';
			$ref->{encoding} ||= $encoding_types{$ref->{type}};
		}
	}

	unless ($Have_MIME_Lite) {
		my ($to, $subject, $reply_to, @extra, $header);

		$to = delete $opt->{to};
		$subject = delete $opt->{subject};
		$reply_to = delete $opt->{reply_to};
		
		for (keys %$opt) {
			$header = ucfirst($_);
			
			if (ref($opt->{$_}) eq 'ARRAY') {
				push(@extra, "$header: " . join(',', @{$opt->{$_}}));
			} else {
				push(@extra, "$header: $opt->{$_}");
			}
		}

		return send_mail_legacy(join(',', @$to),
								$subject,
								$data,
								join(',', @$reply_to),
								0,
								@extra);		
	}
	
	#
	# Prepare for sending the message
	#

	# Configure Net::SMTP sending if that is requested..
	if ( $using =~ /^Net::SMTP$/i ) {
		# Unlike in previous implementations in IC, MV_SMTPHOST is not required.
		# (Net::SMTP gets to figure out the host).
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

	#::logDebug('mime_lite_email will invoke MIME::Lite with ' .uneval($opt));

	#
	# Create message just with body, and add headers later.
	my $msg = new MIME::Lite (
		Data     => $data,
		Encoding => $encoding,
		Type     => $type,
	  ) or do {

		::logError("Can't create MIME::Lite mail ($!).");
		return;
	};

	#
	# Fill in @headers with [ hdr_name, value ], and append with
	# @extra_headers
	my @headers;
	while (my($hdr,$values) = each %$opt ) {
		next if $hdr eq 'attach';
		
		if (! ref $values ) {
			push @headers, [ $hdr, $values ];

		} elsif ( ref $values eq 'ARRAY' ) {
			for my $value (@$values ) { push @headers, [ $hdr, $value ] }

		} else {
			::logError('Only scalars and array refs supported as header values.');
			return;
		}
	}
	push @headers, @extra_headers;

	#
	# Add headers to $msg object
	for my $hdr (@headers) {

		# [0] is name, [1] is value.
		$$hdr[0] =~ s/_/-/g;

		# Finally, header can go in.
		$msg->add($$hdr[0], $$hdr[1]);
	}

	#
	# Add attachments to $msg object
	for my $ref (@$att) {
		$msg->attach( 
			Type => $ref->{type},
			Path => $ref->{path},
			Data => $ref->{data},
			Filename => $ref->{filename},
			Encoding => $ref->{encoding},
			Disposition => $ref->{disposition},
		);
	}

	#
	# Finally, send the whole message.
	#

	$msg->send;

	1;
}

###########################################################################
# Wrapper functions
#

# When send_mail is used normally, we can replace it with the new
# variant (tag_mime_lite_email). However, when headers are passed as
# text mixed with body, we don't want to deal with it. We call the original
# function to do the work, and issue a warning message to encourage
# reimplementation on client side.
#
sub send_mail {

	# See if this is the type of message we don't provide
	# any compatiblity for, and thus call the original implementation.
	if ( ref $_[0] or
			looks_like_email_header (\$_[1]) or
			looks_like_email_header (\$_[2]) ) {
	
		::logError('Using legacy send_mail() because manually- or ' .
			'"tag op=mime"-generated headers were detected within message body.');

		return send_mail_legacy( @_ );
	}

	# Good, this is the type we *can* rework.
	my($to, $subject, $body, $reply) = @_;

	tag_mime_lite_email({ to => $to, subject => $subject,
			reply => $reply, extra_headers => $_[5] }, $body);
}

###########################################################################
# Old functions, preserved more or less as-is. To be called when no
# useful compatibility wrapper can be made.
#

# Vend::Util::send_mail
sub send_mail_legacy {
	my($to, $subject, $body, $reply, $use_mime, @extra_headers) = @_;

	if(ref $to) {
		my $head = $to;

		for(my $i = $#$head; $i > 0; $i--) {
			if($head->[$i] =~ /^\s/) {
				my $new = splice @$head, $i, 1;
				$head->[$i - 1] .= "\n$new";
			}
		}

		$body = $subject;
		undef $subject;
		for(@$head) {
			s/\s+$//;
			if (/^To:\s*(.+)/si) {
				$to = $1;
			}
			elsif (/^Reply-to:\s*(.+)/si) {
				$reply = $_;
			}
			elsif (/^subj(?:ect)?:\s*(.+)/si) {
				$subject = $1;
			}
			elsif($_) {
				push @extra_headers, $_;
			}
		}
	}

	# If configured, intercept all outgoing email and re-route
	if (
		my $intercept = $::Variable->{MV_EMAIL_INTERCEPT}
		                || $Global::Variable->{MV_EMAIL_INTERCEPT}
	) {
		my @info_headers;
		$to = "To: $to";
		for ($to, @extra_headers) {
			next unless my ($header, $value) = /^(To|Cc|Bcc):\s*(.+)/si;
			::logError(
				"Intercepting outgoing email (%s: %s) and instead sending to '%s'",
				$header, $value, $intercept
			);
			$_ = "$header: $intercept";
			push @info_headers, "X-Intercepted-$header: $value";
		}
		$to =~ s/^To: //;
		push @extra_headers, @info_headers;
	}

	my($ok);
#::logDebug("send_mail: to=$to subj=$subject r=$reply mime=$use_mime\n");

	unless (defined $use_mime) {
		$use_mime = $::Instance->{MIME} || 0;
	}

	if(!defined $reply) {
		$reply = $::Values->{mv_email}
				?  "Reply-To: $::Values->{mv_email}\n"
				: '';
	}
	elsif ($reply) {
		$reply = "Reply-To: $reply\n"
			unless $reply =~ /^reply-to:/i;
		$reply =~ s/\s+$/\n/;
	}

	$ok = 0;
	my $none;
	my $using = $Vend::Cfg->{SendMailProgram};

	if($using =~ /^(none|Net::SMTP)$/i) {
		$none = 1;
		$ok = 1;
	}

	SEND: {
#::logDebug("testing sendmail send none=$none");
		last SEND if $none;
#::logDebug("in Sendmail send $using");
		open(MVMAIL,"|$Vend::Cfg->{SendMailProgram} -t") or last SEND;
		my $mime = '';
		$mime = Vend::Interpolate::mime('header', {}, '') if $use_mime;
		print MVMAIL "To: $to\n", $reply, "Subject: $subject\n"
			or last SEND;
		for(@extra_headers) {
			s/\s*$/\n/;
			print MVMAIL $_
				or last SEND;
		}
		$mime =~ s/\s*$/\n/;
		print MVMAIL $mime
			or last SEND;
		print MVMAIL $body
				or last SEND;
		print MVMAIL Vend::Interpolate::do_tag('mime boundary') . '--'
			if $use_mime;
		print MVMAIL "\r\n\cZ" if $Global::Windows;
		close MVMAIL or last SEND;
		$ok = ($? == 0);
	}

	SMTP: {
		my $mhost = $::Variable->{MV_SMTPHOST} || $Global::Variable->{MV_SMTPHOST};
		my $helo =  $Global::Variable->{MV_HELO} || $::Variable->{SERVER_NAME};
		last SMTP unless $none and $mhost;
		eval {
			require Net::SMTP;
		};
		last SMTP if $@;
		$ok = 0;
		$using = "Net::SMTP (mail server $mhost)";
#::logDebug("using $using");
		undef $none;

		my $smtp = Net::SMTP->new($mhost, Debug => $Global::Variable->{DEBUG}, Hello => $helo);
#::logDebug("smtp object $smtp");

		my $from = $::Variable->{MV_MAILFROM}
				|| $Global::Variable->{MV_MAILFROM}
				|| $Vend::Cfg->{MailOrderTo};
		
		for(@extra_headers) {
			s/\s*$/\n/;
			next unless /^From:\s*(\S.+)$/mi;
			$from = $1;
		}
		push @extra_headers, "From: $from" unless (grep /^From:\s/i, @extra_headers);
		push @extra_headers, 'Date: ' . POSIX::strftime('%a, %d %b %Y %H:%M:%S %Z', localtime(time())) unless (grep /^Date:\s/i, @extra_headers);

		my $mime = '';
		$mime = Vend::Interpolate::mime('header', {}, '') if $use_mime;
		$smtp->mail($from)
			or last SMTP;
#::logDebug("smtp accepted from=$from");

		my @to;
		my @addr = split /\s*,\s*/, $to;
		for (@addr) {
			if(/\s/) {
				## Uh-oh. Try to handle
				if ( m{( <.+?> | [^\s,]+\@[^\s,]+ ) }x ) {
					push @to, $1
				}
				else {
					::logError("Net::SMTP sender skipping unparsable address %s", $_);
				}
			}
			else {
				push @to, $_;
			}
		}
		
		@addr = $smtp->recipient(@to, { SkipBad => 1 });
		if(scalar(@addr) != scalar(@to)) {
			::logError(
				"Net::SMTP not able to send to all addresses of %s",
				join(", ", @to),
			);
		}

#::logDebug("smtp accepted to=" . join(",", @addr));

		$smtp->data();

		push @extra_headers, $reply if $reply;
		for ("To: $to", "Subject: $subject", @extra_headers) {
			next unless $_;
			s/\s*$/\n/;
#::logDebug(do { my $it = $_; $it =~ s/\s+$//; "datasend=$it" });
			$smtp->datasend($_)
				or last SMTP;
		}

		if($use_mime) {
			$mime =~ s/\s*$/\n/;
			$smtp->datasend($mime)
				or last SMTP;
		}
		$smtp->datasend("\n");
		$smtp->datasend($body)
			or last SMTP;
		$smtp->datasend(Vend::Interpolate::do_tag('mime boundary') . '--')
			if $use_mime;
		$smtp->dataend()
			or last SMTP;
		$ok = $smtp->quit();
	}

	if ($none or !$ok) {
		::logError("NONE eq $none, OK eq $ok\n");
		::logError("Unable to send mail using %s\nTo: %s\nSubject: %s\n%s\n\n%s",
				$using,
				$to,
				$subject,
				$reply,
				$body,
		);
	}

	$ok;
}

# Vend::Interpolate::tag_mail
# This function does not need a wrapper like send_mail() above because
# it calls send_mail() in the end anyway, and no real sending work is done here.
sub tag_mail {
    my($to, $opt, $body) = @_;
    my($ok);

	my @todo = (
					qw/
						From      
						To		   
						Subject   
						Reply-To  
						Errors-To 
					/
	);

	my $abort;
	my $check;

	my $setsub = sub {
		my $k = shift;
		return if ! defined $CGI::values{"mv_email_$k"};
		$abort = 1 if ! $::Scratch->{mv_email_enable};
		$check = 1 if $::Scratch->{mv_email_enable};
		return $CGI::values{"mv_email_$k"};
	};

	my @headers; # Will contain to/subject/reply_to
	my @extra_headers; # Will contain from/errors_to + eventual manual headers..
	my %found;   # Hash in form of ( header_name => header_val )

	unless($opt->{raw}) {
		for my $header (@todo) {
			::logError("invalid email header: %s", $header)
				if $header =~ /[^-\w]/;
			my $key = lc $header;
			$key =~ tr/-/_/;
			my $val = $opt->{$key} || $setsub->($key); 

			# Redundant: done in tag_mime_lite_email()
			#if($key eq 'subject' and ! length($val) ) {
			#	$val = errmsg('<no subject>');
			#}

			next unless length $val;

			$val =~ s/^\s+//;
			$val =~ s/\s+$//;
			$val =~ s/[\r\n]+\s*(\S)/\n\t$1/g;

			$found{$key} = $val;

			push @extra_headers, "$header: $val" if
				$header =~ /^(from|errors_to)$/;
		}
		unless($found{to} or $::Scratch->{mv_email_enable} =~ /\@/) {
			return
				error_opt($opt, "Refuse to send email message with no recipient.");
		}
		elsif (! $found{to}) {
			$::Scratch->{mv_email_enable} =~ s/\s+/ /g;
			$found{to} = $::Scratch->{mv_email_enable};

			push @headers, "To: $::Scratch->{mv_email_enable}";
		}
	}

	if($opt->{extra}) {
		$opt->{extra} =~ s/^\s+//mg;
		$opt->{extra} =~ s/\s+$//mg;
		push @extra_headers, grep /^\w[-\w]*:/, split /\n/, $opt->{extra};
	}

	$body ||= $setsub->('body');
	unless($body) {
		return error_opt($opt, "Refuse to send email message with no body.");
	}

	$body = format_auto_transmission($body) if ref $body;

	return error_opt("mv_email_enable not set, required.") if $abort;
	if($check and $found{to} ne $::Scratch->{mv_email_enable}) {
		return error_opt(
				"mv_email_enable to address (%s) doesn't match enable (%s)",
				$found{to},
				$::Scratch->{mv_email_enable},
			);
	}

    SEND: {
		# This will use tag_mime_lite_email, unless $body contains headers.
		$ok = send_mail_legacy(
			$found{to}, $found{subject}, $body, $found{reply_to},
			0, @extra_headers );
		}

    if (!$ok) {
		close MVMAIL;
		$body = substr($body, 0, 2000) if length($body) > 2000;
        return error_opt(
					"Unable to send mail using %s\n%s",
					$Vend::Cfg->{SendMailProgram},
					join("\n", @headers, @extra_headers, '', $body),
				);
	}

	delete $::Scratch->{mv_email_enable} if $check;
	return if $opt->{hide};
	return join("\n", @headers, @extra_headers, '', $body) if $opt->{show};
	return ($opt->{success} || $ok);
}

# code/UserTag/email.tag
sub tag_email {
	my ($to, $subject, $reply, $from, $extra, $opt, $body) = @_;
	my $ok = 0;
	my @extra;
	my $att;
	
	use vars qw/ $Tag /;
	
	ATTACH: {
		#::logDebug("Checking for attachment");
		last ATTACH unless $opt->{attach} || $opt->{html};

		unless ($Have_MIME_Lite) {
			::logError("email tag: attachment without MIME::Lite installed.");
			last ATTACH;
		}

		if($opt->{html}) {
			$opt->{mimetype} ||= 'multipart/alternative';
		}
		else {
			$opt->{mimetype} ||= 'multipart/mixed';
		}

		my $vtype = ref($opt->{attach});

		if ($vtype) {
			if ($vtype eq 'HASH') {
				$att = [ $opt->{attach} ];
			}
			elsif ($vtype eq 'ARRAY') {
				$att = $opt->{attach};
			}
		}
		else {
			if ($opt->{attach}) {
				$att = [ { path => $opt->{attach} } ];
			}
		}

		$att ||= [];

		if($opt->{html}) {
			unshift @$att, {
				type => 'text/html',
				data => $opt->{html},
				disposition => 'inline',
			};
		}
	}

	$ok = tag_mime_lite_email({
		to => $to,
		from => $from || '',
		subject => $subject || '',
		cc => $opt->{cc} || '',
		reply => $reply || '',
		type => $opt->{body_mime} || 'text/plain',
		charset => $opt->{charset},
		extra_headers => \@extra || [],
		encoding => $opt->{body_encoding} || '8bit',
		attach => $att || ''
	}, $body);

	if (!$ok) {
		::logError("Unable to send mail using tag_mime_lite_email\n" .
				"To '$to'\n" .
				"From '$from'\n" .
				"With extra headers '$extra'\n" .
				"With reply-to '$reply'\n" .
				"With subject '$subject'\n" .
				"And body:\n$body");
	}

	return $opt->{hide} ? '' : $ok;
}


###########################################################################
# Helper functions

# Vend::Util::send_mail function used to sometimes receive body
# which contains headers as well (usually coming as a result of
# Vend::Interpolate::mime() processing). Figure out if this is the
# case.

sub looks_like_email_header {
	if ( ${$_[0]} =~ /^\n*--[\w-]+?:=\d+\nContent-/s ) { return 1 }
	0;
}

sub format_auto_transmission {
	my $ref = shift;

## Auto-transmission from Vend::Data::update_data
## Looking for structure like:
##
##	[ '### BEGIN submission from', 'ckirk' ],
##	[ 'username', 'ckirk' ],
##	[ 'field2', 'value2' ],
##	[ 'field1', 'value1' ],
##	[ '### END submission from', 'ckirk' ],
##	[ 'mv_data_fields', [ username, field1, field2 ]],
##

	return $ref unless ref($ref);

	my $body = '';
	my %message;
	my $header  = shift @$ref;
	my $fields  = pop   @$ref;
	my $trailer = pop   @$ref;

	$body .= "$header->[0]: $header->[1]\n";

	for my $line (@$ref) {
		$message{$line->[0]} = $line->[1];
	}

	my @order;
	if(ref $fields->[1]) {
		@order = @{$fields->[1]};
	}
	else {
		@order = sort keys %message;
	}

	for (@order) {
		$body .= "$_: ";
		if($message{$_} =~ s/\r?\n/\n/g) {
			$body .= "\n$message{$_}\n";
		}
		else {
			$body .= $message{$_};
		}
		$body .= "\n";
	}

	$body .= "$trailer->[0]: $trailer->[1]\n";
	return $body;
}

1; 

