# oneline

Keeps only the first line of the value, discarding everything from the
first line break onward.

## Syntax

    [filter oneline]TEXT[/filter]
    [value name=field filter="oneline"]

## Description

The filter deletes the first carriage return (`\r`), line feed (`\n`), or
ASCII NUL (`\0`) it finds and everything after it, so only the text up to
that first break survives. Input that is already a single line with no
break is returned unchanged.

## Examples

    [filter oneline]Have no fear,
for the first line is dear![/filter]

produces:

    Have no fear,

A value with no line break passes through untouched:

    [filter oneline]single line[/filter]

produces:

    single line

## See also

[line](line.md), [strip](strip.md), [compress_space](compress_space.md)

## Source

Defined in `code/Filter/oneline.filter`.
