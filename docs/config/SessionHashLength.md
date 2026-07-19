# SessionHashLength

Sets how many characters name each subdirectory level Interchange uses to store
file-based sessions. Reach for it, together with
[SessionHashLevels](SessionHashLevels.md), to control how session files are
spread across the filesystem.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    SessionHashLength  integer

An integer number of characters per directory level. Default: `1`.

## Description

The default `File` [SessionType](SessionType.md) hashes each session ID into a
tree of subdirectories rather than a single flat directory.
`SessionHashLength` sets how many characters make up each directory name, and
[SessionHashLevels](SessionHashLevels.md) sets how many levels deep the tree
goes.

With the defaults (`SessionHashLength 1`, `SessionHashLevels 2`) each level is a
single character, producing a layout like:

```
4
 +----w
6
 +----r
D
 +----9
```

A longer hash length creates more, shallower buckets. This helps when session
IDs are quasi-sequential (for example from `CGI::Session`), which would
otherwise pile many sessions into the same directory before moving on to the
next.

## Examples

Use one level of four-character directories:

```
SessionHashLength  4
SessionHashLevels  1
```

## Notes

Only the file-based session types use this directive; DBM, DBI, and Redis
sessions ignore it.

## See also

[SessionHashLevels](SessionHashLevels.md), [SessionType](SessionType.md),
[SessionDatabase](SessionDatabase.md), the
[sessions](../guides/sessions.md) guide.

## Source

Parsed by `parse_integer` in `lib/Vend/Config.pm`. Consumed in
`lib/Vend/SessionFile.pm` (`keyname`, via `Vend::Util::get_filename`).
