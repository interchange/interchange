UserTag email_raw Documentation <<EOD

This tag takes a raw email message, *including headers*, and
users the SendmailProgram with -t option. Example:

[email-raw]
From: foo@bar.com
To: bar@foo.com
Subject: baz

The text of the message.
[/email-raw]

The headers must be at the beginning of the line, and the header
must have a valid To: or it will not be delivered.

EOD

UserTag email-raw hasEndTag
UserTag email-raw Interpolate
UserTag email-raw Routine <<EOR
sub {
    my($body) = @_;
    my($ok);
    $body =~ s/^\s+//;

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
    $ok;
}
EOR
