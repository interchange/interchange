# NoAbsolute

Forbids catalog pages and tags from reading files by absolute path. Reach for
it to lock down catalogs so page authors can only reach files inside the
catalog tree.

**Scope:** global (`interchange.cfg`)

## Syntax

    NoAbsolute  yes|no

A boolean (`parse_yesno`): `yes`/`no`, `1`/`0`, `on`/`off`, `true`/`false`.
Default: `No`.

## Description

Interchange tags that read a file -- such as [file](../tags/file.md),
[include](../tags/include.md), and the file-reading paths of other tags --
call an internal `allowed_file` check (in `lib/Vend/File.pm`) before opening.
When `NoAbsolute` is set, that check rejects absolute file paths, so a page may
only read files relative to the catalog directory. When it is off (the
default), absolute paths are permitted.

This is a security control for multi-user or untrusted-catalog hosting: it
keeps page code from reading arbitrary files elsewhere on the server. It does
not grant access the Interchange process lacks -- if the daemon has no
operating-system permission to read a file, the file is unreadable regardless
of this setting.

`NoAbsolute` is a global setting read at startup.

## Examples

Prevent arbitrary file access from catalog pages (the distributed
`interchange.cfg` ships with this enabled):

```
NoAbsolute Yes
```

## Notes

Tests for whether a file merely exists -- for example `[if file ...]` -- are
not blocked by `NoAbsolute`; only reads of the file contents are restricted.

Related but distinct is [AllowGlobal](AllowGlobal.md), which governs whether a
catalog's Perl runs outside the `Safe` compartment; `NoAbsolute` restricts the
file-reading tags rather than embedded Perl.

## See also

[AllowGlobal](AllowGlobal.md), [file](../tags/file.md),
[include](../tags/include.md), the [security](../guides/security.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed via
`$Global::NoAbsolute` in `allowed_file` and `readfile` in `lib/Vend/File.pm`
(and in [TemplateDir](TemplateDir.md) validation in `lib/Vend/Config.pm`).
