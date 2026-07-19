# DebugHost

Restricts `::logDebug()` output to requests coming from listed client IP
addresses. Reach for it on a shared or production server so debug tracing
fires only for your own address and not for every visitor.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    DebugHost  ip_range ...

Parsed by `parse_ip_address_regexp` into a compiled matcher. The value is
a whitespace-, comma-, or null-separated list of IP addresses and ranges
(including CIDR notation). Requires the Perl module
`Net::IP::Match::Regexp`. Default: empty (no host restriction).

## Description

When set, the debug routine in `lib/Vend/Util.pm` checks the requesting
client's address against the compiled matcher and returns without logging
if it does not match:

```perl
if(my $re = $Vend::Cfg->{DebugHost}) {
    return unless
        Net::IP::Match::Regexp::match_ip($CGI::remote_addr, $re);
}
```

So debug output is emitted only for requests from the listed addresses.
With `DebugHost` empty (the default) no host filtering is applied and
every request may produce debug output (subject to
[DebugFile](DebugFile.md) being set).

## Examples

Log debug output only for a local network and the loopback address:

```
DebugFile /tmp/debug
DebugHost 10.1.1.0/24 12.176.97.0/25 127.0.0.1
```

## Notes

`DebugHost` needs `Net::IP::Match::Regexp` installed; without it,
configuration of the directive fails. It narrows debug output but does not
turn it on -- [DebugFile](DebugFile.md) must still be set for any debug
logging to occur.

## See also

[DebugFile](DebugFile.md), [DebugTemplate](DebugTemplate.md),
[DataTrace](DataTrace.md), the
[logging-debugging](../guides/logging-debugging.md) guide.

## Source

Parsed by `parse_ip_address_regexp` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{DebugHost}` in `lib/Vend/Util.pm` (the `logDebug` routine).
