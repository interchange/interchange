# textarea

Renders a multi-line `<textarea>` box for free-form text that runs longer than
a single line. Reach for it instead of [text](text.md) when you want the reader
to see and edit several lines at once.

## Usage

    [display type=textarea name=FIELD value="current text" rows=4 cols=40]

To choose this widget in the admin UI, set the `type` field of the field's
`mv_metadata` record (keyed `table::column`) to `textarea`; size it with the
meta record's `height` and `width` columns, which map to `rows` and `cols`:

    code                type       height  width
    products::comment   textarea   4       60

`[display table=products column=comment key=SKU]` then renders the box.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `name` | derived | HTML field name. |
| `value` | (looked up) | Current contents; placed HTML-entity-encoded between the tags. |
| `rows` / `height` | none | Visible number of text lines (the `rows` attribute). |
| `cols` / `width` / `size` | none | Visible width in characters (the `cols` attribute). |
| `maxlength` | none | Maximum number of characters accepted. |
| `wrap` | none | Value for the `wrap` attribute (for example `virtual` or `off`). |
| `disabled` | off | Render the box disabled. |
| `id` | none | HTML `id` for the element. |
| `extra` | none | Extra attributes inserted into the `<textarea>` tag (for example `class="..."`). |

The shorthand type `textarea_ROWS_COLS` presets the size, so
`type=textarea_10_60` is the same as `type=textarea rows=10 cols=60`.

## Description

`textarea` renders from a fixed template rather than a Perl routine. The
template emits `<textarea name="NAME" ...>ENCODED</textarea>`, where `ENCODED`
is the current value HTML-entity encoded, followed by any of `rows`, `cols`,
`disabled`, `maxlength`, `title`, `id`, `wrap`, and `extra` that you supplied.
There is no option list — the value is displayed for editing, not chosen from
choices.

Sizing follows a small set of rules in `lib/Vend/Form.pm`:

- `width` (or `size`) is an alias for `cols`, and `height` is an alias for
  `rows`; whichever you pass fills the corresponding attribute.
- The `textarea_ROWS_COLS` shorthand sets both from the type name — the first
  number is `rows`, the second is `cols`. When that shorthand form is used
  without explicit numbers (for example `type=textarea_wrap`), it defaults to
  `rows=4` and `cols=40`.
- A plain `type=textarea` gets **no** default `rows` or `cols`: each attribute
  is emitted only if you supply it, so an unadorned `textarea` renders with
  neither and the browser applies its own default size.

## Examples

A minimal box (no size given, so no `rows`/`cols` attribute):

    [display type=textarea name=comment]

renders:

    <textarea name="comment"></textarea>

Sized, with current contents:

    [display type=textarea name=comment rows=4 cols=60 value="Please deliver after 5pm."]

renders:

    <textarea name="comment" rows="4" cols="60">Please deliver after 5pm.</textarea>

The `textarea_ROWS_COLS` shorthand is equivalent:

    [display type=textarea_4_60 name=comment value="Please deliver after 5pm."]

renders the same tag:

    <textarea name="comment" rows="4" cols="60">Please deliver after 5pm.</textarea>

## See also

- [text](text.md) — single-line text box (defined in the same file)
- [value](value.md) and [realvalue](realvalue.md) — display the value without
  an editable control
- [display](../admin-tags/display.md), [widget](../admin-tags/widget.md)
- [forms](../guides/forms.md) — building and processing forms

## Source

Defined in `code/Widget/text.widget` (which also defines [text](text.md));
rendered from the `textarea` entry of `%Template` in `lib/Vend/Form.pm`. Size
options are normalized by `display` and `parse_type` in the same module.
