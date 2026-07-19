# UTF8

Enables server-wide UTF-8 handling: when on, Interchange treats configured
character data as UTF-8 and applies encoding conversions. Reach for it to
run a Unicode catalog; it is on by default.

**Scope:** global (`interchange.cfg`)

## Syntax

    UTF8  yes|no

A boolean (`yes`/`no`, `1`/`0`, `on`/`off`). Default: `Yes` -- unless the
environment variable `MINIVEND_DISABLE_UTF8` is set at startup, in which
case the default is `No`.

## Description

`UTF8` sets the global flag `$Global::UTF8`, which gates the server's
character-encoding routines. When it is true, `lib/Vend/CharSet.pm` will
decode and encode text according to the active encoding, and utilities in
`lib/Vend/Util.pm` treat strings as wide characters where appropriate:

```perl
return $octets unless $encoding and $Global::UTF8 and validate_encoding($encoding);
```

The flag is read at startup; it is not a per-catalog switch (catalogs opt
into character conversion through the `MV_UTF8` and `MV_HTTP_CHARSET`
[Variable](Variable.md) settings, which the code validates against the
global flag).

## Examples

Explicitly enable UTF-8 in `interchange.cfg` (the default):

```
UTF8  Yes
```

Turn it off for a byte-oriented (Latin-1) installation:

```
UTF8  No
```

A catalog then declares its own encoding in `catalog.cfg`:

```
Variable  MV_UTF8          1
Variable  MV_HTTP_CHARSET  UTF-8
```

## Notes

Setting `MINIVEND_DISABLE_UTF8` in the environment before Interchange starts
flips the default off without editing `interchange.cfg` -- useful for a
quick fallback. If a catalog sets `MV_HTTP_CHARSET`, Interchange validates
that encoding at configuration time and aborts the catalog if it is
unrecognized.

## See also

[Variable](Variable.md), [XHTML](XHTML.md), the
[internationalization](../guides/internationalization.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm` (stored in
`$Global::UTF8`); consumed by `lib/Vend/CharSet.pm` and `lib/Vend/Util.pm`.
