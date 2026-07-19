# unix

Normalizes line endings to the Unix convention (a single line feed).

## Syntax

    [filter unix]TEXT[/filter]
    [value name=field filter="unix"]

`unix` takes no arguments.

## Description

The filter replaces every DOS/Windows newline (`\r\n`) and every bare carriage
return (`\r`, the classic Mac OS line ending) with a single line feed (`\n`).
Text that already uses Unix newlines is unaffected. Despite the filter's
short description ("DOS to UNIX newlines") it also converts lone carriage
returns, so both DOS and old-Mac input are normalized in one pass.

## Examples

DOS input `Line one\r\nLine two`:

    [filter unix]Line one
    Line two[/filter]

produces text with Unix line endings:

    Line one
    Line two

Any `\r\n` or lone `\r` in the input is emitted as a single `\n`.

## See also

- [dos](dos.md) — the inverse: convert Unix newlines to DOS
- [mac](mac.md) — convert to Mac OS (CR) newlines
- [tabbed](tabbed.md) — replace newlines with tabs

## Source

Defined in `code/Filter/unix.filter`. Applied by
`Vend::Interpolate::filter_value` (`lib/Vend/Interpolate.pm`).
