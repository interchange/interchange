# CodeDef

A general-purpose code mapper: it registers a Perl routine (or a scalar or
list attribute) against a named slot in one of Interchange's extensible
subsystems -- action maps, filters, widgets, order checks, search operators,
and more. Reach for it to add or configure such code with finer control than
the higher-level directives ([ActionMap](ActionMap.md),
[UserTag](UserTag.md), and so on) offer.

**Scope:** both (`interchange.cfg` global, `catalog.cfg` catalog)

## Syntax

    CodeDef  name  type  [value]

- `name` -- the identifier being defined (hyphens become underscores;
  non-word characters are stripped with a warning).
- `type` -- the destination class or attribute. Destination classes include
  `ActionMap`, `Filter`, `FormAction`, `ItemAction`, `OrderCheck`, `SearchOp`,
  `LocaleChange`, `Widget`, `UserTag`, `CoreTag`, `HashCode`, `ArrayCode`, and
  `JavaScriptCheck`. Attribute types (`Routine`, `Description`, `Order`,
  `Required`, `Multiple`, and the other tag attributes) set one property of an
  already-named item.
- `value` -- for a routine, an inline `sub { ... }` (usually a here-document);
  for a boolean attribute, a `1`/`0` (or yes/no) flag; for scalar or list
  attributes, the attribute's value.

The directive accumulates; you write several `CodeDef` lines to build up one
item (its class, description, routine, and so on). Default: empty.

## Description

Each `CodeDef` line routes its `name`/`value` into a code repository keyed by
the resolved destination. Once a `name` has been associated with a destination
class, later lines for the same `name` that carry only an attribute type apply
to that destination, so the class line typically comes first, followed by
`Description`, `Routine`, and any other attributes.

Boolean attributes (such as `Multiple` on a widget, or `Filter` and
`ActionMap` used as type flags) default to true when no value is given and are
false only when the value begins with `0`, `n`, or `f`.

### Global

A global `CodeDef` in `interchange.cfg` registers the code for every catalog.
Global code is subject to the `Safe` compartment unless the calling catalog is
listed in [AllowGlobal](AllowGlobal.md).

### Catalog

A catalog `CodeDef` in `catalog.cfg` applies to that catalog only. Behavior is
otherwise identical to the global scope.

## Examples

Define a filter, from the strap demo `catalog.cfg`:

```
CodeDef string2uri Filter
CodeDef string2uri Description Sanitize a string for use in a URL
CodeDef string2uri Routine <<EOR
sub {
    my $val = shift;
    $val =~ s|/|::|g;
    $val =~ s|-|_|g;
    $val =~ s|\s+|-|g;
    return $val;
}
EOR
```

Define a custom search operator (put in `interchange.cfg`); the routine returns
a matcher sub:

```
CodeDef find_hammer SearchOp find_hammer

CodeDef find_hammer Routine <<EOR
sub {
    my ($self, $i, $string, $opname) = @_;
    return sub {
        my $string = shift;
        $string =~ /hammer/i;
    };
}
EOR
```

Mark a widget as accepting multiple selections:

```
CodeDef checkbox Multiple 1
```

## Notes

A `SearchOp` routine must be a function that *creates and returns* the actual
search function; the returned function receives the value to match and returns
true on a match. The simple example above does not honor `mv_negate` or other
search variables -- see `create_text_query` in `lib/Vend/Search.pm` for a
routine that does.

[UserTag](UserTag.md) is a specialization of this mechanism for defining tags;
for anything other than a `UserTag` definition it delegates to the same code
that `CodeDef` uses.

## See also

[UserTag](UserTag.md), [ActionMap](ActionMap.md), [FormAction](FormAction.md),
[ItemAction](ItemAction.md), [GlobalSub](GlobalSub.md),
[AllowGlobal](AllowGlobal.md), the [perl-embedding](../guides/perl-embedding.md)
guide.

## Source

Parsed by `parse_mapped_code` in `lib/Vend/Config.pm` (the destination classes
are the `%valid_dest` table); the resulting repository is consumed by the
respective subsystem modules (`lib/Vend/Interpolate.pm`, `lib/Vend/Order.pm`,
`lib/Vend/Form.pm`, `lib/Vend/Search.pm`, and others).
