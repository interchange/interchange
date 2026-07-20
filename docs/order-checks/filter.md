# filter

Checks that a field's value passes through a named
[filter](../filters/README.md) completely unchanged -- a way to reuse an
existing filter as a validation rule instead of writing a new regular
expression.

## Syntax

    FIELD=filter FILTERNAME [message]

Used as the check name in an order-profile line. There is no shipped strap
demo profile using `filter` as an order check, so here is a minimal, runnable
example built from a filter that ships in `code/Filter/`:

    coupon=filter alphanumeric Coupon codes may only contain letters and digits.

## Description

The argument names one (or more, space-separated) filters exactly as they
would appear in a `filter=` attribute or `[filter]` tag; the remaining
argument, in quotes if it needs to contain spaces reused elsewhere, is the
failure `message`. The check runs the value through
`Vend::Interpolate::filter_value` and compares the result to the original
value: if the filter changed anything, the check fails.

Because of this, `filter` only makes sense with filters that are
*idempotent on valid input* -- ones that pass acceptable values through
unaltered and only change values you want to reject. Filters that
unconditionally transform their input (case folding, HTML encoding, and
the like) are unsuitable here: valid input is always changed, so the check
always fails.

If no custom `message` is given, the failure text is `FIELD caught by
filter FILTERNAME`.

## Examples

Reject any value the `alpha` filter would change (i.e. anything but
letters):

    lastname=filter alpha The value contains non-alpha characters.

Reject a coupon code containing anything other than letters and digits,
using the `alphanumeric` filter:

    coupon=filter alphanumeric Coupon codes may only contain letters and digits.

Chain two filters, both of which must leave the value unchanged:

    username=filter "no_white lc" Username must be lowercase with no spaces.

## See also

[Filters reference](../filters/README.md), [regex](regex.md),
[error](../tags/error.md), [OrderProfile](../config/OrderProfile.md),
the [cart and checkout](../guides/cart-and-checkout.md) guide.

## Source

Defined in `code/OrderCheck/filter.oc`. The routine takes
`($ref, $name, $value, $code)`, parses `$code` into a filter spec and
message with `Text::ParseWords::shellwords`, and compares `$value` against
`Vend::Interpolate::filter_value($filter, $value, $name)`.
