# Options

Defines the named option types available to the item-options subsystem, and sets
per-type configuration. Reach for it to tune a built-in option type (`Simple`,
`Matrix`, `Old48`) or to register settings for a custom one.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Options  typename  key value  key value ...
    Options  typename  { perl-hash }

Parsed like a [Locale](Locale.md) definition: the first token is the option
type name, followed by shell-quoted `key value` pairs, or a single brace-quoted
Perl hash. Repeated lines for the same type merge. Default: empty as written,
but at startup Interchange always provides the `Simple`, `Matrix`, and `Old48`
types.

## Description

Each `Options` line stores settings for one option type into the catalog's
options repository. After all configuration is read, a postprocess step in
`lib/Vend/Config.pm` walks every named type (the three built-ins plus any you
defined), requires the matching `Vend::Options::TYPE` module, and fills in each
type's defaults from that module's `%Default` hash for keys you did not set. The
type named `default` -- or `Simple` if you define none -- becomes the catalog's
active `Options` type.

The keys a type accepts are defined by its module (`lib/Vend/Options/Simple.pm`,
`Matrix.pm`, `Old48.pm`, or your own). They control matters such as the joiner
between option values, sort order, and the column map used to read option
records. A `remap` key (or the `MV_OPTION_TABLE_MAP` variable) lets a type
rename the record fields it reads.

Because the base types are always present, most catalogs never need an `Options`
line -- they enable options with [OptionsEnable](OptionsEnable.md) and store the
per-product type in a column. Use `Options` only to override a type's defaults or
to introduce a new type.

## Examples

Override the joiner used by the `Simple` option type (in `catalog.cfg`):

```
Options Simple joiner ", "
```

Register a custom type and make it the catalog default:

```
Options MyType sort 1  joiner <BR>
Options default MyType
```

The custom type requires a corresponding `Vend::Options::MyType` module on the
Perl search path.

## Notes

The exact set of accepted keys is defined by each option-type module rather than
by the directive itself; consult the relevant `Vend/Options/*.pm` module for the
keys a given type honors.

## See also

[OptionsEnable](OptionsEnable.md), [OptionsAttribute](OptionsAttribute.md),
[Locale](Locale.md), the [cart-and-checkout](../guides/cart-and-checkout.md)
guide.

## Source

Parsed by `parse_locale` in `lib/Vend/Config.pm`, with a dedicated `Options`
postprocess in the same file; consumed via `$Vend::Cfg->{Options}` and the
option-type modules in `lib/Vend/Options.pm` and `lib/Vend/Options/`.
