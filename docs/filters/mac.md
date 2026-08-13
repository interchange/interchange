# mac

Converts UNIX (`\n`) and DOS (`\r\n`) line endings in the input to classic Mac
OS line endings (`\r`).

## Syntax

    [filter mac]TEXT[/filter]
    [value name=field filter="mac"]

## Description

The filter replaces each line terminator — a bare `\n`, a `\r\n` pair, or a
bare `\r` — with a single carriage return `\r`, the newline convention of
classic (pre-OS X) Mac OS. Mixed input is normalized: every line ending becomes
one `\r`. Text with no line endings is returned unchanged.

The three newline-conversion filters are complementary:

- [unix](unix.md) → `\n`
- [dos](dos.md) → `\r\n`
- `mac` → `\r`

## Examples

    [filter mac]Line one
    Line two[/filter]

The `\n` between the lines is replaced by `\r`, producing (shown with the
carriage return made visible):

    Line one\rLine two

## See also

- [unix](unix.md)
- [dos](dos.md)
- [line](line.md)

## Source

Defined in `code/Filter/mac.filter`.
