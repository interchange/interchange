# selected

Emit ` selected="selected"` when a form value matches a given option value.
Use it inside `<option>` tags to pre-select the choice that reflects the
current value of a field.

## Syntax

    [selected name value]
    [selected name=fieldname value=optvalue multiple=1 delimiter=","]

Standalone tag (no end tag). Returns either the literal string
` selected="selected"` (note the leading space) or the empty string.

## Attributes

| Attribute   | Default | Description |
|-------------|---------|-------------|
| `name`      | (required) | Name of the form field to test. |
| `value`     | (required) | The option value to compare against. |
| `cgi`       | `0`     | When true, read the field from CGI (submitted) values instead of the [value](value.md) namespace. |
| `default`   | `0`     | When true, select this option if the field is empty/unset. |
| `case`      | `0`     | When true, compare case-sensitively. By default the comparison is case-insensitive. |
| `multiple`  | `0`     | Treat the stored field as a list of several selected values. |
| `delimiter` | `\0` (null) | Separator for the `multiple` list; setting a delimiter implies `multiple=1`. |

Positional order: `name`, `value`.

The tag declares `addAttr`, so all options above are read from the attribute
list.

## Description

`[selected]` compares the stored value of field `name` with `value`. By default
the field is read from the [value](value.md) namespace (`$Values`); with
`cgi=1` it reads the raw submitted CGI value instead. The comparison is
case-insensitive unless `case=1`.

If they match, the tag returns ` selected="selected"`, the attribute that marks
an HTML `<option>` as chosen; otherwise it returns nothing. With `default=1`,
the option is selected when the field has no value at all — handy for marking a
"please choose" placeholder.

For multi-select fields, `multiple=1` (or supplying a `delimiter`) treats the
stored field as a delimited list and returns the selected attribute if `value`
appears anywhere in that list. With the default null delimiter, the list is
split on null bytes, which is how Interchange stores multiple submitted values
for one field name.

## Examples

Pre-select the option matching the `size` field:

    <select name="size">
      <option value="S"[selected name=size value=S]>Small</option>
      <option value="M"[selected name=size value=M]>Medium</option>
      <option value="L"[selected name=size value=L]>Large</option>
    </select>

If `[value size]` is `M`, the rendered Medium option is:

    <option value="M" selected="selected">Medium</option>

Mark a placeholder as selected when nothing is chosen yet:

    <option value=""[selected name=country value="" default=1]>Choose...</option>

A multi-select restored from a comma-delimited stored value:

    <option value="red"[selected name=colors value=red multiple=1 delimiter=,]>Red</option>

## See also

- [value](value.md), [loop](loop.md)
- [checked](checked.md)
- Concepts: [forms](../guides/forms.md)

## Source

Defined in `code/SystemTag/selected.coretag` (inline Routine).
