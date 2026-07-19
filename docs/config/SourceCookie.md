# SourceCookie

Enables a cookie that persists the visitor's source (affiliate) name across
visits, and sets that cookie's name, lifetime, and scope. Pair it with
[SourcePriority](SourcePriority.md), which decides where the source value comes
from.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    SourceCookie  name=NAME [expire=WHEN] [domain=DOMAIN] [path=PATH] [secure=1]

or, positionally, in this fixed order:

    SourceCookie  NAME [EXPIRE [DOMAIN [PATH [SECURE]]]]

The value is parsed as ordered attributes: either shell-quoted `key=value`
pairs, or bare values assigned to `name`, `expire`, `domain`, `path`, `secure`
in that order. Default: empty (no source cookie is written). The attributes:

- `name` -- the cookie's name. Setting this is what activates the feature;
  with no `name`, no cookie is written.
- `expire` -- the cookie lifetime (a time expression such as `30 days`).
- `domain` -- the cookie domain.
- `path` -- the cookie path.
- `secure` -- when true, marks the cookie secure (HTTPS only).
- `autoreset` -- when true, rewrites the cookie on every request so its
  expiration is pushed forward each time the visitor returns. Available only in
  the `key=value` form.

## Description

On each request, after [SourcePriority](SourcePriority.md) determines the
current source, Interchange writes it into the source cookie when `name` is set.
The cookie is (re)written when a new source is found, when the stored cookie
differs from the session's source, or -- if `autoreset` is on -- whenever a
source value is present, so that returning visitors keep their affiliate
association alive.

When `mv_pc` arrives with the special value `RESET`, the source is cleared and
the cookie is expired.

## Examples

Store the source in a cookie named `MV_SOURCE` for 30 days:

```
SourceCookie name=MV_SOURCE expire="30 days"
```

Scope the cookie to a domain and refresh its expiration on every visit:

```
SourceCookie name=MV_SOURCE expire="30 days" domain=.example.com autoreset=1
```

The same cookie in positional form (name, then expire):

```
SourceCookie MV_SOURCE "30 days"
```

## See also

[SourcePriority](SourcePriority.md), [Cookies](Cookies.md),
[CookieDomain](CookieDomain.md), [BounceReferrals](BounceReferrals.md).

## Source

Parsed by `parse_ordered_attributes` (order `name expire domain path secure`)
in `lib/Vend/Config.pm` (stored in `$Vend::Cfg->{SourceCookie}`); consumed in
`lib/Vend/Dispatch.pm`, where the cookie is set and expired.
