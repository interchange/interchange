# value

Returns the value of the named user variable, treating the filter's input as
the variable name to look up.

## Syntax

    [filter value]variablename[/filter]

The body of the filter is the **name** of the variable, not text to transform.
`value` is marked private, so it is not offered in the admin UI's filter
menus, but it works wherever filters are applied.

## Description

The filter looks up its input in the `$Values` space — the user/form values
namespace populated by form submissions and the [value](../tags/value.md) tag —
and returns `$Values->{input}`. In effect it is an indirection: the text
between the tags names a variable, and the filter expands to that variable's
current value. If no such variable is set, the result is empty.

This is occasionally useful when the name of the value you want is itself
computed or stored in another field.

## Examples

Set a value, then look it up by name through the filter:

    [value name=greeting set="Hello there" hide=1]

    [filter value]greeting[/filter]

produces:

    Hello there

## See also

- [value](../tags/value.md) — the tag that reads and sets `$Values`
- [cgi](cgi.md) — return the CGI value of a named variable
- [forms](../guides/forms.md) — where user values come from

## Source

Defined in `code/Filter/value.filter` (`CodeDef value Visibility private`);
reads `$::Values`. Applied by `Vend::Interpolate::filter_value`
(`lib/Vend/Interpolate.pm`).
