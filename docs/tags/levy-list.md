# levy-list

Iterate the body once for each levy (a tax, shipping, or handling charge)
recorded on a cart, interpolating the loop body per levy. Use it to render an
itemized breakdown of the "levies" that make up an order total.

## Syntax

    [levy-list]
    [levy-param label]: [levy-param cost]
    [/levy-list]

Container tag (has an end tag). The body is a looping region: it is repeated
once per levy and its prefix sub-tags (default prefix `levy`) are interpolated
against each levy record.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `name`    | current cart | Name of the cart whose levies are listed. |
| `prefix`  | `levy`  | Sub-tag prefix used inside the body (`[levy-param ...]`). |

Positional order: `name`.

Alias: `cart` for `name`.

The tag declares `addAttr`, so any of the standard looping-list options
(`prefix`, `start`, `sort`, and so on) may be passed as attributes and are
handed through to the list machinery.

## Description

A *levy* is one line of the tax/shipping/handling framework introduced with the
[levies](levies.md) tag: each is a hash with members such as `label`,
`description`, `cost`, `group`, and `part_number`. When [levies](levies.md)
runs, it stores the resulting levy records in the session under the current (or
named) cart.

`[levy-list]` reads that stored set —
`$Vend::Session->{levies}{`*cart*`}` — and iterates it exactly like an
[item-list](item-list.md) iterates cart lines. If the named cart has no levies,
the list is empty and the body is not emitted. If the body is empty the tag
returns nothing.

Inside the body, address each levy's members through the prefix sub-tags:
`[levy-param label]`, `[levy-param cost]`, `[levy-code]`, and the rest of the
looping-tag namespace. See [templating](../guides/templating.md) for the full
sub-tag model shared by all looping tags.

## Examples

Recalculate the levies for the current cart, then render them as table rows:

    [levies recalculate=1 hide=1]
    [levy-list]
    <tr>
      <td>[levy-param label]:</td>
      <td align="right">[levy-param cost]</td>
    </tr>
    [/levy-list]

List the levies for a specific cart by name:

    [levy-list cart=main]
    [levy-param description]: [levy-param cost]
    [/levy-list]

## Notes

`[levy-list]` only displays levies; it does not compute them. Run
[levies](levies.md) first (often with `hide=1` so its own output is
suppressed) to populate the session before listing.

## See also

- [levies](levies.md), [item-list](item-list.md), [loop](loop.md)
- Concepts: [templating](../guides/templating.md),
  [pricing](../guides/pricing.md), [shipping](../guides/shipping.md)

## Source

Defined in `code/SystemTag/levy_list.coretag`. Implemented by an inline Routine
that builds a results object from `$Vend::Session->{levies}` and calls
`Vend::Interpolate::labeled_list`.
