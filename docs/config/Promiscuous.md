# Promiscuous

Allows the [value](../tags/value.md) tag to emit raw HTML from user-supplied
values instead of HTML-encoding it. Reach for it only when you deliberately
want form values to contain live markup -- and understand the security cost.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Promiscuous  Yes|No

A boolean (`yes`/`no`, `1`/`0`, `on`/`off`, `true`/`false`). Default: `No`.

## Description

By default the [value](../tags/value.md) tag encodes the HTML metacharacters
`<` and `>` to `&lt;` and `&gt;` so that user-entered data cannot inject
markup into a page. When `Promiscuous` is on, that encoding is skipped
catalog-wide: values are output verbatim. Internally this simply sets the
`enable_html` flag on every `value` expansion, done in `lib/Vend/Parse.pm`
when `$Vend::Cfg->{Promiscuous}` is true.

Turning this on is equivalent to adding `enable_html=1` to every
[value](../tags/value.md) tag. Because it lets any submitted value render as
HTML, it exposes the catalog to cross-site scripting unless you tightly
control and sanitize what reaches those values.

## Examples

Allow HTML from value tags (in `catalog.cfg`):

```
Promiscuous yes
```

## Notes

Prefer leaving this off and enabling HTML on the specific tags that need it
with `[value name=... enable_html=1]`, so the exposure is limited to values
you have vetted.

## See also

[value](../tags/value.md), the [security](../guides/security.md) and
[forms](../guides/forms.md) guides.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{Promiscuous}` in `lib/Vend/Parse.pm`.
