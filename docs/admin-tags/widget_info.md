# widget_info

Look up the registered metadata for a form-widget type: its implementing
widget code, description, help text, documentation, visibility, and whether it
supports multiple values. Reach for it when an admin page needs to describe or
introspect the available widgets rather than render one.

This tag is part of the administrative UI toolset: it is loaded from
`code/UI_Tag/` when the back-office UI is enabled, and is not a storefront
tag.

## Syntax

    [widget_info name=WIDGET attribute=ATTR]
    [widget_info WIDGET ATTR]

Standalone tag (no end tag). Its output is reparsed as Interchange Tag
Language (ITL) by default.

The tag name is registered as `widget-info`; Interchange treats hyphens and
underscores in tag names interchangeably, so `[widget_info]` and
`[widget-info]` are the same tag.

## Attributes

| Attribute   | Default | Description |
|-------------|---------|-------------|
| `name`      | none    | Widget type to query (for example `select`, `yesno`, `date`). Positional parameter 1. |
| `attribute` | none    | Which metadata attribute to return. Positional parameter 2. |

Positional order: `name`, `attribute`.

The queryable attributes are `Widget`, `Documentation`, `Visibility`,
`Description`, `Help`, `Multiple`, and `Version`; the attribute name is matched
case-insensitively. The special attribute `exists` maps to `Widget`, so
`attribute=exists` returns a true value when the widget is defined.

## Description

`[widget_info]` reads the widget code-definition repositories:
`$Global::CodeDef->{Widget}` (widgets defined globally) and, when the widget is
also defined at the catalog level, `$Vend::Cfg->{CodeDef}{Widget}`. A
catalog-level definition takes precedence for a given name.

The return depends on how many arguments you give:

- **`name` and `attribute`** — returns that single attribute's value as a
  scalar. This is the practical, page-friendly form.
- **`name` only** — returns a hash reference of every available attribute for
  that widget.
- **neither** — returns a hash reference of hash references for all widgets.

Because ITL renders a returned hash reference as its Perl stringification (for
example `HASH(0x55...)`), the hash-reference forms are useful mainly from
embedded Perl or when the result is captured and walked programmatically. On a
page, pass both `name` and `attribute` to get printable output.

## Examples

Return one widget's description:

    [widget_info name=yesno attribute=Description]

Test whether a widget type is defined (the `exists` alias maps to `Widget`):

    [if type=explicit compare="[widget_info name=date attribute=exists]"]
      date widget is available
    [/if]

Positional form, fetching a widget's help text:

    [widget_info select Help]

## Notes

- The single scalar form (`name` plus `attribute`) is the one to use on a
  page. The no-argument and name-only forms return hash references, which do
  not render usefully as plain text.
- The attribute set is fixed to the seven names listed above (plus the
  `exists` alias); unknown attribute names return nothing.

## See also

- [widget](widget.md) — render a form widget
- [widget_meta](widget_meta.md) — the default meta record for a widget type
- The [widgets](../widgets/README.md) reference

## Source

Defined in `code/UI_Tag/widget_info.coretag` as an inline Routine. It reads the
`Widget` code definitions from `$Global::CodeDef` and `$Vend::Cfg->{CodeDef}`.
