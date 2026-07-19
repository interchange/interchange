# urldecode

Decodes URL percent-encoding, turning `%XX` hex escapes back into the
characters they represent.

## Syntax

    [filter urldecode]TEXT[/filter]
    [value name=field filter="urldecode"]

`urldecode` takes no arguments. The names `url` and `urld` are aliases for this
filter (see [url](url.md) and [urld](urld.md)).

## Description

The filter finds each `%` followed by two hexadecimal digits and replaces the
sequence with the byte having that value (`chr(hex(...))`). Both upper- and
lower-case hex digits are accepted. Text that is not part of a `%XX` escape —
including a bare `%` not followed by two hex digits — is left unchanged. It is
the inverse of [urlencode](urlencode.md).

Note this filter does not convert `+` to a space; it only handles percent
escapes.

## Examples

    [filter urldecode]a%20b%2Fc[/filter]

produces:

    a b/c

Chained with [urlencode](urlencode.md), the round trip returns the original:

    [filter op="urlencode urldecode"]a b/c[/filter]

produces:

    a b/c

## See also

- [urlencode](urlencode.md) — the encoding counterpart
- [url](url.md), [urld](urld.md) — aliases for this filter
- [linkdecode](linkdecode.md) — decode Interchange link text

## Source

Defined in `code/Filter/urldecode.filter`. Applied by
`Vend::Interpolate::filter_value` (`lib/Vend/Interpolate.pm`).
