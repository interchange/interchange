# config

Return the value of an Interchange configuration directive at runtime -- from
the current catalog's configuration by default, or from the global
(`interchange.cfg`) configuration. Reach for it when a page or template needs
to read a setting rather than hard-code it.

## Syntax

    [config KEY]
    [config KEY global=1]

Standalone tag. The returned value is not reparsed.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `key`     |         | Configuration key to look up (first positional). |
| `global`  | `0`     | When true, read from the global configuration instead of the catalog's. |

Positional order: `key`, `global`.

## Description

With `global` false (the default) the tag reads from the catalog
configuration hash `$Vend::Cfg` -- the parsed contents of `catalog.cfg`. With
`global` true it reads from the `Global::` configuration namespace built from
`interchange.cfg`.

`key` may be a dotted path that walks nested hash and array references, so you
can reach into structured directives. Each segment selects a hash key, or, if
the current value is an array reference and the segment is an integer, an array
element. If a segment cannot be resolved to a hash or array reference the tag
logs an error and returns nothing.

Directive names are documented under [../config/](../config/README.md); the
value returned is whatever Interchange parsed that directive into, which for
some directives is a nested structure rather than a plain string.

## Examples

Read a simple catalog directive:

    [config ImageDir]

Read a global directive:

    [config global=1 PIDfile]

Walk a dotted path into a structured directive (the `products` entry of the
`Database` hash, then its `type`):

    [config Database.products.type]

## Notes

The value is returned as-is with no interpolation. Because it exposes raw
configuration, avoid emitting sensitive keys (for example credentials stored
in directives) into pages served to shoppers.

## See also

[../config/](../config/README.md),
[../guides/configuration.md](../guides/configuration.md),
[var](var.md)

## Source

Defined in `code/UserTag/config.tag`. Implemented by the inline Routine in
that file.
