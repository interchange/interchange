# DiscountSpaceVar

Lists the CGI variables checked, once per request, to decide which discount
space is active. Reach for it to control how a visitor selects an alternate
discount space when [DiscountSpacesOn](DiscountSpacesOn.md) is enabled.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    DiscountSpaceVar  cgi_variable_name ...

A whitespace- or comma-separated list of CGI variable names, appended to an
array. Default: `mv_discount_space`.

## Description

When [DiscountSpacesOn](DiscountSpacesOn.md) is enabled, a per-request dispatch
routine walks this list in order and uses the value of the first named CGI
variable that is set as the active discount space name. If none is set, the
space stays at `main`.

The variable "CGI variable" here means any value posted or passed in the
request (form field or query-string parameter). The default,
`mv_discount_space`, suits most catalogs; add other variable names to tie the
discount space to something else, such as the current cart name via
`mv_cartname`.

This directive has no effect unless [DiscountSpacesOn](DiscountSpacesOn.md) is
also enabled.

## Examples

Keep the default variable (this line is only needed to add to or override the
default):

```
DiscountSpaceVar mv_discount_space
```

Select the discount space from the cart name instead:

```
DiscountSpacesOn Yes
DiscountSpaceVar mv_cartname
```

## See also

[DiscountSpacesOn](DiscountSpacesOn.md), the
[pricing](../guides/pricing.md) guide.

## Source

Parsed by `parse_array` in `lib/Vend/Config.pm`; consumed by the
`DiscountSpaces` per-request dispatch routine in `lib/Vend/Config.pm`
(`@{$Vend::Cfg->{DiscountSpaceVar}}`).
