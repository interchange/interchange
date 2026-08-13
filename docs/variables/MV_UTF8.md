# MV_UTF8

Tells Interchange to treat file, database, and response data as UTF-8. Reach
for it in any catalog that stores or serves non-ASCII text, so that reads and
writes use Perl's UTF-8 layer instead of raw bytes.

**Scope:** global (`interchange.cfg`) or catalog (`catalog.cfg`)

## Syntax

    Variable  MV_UTF8  1

A boolean flag. Default: off (byte semantics).

## Description

When `MV_UTF8` is true, Interchange applies a `:utf8` (or equivalent) binmode
when reading and writing pages, database export/import files, and other text
streams, and it drives the UTF-8 charset declaration on HTTP responses. The
flag is checked in both the catalog and global variable space — code tests
`$::Variable->{MV_UTF8} || $Global::Variable->{MV_UTF8}` — so a global setting
applies everywhere unless a catalog needs to differ.

Enabling UTF-8 handling touches many subsystems: file reads
(`lib/Vend/File.pm`, `lib/Vend/Util.pm`), table export/import
(`lib/Vend/Table/Common.pm`, `lib/Vend/Data.pm`), and the response layer
(`lib/Vend/Server.pm`). See [MV_HTTP_CHARSET](MV_HTTP_CHARSET.md) for the
response charset declaration.

## Examples

Turn on UTF-8 for the whole server:

    Variable  MV_UTF8  1

## Notes

UTF-8 handling depends on the Perl `Encode` module being available; where it is
not, some UTF-8 code paths are skipped even when `MV_UTF8` is set.

## See also

[MV_HTTP_CHARSET](MV_HTTP_CHARSET.md), [MV_EMAIL_CHARSET](MV_EMAIL_CHARSET.md),
the [internationalization](../guides/internationalization.md) guide.

## Source

Consumed in many modules via `$::Variable->{MV_UTF8}` /
`$Global::Variable->{MV_UTF8}`, including `lib/Vend/File.pm`,
`lib/Vend/Util.pm`, `lib/Vend/Table/Common.pm`, and `lib/Vend/Server.pm`.
