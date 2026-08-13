# CheckHTML

Names an external program that would validate a page's generated HTML, invoked
where a page sets the `checkhtml` flag. In the current code this feature is not
wired up and has no effect (see Notes).

**Scope:** global (`interchange.cfg`)

## Syntax

    CheckHTML  program_name_and_arguments

A command line for an external HTML checker (for example `weblint`), read as a
raw string. Default: empty (no checker configured).

## Description

The intent of `CheckHTML` is to pipe generated page HTML through an external
validator such as `weblint` and fold its output back into the page (usually
wrapped in HTML comments so it shows only in page source). Checking was meant to
be triggered per page by putting `[flag checkhtml]` on the page, or by wrapping
a block in `[tag flag checkhtml]...[/tag]`.

## Examples

The historically documented form, in `interchange.cfg`:

```
CheckHTML /usr/local/bin/weblint --structure --fluff -
```

## Notes

This directive does not currently function. The `[flag checkhtml]` tag sets an
internal `$Vend::CheckHTML` variable and `lib/Vend/External.pm` defines a
`check_html` routine that would run `$Global::CheckHTML`, but nothing in the
page-output path calls that routine, so the configured program is never
invoked. Treat `CheckHTML` as non-operational unless you add the call yourself.

Even if wired up, running an external process on every checked page imposes a
significant performance cost and is not appropriate for a production server.

## See also

[DisplayErrors](DisplayErrors.md), the
[logging-debugging](../guides/logging-debugging.md) guide.

## Source

Parsed with no parser (raw string) in `lib/Vend/Config.pm`, stored in
`$Global::CheckHTML`. The unused consumer is `check_html` in
`lib/Vend/External.pm`; the `checkhtml` flag is handled in
`lib/Vend/Interpolate.pm`.
