# HTMLsuffix

Sets the filename extension Interchange appends when it looks up a page on
disk in the catalog's `pages/` directory. Reach for it when your source
pages use a suffix other than `.html` (for example `.htm` or `.itl`).

**Scope:** catalog (`catalog.cfg`)

## Syntax

    HTMLsuffix  EXTENSION

`EXTENSION` is a single string stored verbatim, including the leading dot.
Default: `.html`.

## Description

When Interchange serves a page name -- say `flypage` -- it builds the disk
path by appending `HTMLsuffix` to the name, looking for
`pages/flypage.html` by default. Changing this directive changes only the
name of the file Interchange reads from disk; the page name shown in the
browser's address bar is unaffected.

Page lookup is locale-sensitive. If a page with the configured suffix is
not found, Interchange falls through to other candidates (locale-specific
files, then database-backed `PageTables` if configured). The suffix is
also used by [Jobs](Jobs.md): files in a job directory whose names end in
`HTMLsuffix` are treated as pages and processed as job steps.

The directive is read at catalog configuration time and stored in the
catalog config; changing it requires a reconfigure to take effect.

## Examples

Use a `.htm` extension for all pages:

```
HTMLsuffix .htm
```

Interchange Tag Language (ITL) source files:

```
HTMLsuffix .itl
```

## Notes

The value is stored raw (no parser), so include the leading dot. A value
of `html` (without the dot) would make Interchange look for
`pages/flypagehtml`, which is almost never intended.

## See also

[Locale](Locale.md), [PageDir](PageDir.md), [Jobs](Jobs.md), the
[templating](../guides/templating.md) guide.

## Source

Stored raw (no parser) from the `catalog_directives()` table in
`lib/Vend/Config.pm`; consumed during page lookup in
`Vend::Util::readin` (`lib/Vend/Util.pm`) and in
`lib/Vend/Dispatch.pm`.
