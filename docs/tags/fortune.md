# fortune

Return a random quotation by running the system `fortune` program. A bit of
decoration for a demo home page; the strap demo shows one in a sidebar
component.

## Syntax

    [fortune]
    [fortune short=1]
    [fortune no_computer=1 raw=1]

Standalone tag. Output is HTML-escaped by default (see below).

## Attributes

| Attribute     | Default | Description |
|---------------|---------|-------------|
| `short`       |         | Pass `-s` to `fortune`, restricting output to short quotations (first positional). |
| `no_computer` |         | Draw from a weighted set of non-computer fortune categories. |
| `raw`         |         | Return the fortune verbatim, skipping HTML conversion. |

Positional order: `short`.

Any single-character attribute that is true is passed through as a `-X` flag to
the `fortune` program, so `fortune`'s own options can be used directly.

## Description

The tag runs the program named by the `MV_FORTUNE_COMMAND` global variable,
defaulting to `/usr/games/fortune`, and captures its output. `short` adds the
`-s` flag. `no_computer` supplies an explicit weighted category list that
excludes the "computers" fortunes.

Unless `raw` is set, the captured text is passed through the `text2html` filter
(so newlines become line breaks and the text is HTML-safe) and a `<br>` is
inserted before an attribution dash. With `raw`, the plain program output is
returned unchanged.

## Examples

A short fortune:

    [fortune short=1]

The strap demo's `fortune` component renders one whose "short" flag is driven
by a control value:

    [fortune short="[control short yes]"]

## Notes

This tag depends on the `fortune` program and its data files being installed on
the server; on a host without `/usr/games/fortune` (or a configured
`MV_FORTUNE_COMMAND`) it produces nothing. It executes an external command per
call, so it is unsuitable for high-traffic pages.

## See also

[control](control.md),
[../filters/text2html.md](../filters/text2html.md)

## Source

Defined in `code/UserTag/fortune.tag`. Implemented by the inline Routine in
that file.
