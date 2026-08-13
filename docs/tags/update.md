# update

Refresh a specific piece of Interchange's internal state on demand — the
shopping cart, the form-value namespace, the order process, or table data.
Reach for it when you need to re-run one of those updates from inside a page,
rather than relying on the update that a form submission triggers
automatically.

## Syntax

    [update FUNCTION]
    [update function=FUNCTION name=CARTNAME]

Standalone tag (no end tag). It performs its side effect and returns nothing.

## Attributes

| Attribute  | Default | Description |
|------------|---------|-------------|
| `function` | none    | Which internal update to run: `quantity`, `cart`, `process`, `values`, or `data`. |
| `name`     | current cart | For `function=cart`, the name of the cart to refresh; defaults to the current cart. |

Positional order: `function` (the first positional argument). The tag also
accepts arbitrary named attributes (`addAttr`); `name` is the only one it
reads.

## Description

`update` dispatches on `function`:

- `quantity` — re-reads submitted quantities and rebuilds the cart:
  zero-quantity lines are removed, and per-line quantities are clamped to the
  minimum and maximum set by the `MinQuantityField` and `MaxQuantityField`
  directives. This is the same work an add-to-cart / cart-refresh submission
  does.
- `cart` — "tosses" (recalculates and normalizes) a cart. With `name=` it acts
  on `$Carts->{name}`; without it, on the current cart. Does nothing if the
  named cart does not exist.
- `process` — runs the standard order/action process (`do_process`), as though
  a submitted `mv_action=process` had been dispatched.
- `values` — copies submitted CGI form fields into the persistent
  [value](value.md) namespace (`update_user`). Common Gateway Interface (CGI)
  variables are the raw fields from the current request.
- `data` — applies pending `mv_data_*` database updates carried in the request
  (`update_data`).

## Examples

Commit the current request's form fields into the values namespace, so later
tags and pages see them:

    [update values]

Rebuild the cart after quantities were submitted (drops zero-quantity lines
and enforces the min/max quantity limits):

    [update quantity]

Recalculate a named saved cart:

    [update function=cart name=wishlist]

## Notes

`update` triggers the same routines Interchange runs during normal form
dispatch, so most catalogs never call it directly — you reach for it only when
a page needs to force one of these refreshes itself. `[update values]` is the
common exception, used to pull just-submitted fields into the values namespace
before rendering the rest of a page.

## See also

- [value](value.md) — read from the values namespace that `function=values`
  refreshes
- [process](process.md) — the action URL that ordinarily runs the process step
- [Cart and checkout guide](../guides/cart-and-checkout.md)
- [MinQuantityField](../config/MinQuantityField.md),
  [MaxQuantityField](../config/MaxQuantityField.md)

## Source

Defined in `code/SystemTag/update.coretag` (registered name `update`).
Implemented by `Vend::Interpolate::update`, which delegates to
`Vend::Order::update_quantity`, `Vend::Cart::toss_cart`,
`Vend::Dispatch::do_process`, `Vend::Dispatch::update_user`, and
`Vend::Data::update_data`.
