# Copyright 2002-2007 Interchange Development Group and others
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.
# 
# $Id: email.tag,v 1.2.2.1 2007-03-31 11:33:19 pajamian Exp $

UserTag email Order       to subject reply from extra
UserTag email hasEndTag
UserTag email addAttr
UserTag email Interpolate
UserTag email Version     $Revision: 1.2.2.1 $
UserTag email Routine     <<EOR
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
