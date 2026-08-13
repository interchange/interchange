# default

Returns a user form value, substituting a fallback string when the value
is empty. It is [value](value.md) with the `default=` option filled in for
you. Reach for it to pre-fill a form field or greeting that should show a
placeholder until the shopper supplies a value.

## Syntax

    [default name default-string]
    [default name=field default=string ...]

Standalone tag (no end tag).

## Attributes

| Attribute | Default     | Description |
|-----------|-------------|-------------|
| `name`    | (none)      | Form/values variable to read. |
| `default` | `default`   | String returned when the variable is empty. |

Positional order: `name`, `default`.

`[default]` accepts arbitrary additional attributes (`addAttr`); they are
passed through to [value](value.md), so options such as `filter`, `keep`,
`set`, `scratch`, `enable_html`, and `enable_itl` behave as documented
there.

## Description

The tag reads the named variable from the Values namespace (the same place
[value](value.md) reads). If that value is empty it returns the `default`
string; otherwise it returns the value. Internally it sets the `default`
option and calls the same routine as [value](value.md), so — like `[value]`
— any `[` in the returned value is encoded to `&#91;` and any `<` to
`&lt;` unless you pass `enable_itl` / `enable_html`.

If you give no `default` argument, the literal word `default` is returned
for an empty value (the built-in fallback), which is rarely what you want —
supply your own placeholder.

## Examples

Greet the shopper, falling back to `Anonymous` when `fname` is unset:

    Hello, [default fname Anonymous]!

Pre-fill a text input with the stored value or a placeholder:

    <input type="text" name="fname" value="[default fname Anonymous]">

## Notes

`[default name x]` is equivalent to `[value name=name default=x]`. The
older documentation labelled this tag deprecated in favor of
[value](value.md) with an explicit `default=`; the code carries no
deprecation flag, but for new templates preferring `[value ... default=]`
keeps all the value options in one place.

## See also

[value](value.md), [cgi](cgi.md), [scratch](scratch.md), the
[forms](../guides/forms.md) guide.

## Source

Defined in `code/SystemTag/default.coretag` (inline `Routine`), which
calls `tag_value` (`Vend::Interpolate::tag_value` in
`lib/Vend/Interpolate.pm`).
