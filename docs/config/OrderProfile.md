# OrderProfile

Names the files that hold order-profile definitions -- the ordered checks and
default settings applied when a form is submitted with a chosen profile. Reach
for it to load your catalog's form-validation and checkout profiles.

**Scope:** catalog (`catalog.cfg`)

The catalog directive `Profiles` is an alias for `OrderProfile`; the two names
are interchangeable in `catalog.cfg`. (`Profiles` is also a separate directive at
global scope -- see [Profiles](Profiles.md).)

## Syntax

    OrderProfile  filename ...

A glob of profile file names, resolved relative to the catalog root. Multiple
files or wildcard patterns may be listed, and the directive accumulates across
lines. Each file may hold several profiles, split on `__END__` and named by an
`__NAME__` marker. Default: empty.

## Description

At configuration time, `lib/Vend/Config.pm` reads every matching profile file and
registers the profiles it finds. A profile is a named block of order checks and
value defaults; a form selects one by setting `mv_order_profile` (or, for a
non-checkout action, `mv_click`) to the profile's name. The named checks then run
against the submitted values before the order proceeds.

Because profiles are read at startup, adding or editing one takes effect on the
next catalog reconfiguration.

## Examples

Load two named profile files (in `catalog.cfg`):

```
OrderProfile etc/profiles.order etc/profiles.login
```

Load every profile in a directory by suffix -- close to the strap demo's
`Profiles include/profiles/*.*`:

```
OrderProfile include/profiles/*.profile
```

Prefer a specific suffix over a bare `*` so that editor backups and temporary
files are not read as profiles.

## Notes

The checks a profile defines can also drive `mv_click` actions, provided the
action name is not already claimed in [scratch](../glossary.md) space.

## See also

[Profiles](Profiles.md), [SearchProfile](SearchProfile.md),
[Filter](Filter.md), the [order-checks](../order-checks/) reference and the
[forms](../guides/forms.md) and [cart-and-checkout](../guides/cart-and-checkout.md)
guides.

## Source

Parsed by `parse_profile` in `lib/Vend/Config.pm`; the alias is registered in the
`%DirectiveAlias` table of the same file.
