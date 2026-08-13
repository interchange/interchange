# evalue

`[evalue]` is an **extended alias** for [value](value.md): the alias
definition carries attributes, so it is a drop-in expansion rather than a
simple rename. It returns a form variable from the `$Values` space
HTML-entity-encoded for safe display, without altering the stored value.

## Syntax

    [evalue variable]

At parse time the alias text replaces the tag name in place and the tag
is re-parsed, so:

    [evalue comments]

becomes, literally:

    [value keep=1 filter="encode_entities" name= comments]

which parses as `[value name=comments filter=encode_entities keep=1]` —
the trailing `name=` in the alias definition exists to capture the
positional argument.

## Description

See [value](value.md) for the full attribute list and behavior. Note that
plain [value](value.md) already encodes `[` and `<` by default; `[evalue]`
additionally runs the [encode_entities](../filters/encode_entities.md)
filter, which also escapes `&`, `>`, and `"`, and `keep=1` prevents the
`set=` clearing side effects.

## See also

[value](value.md), [getlocale](getlocale.md) and
[process_search](process_search.md) — the other extended aliases

## Source

Defined as an alias in `code/SystemTag/value.coretag`
(`UserTag evalue Alias value keep=1 filter="encode_entities" name=`);
expansion mechanics in `start()`, `lib/Vend/Parse.pm` (~line 651).
