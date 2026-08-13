# dump

Print a human-readable dump of the current session, the HTTP environment,
and the CGI/form variables. It is a debugging aid: drop `[dump]` on a page
to see exactly what state Interchange is holding for the current shopper.

## Syntax

    [dump]
    [dump KEY]
    [dump no_env=1 no_cgi=1]

Standalone tag. It returns plain text (uneval/Data::Dumper output), so wrap
it in a `<pre>` block when viewing in a browser.

## Attributes

| Attribute    | Default        | Description |
|--------------|----------------|-------------|
| `key`        | (all sections) | Dump only this one key from the session hash (for example `carts`, `values`, `scratch`); positional parameter 1. |
| `no_env`     | (off)          | Omit the HTTP environment section. |
| `no_cgi`     | (off)          | Omit the CGI/form-variable section. |
| `no_session` | (off)          | Omit the full session section. |
| `show_all`   | (off)          | Include CGI variables normally suppressed by `@Global::HideCGI` (such as passwords). |
| `sort`       | (off)          | Sort hash keys in the output for stable, diffable dumps. |
| `indent`     | `2`            | `Data::Dumper` indent style for the output. |

Positional order: `key`.

## Description

With no `key`, `[dump]` emits several labelled sections: a short summary
(`minidump`), the HTTP environment, the CGI values, and the complete
session structure, each fenced by `###### ... #####` banner lines. Null
bytes are escaped to `\0` so the result is safe to view as text.

When you pass a `key`, only that subtree of the session is dumped, wrapped
in `###### SESSION (key) #####` banners. This is the quick way to inspect a
single structure, such as the carts or the accumulated form `values`, when
the full dump is too large. Invoke a plain `[dump]` first to discover the
available session keys under the `SESSION` banner.

By default CGI variables listed in `@Global::HideCGI` (typically credit
card and password fields) are removed from the output; set `show_all=1`
only in a safe, non-production context to see them.

## Examples

Dump everything (wrap in `<pre>` so line breaks survive in HTML):

    <pre>[dump]</pre>

Dump just the shopper's carts:

    <pre>[dump carts]</pre>

Dump the session only, skipping the environment and CGI sections, with
sorted keys for a stable diff:

    <pre>[dump no_env=1 no_cgi=1 sort=1]</pre>

## Notes

The output can contain sensitive session data. Never leave `[dump]` on a
live, shopper-facing page, and never ship `show_all=1` to production.

## See also

[debug](debug.md), the
[logging and debugging](../guides/logging-debugging.md) guide.

## Source

Defined in `code/SystemTag/dump.coretag`, mapped to `::full_dump`. The
routine is `Vend::Error::full_dump` (exported to `main` as `full_dump`) in
`lib/Vend/Error.pm`.
