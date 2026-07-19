# formel

Emit a labeled HTML form element -- text input, textarea, select, radio,
checkbox, or a metadata-driven widget -- pre-filled from the session's form
values and able to highlight itself when the field failed an order-profile
check. The name is short for "form element". Reach for it to build forms whose
fields remember what the shopper typed and flag validation errors.

## Syntax

    [formel LABEL NAME TYPE SIZE]
    [formel label=LABEL name=NAME type=TYPE choices="a,b,c"]

Standalone tag. The returned HTML is not reparsed.

## Attributes

| Attribute   | Default     | Description |
|-------------|-------------|-------------|
| `label`     |             | Text label shown with the element (first positional). |
| `name`      |             | Form field name; also the value key read from `[value ...]`. |
| `type`      | `text`      | `text`, `password`, `textarea`, `select`, `radio`, `checkbox`, `display`, or any type the [display](display.md) tag accepts. |
| `size`      |             | Element size; for `textarea` a `cols,rows` (or `colsxrows`) pair. |
| `choices`   |             | Comma-separated options for `select`/`radio`/`checkbox`; each may be `value=label`. |
| `format`    | `%s %s %s`  | `sprintf` template combining label, element, and help. |
| `order`     |             | When set, place the element before the label. |
| `reset`     |             | Render an empty element (ignore the stored value). |
| `maxlength` |             | `maxlength` attribute for text inputs. |
| `cause`     |             | Error text appended to the label when the field has an error. |
| `signal`    |             | `sprintf` template used to mark the label on error (instead of the CSS-contrast span). |
| `checkfor`  | `name`      | Field name whose error status is checked. |
| `help`      |             | Help text, available as the third `format` slot. |
| `table`     | `products`  | Table used for `type=display` metadata lookups. |

Positional order: `label`, `name`, `type`, `size`.

Defaults for `cause`, `format`, `order`, `reset`, `signal`, and `size` are
taken from the corresponding `mv_formel_*` form values when not given as
attributes.

## Description

The element's current value comes from the session form values
(`[value NAME]`). For `select`, `radio`, and `checkbox`, the matching option(s)
from `choices` are pre-selected; checkboxes support multiple stored values.

Error awareness ties into Interchange's order-profile checks (see
[../guides/forms.md](../guides/forms.md)): if the field named by `checkfor`
has a recorded [error](error.md), the label is wrapped in a
`<span class="mv_contrast">` (the class name comes from the `CSS_CONTRAST`
variable) or formatted with `signal`, so failed fields stand out when a form is
redisplayed. `cause` instead appends the stored error message to the label.

`type=display` renders the field through the [display](display.md) tag using
table metadata, and any unrecognized type is passed straight to
[display](display.md) as a widget type.

## Examples

A pre-filled text field with a label:

    [formel "First name" fname]

A select with value=label choices:

    [formel label="Country" name=country type=select
        choices="us=United States,ca=Canada,mx=Mexico"]

A textarea sized 40 columns by 5 rows:

    [formel label=Comments name=comments type=textarea size="40,5"]

## Notes

Because `formel` reads from `[value ...]` and consults the error table, it
gives you redisplay-with-values and error highlighting without hand-writing the
conditional markup. The exact HTML for `display` and pass-through widget types
is produced by the [display](display.md) tag, not by `formel` itself.

## See also

[value](value.md), [display](display.md), [error](error.md),
[../guides/forms.md](../guides/forms.md),
[../widgets/](../widgets/README.md)

## Source

Defined in `code/UserTag/formel.tag`. Implemented by the inline Routine in that
file.
