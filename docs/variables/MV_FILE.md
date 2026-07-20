# MV_FILE

Holds the filesystem name of the most recently returned page content. Reach for
it when debugging which template or file actually produced the output, since it
can differ from [MV_PAGE](MV_PAGE.md) when control passes through includes or
Perl routines.

**Scope:** runtime (set by the Interchange server; read-only)

This is a variable in the `MV_*` namespace that the server maintains
automatically; you do not set it in a configuration file.

## Syntax

    @@MV_FILE@@

Default: none (set as pages are read).

## Description

When Interchange reads a page file to return its contents, it records that
file's name in the variable space as `MV_FILE`. The value reflects the last
file the file-reading layer handled, so on a page assembled from includes it
names the most recently read piece rather than the top-level page.

## Examples

Display the last file read while building the current page:

    The last filename is: @@MV_FILE@@

## Notes

This variable is maintained by the server and is not intended to be written to.
For the logical page name (what the visitor requested), use
[MV_PAGE](MV_PAGE.md) instead.

## See also

[MV_PAGE](MV_PAGE.md), [MV_PREV_PAGE](MV_PREV_PAGE.md),
the [logging-debugging](../guides/logging-debugging.md) guide.

## Source

Set in the file-reading layer, `lib/Vend/File.pm`, and read via
`$::Variable->{MV_FILE}`.
