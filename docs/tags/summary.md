# summary

Accumulate a running total across repeated calls and display it. Reach for
`[summary]` to sum a column of per-item values (for example total cart weight)
as you loop over the items, then print the accumulated figure at the end.

## Syntax

    [summary amount=NUMBER]
    [summary amount=NUMBER name=LABEL]
    [summary name=LABEL total=1]

Standalone tag (no end tag). Positional order is `amount`. Its output is a bare
number (or formatted string) and is not reparsed as Interchange Tag Language
(ITL).

## Attributes

| Attribute  | Default    | Description                                                        |
|------------|------------|-------------------------------------------------------------------|
| `amount`   |            | Value to add to the running total. Added only when non-empty.     |
| `name`     | `ONLY0000` | Named accumulator to add into; distinct names keep separate totals. |
| `total`    |            | If true, return the accumulated total rather than this call's amount. |
| `hide`     |            | If true, add to the total but return an empty string.             |
| `reset`    |            | If true, zero the accumulator before adding.                      |
| `format`   |            | `sprintf` format applied to the returned value (e.g. `%.2f`).     |
| `currency` |            | If true, format the returned value as localized currency.         |

Positional order: `amount` (the only positional parameter). The tag also
accepts arbitrary named attributes (`addAttr`).

## Description

`[summary]` keeps its accumulators in a per-request hash
(`$Instance->{tag_summary_hash}`), so totals reset naturally on each page. Each
call adds `amount` (when non-empty) to the named accumulator and returns a
value:

- normally, the `amount` just supplied;
- with `total=1`, the accumulated running total;
- with `hide=1`, an empty string (the addition still happens).

When no `name` is given, the shared accumulator `ONLY0000` is used, and
`reset=1` clears *all* accumulators; with an explicit `name`, `reset=1` clears
only that one. The returned value is passed through `format` (a `sprintf`
pattern) if given, otherwise through [currency](currency.md) formatting if
`currency=1`, otherwise returned raw.

## Examples

Add a per-item extended weight while iterating a cart, then show the total:

    [item-list]
      [seti weight][summary amount=`[item-quantity] * [item-field weight]`][/seti]
      ... [item-field description] ([scratch weight] lb) ...
    [/item-list]

    Total weight: [summary format="%s" total=1] lb

The first `[summary]` inside the loop accumulates each line's weight (its
per-call return is captured but unused here); the final call prints the total.

Accumulate an order subtotal and display it as currency:

    [item-list]
      [summary name=merch amount=`[item-quantity] * [item-price noformat=1]` hide=1]
    [/item-list]
    Merchandise total: [summary name=merch total=1 currency=1]

## Notes

- Accumulators live only for the current page request; there is no persistence
  across requests.
- Because a bare `[summary amount=...]` echoes the amount, wrap it in
  [seti](seti.md) or use `hide=1` when you only want the side effect of adding
  to the total.

## See also

- [currency](currency.md) — currency formatting used by `currency=1`
- [item-list](item-list.md) — the loop this tag is usually accumulated inside
- [subtotal](subtotal.md), [total-cost](total-cost.md) — built-in cart totals

## Source

Defined in `code/UserTag/summary.tag` as an inline `Routine`.
