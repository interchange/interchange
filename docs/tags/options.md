# options

Render the option-selection widgets (size, color, and the like) for a
product that has variants. Reach for it on a flypage to let the shopper pick
among a product's configured options.

## Syntax

    [options SKU]
    [options code=SKU options_type=simple]

Standalone tag. Returns HTML form widgets for the product's options.

## Attributes

| Attribute            | Default | Description |
|----------------------|---------|-------------|
| `code`               | (none)  | Product SKU whose options to display. |
| `options_type`       | auto    | Force an options module (`simple`, `matrix`, or `modular`) instead of auto-detecting. |
| `admin_page`         | off     | Render the admin-side editing widgets instead of the storefront display. |
| `display_routine`    | module default | Override the Perl routine that renders the widgets. |
| `admin_page_routine` | module default | Override the routine used for `admin_page`. |
| `routine_description`| (label) | Human-readable label used in error messages. |

Positional order: `code`.

Any additional attributes are passed through to the chosen options module,
which recognizes many of its own (joiner, price display, and so on) — see
the [pricing](../guides/pricing.md) and product-options documentation for a
module's full option set.

## Description

Interchange supports product options through pluggable **options modules**.
The three built-in types are:

- **simple** — a flat set of options stored in one table,
- **matrix** — options that combine into a distinct sub-SKU (variant) with
  its own price and inventory,
- **modular** — composable option groups.

`[options]` determines which module applies to the SKU — from the item's
options-type attribute, or the [OptionsEnable](../config/OptionsEnable.md)
directive, or an explicit `options_type=` — then calls that module's display
routine to build the widgets (`<select>` menus, radio buttons, etc.). If no
options type can be found for the SKU, the tag returns an empty string.

The widgets it emits set the `mv_order_*` / `mv_sku` form fields the cart
expects, so an option choice is carried into the order when the form is
submitted.

## Examples

Display option widgets for a product on its flypage:

    [options [item-code]]

Force the simple options module for a specific SKU from the strap demo:

    [options code=os28004 options_type=simple]

Typical use inside an order form:

    <form action="[process]" method="post">
      <input type="hidden" name="mv_order_item" value="[item-code]">
      [options [item-code]]
      <input type="submit" value="Add to cart">
    </form>

## Notes

The exact widgets and the attributes they honor come from the active options
module, not from this tag; `[options]` is the dispatcher. Which module is
chosen depends on catalog configuration
([OptionsEnable](../config/OptionsEnable.md)) and the product's data.

## See also

- [OptionsEnable](../config/OptionsEnable.md) — configure options handling
- [accessories](accessories.md) — build a single option widget directly
- [price](price.md), [order](order.md)
- [pricing](../guides/pricing.md)

## Source

Defined in `code/SystemTag/options.coretag`. Implemented by
`Vend::Options::tag_options` (`lib/Vend/Options.pm`), which dispatches to the
per-module `display_options` routine under `Vend::Options::*`.
