# Replace

Resets a named directive to its default before the current (sub)catalog's
own settings are applied, so an accumulating directive starts fresh rather
than adding to the base catalog's value. Reach for it in a subcatalog whose
base catalog already set a directive you want to redefine from scratch.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Replace  DIRECTIVE_NAME

The exact name of another directive (`parse_replace`). Default: empty.

## Description

Many directives accumulate: each additional line appends to a list or
merges into a hash rather than overwriting. When a subcatalog inherits such
a directive from its base catalog, there is otherwise no way to discard the
inherited value and begin again. `Replace DIRECTIVE_NAME` does exactly
that: it resets the named directive to the value it would have had by
default, so subsequent lines for that directive in the subcatalog build on
a clean slate.

The reset happens where the `Replace` line appears, so place it before the
lines that set the new value. Capitalization of the target directive name
must be exact.

The parser sets the target directive to its catalog default
(`get_catalog_default`) and records the replacement in
`lib/Vend/Config.pm`.

## Examples

In a subcatalog, clear an inherited [Autoload](Autoload.md) list and set
your own:

```
Replace  Autoload
Autoload my_setup_routine
```

Reset [ProductFiles](ProductFiles.md) so only the tables named below are
searched:

```
Replace  ProductFiles
ProductFiles specials
```

## Notes

`Replace` is meaningful chiefly in a subcatalog that inherits a base
catalog's directives; in a standalone `catalog.cfg` there is usually no
prior value to replace. The target name is case-sensitive and must match
the directive's canonical capitalization.

## See also

[AddDirective](AddDirective.md), [SubCatalog](SubCatalog.md),
[Catalog](Catalog.md), the [configuration](../guides/configuration.md)
guide.

## Source

Parsed by `parse_replace` in `lib/Vend/Config.pm`, which resets the target
via `get_catalog_default`.
