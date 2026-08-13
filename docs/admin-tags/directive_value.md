# directive_value

Return the configured value of an Interchange configuration directive as
seen by the running catalog, optionally with catalog and global variables
expanded. It is part of the administrative UI toolset (loaded only when the
admin UI is enabled), not a storefront tag; the admin uses it to show the
current settings of directives in configuration screens.

## Syntax

    [directive_value name]
    [directive_value name unparse]

Standalone tag.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `name`    |         | The directive name to look up (for example `MailOrderTo`). |
| `unparse` |         | If true, expand `@@GLOBAL@@` and `__CATALOG__` variable references in the value. |

Positional order: `name`, `unparse` (the first two parameters).

## Description

The tag calls `UI::Primitive::read_directive`, which returns both the raw
directive value and a parsed form. When `unparse` is true, variable
references are interpolated in the parsed form:

- `@@NAME@@` is replaced with the corresponding global variable
  (`$Global::Variable->{NAME}`).
- `__NAME__` is replaced with the corresponding catalog variable
  (`$Vend::Cfg->{Variable}{NAME}`).

The tag returns the parsed value when one is available, otherwise the raw
value.

## Examples

Show the configured order-email recipient:

    [directive_value MailOrderTo]

Show a directive whose configured value contains variable references, with
those references resolved:

    [directive_value name=DirConfig unparse=1]

## Notes

- What counts as the "parsed" versus "raw" value is determined by
  `UI::Primitive::read_directive`; for most simple scalar directives the two
  are the same.

## See also

- [Configuration reference](../config/) — the directives this tag reports on
- The [admin UI guide](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/directive_value.coretag`. Implemented by the inline
Routine in that file, which calls `UI::Primitive::read_directive`.
