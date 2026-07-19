# show

Displays an option list as `value=label` pairs in plain text, rather than
rendering an input control. Reach for it to show a field's full option
definition — both the stored values and their labels — for a report or a
read-only meta display.

## Usage

    [display type=show name=FIELD passed="v1=Label 1,v2=Label 2"]

The option list comes from the same sources as [select](select.md) (a `passed`
string, a database `lookup`/`lookup_query`, or a meta record's `options`
field). To choose this widget in the admin UI, set the `type` field of the
field's `mv_metadata` record (keyed `table::column`) to `show`.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `passed` | none | Option string, e.g. `red=Red,green=Green`. |
| `lookup` / `lookup_query` | none | Build the list from the database (see [select](select.md)). |
| `delimiter` | `,` | Separator used to join the output pairs. |

## Description

`show` takes the parsed option array (each element a `value,label` pair), joins
each pair back together with `=`, and joins the pairs with the delimiter. The
result reconstructs a `value=label,value=label` string from the stored options
and is returned as plain text, not HTML. Use [options](options.md) when you
want only the values.

## Examples

    [display type=show name=color passed="red=Red,green=Green,blue=Blue"]

renders the full pairs:

    red=Red,green=Green,blue=Blue

With a custom joiner:

    [display type=show name=color delimiter=" | " passed="red=Red,green=Green"]

renders:

    red=Red | green=Green

## See also

- [options](options.md) — the same list showing only the values
- [option_format](option_format.md) — the admin editor for an options string
- [select](select.md) — render the options as a dropdown control

## Source

Defined in `code/Widget/show.widget`; implemented by
`Vend::Form::show_data` in `lib/Vend/Form.pm`.
