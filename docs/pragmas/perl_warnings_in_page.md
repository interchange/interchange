# perl_warnings_in_page

Turns on Perl warnings (`$^W`) during page interpolation, so warnings from
`[perl]`, `[calc]`, and embedded Perl in a page are emitted. Set it while
debugging page-level Perl.

**Default:** off — Perl warnings are not enabled for page interpolation.

## Syntax

Catalog-wide, in `catalog.cfg`:

    Pragma perl_warnings_in_page

Page-wide, anywhere in an Interchange page:

    [pragma perl_warnings_in_page]
    [pragma perl_warnings_in_page 0]

Block-wide, around an Interchange Tag Language (ITL) block:

    [tag pragma perl_warnings_in_page]1[/tag]

This is a boolean pragma.

## Description

At the start of `interpolate_html()`, Interchange sets `$^W = 1` when
`perl_warnings_in_page` is set, enabling Perl's warning machinery for the
interpolation of that page. Warnings then go to the Interchange error log as
usual. Use it to surface undefined-value and other Perl warnings from Perl-based
tags while developing, then turn it off in production.

## Examples

Enable warnings for one page under development:

    [pragma perl_warnings_in_page]
    [calc]$undefined + 1[/calc]

Enable warnings catalog-wide. In `catalog.cfg`:

    Pragma perl_warnings_in_page

## Notes

This controls warnings emitted during Interchange page interpolation; it is a
development aid, not something to leave on in production where it adds log noise.

## See also

- [Pragma](../config/Pragma.md)

## Source

The `Pragma` directive is parsed by `boolean_value` in
`lib/Vend/Config.pm`. This pragma is consumed in `interpolate_html()` in
`lib/Vend/Interpolate.pm`.
