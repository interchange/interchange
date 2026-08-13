# seti

Store a value into a scratch variable, interpolating the body first. It is the
interpolating counterpart of [set](set.md): the body is evaluated as
Interchange Tag Language (ITL) and the resulting text is what gets stored.

## Syntax

    [seti name] VALUE-WITH-ITL [/seti]

Container tag (has an end tag). The body is interpolated before being stored.
The tag itself produces no output.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `name`    | (required) | Name of the scratch variable to set. |

Positional order: `name`.

## Description

`[seti]` maps to the same routine as [set](set.md),
`Vend::Interpolate::set_scratch`, but the tag is defined with the `Interpolate`
flag, so its body is processed as ITL before assignment. The interpolated
result is stored in the named key of the session scratch namespace
(`$Scratch`), and the tag returns the empty string.

Use `[seti]` when you want to capture the value of an expression *now* — for
example the result of a [calc](calc.md), a [value](value.md), or a database
lookup — and read the fixed result back later. Use [set](set.md) instead when
you want to store literal or as-yet-unevaluated markup.

## Examples

Compute a value once and reuse it:

    [seti line_total][calc][value qty] * [item-price][/calc][/seti]
    Total: [scratch line_total]

Capture a field's current value into scratch:

    [seti code][cgi mv_sku][/seti]

The stored value is the interpolated text of `[cgi mv_sku]`, not the literal
string.

## See also

- [set](set.md), [scratch](scratch.md), [scratchd](scratchd.md)
- [tmp](tmp.md), [calc](calc.md), [value](value.md)
- Concepts: [sessions](../guides/sessions.md)

## Source

Defined in `code/SystemTag/seti.coretag`. Implemented by
`Vend::Interpolate::set_scratch`.
