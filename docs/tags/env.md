# env

Return a single HTTP/CGI environment variable, or -- with no argument -- an
HTML table of the entire environment. Handy for diagnostics and for reading
request metadata such as the client address or user agent.

## Syntax

    [env VARNAME]
    [env name=VARNAME]
    [env]

Standalone tag. The returned value is not reparsed.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `arg`     |         | Name of the environment variable to return (first positional). |

Positional order: `arg`.
Alias: `name` for `arg`.

## Description

The tag reads the request environment provided to Interchange (the link
program's environment, `::http()->{env}`), which holds the standard CGI
variables such as `REMOTE_ADDR`, `REMOTE_PORT`, `HTTP_USER_AGENT`, and
`REQUEST_METHOD`.

With an argument, the value of that one variable is returned. With no argument,
the tag returns a small HTML table listing every environment variable and its
value -- convenient for a quick debugging dump.

## Examples

Show the client's connection and browser details:

    Client connection: [env REMOTE_ADDR]:[env name=REMOTE_PORT]<br>
    Client browser: [env arg=HTTP_USER_AGENT]

Dump the whole environment as a table:

    [env]

## Notes

This is read-only access to the request environment; the tag cannot set
variables. The unargumented table form is meant for diagnostics -- do not leave
it in shopper-facing pages, as it can reveal server details.

## See also

[cgi](cgi.md),
[../guides/logging-debugging.md](../guides/logging-debugging.md)

## Source

Defined in `code/UserTag/env.tag`. Implemented by the inline Routine in that
file.
