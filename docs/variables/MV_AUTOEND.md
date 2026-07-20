# MV_AUTOEND

Appends a fixed block of Interchange Tag Language (ITL) to the end of every
top-level page before it is interpolated. Reach for it to run teardown or
trailing markup — a footer component, closing tags, a tracking snippet — on
every page without editing each page file.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Variable  MV_AUTOEND  itl-text

The value is arbitrary text (typically ITL) appended verbatim at the very end
of the page. Default: unset (nothing appended).

## Description

When Interchange interpolates a top-level page, `interpolate_html()` appends
`$::Variable->{MV_AUTOEND}` to the page content before processing, as the
mirror of [MV_AUTOLOAD](MV_AUTOLOAD.md), which prepends. The append happens only
at the top level of page interpolation, so it wraps the page as a whole once.

## Examples

Add a footer component to every page:

    Variable  MV_AUTOEND  [component footer]

## See also

[MV_AUTOLOAD](MV_AUTOLOAD.md), the [templating](../guides/templating.md) guide.

## Source

Consumed in `lib/Vend/Interpolate.pm` (`interpolate_html`) via
`$::Variable->{MV_AUTOEND}`.
