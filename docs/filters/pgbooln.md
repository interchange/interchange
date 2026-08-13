# pgbooln

Coerces a value to a PostgreSQL boolean literal, mapping undefined input to
NULL.

## Syntax

    [value name=field filter="pgbooln"]
    [filter pgbooln]TEXT[/filter]

## Description

The filter behaves like [pgbool](pgbool.md) except for undefined input:
where `pgbool` returns `f` for an undefined value, `pgbooln` returns undef
(SQL NULL). This lets a boolean column stay NULL ("unknown") when no value
was supplied, rather than being forced to false.

For a defined value the filter strips all whitespace and returns `f` when
the remaining text is empty, `0`, `f`, or `false` (case-insensitively), and
`t` for anything else.

## Examples

| Input      | Output        |
|------------|---------------|
| (undef)    | NULL (undef)  |
| `` (empty) | `f`           |
| `0`        | `f`           |
| `false`    | `f`           |
| `1`        | `t`           |
| `yes`      | `t`           |

For example:

    [filter pgbooln]1[/filter]

produces:

    t

## See also

[pgbool](pgbool.md), [yesno](yesno.md)

## Source

Defined in `code/Filter/pgbooln.filter`.
