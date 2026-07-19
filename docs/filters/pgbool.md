# pgbool

Coerces a value to a PostgreSQL boolean literal, treating undefined input
as false.

## Syntax

    [value name=field filter="pgbool"]
    [filter pgbool]TEXT[/filter]

## Description

The filter returns the PostgreSQL boolean literals `t` or `f`. It returns
`f` when the value is undefined, and otherwise strips all whitespace and
returns `f` when the remaining text is empty, `0`, `f`, or `false`
(case-insensitively). Every other value returns `t`.

Use it when storing an Interchange form value into a PostgreSQL `boolean`
column, so that assorted "off" inputs all become `f`. For a variant that
maps undefined input to SQL NULL instead of `f`, use
[pgbooln](pgbooln.md).

## Examples

| Input      | Output |
|------------|--------|
| (undef)    | `f`    |
| `` (empty) | `f`    |
| `0`        | `f`    |
| `false`    | `f`    |
| `f`        | `f`    |
| `1`        | `t`    |
| `yes`      | `t`    |
| `on`       | `t`    |

For example:

    [filter pgbool]false[/filter]

produces:

    f

## See also

[pgbooln](pgbooln.md), [yesno](yesno.md)

## Source

Defined in `code/Filter/pgbool.filter`.
