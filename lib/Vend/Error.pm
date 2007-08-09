# Vend::Error - Handle Interchange error pages and messages
# 
# $Id: Error.pm,v 2.15 2007-08-09 13:40:53 pajamian Exp $
#
# Copyright (C) 2002-2007 Interchange Development Group
# Copyright (C) 1996-2002 Red Hat, Inc.
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
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA  02110-1301  USA.

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

$VERSION = substr(q$Revision: 2.15 $, 10);

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
		::interpolate_html($page, 1);
		::response();
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
	my $opt = shift || {};
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
	unless ($opt->{no_env}) {
		$out .= "###### ENVIRONMENT     #####\n";
		if(my $h = ::http()) {
			$out .= uneval($h->{env});
		}
		else {
			$out .= uneval(\%ENV);
		}
		$out .= "\n###### END ENVIRONMENT #####\n";
	}
	unless($opt->{no_cgi}) {
		my %cgi = %CGI::values;
		unless($opt->{show_all}) {
			for(@Global::HideCGI) {
				delete $cgi{$_};
			}
		}
		$out .= "###### CGI VALUES      #####\n";
		$out .= uneval(\%cgi);
		$out .= "\n###### END CGI VALUES  #####\n";
	}
	unless($opt->{no_session}) {
		$out .= "###### SESSION         #####\n";
		$out .= uneval($Vend::Session);
		$out .= "\n###### END SESSION    #####\n";
	}
	$out =~ s/\0/\\0/g;
	return $out;
}

sub do_lockout {
	my ($cmd);
	my $msg = '';

	# If the lockout SpecialSub exists, it is run. If it returns 
	# true, we return now. If it returns false, we run the lockout
	# as normal.
	if (my $subname = $Vend::Cfg->{SpecialSub}{lockout}) {
		::logDebug(errmsg("running subroutine '%s' for lockout", $subname));
		my $sub = $Vend::Cfg->{Sub}{$subname} || $Global::GlobalSub->{$subname};
		my $status;
		eval {
			$status = $sub->();
		};

		if($@) {
			::logError("Error running lockout subroutine %s: %s", $subname, $@);
		}

		return $status if $status;
	}

	# Now we log the error after custom lockout routine gets chance
	# to bypass 
	my $pause = $::Limit->{lockout_reset_seconds} || 30;
	my $msg = errmsg(
		"WARNING: POSSIBLE BAD ROBOT. %s accesses with no %d second pause.",
		$Vend::Session->{accesses},
		$pause,
	);
	::logError($msg);

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
	$Vend::LockedOut = 1;
	logError($msg) if $msg;
	return;
}

1;
