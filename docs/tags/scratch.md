# scratch

Return the value of a scratch variable. Scratch is Interchange's per-session
scratchpad namespace, used to hold temporary values across the pages of a
session. Reach for `[scratch]` whenever you need to read back something you
stored with [set](set.md), [seti](seti.md), or [tmp](tmp.md).

## Syntax

    [scratch name]
    [scratch name=varname filter=filtername keep=1]

Standalone tag (no end tag). The returned value is inserted as-is; it is not
reparsed as Interchange Tag Language (ITL).

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `name`    | (required) | Name of the scratch variable to read. |
| `filter`  | none    | One or more [filters](../filters/) to apply to the value before returning it. |
| `keep`    | `0`     | When a `filter` is given, `keep=1` returns the filtered value but leaves the stored scratch value untouched. |

Positional order: `name`.

The tag declares `addAttr`, so `filter` and `keep` are read from the options
hash even though they are not positional.

## Description

`[scratch]` looks up the named key in the session scratch namespace
(`$Scratch`) and returns its value, or the empty string if it is unset.

When you pass a `filter`, the value is run through that filter before being
returned. By default the filtered value is also written back into scratch,
replacing the stored value; pass `keep=1` to filter only for display and leave
the stored value intact.

Scratch variables are set with the [set](set.md) and [seti](seti.md) container
tags (or [tmp](tmp.md)/[tmpn](tmpn.md) for values that clear at end of page or
request). They cannot be set with this tag.

## Examples

Read a scratch value set earlier on the page:

    [set greeting]Welcome back[/set]
    [scratch greeting]

produces:

    Welcome back

Read a value and HTML-entity-encode it for safe display, without changing what
is stored:

    [scratch name=comment filter=encode_entities keep=1]

## Notes

Scratch persists for the life of the session unless explicitly deleted; use
[scratchd](scratchd.md) to read and delete in one step, or [tmp](tmp.md) for
values that should not persist.

## See also

- [set](set.md), [seti](seti.md), [scratchd](scratchd.md)
- [tmp](tmp.md), [tmpn](tmpn.md)
- [value](value.md)
- Concepts: [sessions](../guides/sessions.md)

## Source

Defined in `code/SystemTag/scratch.coretag` (inline Routine).
