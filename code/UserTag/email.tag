# Copyright 2002 Interchange Development Group (http://www.icdevgroup.org/)
# Licensed under the GNU GPL v2. See file LICENSE for details.
# $Id: email.tag,v 1.4 2004-10-14 20:07:36 docelic Exp $

UserTag email Order to subject reply from extra
UserTag email hasEndTag
UserTag email addAttr
UserTag email Interpolate
UserTag email Routine <<EOR
sub {
    my ($to, $subject, $reply, $from, $extra, $opt, $body) = @_;
    my $ok = 0;
    my @extra;

    $subject = '<no subject>' unless defined $subject && $subject;

    $reply = '' unless defined $reply;
    $reply = "Reply-to: $reply\n" if $reply;
	if (! $from) {
		$from = $Vend::Cfg->{MailOrderTo};
		$from =~ s/,.*//;
	}
	$extra =~ s/\s*$/\n/ if $extra;
        $extra .= "From: $from\n" if $from;
	@extra = grep /\S/, split(/\n/, $extra);

    SEND: {
            $ok = send_mail($to, $subject, $body, $reply, 0, @extra);
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

	return $opt->{hide} ? '' : $ok;
}
EOR

