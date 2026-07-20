# cache_control

Sets the `Cache-Control` HTTP response header that Interchange emits. Reach for
it to control browser and proxy caching of Interchange pages from the catalog
configuration.

**Default:** unset — no `Cache-Control` header is added by this pragma.

## Syntax

Catalog-wide, in `catalog.cfg`:

    Pragma cache_control=no-cache

Page-wide, anywhere in an Interchange page:

    [pragma cache_control max-age=3600]

Block-wide, around an Interchange Tag Language (ITL) block:

    [tag pragma cache_control]private, max-age=60[/tag]

The value is the literal header content (for example `no-cache`,
`max-age=3600`, `private`).

## Description

`get_cache_headers()` reads this pragma; when it has a value, Interchange adds a
`Cache-Control: VALUE` line to the response headers. The value is used verbatim,
so any valid `Cache-Control` directive string may be supplied.

The pragma value also feeds Interchange's cached-cookie suppression logic: when
[SuppressCachedCookies](../config/SuppressCachedCookies.md) is enabled, a
non-`POST` request whose `cache_control` value does **not** contain `no-cache` is
treated as cacheable, and `Set-Cookie` headers are suppressed to avoid caching a
user-specific cookie. Include `no-cache` in the value to keep cookies flowing.

## Examples

Mark pages as cacheable for an hour. In `catalog.cfg`:

    Pragma cache_control=max-age=3600

Prevent caching of a sensitive page:

    [pragma cache_control no-cache]

## Notes

Because the value is passed through literally, mistakes in the header string are
sent to the client as-is. There is no validation of the directive syntax.

## See also

- [x_accel_expires](x_accel_expires.md)
- [SuppressCachedCookies](../config/SuppressCachedCookies.md)
- [Pragma](../config/Pragma.md)

## Source

The `Pragma` directive is parsed by `boolean_value` in
`lib/Vend/Config.pm`. This pragma is consumed in `get_cache_headers()` and the
cached-cookie suppression logic in `lib/Vend/Server.pm`.
