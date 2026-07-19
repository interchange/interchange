# evalue

`[evalue]` is an alias for [value](value.md) preset with `keep=1
filter="encode_entities"`. It returns a form variable from the `$Values`
space HTML-entity-encoded for safe display, without altering the stored value.
Use it wherever you would use `[value name filter=encode_entities keep=1]`.

Because the alias also presets `name=`, pass the variable name as an
attribute:

    [evalue name=comments]

is equivalent to:

    [value name=comments filter=encode_entities keep=1]

See [value](value.md) for the full attribute list and behavior. Note that
plain [value](value.md) already encodes `[` and `<` by default; `[evalue]`
additionally runs the `encode_entities` filter, which also escapes `&`, `>`,
and `"`.

## Source

Defined as an alias in `code/SystemTag/value.coretag`
(`UserTag evalue Alias value keep=1 filter="encode_entities" name=`).
