UserTag email_raw Documentation <<EOD

=head1 email-raw

This tag takes a raw email message, I<including headers>, and
uses the SendmailProgram with B<-t> option. Example:

	[email-raw]
	From: foo@bar.com
	To: bar@foo.com
	Subject: baz
    
	The text of the message.
	[/email-raw]

The headers must be at the beginning of the line, and the header
must have a valid C<To:> or it will not be delivered.

=cut

EOD

UserTag email-raw hasEndTag
UserTag email-raw addAttr
UserTag email-raw Interpolate
UserTag email-raw Routine <<EOR
sub {
    my($opt, $body) = @_;
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

    return $opt->{hide} ? '' : $ok;
}
EOR
