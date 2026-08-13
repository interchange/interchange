# set

Store a value into a scratch variable, without interpolating the body. Scratch
is Interchange's per-session scratchpad namespace; `[set]` is the usual way to
put a literal value there for later reading with [scratch](scratch.md).

## Syntax

    [set name] VALUE [/set]

Container tag (has an end tag). The body is the value to store. By default the
body is stored verbatim — any Interchange Tag Language (ITL) inside it is not
interpolated. The tag itself produces no output.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `name`    | (required) | Name of the scratch variable to set. |

Positional order: `name`.

## Description

`[set]` maps to `Vend::Interpolate::set_scratch`, which assigns the tag body to
the named key in the session scratch namespace (`$Scratch`) and returns the
empty string.

Because the body is not interpolated, `[set]` is the right choice for storing
literal text, template fragments, or ITL that you want to store now and
interpolate later. To store an interpolated result instead, use
[seti](seti.md), which is the same tag with interpolation turned on, or pass
`interpolate=1` to this tag.

The value persists for the life of the session; read it back with
[scratch](scratch.md), read-and-delete it with [scratchd](scratchd.md), or use
[tmp](tmp.md) instead when the value should not outlive the page or request.

## Examples

Store a literal value and read it back:

    [set page_title]Product catalog[/set]
    <title>[scratch page_title]</title>

produces:

    <title>Product catalog</title>

Store ITL to be interpolated later, not now:

    [set greeting]Hello, [value fname]![/set]

The stored value is the literal string `Hello, [value fname]!`; the
[value](value.md) tag is evaluated only when [scratch](scratch.md) later inserts
it into an interpolated context.

## See also

- [seti](seti.md), [scratch](scratch.md), [scratchd](scratchd.md)
- [tmp](tmp.md), [tmpn](tmpn.md)
- [value](value.md)
- Concepts: [sessions](../guides/sessions.md)

## Source

Defined in `code/SystemTag/set.coretag`. Implemented by
`Vend::Interpolate::set_scratch`.
