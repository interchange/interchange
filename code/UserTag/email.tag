# Copyright 2002-2007 Interchange Development Group and others
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.  See the LICENSE file for details.
# 
# $Id: email.tag,v 1.14 2007-03-30 23:40:56 pajamian Exp $

UserTag email Order to subject reply from extra
UserTag email hasEndTag
UserTag email addAttr
UserTag email Interpolate
UserTag email Routine <<EOR

my $Have_mime_lite;
BEGIN {
	eval {
		require MIME::Lite;
		$Have_mime_lite = 1;
	};
}

sub {
    my ($to, $subject, $reply, $from, $extra, $opt, $body) = @_;
    my $ok = 0;
    my @extra;

	use vars qw/ $Tag /;

    $subject = '<no subject>' unless defined $subject && $subject;

	if (! $from) {
		$from = $Vend::Cfg->{MailOrderTo};
		$from =~ s/,.*//;
	}

	# Prevent header injections from spammers' hostile content
	for ($to, $subject, $reply, $from) {
		# unfold valid RFC 2822 "2.2.3. Long Header Fields"
		s/\r?\n([ \t]+)/$1/g;
		# now remove any invalid extra lines left over
		s/[\r\n](.*)//s
			and ::logError("Header injection attempted in email tag: %s", $1);
	}

    $reply = '' unless defined $reply;
    $reply = "Reply-to: $reply\n" if $reply;

	for (grep /\S/, split /[\r\n]+/, $extra) {
		# require header conformance with RFC 2822 section 2.2
		push (@extra, $_), next if /^[\x21-\x39\x3b-\x7e]+:[\x00-\x09\x0b\x0c\x0e-\x7f]+$/;
		::logError("Invalid header given to email tag: %s", $_);
	}
	unshift @extra, "From: $from" if $from;

	my $sent_with_attach = 0;

	ATTACH: {
#::logDebug("Checking for attachment");
		last ATTACH unless $opt->{attach} || $opt->{html};

		unless ($Have_mime_lite) {
			::logError("email tag: attachment without MIME::Lite installed.");
			last ATTACH;
		}

		my $att1_format;
		if($opt->{html}) {
			$opt->{mimetype} ||= 'multipart/alternative';
			$att1_format = 'flowed';
		}
		else {
			$opt->{mimetype} ||= 'multipart/mixed';
		}

		my $att = $opt->{attach};
		my @attach;
		my @extra_headers;

		for(@extra) {
			m{(.*?):\s+(.*)};
			my $name = $1 or next;
			next if lc($name) eq 'from';
			my $content = $2 or next;
			$name =~ s/[-_]+/-/g;
			$name =~ s/\b(\w)/\U$1/g;
			push @extra_headers, "$name:", $content;
		}

		my $msg = new MIME::Lite 
					To => $to,
					From => $from,
					Subject => $subject,
					Type => $opt->{mimetype},
					Cc => $opt->{cc},
					@extra_headers,
				;
		$opt->{body_mime} ||= 'text/plain';
		$opt->{body_encoding} ||= '8bit';
		$msg->attach(
				Type => $opt->{body_mime},
				Encoding => $opt->{body_encoding},
				Data => $body,
				Disposition => $opt->{body_disposition} || 'inline',
				Format => $opt->{body_format} || $att1_format,
			);

		if(! ref($att) ) {
			my $fn = $att;
			$att = [ { path => $fn } ];
		}
		elsif(ref($att) eq 'HASH') {
			$att = [ $att ];
		}

		$att ||= [];

		if($opt->{html}) {
			unshift @$att, {
								type => 'text/html',
								data => $opt->{html},
								disposition => 'inline',
							};
		}

		my %encoding_types = (
			'text/plain' => '8bit',
			'text/html' => 'quoted-printable',
		);

		for my $ref (@$att) {
			next unless $ref;
			next unless $ref->{path} || $ref->{data};
			unless ($ref->{filename}) {
				my $fn = $ref->{path};
				$fn =~ s:.*[\\/]::;
				$ref->{filename} = $fn;
			}

			$ref->{type} ||= 'AUTO';
			$ref->{disposition} ||= 'attachment';

			if(! $ref->{encoding}) {
				$ref->{encoding} = $encoding_types{$ref->{type}};
			}
			eval {
				$msg->attach(
					Type => $ref->{type},
					Path => $ref->{path},
					Data => $ref->{data},
					Filename => $ref->{filename},
					Encoding => $ref->{encoding},
					Disposition => $ref->{disposition},
				);
			};
			if($@) {
				::logError("email tag: failed to attach %s: %s", $ref->{path}, $@);
				next;
			}
		}

		my $body = $msg->as_string;
#::logDebug("Mail body: \n$body");
		if($opt->{test}) {
			return $body;
		}
		else {
			$body =~ s/^(.+?)(?:\r?\n){2}//s;
			my $headers = $1;
			last SEND unless $headers;
			my @head = split(/\r?\n/,$headers);

			$ok = send_mail(\@head,$body);

			$sent_with_attach = 1;
		}
	}

	$ok = send_mail($to, $subject, $body, $reply, 0, @extra)
			unless $sent_with_attach;

    if (!$ok) {
        logError("Unable to send mail using $Vend::Cfg->{SendMailProgram}\n" .
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

