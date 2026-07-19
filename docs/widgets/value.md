# value

Displays a field's value as HTML-entity-encoded text with no form control —
read-only output, not an input. Reach for it in a table editor or form when you
want to show a field but not let the user change it.

## Usage

    [display type=value name=FIELD value="text to show"]

To choose this widget in the admin UI, set the `type` field of the field's
`mv_metadata` record (keyed `table::column`) to `value`:

    code                type
    mytable::created    value

`[display table=mytable column=created key=SKU]` then shows the stored value
as plain, encoded text.

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `name` | derived | Field whose value is shown (used for the lookup; no field name is emitted, since nothing is submitted). |
| `value` | (looked up) | The value to display. |

This widget takes no formatting options; it emits the encoded value and nothing
else.

## Description

`value` returns the field's value after HTML-entity encoding
(`HTML::Entities::encode`, applied by the widget engine before the routine
runs). No `<input>`, `<select>`, or other control is produced, so the value is
displayed but cannot be edited or submitted. Because the value is encoded,
any markup in the data is shown literally rather than interpreted — use
[realvalue](realvalue.md) only when you deliberately need the raw, unencoded
value.

## Examples

    [display type=value name=note value="Ships in 3<5 days & counting"]

renders the value with the special characters encoded:

    Ships in 3&lt;5 days &amp; counting

A browser displays this as the literal text `Ships in 3<5 days & counting`.

## See also

- [realvalue](realvalue.md) — the same idea but *without* encoding (unsafe with
  untrusted data)
- [text](text.md) and [textarea](textarea.md) — editable equivalents

## Source

Defined in `code/Widget/value.widget`. Its routine returns the pre-encoded
value prepared by `Vend::Form::display` in `lib/Vend/Form.pm`.
