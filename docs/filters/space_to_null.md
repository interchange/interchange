# space_to_null

Replaces runs of whitespace with a single NUL character.

## Syntax

    [value name=field filter="space_to_null"]

## Description

The filter converts each run of whitespace (Perl's `\s+`: spaces, tabs,
carriage returns, and newlines) into one ASCII NUL character (`\0`). This
produces the NUL-delimited internal form Interchange uses for multivalued
data, so a space-separated list can be treated as separate values. It is
the counterpart of [null_to_space](null_to_space.md).

Note that the conversion is on whitespace runs, not spaces alone, so tabs
and newlines between tokens also become NUL separators.

## Examples

Given the input `S M L`, applying the filter:

    [value name=sizes filter="space_to_null"]

produces the internal string `S\0M\0L`, where each `\0` is a NUL separator
(invisible when printed; see [show_null](show_null.md) to reveal it).

## See also

[null_to_space](null_to_space.md), [colons_to_null](colons_to_null.md),
[show_null](show_null.md), [no_white](no_white.md)

## Source

Defined in `code/Filter/space_to_null.filter`.
