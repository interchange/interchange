# Vend::Error - Handle Interchange error pages and messages
# 
# $Id: Error.pm,v 2.5 2002-09-16 23:06:31 mheins Exp $
#
# Copyright (C) 1996-2002 Red Hat, Inc. <interchange@redhat.com>
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

package Vend::Error;

use Vend::Util;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw (
				do_lockout
				full_dump
				get_locale_message
				interaction_error
				minidump
			);

use strict;

use vars qw/$VERSION/;

$VERSION = substr(q$Revision: 2.5 $, 10);

sub get_locale_message {
	my ($code, $message, @arg) = @_;
	if ($Vend::Cfg->{Locale} and defined $Vend::Cfg->{Locale}{$code}) {
		$message = $Vend::Cfg->{Locale}{$code};
	}
	elsif ($Global::Locale and defined $Global::Locale->{$code}) {
		$message = $Global::Locale->{$code};
	}
	elsif ($Vend::Cfg->{Locale} and -f "$Global::ConfDir/$code.html" ) {
		$message = readfile("$Global::ConfDir/$code.$::Scratch->{mv_locale}");
	}
	elsif (-f "$Global::ConfDir/$code.html") {
		$message = readfile("$Global::ConfDir/$code.html");
	}
	if($message !~ /\s/) {
		if($message =~ /^http:/) {
			$Vend::StatusLine =~ s/([^\r\n])$/$1\r\n/;
			$Vend::StatusLine .= "Status: 302 Moved\r\nLocation: $message\r\n";
			$message = "Redirected to $message.";
		}
		else {
			my $tmp = readin($message);
			$message = $tmp if $tmp;
		}
	}
	return sprintf($message, @arg);
}

## INTERFACE ERROR

# An incorrect response was returned from the browser, either because of a
# browser bug or bad html pages.

sub interaction_error {
    my($msg) = @_;
    my($page);

    logError( "Difficulty interacting with browser: %s", $msg );

    $page = readin(find_special_page('interact'));
    if (defined $page) {
		$page =~ s#\[message\]#$msg#ig;
		::response(::interpolate_html($page, 1));
    }
	else {
		logError( "Missing special page: interact" , '');
		::response("$msg\n");
    }
}

sub minidump {
	my $out = <<EOF;
Full client host name:  $CGI::remote_host
Full client IP address: $CGI::remote_addr
Query string was:       $CGI::query_string
EOF
	for(qw/browser last_url/) {
		$out .= "$_: $Vend::Session->{$_}\n";
	}

	for(keys %{$Vend::Session->{carts}} ) {
		next if ! $Vend::Session->{carts}->{$_};
		$out .= scalar @{$Vend::Session->{carts}->{$_}};
		$out .= " items in $_ cart.\n";
	}
	return $out;
}

sub full_dump {
	my $portion = shift;
	my $out = '';
	if($portion) {
		$out .= "###### SESSION ($portion) #####\n";
		$out .= uneval($Vend::Session->{$portion});
		$out .= "\n###### END SESSION    #####\n";
		$out =~ s/\0/\\0/g;
		return $out;
	}

	$out = minidump();
	local($Data::Dumper::Indent) = 2;
	$out .= "###### ENVIRONMENT     #####\n";
	if(my $h = ::http()) {
		$out .= uneval($h->{env});
	}
	else {
		$out .= uneval(\%ENV);
	}
	$out .= "\n###### END ENVIRONMENT #####\n";
	$out .= "###### CGI VALUES      #####\n";
	$out .= uneval(\%CGI::values);
	$out .= "\n###### END CGI VALUES  #####\n";
	$out .= "###### SESSION         #####\n";
	$out .= uneval($Vend::Session);
	$out .= "\n###### END SESSION    #####\n";
	$out =~ s/\0/\\0/g;
	return $out;
}

sub do_lockout {
	my ($cmd);
	my $msg = shift || '';
	if($cmd = $Global::LockoutCommand) {
		my $host = $CGI::remote_addr;
		$cmd =~ s/%s/$host/ or $cmd .= " $host";
		$msg .= errmsg("Performing lockout command '%s'", $cmd);
		system $cmd;
		$msg .= errmsg("\nBad status %s from '%s': %s\n", $?, $cmd, $!)
			if $?;
		logGlobal({level => 'notice'}, $msg);
	}
	$Vend::Cfg->{VendURL} = $Vend::Cfg->{SecureURL} = 'http://127.0.0.1';
	logError($msg);
}

1;
