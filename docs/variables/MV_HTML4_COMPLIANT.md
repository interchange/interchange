# MV_HTML4_COMPLIANT

Makes Interchange join query-string parameters in generated links with `&amp;`
instead of a bare `&`, producing HTML4-compliant markup. Reach for it when you
need generated URLs to validate as HTML4.

**Scope:** global (`interchange.cfg`)

## Syntax

    Variable  MV_HTML4_COMPLIANT  1

A boolean flag. Default: `0` (bare `&` joiner).

## Description

When the URL separator character is `&` and `MV_HTML4_COMPLIANT` is true,
Interchange sets its URL joiner to `&amp;` (and matches either form when
splitting). This affects the multi-parameter links the server builds, such as
those from [area](../tags/area.md) and [page](../tags/page.md). The setting is
resolved during global configuration post-processing at startup.

## Examples

Emit HTML4-compliant link joiners:

    Variable  MV_HTML4_COMPLIANT  1

## Notes

This changes only the parameter joiner in generated URLs; it does not otherwise
alter page markup.

## See also

[area](../tags/area.md), [page](../tags/page.md), the
[templating](../guides/templating.md) guide.

## Source

Consumed in `lib/Vend/Config.pm` (`global_directive_postprocess`) via
`$Global::Variable->{MV_HTML4_COMPLIANT}`.
