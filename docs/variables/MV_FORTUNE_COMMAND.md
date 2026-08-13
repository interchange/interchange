# MV_FORTUNE_COMMAND

Sets the external command the `fortune` user tag runs to produce a random
fortune. Reach for it when the `fortune` program is installed somewhere other
than the default path.

**Scope:** global (`interchange.cfg`)

## Syntax

    Variable  MV_FORTUNE_COMMAND  /path/to/fortune

The value is the command to execute. Default: `/usr/games/fortune`.

## Description

The `fortune` user tag runs the command named by `MV_FORTUNE_COMMAND` and
returns its output. When the variable is unset, it runs `/usr/games/fortune`.

## Examples

Point at a fortune binary in a custom location:

    Variable  MV_FORTUNE_COMMAND  /usr/local/bin/fortune

## Notes

The tag runs an external program; it works only where that program is installed
and permitted to run.

## Source

Consumed in `code/UserTag/fortune.tag` via
`$Global::Variable->{MV_FORTUNE_COMMAND}`.
