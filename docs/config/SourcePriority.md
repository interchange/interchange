# SourcePriority

Lists, in priority order, the CGI variables (and special sources) Interchange
checks to find the visitor's source, or affiliate, name. The first one that
yields a value wins.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    SourcePriority  ENTRY [ENTRY ...]

The value is a whitespace/comma-separated list that **replaces** any previous
value (parser type `array_complete`). Default: `mv_pc mv_source`.

Each entry is checked in turn:

- a plain name -- read the CGI variable of that name; the first non-empty one
  becomes the source.
- `mv_pc` -- read the affiliate name from the `mv_pc` variable, but ignore its
  reserved values (`RESET`, or an all-digit page counter).
- `cookie-NAME` -- read the cookie labeled `NAME`.
- `session` -- stop looking if a session already exists for the visitor. This
  keeps an affiliate from getting credit when a returning customer follows a
  banner back to a site they already have a session on.
- `session-NAME` -- stop looking if the session variable `NAME` is set.

## Description

On each request Interchange walks the `SourcePriority` list and takes the
source from the first entry that produces a value. The resolved source is stored
in the session and, when [SourceCookie](SourceCookie.md) is configured, written
to a cookie so it survives later visits.

The `session` and `session-NAME` entries act as short-circuits rather than
sources: they let you decide, for returning visitors, whether a new affiliate
may overwrite an existing association.

## Examples

Check a CGI variable and then a cookie:

```
SourcePriority mv_source cookie-MV_SOURCE
```

Prefer an existing session, so affiliates do not steal credit for returning
customers, but still accept `mv_pc` or `mv_source` for genuinely new visits:

```
SourcePriority session mv_pc mv_source
```

Read the affiliate id from a custom CGI variable named `affid`:

```
SourcePriority affid
```

## See also

[SourceCookie](SourceCookie.md), [Cookies](Cookies.md),
[BounceReferrals](BounceReferrals.md).

## Source

Parsed by `parse_array_complete` in `lib/Vend/Config.pm` (stored in
`$Vend::Cfg->{SourcePriority}`); consumed in the source-resolution loop in
`lib/Vend/Dispatch.pm`.
