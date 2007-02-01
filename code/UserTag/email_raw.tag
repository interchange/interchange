# Copyright 2002-2005 Interchange Development Group (http://www.icdevgroup.org/)
# Licensed under the GNU GPL v2. See file LICENSE for details.
# $Id: email_raw.tag,v 1.7 2007-02-01 08:21:50 ton Exp $

UserTag email-raw hasEndTag
UserTag email-raw addAttr
UserTag email-raw Interpolate
UserTag email-raw Version     $Revision: 1.7 $
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
	my $using = $Vend::Cfg->{SendMailProgram};

	if (lc $using eq 'none') {
		$ok = 1;
		last SEND;
	} elsif (lc $using eq 'net::smtp') {
		$body =~ s/^(.+?)(?:\r?\n){2}//s;
		my $headers = $1;
		last SEND unless $headers;
		my @head = split(/\r?\n/,$headers);
		$ok = send_mail(\@head,$body);
	} else {
		open(Vend::MAIL,"|$using -t") or last SEND;
		print Vend::MAIL $body
			or last SEND;
		close Vend::MAIL
			or last SEND;
		$ok = ($? == 0);
	}
    }

    if (!$ok) {
        ::logError("Unable to send mail using $Vend::Cfg->{SendMailProgram}\n" .
            "Message follows:\n\n$body");
    }

    return $opt->{hide} ? '' : $ok;
}
EOR
