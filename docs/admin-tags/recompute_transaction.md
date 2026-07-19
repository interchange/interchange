# recompute_transaction

Recalculate the stored totals of a completed order: line-item subtotals, item
count, order subtotal, and grand total (optionally sales tax), writing the
corrected values back to the `transactions` and `orderline` tables. Reach for
it from the administrative order screens after editing an order's contents or
prices. This tag is part of the admin UI toolset (the tags in `code/UI_Tag/`,
loaded when the admin UI feature is enabled), not a storefront tag.

## Syntax

    [recompute_transaction]

Standalone tag (no end tag). It takes no attributes; all input comes from CGI
and the catalog databases. Its `Interpolate` flag is off, so nothing is
reparsed. The tag runs for its side effects (database updates) and returns no
useful value.

## Attributes

This tag defines no attributes and no positional parameters. It reads two CGI
variables directly:

| CGI variable     | Required | Description |
|------------------|----------|-------------|
| `order_number`   | yes      | Key of the row in the `transactions` table to recompute. The tag dies with `No transaction number.` if it is empty. |
| `recompute_tax`  | no       | When true, sales tax is recomputed as well (see below). |

## Description

CGI variables are values submitted by the browser (form fields or query
string). The tag:

1. Loads the transaction row named by `order_number` from the `transactions`
   table (dying if the table, the `orderline` table, the `userdb` table, or the
   row itself is missing).
2. Queries every `orderline` row whose `order_number` matches, and for each
   recomputes `subtotal` as `quantity * price`. Rows whose stored subtotal
   disagrees are queued for update.
3. Sums the recomputed line subtotals into the transaction `subtotal`, sums the
   quantities into `nitems`, and sets `total_cost` to
   `subtotal + salestax + shipping + handling`.
4. Writes the corrected `transactions` row back with `set_slice`, sets the CGI
   variable `mv_data_table` to `transactions`, and records an administrative
   warning `Recomputed transaction <order_number>` (retrievable with the
   [warnings](../tags/warnings.md) tag).

When `recompute_tax` is set, the tag temporarily copies the transaction's own
field values into the session `Values` space, calls the
[salestax](../tags/salestax.md) tag to derive a fresh `salestax` figure, stores
it on the transaction row, rewrites every affected `orderline` row, and then
restores the prior `Values`. Without `recompute_tax`, only the line rows whose
subtotals actually changed are updated and the stored `salestax` is reused
as-is.

The prices used are the prices already recorded on the order lines; the tag
does not re-price against the current `products` table.

## Examples

Recompute the order whose number arrives in the request, from an admin action
page:

    [recompute_transaction]

A minimal admin form that submits an order number and asks for a full
recompute including tax:

    <form method="post" action="[area recompute_order]">
    [set order_number][cgi order_number][/set]
    Order number:
    <input name="order_number" value="[cgi order_number]">
    <label>
      <input type="checkbox" name="recompute_tax" value="1"> recompute tax
    </label>
    <input type="submit" value="Recompute">
    </form>

On the `recompute_order` page:

    [recompute_transaction]
    Recomputed. [loop list="[warnings]"][loop-code][/loop]

## Notes

The tag performs no access-control check of its own; gate it behind the admin
login like the rest of the order-administration pages.

Because totals are derived from the values already stored on the order lines,
running the tag after manually correcting a line's `quantity` or `price` is the
supported way to bring `subtotal`, `nitems`, and `total_cost` back into
agreement.

## See also

- [salestax](../tags/salestax.md)
- [warnings](../tags/warnings.md)
- [table_editor](table_editor.md)
- Concepts: [admin UI](../guides/admin-ui.md),
  [cart and checkout](../guides/cart-and-checkout.md)

## Source

Defined in `code/UI_Tag/recompute_transaction.tag` as an inline `UserTag`
Routine (registered `UserTag recompute-transaction`; hyphen and underscore
spellings are equivalent when invoking the tag).
