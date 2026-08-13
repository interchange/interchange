# cache_control

Sets the `Cache-Control` HTTP response header that Interchange emits. Reach for
it to control browser and proxy caching of Interchange pages from the catalog
configuration.

**Default:** unset — no `Cache-Control` header is added by this pragma.

## Syntax

Catalog-wide, in `catalog.cfg`:

    Pragma cache_control=no-cache

Page-wide or block-wide, anywhere in an Interchange page, with the value in
the tag body:

    [tag pragma cache_control]max-age=3600[/tag]
    [tag pragma cache_control]private, max-age=60[/tag]

The value is the literal header content (for example `no-cache`,
`max-age=3600`, `private`).

The short `[pragma NAME VALUE]` form cannot be used for most `Cache-Control`
values; see Notes.

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

    [tag pragma cache_control]no-cache[/tag]

## Notes

Because the value is passed through literally, mistakes in the header string are
sent to the client as-is. There is no validation of the directive syntax.

The short page-wide form `[pragma NAME VALUE]` does not work for most
`Cache-Control` values. That form is extracted by `vars_and_comments()` in
`lib/Vend/Interpolate.pm` with the regular expression
`\[pragma\s+(\w+)(?:\s+(\w+))?\]`, so the value must be a single word of
`\w` characters. Values containing `-` or `=` — which covers `no-cache`,
`no-store`, `max-age=3600`, and `must-revalidate` — do not match, the pragma
is left unset, and the tag text is not removed from the page. Only bare word
values such as `private` or `public` can be set this way. Use the
`[tag pragma cache_control]VALUE[/tag]` body form instead: it is handled at
runtime by `Vend::Interpolate::pragma()`, which takes the value from the tag
body verbatim.

In `catalog.cfg`, `Pragma` settings are split on whitespace and commas by
`parse_boolean_value()` before the `NAME=VALUE` pair is split on the first
`=`. So `Pragma cache_control=max-age=3600` works, but a value containing a
space or comma (such as `private, max-age=60`) does not — the remainder is
read as a further pragma setting. Set multi-directive values from a page with
the `[tag pragma]` body form.

## See also

- [x_accel_expires](x_accel_expires.md)
- [SuppressCachedCookies](../config/SuppressCachedCookies.md)
- [Pragma](../config/Pragma.md)

## Source

The `Pragma` directive is parsed by `boolean_value` in
`lib/Vend/Config.pm`. This pragma is consumed in `get_cache_headers()` and the
cached-cookie suppression logic in `lib/Vend/Server.pm`.
