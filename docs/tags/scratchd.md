# scratchd

Return the value of a scratch variable and then delete it (a destructive
read). Use it for one-shot values such as a flash message that should appear
once and then be cleared.

## Syntax

    [scratchd name]
    [scratchd name=varname filter=filtername]

Standalone tag (no end tag). The returned value is inserted as-is; it is not
reparsed as Interchange Tag Language (ITL).

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `name`    | (required) | Name of the scratch variable to read and delete. |
| `filter`  | none    | One or more [filters](../filters/) to apply to the value before returning it. |

Positional order: `name`.

The tag declares `addAttr`, so `filter` is read from the options hash.

## Description

`[scratchd]` deletes the named key from the session scratch namespace
(`$Scratch`) and returns the value it held. After the tag runs the variable no
longer exists, so a later [scratch](scratch.md) of the same name returns the
empty string.

If a `filter` is supplied, the value is passed through that filter before being
returned. Unlike [scratch](scratch.md), there is no `keep` option here — the
variable is always removed.

## Examples

Display a one-time status message and clear it so it does not show again on the
next page:

    [set flash]Your changes were saved.[/set]
    ...
    [if scratch flash][scratchd flash][/if]

Read and remove a stored token, filtered:

    [scratchd name=csrf_token filter=strip]

## See also

- [scratch](scratch.md), [set](set.md), [seti](seti.md)
- [tmp](tmp.md), [tmpn](tmpn.md)
- Concepts: [sessions](../guides/sessions.md)

## Source

Defined in `code/SystemTag/scratchd.coretag` (inline Routine).
