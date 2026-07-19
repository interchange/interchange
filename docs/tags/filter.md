# filter

Applies one or more filters to the text between its tags. Reach for it to
transform a block of output — trim it, strip HTML, uppercase it, format a
number — without wiring a `filter=` attribute onto some other tag.

## Syntax

    [filter op] TEXT [/filter]
    [filter op="filter1 filter2 ..."] TEXT [/filter]

Container tag (has an end tag and processes its body). The body is interpolated
first; the filters then run on the result.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `op`      | (none)  | Space-separated list of filters to apply, in order. |

Positional order: `op`.

## Description

The tag maps to `Vend::Interpolate::filter_value`, the same routine that backs
the `filter=` attribute found on many tags and the `Filter` catalog directive.
A *filter* is a named text transform; Interchange ships dozens (see
[../filters/](../filters/)) and you can define your own. When `op` names several
filters, they are applied left to right, each operating on the output of the
previous one.

Beyond named filters, `op` understands a few inline shorthands handled directly
by the routine:

- A bare integer `N` truncates the text to `N` characters.
- `N.` truncates to `N` characters and appends `...`; `N$` keeps the last `N`
  characters, prefixing `...`.
- `wordsN` keeps the first `N` whitespace-separated words (with a trailing
  `...` if truncated when written `wordsN.`).
- A `sprintf` format containing `%` (for example `%.2f`) formats the value.

Filters that take arguments accept them dotted onto the name, for example
`[filter op="10."]` or `[filter op="mv_number.2"]`; the routine peels
`.arg` suffixes off and passes them to the filter.

## Examples

Trim leading and trailing whitespace:

    [filter strip]   spaced out   [/filter]

produces:

    spaced out

Chain filters — strip HTML tags, then uppercase:

    [filter op="strip_html upper"]<b>hello</b>[/filter]

produces:

    HELLO

Keep only the first 20 characters of a description:

    [filter 20][description os28004][/filter]

## Notes

- The identical filter set is available as the `filter=` attribute on tags such
  as [cgi](cgi.md), [value](value.md), and [data](data.md); use `[filter]` when
  you want to transform a literal or already-interpolated block.

## See also

- [input-filter](input-filter.md) — attach a filter to a CGI variable
- [cgi](cgi.md), [data](data.md), [value](value.md) — tags with a `filter=`
  attribute
- Filter reference: [../filters/](../filters/)
- Guide: [Templating with ITL](../guides/templating.md)

## Source

Defined in `code/SystemTag/filter.coretag`. Implemented by
`Vend::Interpolate::filter_value` in `lib/Vend/Interpolate.pm`.
