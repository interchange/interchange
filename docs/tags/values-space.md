# values-space

Switch the active `$Values` namespace, so a page can keep several independent
sets of form values (for example a "billing" set and a separate "shipping" or
"quote" set). Reach for it in the rare case you need parallel value stores; it
is the values-space analogue of [discount-space](discount_space.md).

## Syntax

    [values-space name]
    [values-space name=quote copy="fname lname email"]
    [values-space]

Standalone tag (no end tag).

## Attributes

| Attribute  | Default | Description |
|------------|---------|-------------|
| `name`     |         | Namespace to switch to (positional 1). The empty string `''` selects the default (main) values space. Omit entirely to query. |
| `clear`    | `0`     | Empty the target namespace after switching to it. |
| `copy`     |         | Space-separated variable names to copy from the previous space into the new one. |
| `copy_all` | `0`     | Copy every variable from the previous space into the new one. |
| `show`     | `0`     | Return the name of the previously active space. |

Positional order: `name`.

## Description

`$Values` (the store [value](value.md) reads and writes) normally points at the
session's single values hash. `[values-space name]` repoints `$Values` at a
named repository kept on the session (`values_repository`), creating it if
needed, and remembers the switch in `$Vend::ValuesSpace`. Every subsequent
[value](value.md), form field, and `$Values` reference then operates on that
namespace until you switch again — passing `name=""` returns to the default
space.

Called with no `name`, the tag returns the name of the currently active space
without changing anything. `copy`/`copy_all` seed the destination space from
the one you are leaving; `clear` empties the destination; `show` makes the tag
return the previous space's name (handy for restoring it later).

This is an advanced, session-global switch: it changes where *all* value
operations go, so remember to switch back.

## Examples

Query the current space:

    Current values space: [values-space]

Switch to a "quote" space, carrying over a couple of fields:

    [values-space name=quote copy="fname lname email"]
    ... [value fname] etc. now read/write the quote space ...

Switch back to the default space when done:

    [values-space name=""]

Capture and restore the previous space around a block:

    [tmp save][values-space name=quote show=1][/tmp]
    ... work in the quote space ...
    [values-space name="[scratch save]"]

## Notes

- The switch is global for the request, not scoped to a block. Use
  [local](local.md) (which can localize the values space) if you need an
  automatically restored, block-scoped change instead.
- Each namespace is a separate hash on the session; data does not cross between
  spaces unless you `copy` it.

## See also

- [value](value.md) / [value-extended](value-extended.md) — read from a space
  (they accept a `values_space` option too)
- [discount-space](discount_space.md) — the equivalent for discounts
- [local](local.md) — block-scoped value/scratch localization
- The [forms guide](../guides/forms.md)

## Source

Defined in `code/UserTag/values_space.tag` (inline `Routine`), registered as
`values-space`.
