# AlwaysSecureGlob

Marks pages as secure-only by wildcard pattern rather than by exact name,
so whole directories or prefixes are served over HTTPS. Reach for it when
you want every page under an area (for example the admin UI) to use
`SecureURL`.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    AlwaysSecureGlob  pattern ...

A list of DOS-style wildcard patterns (`*`, `?`, `{a,b}`), compiled into a
single fully anchored, case-insensitive regular expression. Default:
empty.

## Description

`AlwaysSecureGlob` is the pattern-matching counterpart to `AlwaysSecure`.
The patterns are compiled to one anchored regex (`^(...)$`). When
Interchange builds a link (`vendUrl` in `lib/Vend/Util.pm`), a page path
matching that regex is generated with the catalog's `SecureURL` base,
producing an `https://` link, exactly as an exact `AlwaysSecure` match
would.

## Examples

Force every admin, certificate, and UI page onto HTTPS, from the strap
demo `catalog.cfg`:

```
AlwaysSecureGlob   <<EOD
	admin*,
	cert*,
	ui*,
EOD
```

## Notes

Because the compiled expression is fully anchored, a pattern must describe
the whole page path: `admin*` matches `admin` and `admin/user` but a bare
`admin` (no `*`) would match only the exact name `admin`. Use `*` to cover
everything beneath a prefix.

Like `AlwaysSecure`, this affects generated links and -- with
`ExtraSecure` -- enforcement, but it does not configure the web server's
TLS.

## See also

[AlwaysSecure](AlwaysSecure.md), [ExtraSecure](ExtraSecure.md), [SecureURL](SecureURL.md), the
[security](../guides/security.md) guide.

## Source

Parsed by `parse_list_wildcard_full` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{AlwaysSecureGlob}` in `lib/Vend/Util.pm`.
