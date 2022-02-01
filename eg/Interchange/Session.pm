package Interchange::Session;

# Interchange::Session
# Adapted from various existing Interchange core code
# by Jon Jensen <jon@endpointdev.com>, December 2016
#
# Can be used, for example, in a global ActionMap to read a common file
# session read-only, without locking and opening that session the usual way.
# Of course utmost care should be taken to not allow arbitrary sessions to
# be read, nor possibly sensitive data revealed from those sessions.

use strict;
use warnings;
use utf8;
use Vend::Util ();

# This function reads a session from disk without affecting any in-memory session details

sub read_cookie_session {
    #::logDebug("in read_cookie_session");
    # adapted from &Vend::Dispatch::dispatch
    unless ($CGI::cookie
        and $::Instance->{CookieName} ||= 'MV_SESSION_ID'
        and $CGI::cookie =~ /\b$::Instance->{CookieName}=(\w{8,32})(?:[:_]|%3[aA])([-\@.:A-Za-z0-9]+)/a
    ) {
        ::logDebug("No session cookie found");
        return;
    }

    my ($id, $host) = ($1, $2);
    #::logDebug("id=$id host=$host");
    unless (Vend::Util::is_ipv4($host)
        or Vend::Util::is_ipv6($host)
        or $host =~ /[A-Za-z0-9][-\@A-Za-z.0-9]+/a
    ) {
        ::logDebug("Ignoring invalid session cookie: $CGI::cookie");
        return;
    }

    # adapted from &Vend::Session::session_name
    my $session_name = $id . ':' . $host;
    #::logDebug("session_name=$session_name");

    # adapted from &Vend::Session::read_session
    Vend::Session::open_session();
    my $s;
    $s = $Vend::SessionDBM{$session_name}
        or $Global::Variable->{MV_SESSION_READ_RETRY}
        and do {
            my $i = 0;
            my $tries = $Global::Variable->{MV_SESSION_READ_RETRY} + 0 || 5;
            while($i++ < $tries) {
                ::logDebug("Retrying session $id read on undef, try $i");
                $s = $Vend::SessionDBM{$session_name};
                next unless $s;
                ::logDebug("Session $id re-read successfully on try $i");
                last;
            }
        };
    return unless $s;

    my $session = ref $s ? $s : Vend::Util::evalr($s);
    if ($@) {
        ::logError("Could not eval '$s' from session $id: $@");
        return;
    }

    # adapted from &Vend::Dispatch::dispatch
    # (use stricter IP matching test even when a cookie is present, given higher-security situation here)
    my $compare_host = $CGI::secure ? $session->{shost} : $session->{ohost};
    if ($compare_host ne $CGI::remote_addr) {
        ::logDebug("Rejecting attempt to read session $id for IP address $compare_host from IP address $CGI::remote_addr");
        return;
    }

    my $time = time();
    #::logDebug("time=$time session time=" . $session->{'time'} . " SessionExpire=" . $Vend::Cfg->{SessionExpire} . " diff=" . ($time - $session->{'time'}));
    my $time_diff = $time - $session->{'time'};
    if ($time_diff > $Vend::Cfg->{SessionExpire}) {
        ::logDebug("Rejecting attempt to use session $id expired by $time_diff seconds");
        return;
    }

    return $session;
}

1;
