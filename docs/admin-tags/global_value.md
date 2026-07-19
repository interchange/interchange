# global_value

Return the value of a Perl global variable named by its fully qualified
symbol. It is part of the administrative UI toolset (loaded only when the
admin UI is enabled), not a storefront tag; the admin uses it to read
process-level globals that are not otherwise exposed to pages.

## Syntax

    [global_value name]

Standalone tag. Interchange treats `-` and `_` as equivalent in tag names,
so the shipped admin writes it as `[global-value ...]`; that is the same tag.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `name`    |         | Fully qualified name of a Perl scalar global (for example `Vend::Cfg->{VendRoot}` is *not* valid here — this reads a package scalar such as `Global::VendRoot`). |

Positional order: `name` (the only parameter).

## Description

The tag performs a symbolic scalar dereference: given a package-qualified
name it returns the value of that global scalar (`${$name}`), or the empty
string if it is undefined. It reads only simple package scalars, not hash or
array elements.

## Examples

Read the Interchange root directory global:

    [global_value Global::VendRoot]

Read the running server's version scalar:

    [global_value Global::Version]

## Notes

- This tag dereferences an arbitrary symbol with `no strict 'refs'`, so it
  can expose any package global in the interpreter. It is deliberately an
  admin-only tag; do not enable it in storefront contexts.
- It only reads scalars. To read structured configuration prefer the
  purpose-built tags (for directives, see
  [directive_value](directive_value.md)).

## See also

- [directive_value](directive_value.md) — read configuration directive values
- The [admin UI guide](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/global_value.coretag`. Implemented by the inline
Routine in that file.
