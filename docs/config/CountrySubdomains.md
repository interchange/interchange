# CountrySubdomains

Teaches Interchange about country-code top-level domains (ccTLDs) so that
[DomainTail](DomainTail.md)-based visitor qualification uses the correct
registrable domain for hosts under those TLDs. Reach for it when you use
domain-based session or robot qualification and serve visitors from
countries whose ccTLDs use second-level registration (`co.uk`, `com.au`,
and the like).

**Scope:** global (`interchange.cfg`)

## Syntax

    CountrySubdomains  country_code "sub1 sub2 ..."  country_code "..."

A hash (`parse_hash`): each key is a ccTLD (for example `uk`), each value
a whitespace-separated list of the second-level labels used under it (for
example `co gov ac`). Multiple pairs may appear on one line, and the
directive accumulates across lines and here-documents. Default: empty.

## Description

With [DomainTail](DomainTail.md) enabled, Interchange derives a "domain
tail" from the visitor's hostname to qualify the session. For a host like
`machine.example.co.uk`, the naive tail `co.uk` is a public suffix, not a
real domain. Listing `co` under `uk` lets Interchange use
`example.co.uk` -- the actual registrable domain -- instead.

At the end of configuration each value is compiled into a case-insensitive
regular expression stored back in the same hash
(`$Global::CountrySubdomains->{$tld}`). At request time
`lib/Vend/Dispatch.pm` looks up the visitor's TLD and, if the host matches
the compiled pattern, takes one extra label into the domain tail.

Interchange ships a ready-made block of country definitions in
`dist/subdomains.cfg`. The usual practice is to `include` that file from
`interchange.cfg` rather than list every country by hand.

## Examples

Pull in the distributed definitions from `interchange.cfg`:

```
include subdomains.cfg
```

Define or extend entries directly, using a here-document for many
countries:

```
CountrySubdomains <<EOC
  uk "co gov ac org me net sch nhs police mod"
  au "com net org edu gov asn id"
  jp "co or ne ac ad ed go gr lg"
EOC
```

Add a couple of countries inline:

```
CountrySubdomains ar "com edu gov int mil net org" at "ac co gv or priv"
```

## Notes

Values are compiled to regexes only after the whole configuration is read,
so ordering among `CountrySubdomains` lines does not matter and later
lines add to (rather than replace) earlier keys with distinct TLDs. The
feature has no effect unless [DomainTail](DomainTail.md) is on.

## See also

[DomainTail](DomainTail.md), [IpHead](IpHead.md), [IpQuad](IpQuad.md),
[WideOpen](WideOpen.md), the [sessions](../guides/sessions.md) guide.

## Source

Parsed by `parse_hash` in `lib/Vend/Config.pm` and compiled to regexes in
its configuration postprocess; consumed via `$Global::CountrySubdomains`
in `lib/Vend/Dispatch.pm`.
