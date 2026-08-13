# Suggest

Checks that a capability or resource is present and logs a **warning** if it is
not, without aborting startup. It is the non-fatal counterpart of
[Require](Require.md): use it for optional features whose absence should be
noticed but not stop the server.

**Scope:** both (`interchange.cfg` and `catalog.cfg`)

## Syntax

    Suggest  TYPE  ITEM ["error message"]

The value is a `type item` pair (parser type `suggest`), optionally followed by
a quoted custom message and, for module checks, a `/path`. Default: empty. The
types match those of [Require](Require.md):

- `globalsub` -- a [GlobalSub](GlobalSub.md) of that name exists.
- `sub` -- a catalog [Sub](Sub.md) of that name exists.
- `taggroup` -- a [TagGroup](TagGroup.md) is defined.
- `usertag` -- a [UserTag](UserTag.md) is defined.
- `module` (or `perlmodule`) -- a Perl module is installable; an optional path
  argument is prepended to `@INC` for the check.
- `include` (or `perlinclude`) -- prepend a path to Perl's `@INC`.
- `file` -- a readable file exists.
- `executable` -- an executable file exists.

## Description

At configuration time Interchange tests the named item. If it is missing,
`Suggest` emits a warning to the log (and to the console during a foreground
start) and continues; the required-but-fatal behavior belongs to
[Require](Require.md). Whether the check runs against global or catalog
resources depends on where the directive appears: in `interchange.cfg` it tests
global items, in `catalog.cfg` it tests that catalog's items.

`Suggest`, [Require](Require.md), and [Capability](Capability.md) share one
implementation; they differ only in what happens when the item is absent
(warn, abort, or silently note).

## Examples

Warn if optional modules or tags used by the catalog are not available:

```
Suggest module    Business::UPS
Suggest module    Archive::Zip
Suggest usertag   table_editor
Suggest globalsub file_info
```

Check a module in a non-standard location:

```
Suggest module Set::Crontab /usr/local/perl/modules/
```

## See also

[Require](Require.md), [Capability](Capability.md), [GlobalSub](GlobalSub.md),
[Sub](Sub.md), [UserTag](UserTag.md), [TagGroup](TagGroup.md).

## Source

Parsed by `parse_suggest` (a wrapper around `parse_require` with the warn flag)
in `lib/Vend/Config.pm`; the check runs at configuration time.
