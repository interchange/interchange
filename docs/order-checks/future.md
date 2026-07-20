# future

Checks that a submitted date is at or after the current time, optionally
requiring a minimum gap (or, with a negative gap, allowing some slack into
the past).

## Syntax

    FIELD=future [interval] [message]

Used as the check name in an order-profile line. There is no shipped strap
demo profile using `future`; a minimal example against a delivery-date
field:

    delivery_date=future Delivery date must be in the future.

## Description

The check accepts the value in either of two forms: the `YYYY-MM-DD` form
(and longer forms with time, `YYYYMMDDHHMMSS`), or a CGI-style date made of
year/month/day parts joined by null characters (as produced by some date
widgets) -- the latter is normalized first with the
[date_change](../filters/date_change.md) filter. Any value that doesn't
reduce to a valid `YYYY[MM[DD[HH[MM[SS]]]]]`
digit string fails outright.

`interval` is an optional adjustment such as `2 days` or `-60 minutes` --
a signed number and a unit word, parsed by `Vend::Util::adjust_time` -- and
is passed to `Vend::Interpolate::mvtime` to compute a comparison time offset
from now. The check succeeds only if the (normalized)
value is not less than that computed time. A negative interval lets a date
that is somewhat in the past still pass -- useful for "must be within the
last N minutes" style checks framed as "future".

If no custom `message` is given, the failure text is `Date must be in the
future at least INTERVAL` (or just `Date must be in the future` with no
interval).

## Examples

Require a date field to be strictly in the future:

    event_date=future

Require the date to be at least two days ahead, with a custom message:

    event_date=future 2 days "Date must be at least two days ahead"

Allow a timestamp up to 60 minutes in the past (a "recent enough" check):

    submitted_at=future -60 minutes "Time must be within an hour behind"

## Notes

This check is meant for date fields and date-picker widgets; it has no
special handling for anything else. The interval argument is parsed with
`Text::ParseWords::shellwords`, so quote a multi-word custom message the
same way you would for [regex](regex.md) or [filter](filter.md).

## See also

[date_change](../filters/date_change.md), [regex](regex.md),
[error](../tags/error.md), [OrderProfile](../config/OrderProfile.md),
the [cart and checkout](../guides/cart-and-checkout.md) guide.

## Source

Defined in `code/OrderCheck/future.oc`. The routine takes
`($ref, $name, $value, $code)` and compares a normalized value against
`Vend::Interpolate::mvtime(undef, { adjust => $adjust }, "%Y%m%d%H%M")`.
