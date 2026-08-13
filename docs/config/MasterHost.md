# MasterHost

Restricts protected operations -- reconfiguration, protected databases, and
administrative functions -- to clients whose host name or IP matches a pattern.
Reach for it to lock privileged actions to a known workstation or network.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    MasterHost  regexp

A regular expression matched against the client's remote host name and remote
IP address, stored verbatim (no parser is run). Default: empty (no host
restriction from this directive).

## Description

Interchange's `check_security` routine in `lib/Vend/Util.pm` gates sensitive
operations: catalog reconfiguration, access to a protected database, and
administrative functions. When `MasterHost` is set, a request is allowed only
if the value matches the client. The pattern is anchored on both ends when
tested:

```perl
if (    $Vend::Cfg->{MasterHost}
        and
    (   $CGI::remote_host !~ /^($Vend::Cfg->{MasterHost})$/
        and
        $CGI::remote_addr !~ /^($Vend::Cfg->{MasterHost})$/  )   )
```

A request passes if either the remote host name or the remote IP matches;
otherwise the attempt is logged as an `ALERT` and denied. Because the value is
wrapped in `^(...)$`, write it as a regular expression -- escape the dots in a
literal IP.

`MasterHost` is one of three security checks (`MasterHost`,
[Password](Password.md), [RemoteUser](RemoteUser.md)); if none of the three is
configured, Interchange refuses the protected operation outright rather than
allowing it.

## Examples

Allow protected operations only from the local host:

```
MasterHost 127\.0\.0\.1
```

Allow a specific workstation by name or a specific IP:

```
MasterHost my\.workstation\.example\.com|192\.168\.7\.28
```

## Notes

`MasterHost` matches on `REMOTE_HOST`/`REMOTE_ADDR` as seen by Interchange.
Behind a proxy those may be the proxy's values unless the front end forwards
the real client address, so verify what your web server passes through before
relying on host matching.

## See also

[RemoteUser](RemoteUser.md), [Password](Password.md),
[AllowRemoteSearch](AllowRemoteSearch.md), the
[security](../guides/security.md) and [admin-ui](../guides/admin-ui.md) guides.

## Source

Stored unparsed (no `parse_*` routine) in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{MasterHost}` in `check_security` in `lib/Vend/Util.pm`.
