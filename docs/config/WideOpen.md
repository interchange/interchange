# WideOpen

Disables the IP-address check that ties a session to the client that
created it. Enabling it improves compatibility with clients whose IP address
changes between requests, at a real cost in session security.

**Scope:** catalog (`catalog.cfg`)

> **Security warning:** `WideOpen` weakens session security. With it on,
> anyone who obtains a valid session id can hijack that session. Leave it
> off unless you have a specific compatibility problem and are also using
> payment encryption or a real-time gateway.

## Syntax

    WideOpen  yes|no

A boolean (`yes`/`no`, `1`/`0`, `on`/`off`). Default: `No`.

## Description

Normally Interchange qualifies each session by the client's host/IP so a
stolen session id from a different address is rejected. When `WideOpen` is
enabled, that check is skipped: the host portion of the session cookie is set
to the literal `nobody`, and the per-request host comparison is bypassed
(`lib/Vend/Dispatch.pm`):

```perl
$CGI::host = 'nobody' if $Vend::Cfg->{WideOpen};
```

The option exists for environments where a client's apparent IP address
changes from one request to the next (some proxy pools, mobile networks, old
browsers), which would otherwise break the session on every hop.

## Examples

Enable it (in `catalog.cfg`):

```
WideOpen  Yes
```

## Notes

Because it removes a defense against session hijacking, only enable
`WideOpen` when clients genuinely experience session loss from changing IP
addresses, and pair it with encryption ([CreditCardAuto](CreditCardAuto.md)
/ PGP) or a real-time payment gateway so a hijacked session cannot expose
stored card data. See [DomainTail](DomainTail.md) and
[CountrySubdomains](CountrySubdomains.md) for related host-handling
directives.

## See also

[DomainTail](DomainTail.md), [CreditCardAuto](CreditCardAuto.md),
[CountrySubdomains](CountrySubdomains.md), [Promiscuous](Promiscuous.md),
the [sessions](../guides/sessions.md) and [security](../guides/security.md)
guides.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Dispatch.pm` (session-host qualification).
