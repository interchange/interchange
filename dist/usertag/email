UserTag email Order to subject reply from extra
UserTag email hasEndTag
UserTag email Interpolate
UserTag email Routine <<EOR
sub {
    my($to, $subject, $reply, $from, $extra, $body) = @_;
    my($ok);

    $subject = '<no subject>' unless defined $subject && $subject;

    $reply = '' unless defined $reply;
    $reply = "Reply-to: $reply\n" if $reply;
	if (! $from) {
		$from = $Vend::Cfg->{MailOrderTo};
		$from =~ s/,.*//;
	}

	$extra =~ s/\s*$/\n/ if $extra;
    $ok = 0;
    SEND: {
        open(Vend::MAIL,"|$Vend::Cfg->{SendMailProgram} -t") or last SEND;
        print Vend::MAIL
			"To: $to\n",
			"From: $from\n",
			$reply,
			$extra || '',
			"Subject: $subject\n\n",
			$body
            or last SEND;
        close Vend::MAIL or last SEND;
        $ok = ($? == 0);
    }

    if (!$ok) {
        logError("Unable to send mail using $Vend::Cfg->{'SendMailProgram'}\n" .
            "To '$to'\n" .
            "From '$from'\n" .
            "With extra headers '$extra'\n" .
            "With reply-to '$reply'\n" .
            "With subject '$subject'\n" .
            "And body:\n$body");
    }
    $ok;
}
EOR
