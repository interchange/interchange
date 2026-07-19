# realvalue

Displays a field's value as raw, **unencoded** text with no form control.
Identical to [value](value.md) except that it performs no HTML-entity encoding,
so any HTML or Interchange Tag Language (ITL) in the data passes through
literally. Reach for it only when you fully trust the data and deliberately
want its markup rendered.

> **Caution:** because the value is emitted unencoded, untrusted data can inject
> arbitrary HTML (and, in some contexts, ITL) into the page. Use
> [value](value.md) unless you specifically need raw output.

## Usage

    [display type=realvalue name=FIELD value="<b>trusted markup</b>"]

To choose this widget in the admin UI, set the `type` field of the field's
`mv_metadata` record (keyed `table::column`) to `realvalue`:

    code               type
    mytable::blurb     realvalue

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `name` | derived | Field whose value is shown (used for the lookup; no field name is emitted). |
| `value` | (looked up) | The value to display, emitted verbatim. |

This widget takes no formatting options.

## Description

`realvalue` returns `opt->{value}` directly — the resolved field value before
the widget engine's HTML-entity encoding step. No control is produced and no
escaping is applied, so the browser interprets any markup in the value.
Contrast with [value](value.md), which returns the encoded form.

## Examples

    [display type=realvalue name=blurb value="Now <b>on sale</b>!"]

renders the value verbatim:

    Now <b>on sale</b>!

A browser renders the `<b>` tag, showing **on sale** in bold — the markup is
live, not escaped.

## See also

- [value](value.md) — the encoded (safe) counterpart
- [text](text.md) and [textarea](textarea.md) — editable equivalents

## Source

Defined in `code/Widget/realvalue.widget`, whose routine is
`sub { my $opt = shift; return $opt->{value} }`. Value resolution happens in
`Vend::Form::display` in `lib/Vend/Form.pm`.
