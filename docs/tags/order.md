# order

Produce a link that adds an item to the shopping cart when followed. Reach
for it to build "buy" / "add to cart" links outside of a form.

## Syntax

    [order SKU]
    [order code=SKU quantity=1]
    [order code=SKU area=1]

Standalone tag. Returns an `<a href="...">` opening anchor tag by default,
or a bare URL when `area` is set.

## Attributes

| Attribute  | Default | Description |
|------------|---------|-------------|
| `code`     | (none)  | SKU of the item to order. |
| `quantity` | (none)  | Quantity to add; omitted means the cart's default (usually 1). |
| `base`     | all [ProductFiles](../config/ProductFiles.md) | Product table(s) to source the item from. |
| `cart`     | current | Name of the cart to add the item to. |
| `mv_sku`   | (none)  | Master SKU, for ordering a specific variant. |
| `page`     | `order` special page | Destination page the link leads to after adding. |
| `area`     | off     | Return only the URL (no `<a ...>` wrapper). |
| `arg`      | (none)  | Extra path argument appended to the target page. |
| `form`     | (none)  | Extra `name=value` form data (newline-separated) to include. |

Positional order: `code`, `quantity`.
Aliases: `item`, `sku` for `code`; `table`, `database`, `db`, `mv_ib` for
`base`; `href` for `page`; `variant` for `mv_sku`.

## Description

`[order]` assembles a URL to the `order`
[special page](../config/SpecialPage.md) carrying the form parameters that
tell Interchange to add an item: `mv_action=refresh`, `mv_order_item=CODE`,
and, when supplied, `mv_order_quantity`, `mv_order_mv_ib` (the source
table), `mv_cartname`, and `mv_sku`. Following the link performs the add and
lands on the destination page.

By default the tag returns a complete opening anchor tag
(`<a href="...">`) built the same way [page](page.md) builds one, so you
write the link text and closing `</a>` yourself. With `area=1` it returns
just the URL — built like [area](area.md) — for use inside an attribute you
are constructing by hand. The generated URL honors secure-URL handling the
same way the other link tags do.

## Examples

A minimal add-to-cart link (the tag emits the opening `<a>`):

    [order os28005]Add to cart</a>

Order ten of an item, using `area` to place the URL inside an anchor you
write yourself:

    <a href="[order code=os28005 quantity=10 area=1]">Buy 10</a>

Add to a named cart:

    [order code=os28005 cart=wishlist]Save for later</a>

## Notes

The default form widgets for adding to a cart (`mv_order_item` inputs in a
submit form) do the same job; `[order]` is for cases where a plain link,
not a form, is what you want.

## See also

- [area](area.md), [page](page.md) — the URL/anchor builders `[order]` uses
- [onfly](onfly.md) — order an item that has no product record
- [nitems](nitems.md), [item-list](item-list.md)
- [cart and checkout](../guides/cart-and-checkout.md)

## Source

Defined in `code/SystemTag/order.coretag` (inline `Routine`). Delegates to
`Vend::Interpolate::tag_page` / `tag_area` (`lib/Vend/Interpolate.pm`).
