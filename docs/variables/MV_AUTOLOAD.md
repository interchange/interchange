# MV_AUTOLOAD

Prepends a fixed block of Interchange Tag Language (ITL) to the top of every
top-level page before it is interpolated. Reach for it to run setup markup —
loading a component, setting scratch values, applying a wrapper — on every page
without editing each page file.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_AUTOLOAD  itl-text

The value is arbitrary text (typically ITL) inserted verbatim at the very start
of the page. Default: unset (nothing prepended).

## Description

When Interchange interpolates a top-level page, `interpolate_html()` prepends
`$::Variable->{MV_AUTOLOAD}` to the page content before processing. Because it
is added ahead of the page body, tags in the autoload run first. The companion
variable [MV_AUTOEND](MV_AUTOEND.md) appends text to the end of the page in the
same pass.

The prepend happens only at the top level of page interpolation (not for nested
`[include]` or component interpolation), so it wraps the page as a whole once.

## Examples

Load a common header component on every page:

    Variable  MV_AUTOLOAD  [component header]

Set a scratch value that every page can read:

    Variable  MV_AUTOLOAD  [set page_loaded]1[/set]

## See also

[MV_AUTOEND](MV_AUTOEND.md), the [templating](../guides/templating.md) guide.

## Source

Consumed in `lib/Vend/Interpolate.pm` (`interpolate_html`) via
`$::Variable->{MV_AUTOLOAD}`.
