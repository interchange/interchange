# options

Displays the **values** of an option list as plain text (comma-joined), rather
than rendering an input control. Reach for it when you want to show which option
*values* a field defines — for example in a report or a read-only meta display.

## Usage

    [display type=options name=FIELD passed="v1=Label 1,v2=Label 2"]

The option list comes from the same sources as [select](select.md) (a `passed`
string, a database `lookup`/`lookup_query`, or a meta record's `options`
field). To choose this widget in the admin UI, set the `type` field of the
field's `mv_metadata` record (keyed `table::column`) to `options`.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `passed` | none | Option string, e.g. `red=Red,green=Green`. |
| `lookup` / `lookup_query` | none | Build the list from the database (see [select](select.md)). |
| `delimiter` | `,` | Separator used both to split the input and to join the output. |

## Description

`options` takes the parsed option array (each element a `value,label` pair) and
returns just the first column — the values — joined with the delimiter. Labels
are discarded. The result is a plain string, not HTML, so it is safe to drop
into surrounding text. Use [show](show.md) instead when you want the full
`value=label` pairs.

## Examples

    [display type=options name=color passed="red=Red,green=Green,blue=Blue"]

renders the values only:

    red,green,blue

With a custom joiner:

    [display type=options name=color delimiter="; " passed="red=Red,green=Green"]

renders:

    red; green

## See also

- [show](show.md) — the same list shown as `value=label` pairs
- [select](select.md) — render the options as a dropdown control
- [option_format](option_format.md) — the admin editor for an options string

## Source

Defined in `code/Widget/options.widget`; implemented by
`Vend::Form::show_options` in `lib/Vend/Form.pm`.
