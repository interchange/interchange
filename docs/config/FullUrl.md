# FullUrl

Includes the request hostname when Interchange decides which catalog a request
belongs to. Reach for it when several catalogs must share the same script path
(for example each served from its own domain's root) on one Interchange server.

**Scope:** global (`interchange.cfg`)

## Syntax

    FullUrl  yes|no

A boolean (`yes`/`no`, `1`/`0`, `on`/`off`). Default: `No`.

## Description

Interchange normally selects the catalog for a request from the CGI
`SCRIPT_NAME` alone. A request for `www.example.com/cat1` has script name
`/cat1`; a request for `www.example.com` has script name `/`. Because only one
catalog can own a given script name, two domains cannot both serve their pages
from `/`.

With `FullUrl` enabled, Interchange prepends the server hostname to the script
name before matching, so the effective key becomes hostname plus script path.
Catalogs are then distinguished by domain as well as path, letting several
sites share one script name.

The setting is read at startup and applied while mapping each request. When it
is on, the port is normally kept as part of the hostname unless
[FullUrlIgnorePort](FullUrlIgnorePort.md) is also set.

## Examples

Enable hostname-aware catalog selection in `interchange.cfg`:

```
FullUrl yes
```

With it on, [Catalog](Catalog.md) lines must include the hostname in their
script specification:

```
FullUrl yes

Catalog  mystore  /path/to/catalogs/mystore/  www.example.com/cgi-bin/mystore
```

## Notes

`FullUrl` and non-`FullUrl` [Catalog](Catalog.md) definitions are not
compatible: when you turn `FullUrl` on, you must update *every* `Catalog` line
in `interchange.cfg` to include the hostname, or those catalogs will no longer
match. See [FullUrlIgnorePort](FullUrlIgnorePort.md) to drop the port from the
comparison.

## See also

[FullUrlIgnorePort](FullUrlIgnorePort.md), [Catalog](Catalog.md),
[SubCatalog](SubCatalog.md), [Mall](Mall.md), the
[configuration](../guides/configuration.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Server.pm` (`map_misc_cgi`, which prefixes the hostname onto
`SCRIPT_NAME`) and `lib/Vend/Dispatch.pm`.
