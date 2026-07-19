# tabbed

Replaces newlines in the value with TAB characters.

## Syntax

    [filter tabbed]TEXT[/filter]
    [value name=field filter="tabbed"]

`tabbed` takes no arguments.

## Description

The filter replaces every Unix newline (`\n`), optionally preceded by a
carriage return (`\r`), with a single TAB character (`\t`). Each newline
becomes exactly one tab — runs of blank lines are not collapsed. A lone
carriage return that is not followed by a newline (old Mac OS line ending) is
**not** converted; normalize such input with [unix](unix.md) first if needed.

This is handy for flattening a multi-line textarea value onto a single
tab-delimited line, for example when building a row for a tab-separated
export.

## Examples

    [filter tabbed]One
    Two
    Three[/filter]

produces (tabs shown as arrows):

    One→Two→Three

DOS newlines (`\r\n`) are handled the same way, each becoming one tab.

## See also

- [unix](unix.md), [dos](dos.md), [mac](mac.md) — convert between newline
  conventions
- [oneline](oneline.md) — keep only the first line
- [options2line](options2line.md) — related options/line conversions

## Source

Defined in `code/Filter/tabbed.filter`. Applied by
`Vend::Interpolate::filter_value` (`lib/Vend/Interpolate.pm`).
