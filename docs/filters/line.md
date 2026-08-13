# line

Returns only the first line of the input, discarding everything from the first
newline onward.

## Syntax

    [filter line]TEXT[/filter]
    [value name=field filter="line"]

## Description

The filter matches from the start of the string up to the first `\n` (an
optional preceding `\r` is consumed too, so both UNIX and DOS line endings are
handled) and keeps only the text before it. If the input has no newline, it is
returned unchanged. The newline and all following lines are dropped, including
any trailing text.

Unlike [oneline](oneline.md), which also stops at an ASCII NUL, `line` breaks
only on newlines.

## Examples

    [filter line]Line 1 (visible)
    Line 2 (not visible)
    Line 3 (not visible)[/filter]

produces:

    Line 1 (visible)

## See also

- [oneline](oneline.md)
- [unix](unix.md)
- [dos](dos.md)
- [mac](mac.md)
- [strip](strip.md)

## Source

Defined in `code/Filter/line.filter`.
