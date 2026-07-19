# onfly

Build an on-the-fly cart item — one whose fields come from a submitted
string rather than a product record — and return it as an item structure.
This is the default handler behind the [OnFly](../config/OnFly.md) directive;
you rarely call it directly on a page.

## Syntax

    [onfly code=SKU quantity=1 text="price=9.99|description=Custom item"]

Standalone tag. Returns an item hash reference (used internally by the
ordering machinery), not display text.

## Attributes

| Attribute  | Default | Description |
|------------|---------|-------------|
| `code`     | (none)  | The item code/SKU to assign. |
| `quantity` | (none)  | The quantity to assign. |
| `text`     | (none)  | Field data as `key=value` pairs joined by the on-the-fly joiner (default `|`). |

Positional order: `code`, `quantity`.

## Description

On-the-fly ordering lets a shopper add an item that has no row in the
products database — a build-to-order or dynamically priced item, for
example. When `mv_order_fly` is submitted and the
[OnFly](../config/OnFly.md) directive is enabled, Interchange calls the tag
named by that directive (this `[onfly]` tag by default) with the item code,
quantity, and the `mv_order_fly` value.

`[onfly]` parses the field string into an item. Fields are separated by the
joiner in the `MV_ONFLY_JOINER` [variable](../config/Variable.md) (default
`|`), and each field is a `name=value` pair — unless `MV_ONFLY_FIELDS` names
a fixed, positional field list, in which case the values are assigned to
those field names in order. The parsed item always gets:

- `mv_price` set from a `price` field if not given explicitly,
- `code` set from the `code` argument if the data did not supply one,
- `quantity` set from the `quantity` argument if the data did not supply one.

The result is an item hash that the cart machinery inserts. Because it
returns a structure rather than text, placing `[onfly]` inline on a page is
not useful; configure it through [OnFly](../config/OnFly.md) or a custom
handler tag modeled on it.

## Examples

Enable the default handler in `catalog.cfg`:

    OnFly  1

A form then submits an on-the-fly item with a `mv_order_fly` field such as:

    price=19.95|description=Engraved plaque|weight=2

which `[onfly]` turns into a cart item with those fields, plus the `code`
and `quantity` from the order.

Use a custom handler tag instead:

    OnFly  my_onfly_tag

Write `my_onfly_tag` using this `[onfly]` tag's routine as a starting point.

## Notes

The historic documentation lists a `create` attribute; the corresponding
branch is commented out in the current source and has no effect. Only
`code`, `quantity`, and the field `text` are honored.

## See also

- [OnFly](../config/OnFly.md) — directive that enables on-the-fly ordering
- [order](order.md) — build an order link for a catalog item
- [cart and checkout](../guides/cart-and-checkout.md)

## Source

Defined in `code/SystemTag/onfly.coretag`. Implemented by
`Vend::Order::onfly` (`lib/Vend/Order.pm`).
