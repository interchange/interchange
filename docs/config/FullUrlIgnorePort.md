# FullUrlIgnorePort

Strips the port number from the hostname when [FullUrl](FullUrl.md) catalog
selection is in effect. Reach for it when Interchange sees a `host:port` server
name (behind a proxy, or on a non-standard port) but you want catalog matching
to ignore the port.

**Scope:** global (`interchange.cfg`)

## Syntax

    FullUrlIgnorePort  yes|no

A boolean (`yes`/`no`, `1`/`0`, `on`/`off`). Default: `No`.

## Description

When [FullUrl](FullUrl.md) is enabled, Interchange prepends the server hostname
to the script name to choose a catalog. If the server host arrives with a port
appended (`www.example.com:8080`), that port becomes part of the match key and
can prevent a `Catalog` line written for the bare hostname from matching.

With `FullUrlIgnorePort` enabled, Interchange removes the `:port` suffix from
the hostname before it is used -- both when building the effective script name
and when computing catalog cookie paths -- so matching is done on the hostname
alone.

This directive only has an effect when `FullUrl` is on. It is read at startup
and applied while mapping each request.

## Examples

Ignore the port during hostname-based catalog selection (`interchange.cfg`):

```
FullUrl yes
FullUrlIgnorePort yes
```

A request to `www.example.com:8080/cgi-bin/mystore` now matches a `Catalog`
line written for `www.example.com/cgi-bin/mystore`.

## See also

[FullUrl](FullUrl.md), [Catalog](Catalog.md), [Mall](Mall.md), the
[configuration](../guides/configuration.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Server.pm` (`map_misc_cgi`, which strips `:.*` from the server host)
and `lib/Vend/Dispatch.pm`.
