# x_accel_expires

Sets the `X-Accel-Expires` HTTP response header, which controls how long an nginx
reverse proxy caches the response. Reach for it when Interchange sits behind nginx
proxy caching and you want per-response cache lifetimes.

**Default:** unset — no `X-Accel-Expires` header is added.

## Syntax

Catalog-wide, in `catalog.cfg`:

    Pragma x_accel_expires=3600

Page-wide, anywhere in an Interchange page:

    [pragma x_accel_expires 60]

Block-wide, around an Interchange Tag Language (ITL) block:

    [tag pragma x_accel_expires]0[/tag]

The value is the literal header content (typically a number of seconds, or `0`
to disable proxy caching for the response).

## Description

`get_cache_headers()` reads this pragma; when it is defined and non-empty,
Interchange adds an `X-Accel-Expires: VALUE` line to the response headers. nginx
uses this header, when configured to honor it, to decide how long to cache the
proxied response — overriding the cache time it would otherwise derive from
`Cache-Control` or `Expires`.

The value is emitted verbatim. A length check means an empty value adds no
header, but `0` is a meaningful value that tells nginx not to cache the response.

## Examples

Let nginx cache catalog pages for an hour. In `catalog.cfg`:

    Pragma x_accel_expires=3600

Disable proxy caching for one dynamic page:

    [pragma x_accel_expires 0]

## Notes

Added in Interchange 5.12. This header only has effect when the fronting nginx is
configured to honor `X-Accel-Expires` (via `proxy_cache` with the default
`proxy_ignore_headers` behavior).

## See also

- [cache_control](cache_control.md)
- [Pragma](../config/Pragma.md)

## Source

The `Pragma` directive is parsed by `boolean_value` in
`lib/Vend/Config.pm`. This pragma is consumed in `get_cache_headers()` in
`lib/Vend/Server.pm`.
