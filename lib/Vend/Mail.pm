#!/usr/bin/perl
#
# $Id: Mail.pm,v 1.1.2.1 2000-11-07 23:06:22 zarko Exp $
#
# Copyright (C) 1996-2000 Akopia, Inc. <info@akopia.com>
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

package Vend::Mail;
require Exporter;

$VERSION = substr(q$Revision: 1.1.2.1 $, 10);

@ISA = qw(Exporter);

@EXPORT = qw (
	send_compat
);

sub send_compat {
	my($to, $subject, $body, $reply, $use_mime, @extra_headers) = @_;
	my($ok);
#::logDebug("Vend::Mail::send: to=$to subj=$subject r=$reply mime=$use_mime\n");

	unless (defined $use_mime) {
		$use_mime = $::Instance->{MIME} || undef;
	}

	if(!defined $reply) {
		$reply = $::Values->{mv_email}
				?  "Reply-To: $::Values->{mv_email}\n"
				: '';
	} elsif($reply) {
		$reply = "Reply-To: $reply\n"
			unless $reply =~ /^reply-to:/i;
		$reply =~ s/\s+$/\n/;
	}

	$ok = 0;
	my $none;

	if("\L$Vend::Cfg->{SendMailProgram}" eq 'none') {
		$none = 1;
		$ok = 1;
	}

	SEND: {
		last SEND if $none;
		open(MVMAIL,"|$Vend::Cfg->{SendMailProgram} $to") or last SEND;
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

	if($none or !$ok) {
		logError("Unable to send mail using %s\nTo: %s\nSubject: %s\n%s\n\n%s",
				$Vend::Cfg->{SendMailProgram},
				$to,
				$subject,
				$reply,
				$body,
		);
	}

	$ok;
}
