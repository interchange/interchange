# widget

Build a single HTML form control (a `select`, radio group, checkbox set, text
box, and so on) from a widget definition and a value. Reach for it when you
need one form widget on an admin page and want to supply its options directly,
rather than looking them up from a product record.

This tag is part of the administrative UI toolset: it is loaded from
`code/UI_Tag/` when the back-office UI is enabled, and is not a storefront
tag. For the storefront equivalent that looks options up from the products
table, see [accessories](../tags/accessories.md).

## Syntax

    [widget name=fieldname type=select passed="a=A, b=B"]
    [widget name=fieldname type=select]OPTION STRING[/widget]

Container tag (it has an end tag). The body is interpolated as Interchange Tag
Language (ITL) before use, and becomes the option definition string when
`data`/`passed` are not given. The return value is HTML for the widget and is
reparsed as ITL by default.

The tag name is registered as `widget`.

## Attributes

| Attribute    | Default       | Description |
|--------------|---------------|-------------|
| `name`       | none          | Field name of the resulting HTML control. Required. Positional parameter 1. |
| `type`       | `select`      | Widget type: `select`, `radio`, `checkbox`, `text`, `textarea`, `password`, `hidden`, `yesno`, and the other types the form-widget engine understands (see [widgets](../widgets/README.md)). |
| `set`        | none          | Explicit value for the control, overriding any current or default value. |
| `default`    | none          | Value used when there is no value for `name` in the Values space and `set` is not given. |
| `pre_filter` | none          | Filter name(s) applied to the value before display. |
| `attribute`  | `attribute`   | Option/attribute name passed to the form builder. |
| `table`      | none          | Table to read an option definition from (when `passed`/`data` are not supplied). |
| `field`      | none          | Column read for the option definition. |
| `key`        | none          | Key used for the option-definition lookup. |
| `passed`     | body / `data` | The option definition string itself (for example `value=label` pairs). |
| `data`       | none          | Alias source for `passed`. |
| `cols`       | none          | Column width for sized widgets. |
| `rows`       | none          | Row count for sized widgets (for example `textarea`). |
| `delimiter`  | none          | Delimiter used when parsing the option string. |
| `extra`      | none          | Extra HTML/JavaScript attributes emitted on the tag. |
| `js`         | none          | Alias source for `extra`. |
| `filter`     | none          | When set, appends a hidden `ui_filter:NAME` input carrying this filter, so a submit-time filter is applied to the field. |

Positional order: `name`. Named and positional parameters cannot be mixed: if
any `name=value` attribute is present, the tag takes the named path and any
bare positional token is silently discarded. Since `[widget]` almost always
needs `type` or other attributes, write `name=` explicitly.

Aliases: `db` for `table`; `column` for `field`; `outboard` for `key`.

The tag declares `addAttr`, so any other attribute is forwarded to the
form-widget builder.

## Description

`[widget]` is a thin front end to `Vend::Form::display`, the routine that
renders every form control in Interchange. It resolves a value and an option
definition, then asks the builder for the widget markup.

The value is chosen in this order: `set` if defined; otherwise the current
`[value name]` from the Values space, falling back to `default`. If
`pre_filter` is given, the value is passed through those filters before
rendering. The option definition (the choices for a `select`, `radio`, or
`checkbox` widget) comes from `data`, then `passed`, then the tag body.

The Values space is Interchange's per-session store of form field values
(what `[value ...]` reads). Because `[widget]` reads it by `name`, a control
built with `[widget]` shows the value the shopper or operator last submitted
for that field.

When `filter` is set, the tag additionally emits a hidden input named
`ui_filter:NAME`, which the form processor uses to apply the named filter to
the submitted value.

## Examples

A `select` widget with two literal options, defaulting to `b`:

    [widget name=status type=select default=b passed="a=Active, b=Inactive"]

A radio group whose options come from the tag body:

    [widget name=color type=radio]
      red=Red, green=Green, blue=Blue
    [/widget]

A plain text box pre-filled from the current value of the `email` field:

    [widget name=email type=text cols=40]

A `yesno` widget with a submit-time filter attached:

    [widget name=active type=yesno filter=digits]

## Notes

- `[widget]` supplies options directly; use
  [accessories](../tags/accessories.md) when the option string should be read
  from a product (or other database) record.
- The set of valid `type` values, and the grammar of the option string, belong
  to the form-widget engine; see the [widgets](../widgets/README.md) reference
  and the [forms guide](../guides/forms.md).

## See also

- [accessories](../tags/accessories.md) — database-driven form widgets
- [widget_info](widget_info.md) — query a widget definition's metadata
- [widget_meta](widget_meta.md) — the default meta record for a widget type
- The [forms guide](../guides/forms.md)

## Source

Defined in `code/UI_Tag/widget.coretag` as an inline Routine. It builds an
option hash and calls `Vend::Form::display`.
