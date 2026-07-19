# ExtraSecure

Blocks non-HTTPS access to pages listed under [AlwaysSecure](AlwaysSecure.md).
Reach for it to guarantee that pages you have marked secure are never served
over plain HTTP.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    ExtraSecure  yes|no

A yes/no boolean (`yes`/`no`, `1`/`0`, `on`/`off`, `true`/`false`). Default:
`No`.

## Description

Pages named in [AlwaysSecure](AlwaysSecure.md) are meant to be delivered over
HTTPS. With `ExtraSecure` enabled, a request for such a page that does not
arrive over a secure connection is refused: instead of the requested page,
Interchange serves the `violation` special page (`lib/Vend/Page.pm`). With
`ExtraSecure` off, an insecure request for an always-secure page is not blocked
at this level.

## Examples

Enforce HTTPS for always-secure pages in `catalog.cfg`:

```
AlwaysSecure  checkout ord/checkout login
ExtraSecure   Yes
```

## Notes

`ExtraSecure` only enforces the pages listed in
[AlwaysSecure](AlwaysSecure.md); it does not by itself make any page secure. Pair
it with a correctly configured [SecureURL](SecureURL.md) so the secure versions
of those pages resolve.

## See also

[AlwaysSecure](AlwaysSecure.md), [AlwaysSecureGlob](AlwaysSecureGlob.md),
[SecureURL](SecureURL.md), the [security](../guides/security.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Page.pm` (`$Vend::Cfg->{ExtraSecure}`).
