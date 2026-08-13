# cgi

Replaces the value with the current CGI value of the variable it names.

## Syntax

    [filter cgi]variable_name[/filter]
    [value name=field filter="cgi"]

`cgi` is unusual: it treats its input not as data to transform but as the
*name* of a CGI variable, and returns that variable's current value. A CGI
variable is any form field or query-string parameter submitted with the
request.

## Description

The filter returns `$CGI::values{NAME}`, where `NAME` is the filter's
input text. If no CGI variable by that name was submitted, the result is
empty (undefined). Any surrounding whitespace in the input is significant,
since it becomes part of the variable name being looked up.

Because the filter reads live request data, it is mainly useful in the
[filter](../tags/filter.md) tag form shown below, where the body holds a
literal variable name.

## Examples

    [cgi name=online_cgi_test set="TEST VALUE" hide=1]
    My test value is [filter cgi]online_cgi_test[/filter]

produces:

    My test value is TEST VALUE

Here the [cgi](../tags/cgi.md) tag first sets `online_cgi_test` in the
session's CGI space (with `hide=1` suppressing output), and the `cgi`
filter then retrieves it by name.

## See also

- [value](value.md)
- [cgi](../tags/cgi.md) tag

## Source

Defined in `code/Filter/cgi.filter`.
