# UrlSepChar

Sets the character Interchange uses to separate parameters in the URLs it
generates. Reach for it to produce links that use `;` or `:` instead of the
default `&` between query parameters.

**Scope:** global (`interchange.cfg`)

## Syntax

    UrlSepChar  char

A single character that is not a word character (`\w`) and not `%`. The
recommended values are `&`, `;`, or `:`; any other legal character is accepted
but produces a startup warning. A value longer than one character, or a word or
`%` character, is a configuration error. Default: `&`.

## Description

`UrlSepChar` sets `$Global::UrlSepChar`, the string placed between parameters in
Interchange-generated URLs (from tags such as [area](../tags/area.md) and
[page](../tags/page.md)). The related joining string `$Global::UrlJoiner` is
derived from it at startup, so changing `UrlSepChar` changes how multi-parameter
links are assembled throughout the server.

## Examples

Use a colon as the URL separator (in `interchange.cfg`):

```
UrlSepChar  :
```

## Notes

Because it is validated to reject word characters and `%`, only punctuation
suitable as a query separator is allowed. Choosing a value other than `&`, `;`,
or `:` logs a "not a recommended value" warning at startup but is not fatal.

## See also

[AutoVariable](AutoVariable.md) (the default exports `UrlJoiner` as a Variable),
[FullUrl](FullUrl.md), the [templating](../guides/templating.md) guide.

## Source

Parsed by `parse_url_sep_char` in `lib/Vend/Config.pm`; consumed there to set
`$Global::UrlSepChar` and derive `$Global::UrlJoiner`, used when building URLs.
