# lspace_to_nbsp

Replaces the run of leading spaces at the start of each line with the same
number of `&nbsp;` HTML entities, preserving indentation in HTML output.

## Syntax

    [filter lspace_to_nbsp]TEXT[/filter]
    [value name=field filter="lspace_to_nbsp"]

## Description

HTML collapses leading whitespace, so indentation typed into a value is lost
when rendered. This filter converts each line's *leading* spaces into an equal
number of non-breaking spaces (`&nbsp;`), which browsers preserve. It operates
per line (the match is applied in multiline mode), so indentation is kept on
every line, not just the first. Only leading spaces are affected; spaces
elsewhere on a line and tab characters are left alone.

For converting *all* spaces (not just leading ones), use
[space_to_nbsp](space_to_nbsp.md).

## Examples

    [filter lspace_to_nbsp]   Hello
      World[/filter]

produces (three and two leading spaces become `&nbsp;` entities):

    &nbsp;&nbsp;&nbsp;Hello
    &nbsp;&nbsp;World

## See also

- [space_to_nbsp](space_to_nbsp.md)
- [space_to_null](space_to_null.md)
- [pre](pre.md)

## Source

Defined in `code/Filter/lspace_to_nbsp.filter`.
