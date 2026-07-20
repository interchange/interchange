# MV_HTTP_CHARSET

Sets the character set Interchange declares in the HTTP `Content-Type` response
header. Reach for it to tell browsers how to decode your pages when you serve
content in a specific encoding.

**Scope:** catalog (`catalog.cfg`) or global (`interchange.cfg`)

## Syntax

    Variable  MV_HTTP_CHARSET  charset

`charset` is a charset name such as `UTF-8` or `iso-8859-1`. Default: empty (no
charset appended to the response `Content-Type`).

## Description

When building an HTTP response, Interchange looks up the charset to declare by
checking the current catalog's variable space first and then the global space:
`$c->{Variable}{MV_HTTP_CHARSET} || $Global::Variable->{MV_HTTP_CHARSET}`. The
resolved value is appended to the `Content-Type` header (for example
`text/html; charset=UTF-8`).

This declaration is about what the response *says* it is; it does not by itself
re-encode data. To make Interchange handle data as UTF-8 internally, also set
[MV_UTF8](MV_UTF8.md).

## Examples

Declare UTF-8 responses for a catalog:

    Variable  MV_HTTP_CHARSET  UTF-8

## Notes

The same lookup is duplicated in the response `send()` path so it works from
within the `Safe` compartment; both read the same variable.

## See also

[MV_UTF8](MV_UTF8.md), [MV_EMAIL_CHARSET](MV_EMAIL_CHARSET.md),
the [internationalization](../guides/internationalization.md) guide.

## Source

Consumed in `lib/Vend/CharSet.pm` (`default_charset`) and `lib/Vend/Server.pm`
via `$c->{Variable}{MV_HTTP_CHARSET}` / `$Global::Variable->{MV_HTTP_CHARSET}`.
