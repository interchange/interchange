# Require

Asserts that a named capability -- a Perl module, subroutine, tag, file, or
executable -- is present, and aborts startup if it is not. Reach for it to
fail fast and loudly when a catalog (or the whole daemon) is missing
something it cannot run without.

**Scope:** both (`interchange.cfg` global, `catalog.cfg` catalog)

## Syntax

    Require  TYPE  ITEM [ITEM ...] [/path] ["error message"]

The first word is the capability type; the remaining words are items to
test (`parse_require`). Recognized types:

| Type                   | Requires the existence of                        |
|------------------------|--------------------------------------------------|
| `globalsub`            | a [GlobalSub](GlobalSub.md) of that name         |
| `sub`                  | a [Sub](Sub.md) of that name                     |
| `taggroup`             | every tag in the named tag group(s)              |
| `usertag`              | a [UserTag](UserTag.md) of that name             |
| `module` / `perlmodule`| a loadable Perl module                           |
| `include` / `perlinclude` | a readable directory to prepend to `@INC`     |
| `file`                 | a readable file                                  |
| `executable`           | an executable file                               |

A trailing `/path` argument supplies an extra module search path (for
`module`) or a default item path. A trailing quoted string replaces the
default error message. Default: empty (nothing required).

## Description

`Require` checks each named item and, if any is absent, calls
`config_error`, which aborts. What aborts depends on scope:

### Global

In `interchange.cfg`, a failed `Require` aborts the Interchange daemon --
the server does not start. Use it for things every catalog depends on, such
as a payment module.

### Catalog

In `catalog.cfg`, a failed `Require` aborts configuration of that catalog
only: the catalog is skipped and not added to the running server, while
other catalogs continue. Use it for per-catalog prerequisites.

For a `module` requirement, whether Interchange actually loads the module
or merely looks for a readable file depends on whether global/unsafe Perl
is permitted for the catalog ([AllowGlobal](AllowGlobal.md)). The related
[Suggest](Suggest.md) directive performs the same tests but only warns, and
[Capability](Capability.md) tests silently without warning or aborting.

## Examples

Global -- require a Perl module before the daemon starts (from
`interchange.cfg`):

```
Require module Vend::Payment::TestPayment
```

Catalog -- require modules with custom messages (from the strap
`catalog.cfg`):

```
Require module Digest::MD5    "Need %s %s for better cache keys."
Require module Safe::Hole     "Need %s %s for embedded perl object access."
```

Load a module from a non-standard directory by giving an extra search
path:

```
Require module Vend::Swish /usr/lib/swish-e/perl
```

Require a usertag and a global subroutine to be defined:

```
Require usertag   table_editor
Require globalsub file_info
```

Require a readable file and an executable:

```
Require file /etc/syslog.conf
Require executable /usr/local/bin/gfont
```

## Notes

The `%s %s` placeholders in a custom message are filled with the capability
type and the item name. The `include` type is meaningful mainly with
`Require` (it modifies `@INC` as a side effect of the test).

## See also

[Suggest](Suggest.md), [Capability](Capability.md),
[GlobalSub](GlobalSub.md), [UserTag](UserTag.md),
[AllowGlobal](AllowGlobal.md), the
[configuration](../guides/configuration.md) guide.

## Source

Parsed by `parse_require` in `lib/Vend/Config.pm` (shared with
`parse_suggest` and `parse_capability`).
