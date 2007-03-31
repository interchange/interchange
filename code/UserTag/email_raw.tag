# Copyright 2002-2007 Interchange Development Group and others
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.
# 
# $Id: email_raw.tag,v 1.6.2.1 2007-03-31 00:20:18 pajamian Exp $

UserTag email-raw hasEndTag
UserTag email-raw addAttr
UserTag email-raw Interpolate
UserTag email-raw Version     $Revision: 1.6.2.1 $
UserTag email-raw Routine     <<EOR
sub {
    my($opt, $body) = @_;
    my($ok);
    $body =~ s/^\s+//;

	# If configured, intercept all outgoing email and re-route
	if (
		my $intercept = $::Variable->{MV_EMAIL_INTERCEPT}
		                || $Global::Variable->{MV_EMAIL_INTERCEPT}
	) {
		$body =~ s/\A(.*?)\r?\n\r?\n//s;
		my $header_block = $1;
		# unfold valid RFC 2822 "2.2.3. Long Header Fields"
		$header_block =~ s/\r?\n([ \t]+)/$1/g;
		my @headers;
		for (split /\r?\n/, $header_block) {
			if (my ($header, $value) = /^(To|Cc|Bcc):\s*(.+)/si) {
				logError(
					"Intercepting outgoing email (%s: %s) and instead sending to '%s'",
					$header, $value, $intercept
				);
				$_ = "$header: $intercept";
				push @headers, "X-Intercepted-$header: $value";
			}
			push @headers, $_;
		}
		$body = join("\n", @headers) . "\n\n" . $body;
	}

    SEND: {
        open(Vend::MAIL,"|$Vend::Cfg->{SendMailProgram} -t") or last SEND;
        print Vend::MAIL $body 
            or last SEND;
        close Vend::MAIL
            or last SEND;
        $ok = ($? == 0);
    }

    if (!$ok) {
        ::logError("Unable to send mail using $Vend::Cfg->{SendMailProgram}\n" .
            "Message follows:\n\n$body");
    }

    return $opt->{hide} ? '' : $ok;
}
EOR
