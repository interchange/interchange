# fly-list

Performs the flypage lookup for a product code and renders its body as that
product's flypage would be rendered — a single-item loop with `item-` prefix
sub-tags. Reach for it to show full product detail for a SKU inline on any page,
without linking off to the flypage.

## Syntax

    [fly-list code] ... item body ... [/fly-list]
    [fly-list code=sku onfly=1 prefix=item] ... [/fly-list]

Container tag (has an end tag). Like the flypage, the body is a one-row loop
template: it is interpolated with the item's `item-` sub-tags resolved, and the
result is reparsed.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `code`    | (none)  | Product code (SKU) to look up and display. |
| `onfly`   | `0`     | Render even when the code is not a real products-table row. |
| `prefix`  | `item`  | Sub-tag prefix for the single-item loop. |

Positional order: `code`. The tag accepts arbitrary additional attributes
(`addAttr`), passed through as loop options.

## Description

The tag maps to `Vend::Interpolate::fly_page`, the same routine that builds a
flypage. It resolves the product code against the `ProductFiles` tables (running
any configured `flypage` SpecialSub first), builds a one-element result list,
and runs the body through `labeled_list` — so exactly the same `item-` prefix
sub-tags available on a flypage or in [item-list](item-list.md) work here.

If the code is not found in a products table and `onfly` is not set, the tag
returns nothing. With `onfly=1`, it renders anyway (used with the on-the-fly
item mechanism, where an item need not exist in the database).

Because it reuses the flypage engine, `[fly-list]` with a body is essentially "a
flypage for this SKU, inline." A flypage's own `[fly-list]` (with no `code`)
uses the current fly page code — see the strap `flypage.html`.

### Prefix sub-tags

The single loop row exposes the standard `item-` sub-tags: `[item-code]`,
`[item-field col]`, `[item-data table col]`, `[item-description]`,
`[item-price]`, and the conditionals/counters shared by all looping tags. The
full sub-tag model is documented in
[Templating with ITL](../guides/templating.md#loops-and-prefix-sub-tags).

## Examples

Show detail for one SKU inline:

    [fly-list code=os28004]
    <h2>[item-field description]</h2>
    Price: [item-price]
    [/fly-list]

Look up a code passed in the session (as in the strap flypage):

    [fly-list code="[data session arg]"]
    [item-field name] — [item-field description]
    [/fly-list]

## Notes

- The lookup honors the catalog's `flypage` SpecialSub if one is defined, so a
  code may be transformed before display.
- Without a matching product and without `onfly`, output is empty rather than an
  error.

## See also

- [item-list](item-list.md) — same sub-tag model, over cart lines
- [loop](loop.md) — general list iterator
- [page](page.md), [area](area.md) — link to a real flypage instead
- Guide: [Templating with ITL](../guides/templating.md)

## Source

Defined in `code/SystemTag/fly_list.coretag`. Implemented by
`Vend::Interpolate::fly_page` in `lib/Vend/Interpolate.pm`.
