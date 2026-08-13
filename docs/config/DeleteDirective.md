# DeleteDirective

Disables named configuration directives so they are ignored when catalog
configuration is parsed. Reach for it on a multi-catalog server to save
memory or to forbid catalogs from setting particular directives.

**Scope:** global (`interchange.cfg`)

## Syntax

    DeleteDirective  directive ...

A whitespace- or comma-separated list of directive names. Names are
lowercased and each is flagged for deletion; the directive accumulates
across lines. Default: empty (nothing deleted).

## Description

Interchange builds its table of recognized catalog directives at startup.
Any directive flagged by `DeleteDirective` is skipped while that table is
assembled:

```perl
next if $Global::DeleteDirective->{$directive};
```

A deleted directive is no longer recognized in `catalog.cfg`: catalogs
cannot set it, and Interchange does not allocate storage for it. This both
trims per-catalog memory (useful when hosting many catalogs) and lets an
administrator lock catalogs out of specific settings.

## Examples

Remove two directives from the catalog vocabulary:

```
DeleteDirective DescriptionField OfflineDir
```

After this, a `DescriptionField` line in any `catalog.cfg` is not
recognized.

## Notes

Deleting a directive removes its configurability, not necessarily the
underlying behavior's fallback. A directive with a hardcoded default
elsewhere may still behave as if set to that default; whether a given
subsystem falls back cleanly depends on that subsystem. Test before
relying on deletion to change runtime behavior rather than merely
forbidding configuration. To *add* a directive rather than remove one, see
[AddDirective](AddDirective.md).

## See also

[AddDirective](AddDirective.md), the
[configuration](../guides/configuration.md) guide.

## Source

Parsed by an inline subroutine in `lib/Vend/Config.pm` (populating
`$Global::DeleteDirective`); consumed in `lib/Vend/Config.pm` when the
catalog directive table is built.
