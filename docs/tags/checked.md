# checked

Emits ` checked="checked"` when a form variable matches a given value, so
a checkbox or radio button redisplays in the state the shopper last chose.
Reach for it inside `<input type="checkbox">` and `<input type="radio">`
elements to give them "memory" across form submissions.

## Syntax

    [checked name value]
    [checked name=field value=v cgi=1 default=1 ...]

Standalone tag (no end tag). It returns either the literal string
` checked="checked"` (note the leading space) or an empty string.

## Attributes

| Attribute   | Default | Description |
|-------------|---------|-------------|
| `name`      | (none)  | Form variable to test. |
| `value`     | `on`    | Value that marks the control checked. |
| `cgi`       | `0`     | Test the CGI namespace instead of user values. |
| `default`   | `0`     | Mark checked when the variable has never been set. |
| `case`      | `0`     | Match case-sensitively (default folds case). |
| `multiple`  | `0`     | Treat the stored value as a list of values. |
| `delimiter` | `\0`    | Separator for `multiple`; setting it implies `multiple=1`. |

Positional order: `name`, `value`.

Positional and named arguments cannot be mixed. Interchange takes the
positional path only when the tag has no `name=value` attribute at all, so a
bare token written alongside a named attribute is silently discarded — no
error, just a missing value. Write an invocation either entirely positionally
(`[checked gift_wrap 1]`) or, as below, entirely with named attributes.

`multiple` and `default` may also be supplied bare (as
`Implicit`/flag attributes). `[checked]` accepts arbitrary additional
attributes (`addAttr`).

## Description

By default the tag reads the Values namespace (the same place
[value](value.md) reads, populated from submitted form fields). With
`cgi=1` it reads the volatile CGI namespace (the same place
[cgi](cgi.md) reads). It compares the stored value to `value`:

- If the stored value is empty and `default` is true, the control is
  checked. This handles the first display, before the form has ever been
  submitted.
- Otherwise the control is checked when the stored value equals `value`.
  Matching folds case unless `case=1`.
- With `multiple` (or any `delimiter`), the stored value is treated as a
  delimiter-separated list and the control is checked when `value` appears
  anywhere in it. The default delimiter is an ASCII null (`\0`), the
  format Interchange uses for stacked multiple-select values.

Because an unchecked checkbox submits no value at all, a checkbox will not
reset itself on the next submit unless you also clear the variable — for
example with `[value name=foo set=""]` before the input.

## Examples

Give a checkbox memory across a refresh, reading the CGI namespace:

    <input type="checkbox" name="gift_wrap" value="1"[checked name=gift_wrap value=1 cgi=1]> Gift wrap

Two radio buttons where "No" is selected until the shopper chooses:

    <input type="radio" name="factory_sealed" value="1"[checked name=factory_sealed value=1]> Yes
    <input type="radio" name="factory_sealed" value="0"[checked name=factory_sealed value=0 default=1]> No

A checkbox in a group where several values may be stored together:

    <input type="checkbox" name="colors" value="red"[checked name=colors value=red multiple=1]> Red
    <input type="checkbox" name="colors" value="blue"[checked name=colors value=blue multiple=1]> Blue

## Notes

The returned string begins with a space, so write it immediately after the
attribute before it (`value="0"[checked ...]`) without adding your own
space.

## See also

[selected](selected.md), [value](value.md), [cgi](cgi.md), the
[forms](../guides/forms.md) guide.

## Source

Defined in `code/SystemTag/checked.coretag` (inline `Routine`).
