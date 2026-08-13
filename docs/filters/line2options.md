# line2options

Converts a multi-line string into a single comma-separated options list, one
line per option.

## Syntax

    [filter line2options]TEXT[/filter]
    [value name=field filter="line2options"]

## Description

The filter turns line-separated text into the comma-delimited form Interchange
uses for option lists (as stored by option/attribute widgets). Processing, in
order:

1. Leading and trailing whitespace of the whole string is trimmed.
2. The string is split on runs of `\r`/`\n` (`[\r\n]+`), one option per line.
3. Each option has leading whitespace and trailing commas/whitespace trimmed,
   and any embedded comma is encoded as `&#44;` so it does not act as a
   delimiter.
4. The options are joined with commas.

Empty input is returned unchanged. This is the inverse of
[options2line](options2line.md).

Note: the routine accepts a third (delimiter) argument but does not use it;
the split is always on newlines regardless of any dotted argument supplied.

## Examples

    [filter line2options]one
    two
    three[/filter]

produces:

    one,two,three

## See also

- [options2line](options2line.md)
- [line](line.md)
- [option_format](option_format.md)

## Source

Defined in `code/Filter/line2options.filter`.
