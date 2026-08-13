# SessionHashLevels

Sets how many nested subdirectory levels Interchange uses to spread file-based
sessions across the filesystem. Reach for it, together with
[SessionHashLength](SessionHashLength.md), to keep any single session directory
from holding an unwieldy number of files.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    SessionHashLevels  integer

An integer number of directory levels. Default: `2`.

## Description

The default `File` [SessionType](SessionType.md) does not store every session in
one flat directory; it hashes the session ID into a tree of subdirectories.
`SessionHashLevels` sets how many levels deep that tree goes, and
[SessionHashLength](SessionHashLength.md) sets how many characters name each
level.

With the defaults (`SessionHashLevels 2`, `SessionHashLength 1`) sessions are
filed two levels deep under one-character directory names, giving a layout like:

```
4
 +----w
6
 +----r
D
 +----9
 +----R
```

More levels spread sessions across more directories, which helps filesystems
that slow down with very large directories.

## Examples

Break sessions into a single level of four-character directories -- useful when
session IDs come from a module that generates quasi-sequential IDs:

```
SessionHashLevels  1
SessionHashLength  4
```

## Notes

This directive only affects the file-based session types; DBM, DBI, and Redis
sessions ignore it.

Prior historic documentation stated a default of `1` in its description text;
the current code sets the default to `2`
(`catalog_directives()` in `lib/Vend/Config.pm`).

## See also

[SessionHashLength](SessionHashLength.md), [SessionType](SessionType.md),
[SessionDatabase](SessionDatabase.md), the
[sessions](../guides/sessions.md) guide.

## Source

Parsed by `parse_integer` in `lib/Vend/Config.pm`. Consumed in
`lib/Vend/SessionFile.pm` (`keyname`, via `Vend::Util::get_filename`).
