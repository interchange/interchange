# urlencode

Percent-encodes the value so it is safe to place in a URL.

## Syntax

    [filter urlencode]TEXT[/filter]
    [value name=field filter="urlencode"]

`urlencode` takes no arguments.

## Description

The filter replaces every character that is not a word character (`A-Z`,
`a-z`, `0-9`, `_`) or a colon (`:`) with a `%XX` escape, where `XX` is the
lower-case, two-digit hexadecimal value of the byte (`sprintf "%%%02x"`). Word
characters and colons pass through unchanged; everything else — spaces,
slashes, ampersands, question marks, punctuation — is encoded. It is the
inverse of [urldecode](urldecode.md).

Note the colon is deliberately left unescaped (so scheme separators like
`http:` survive), which means the output is not a strict RFC 3986
component encoding; it is aimed at building Interchange query strings, not at
encoding a full URL where a literal `:` would need escaping.

## Examples

    [filter urlencode]a b/c[/filter]

produces:

    a%20b%2fc

The colon is preserved:

    [filter urlencode]item:1234[/filter]

produces:

    item:1234

## See also

- [urldecode](urldecode.md) — the decoding counterpart

## Source

Defined in `code/Filter/urlencode.filter`. Applied by
`Vend::Interpolate::filter_value` (`lib/Vend/Interpolate.pm`).
