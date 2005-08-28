# Copyright 2002 Interchange Development Group (http://www.icdevgroup.org/)
# Licensed under the GNU GPL v2. See file LICENSE for details.
# $Id: email.tag,v 1.7 2005-08-28 14:31:30 mheins Exp $

UserTag email Order to subject reply from extra
UserTag email hasEndTag
UserTag email addAttr
UserTag email Interpolate
UserTag email Routine <<EOR

my $Have_mime_lite;
BEGIN {
	require MIME::Lite;
	$Have_mime_lite = 1;
}

sub {
    my ($to, $subject, $reply, $from, $extra, $opt, $body) = @_;
    my $ok = 0;
    my @extra;

	use vars qw/ $Tag /;

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

	ATTACH: {
#::logDebug("Checking for attachment");
		last ATTACH unless $opt->{attach} || $opt->{html};

		my $att1_format;
		if($opt->{html}) {
			$opt->{mimetype} ||= 'multipart/alternative';
			$att1_format = 'flowed';
		}
		else {
			$opt->{mimetype} ||= 'multipart/mixed';
		}

		if(! $Have_mime_lite) {
			::logError("email tag: attachment without MIME::Lite installed.");
			last ATTACH;
		}
		my $att = $opt->{attach};
		my @attach;
		my @extra_headers;

		for(@extra) {
			m{(.*?):\s+(.*)};
			my $name = $1 or next;
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
			return $Tag->email_raw({}, $body);
		}
	}

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

