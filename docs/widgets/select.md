# select

Renders a `<select>` dropdown menu from a list of value/label choices. This is
the default Interchange form widget for a field with options and the workhorse
behind Yes/No, combo, and multi-select variants. Reach for it whenever a field
has a fixed or looked-up set of choices.

## Usage

    [display type=select name=FIELD passed="v1=Label 1,v2=Label 2"]

The choices can come from three places (see Description): a `passed` option
string, a database `lookup`/`lookup_query`, or the meta record's `options`
field. To choose this widget in the admin UI, set the `type` field of the
field's `mv_metadata` record (keyed `table::column`) to `select` and put the
choices in the `options` field. The strap demo does this for the `access`
table's superuser flag:

    code            type      options
    access::super   select    0=No, 1=Yes

`[display table=access column=super key=USER]` then renders the dropdown.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `name` | derived | HTML field name. |
| `value` | (looked up) | Current value; the matching option is marked `SELECTED`. |
| `passed` | none | Option string, e.g. `red=Red,green=Green`. Also accepts an array or hash reference when called from Perl. |
| `options` | none | Option string merged with lookup results (meta-record field). |
| `lookup` | none | Column (or `key,label` pair) to build options from a database `SELECT DISTINCT`. |
| `lookup_query` | none | Full `SELECT` statement(s) to build options; first column is the value, second the label. |
| `table` | first product table | Table used by `lookup`/`lookup_query`. |
| `multiple` | off | Render a multi-select box (equivalent to the `multiple` widget). |
| `rows` | none | When set, becomes the `size` attribute (a scrolling list box). |
| `cols` | none | Truncate long labels to this many characters (with a trailing `..`). |
| `delimiter` | `,` | Separator used when splitting a `passed` string into options. |
| `option_template` | none | Per-option template using `{VALUE}`/`{LABEL}` instead of the plain label. |
| `extra` | none | Extra attributes inserted into the `<select>` tag (for example `class="..."`). |

## Description

`select` renders an HTML `<select>` element. Each choice is a `value=label`
pair; a bare `value` with no `=label` uses the value as its own label. A
trailing `*` on a choice marks it as the default selection when no `value` is
supplied. Choices whose value has the form `~~Group~~` open an `<optgroup>`.

Where the options come from:

- **passed** — an inline string such as `passed="S=Small,M=Medium,L=Large"`,
  split on the delimiter, then on `=` into value and label.
- **lookup / lookup_query** — Interchange queries the database and builds the
  options from the rows. `lookup=state` selects distinct values of that
  column; `lookup_query="select code,name from country"` uses the first two
  selected columns as value and label.
- **meta options** — when rendered through [display](../admin-tags/display.md)
  with an `mv_metadata` record, the record's `options` field supplies the
  choices, and special values like `columns::`, `keys::`, or `filters` expand
  to the table's columns, keys, or the installed filter names.

The current `value` is compared to each option value; the match receives
`SELECTED`. Labels are HTML-entity encoded unless `pre_filter=decode_entities`.

## Examples

A minimal inline dropdown:

    [display type=select name=color passed="red=Red,green=Green,blue=Blue"]

renders:

    <select name="color"><option value="red">Red<option value="green">Green<option value="blue">Blue</select>

With a current value, the matching option is selected:

    [display type=select name=color value=green passed="red=Red,green=Green,blue=Blue"]

renders:

    <select name="color"><option value="red">Red<option value="green" SELECTED>Green<option value="blue">Blue</select>

Building the list from the database with a query:

    [display type=select name=country
             lookup_query="select code, name from country order by name"]

renders one `<option value="CODE">Name` per row of the `country` table.

## See also

- [multiple](multiple.md) — the same widget forced into multi-select mode
- [combo](combo.md) and [movecombo](movecombo.md) — dropdown plus a text box
- [radio](radio.md) — the same choices as radio buttons
- [yesno](yesno.md), [noyes](noyes.md), [ynzero](ynzero.md) — two-choice
  wrappers that delegate to this widget
- [accessories](../tags/accessories.md) — product-option front end to the
  widget engine
- [forms](../guides/forms.md) — building and processing forms

## Source

Defined in `code/Widget/select.widget`; implemented by
`Vend::Form::dropdown` in `lib/Vend/Form.pm`.
