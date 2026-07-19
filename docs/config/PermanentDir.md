# PermanentDir

Names the directory where Interchange stores the result files for saved
("more") searches that are marked permanent. Reach for it to relocate those
stored search results away from the default `perm` directory.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    PermanentDir  directory

A single relative directory (an absolute path is rejected), resolved
against the catalog root. Default: `perm`.

## Description

Large search result sets are paged with the "more" mechanism, which stores
the matching set on disk so later pages can be retrieved without rerunning
the search. Transient result sets live under [ScratchDir](ScratchDir.md);
result sets kept beyond the session -- permanent "more" lists -- are stored
under `PermanentDir` instead.

When Interchange needs the file for a permanent list, `lib/Vend/Search.pm`
builds the path from `$Vend::Cfg->{PermanentDir}`. The directory is always
taken relative to the catalog root and must be writable by the Interchange
daemon.

## Examples

Store permanent search results under `tmp/perm` (in `catalog.cfg`):

```
PermanentDir tmp/perm
```

## See also

[ScratchDir](ScratchDir.md), [SessionDatabase](SessionDatabase.md),
the [search](../guides/search.md) guide.

## Source

Parsed by `parse_relative_dir` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{PermanentDir}` in `lib/Vend/Search.pm`.
