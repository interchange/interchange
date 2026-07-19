# text

Renders a single-line `<input type="text">` box. This is the default
Interchange form widget: a field with no widget declared and no options renders
as a text box. Reach for it for free-form single-line input.

## Usage

    [display type=text name=FIELD value="current text"]

To choose this widget in the admin UI, set the `type` field of the field's
`mv_metadata` record (keyed `table::column`) to `text`; the strap demo uses it
for most plain fields, for example:

    code                type    width
    affiliate::name     text    50

`[display table=affiliate column=name key=CODE]` then renders the text box.
Because `text` is the default, a meta record with an empty `type` also renders
as a text box.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `name` | derived | HTML field name. |
| `value` | (looked up) | Current value; placed HTML-entity-encoded in the `value` attribute. |
| `width` / `cols` / `size` | none | Size of the box in characters (the `size` attribute). |
| `maxlength` | none | Maximum number of characters the box accepts. |
| `disabled` | off | Render the box disabled. |
| `id` | none | HTML `id` for the element. |
| `extra` | none | Extra attributes inserted into the `<input>` tag (for example `class="..."`). |

The shorthand type `text_NN` sets the width, so `type=text_40` is the same as
`type=text width=40`.

## Description

`text` renders from a fixed template rather than a Perl routine. The template
emits `<input type="text" name="NAME" value="ENCODED" ...>` where `ENCODED` is
the current value HTML-entity encoded, followed by any of `size`, `title`,
`id`, `disabled`, `maxlength`, and `extra` that you supplied. There is no
option list — the value is displayed for editing, not chosen from choices.

Because the widget engine registers `text` as its `default` template, any field
whose widget cannot be resolved also falls back to this box.

## Examples

A minimal text box:

    [display type=text name=email value="me@example.com"]

renders:

    <input type="text" name="email" value="me@example.com">

With a width:

    [display type=text name=email width=40 value="me@example.com"]

renders:

    <input type="text" name="email" value="me@example.com" size="40">

## See also

- [textarea](textarea.md) — multi-line text box (defined in the same file)
- [value](value.md) and [realvalue](realvalue.md) — display the value without
  an editable control
- [forms](../guides/forms.md) — building and processing forms

## Source

Defined in `code/Widget/text.widget` (which also defines `textarea`); rendered
from the `text` entry of `%Template` in `lib/Vend/Form.pm` (the same template
is aliased as `default`).
