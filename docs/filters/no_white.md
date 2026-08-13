# no_white

Removes every whitespace character from the value.

## Syntax

    [filter no_white]TEXT[/filter]
    [value name=field filter="no_white"]

## Description

The filter strips all whitespace anywhere in the input -- spaces, tabs,
carriage returns, and newlines -- by deleting every run that matches Perl's
`\s+`. Unlike [strip](strip.md), which only trims the leading and trailing
ends, `no_white` also removes whitespace in the middle of the value.

## Examples

    [filter no_white]  X  X  [/filter]

produces:

    XX

Interior newlines and tabs are removed as well:

    [filter no_white]12 34	56[/filter]

produces:

    123456

## See also

[strip](strip.md), [compress_space](compress_space.md)

## Source

Defined in `code/Filter/no_white.filter`.
