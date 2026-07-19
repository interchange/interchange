# salestax

Return the calculated sales tax for the current shopping cart, formatted as
currency. Reach for it on basket and checkout pages to show the tax line.

## Syntax

    [salestax]
    [salestax name=cartname noformat=1]

Standalone tag (no end tag). The result is a formatted currency string by
default; it is not reparsed as Interchange Tag Language (ITL).

## Attributes

| Attribute         | Default | Description |
|-------------------|---------|-------------|
| `name`            | current cart | Name of the cart to tax; empty means the current cart. |
| `noformat`        | `0`     | When true, return the raw number instead of a currency-formatted string. |
| `discount_space`  | current | Name of the discount namespace to switch into while computing the tax. |

Positional order: `name`, `noformat`.

Aliases: `cart` for `name`; `space` for `discount_space`.

Because the tag declares `addAttr`, any other attribute you pass (for example
`type`) is forwarded to the underlying `salestax` routine as an option.

## Description

`[salestax]` calls the internal `salestax` routine for the named cart and
passes the result through Interchange's `currency` formatter, so the value
respects the active locale unless you set `noformat`.

How the tax amount itself is derived depends on catalog configuration, checked
in this order:

- If a value has been assigned into the session (for example by the
  [assign](assign.md) tag), that fixed amount is returned unchanged, with no
  rounding.
- If [SalesTax](../config/SalesTax.md) is set to `multi`, the VAT/multi-tax
  engine computes the tax.
- If `SalesTax` contains an ITL tag (a `[`), that markup is interpolated and
  its result used.
- If [SalesTaxFunction](../config/SalesTaxFunction.md) is defined, it supplies
  the tax lookup table.
- Otherwise the built-in `SalesTaxTable` lookup is used, keyed on the value
  fields named by `SalesTax` (typically the customer's state or country).

The `discount_space` attribute temporarily switches the discount namespace for
the duration of the calculation, which matters when a catalog keeps separate
discount sets. The pragma `no_negative_tax`, when set, clamps a negative
computed tax to zero.

## Examples

Show the tax for the current cart, formatted for the active locale:

    Sales tax: [salestax]

Get the unformatted number, for use in a calculation:

    [tmp raw_tax][salestax noformat=1][/tmp]

Tax a specifically named cart:

    [salestax name=layaway]

## Notes

The tag reads the customer's tax jurisdiction from the value fields named in
the `SalesTax` directive (commonly `state` and `zip`), so those form values
must be set before the tax will be correct.

## See also

- [assign](assign.md)
- [currency](currency.md)
- [total-cost](total-cost.md)
- [subtotal](subtotal.md)
- [SalesTax](../config/SalesTax.md),
  [SalesTaxFunction](../config/SalesTaxFunction.md)
- Concepts: [taxes](../guides/taxes.md)

## Source

Defined in `code/SystemTag/salestax.coretag`. The inline Routine wraps
`Vend::Interpolate::salestax` and `Vend::Util::currency`.
