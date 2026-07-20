# strip_white

Strips leading whitespace from the top of HTML pages that Interchange outputs.
Set it to tidy up the blank space that Interchange tags at the top of a page
leave behind, mostly to make browser "View source" more pleasant.

**Default:** off — leading whitespace is left unchanged.

## Syntax

Catalog-wide, in `catalog.cfg`:

    Pragma strip_white

Page-wide, anywhere in an Interchange page:

    [pragma strip_white]
    [pragma strip_white 0]

Block-wide, around an Interchange Tag Language (ITL) block:

    [tag pragma strip_white]1[/tag]

This is a boolean pragma.

## Description

Interchange tags placed at the top of a page (configuration tags, `[comment]`
blocks, control tags) commonly produce no visible output but leave the newlines
and indentation that surrounded them, so the delivered HTML starts with a run of
blank lines. When `strip_white` is set, Interchange removes leading whitespace
(`s/^\s+//`) from the output.

The trimming is applied in two places: on a named output block when it is
collected in `Vend::Page`, and on the whole response body in `Vend::Server`
before it is sent (only when a response has not already been made).

## Examples

Turn it on catalog-wide. In `catalog.cfg`:

    Pragma strip_white

A page that begins with several control tags:

    [pragma strip_white]
    [set foo]bar[/set]
    [comment]housekeeping[/comment]
    <html>
    ...

is delivered starting at `<html>` rather than with several leading blank lines.

## Notes

This pragma only strips whitespace at the very top of the output; it does not
compress whitespace elsewhere in the page.

## See also

- [Pragma](../config/Pragma.md)

## Source

The `Pragma` directive is parsed by `boolean_value` in
`lib/Vend/Config.pm`. This pragma is consumed in `output_cat()` in
`lib/Vend/Page.pm` and in `respond()` in `lib/Vend/Server.pm`.
