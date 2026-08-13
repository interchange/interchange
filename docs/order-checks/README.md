# Order checks

Order checks validate submitted form fields during order-profile processing.
The checks documented here are the **pluggable** ones: each is a `CodeDef` you
name in an [OrderProfile](../config/OrderProfile.md), and you can add your own
the same way. You reach them with the `&fatal`, `&set`, and per-field check
syntax described in the
[cart-and-checkout](../guides/cart-and-checkout.md) and
[forms](../guides/forms.md) guides.

> **Crucial split.** The everyday profile keywords you write in a profile —
> `required`, `email`, `phone`, `zip`, `state`, `mandatory`, and the rest — are
> **not** in this directory. They are built-in checks hard-coded in
> `Vend::Order` and have no pages here; see the
> [cart-and-checkout](../guides/cart-and-checkout.md) and
> [forms](../guides/forms.md) guides for the full built-in list and profile
> syntax. This directory documents only the pluggable `CodeDef` checks below.
> (Note that [required](required.md) here is the admin editor's client-side
> `JavaScriptCheck`, a different mechanism from the built-in `required`
> profile keyword.)

## Pluggable checks

- [always_pass](always_pass.md) — always succeed; a placeholder for a field
  position that needs no real validation.
- [always_fail](always_fail.md) — always fail; unconditionally reject a
  submission unless other logic clears the field first.
- [email_only](email_only.md) — the field is a syntactically valid email
  address.
- [exists](exists.md) — the value is the key of an existing record in a table
  (or matches a value in a named column).
- [unique](unique.md) — the value does *not* already exist in a table; the
  inverse of [exists](exists.md).
- [filter](filter.md) — the value passes through a named
  [filter](../filters/README.md) unchanged, reusing a filter as a validation
  rule.
- [future](future.md) — a submitted date is at or after now, with an optional
  minimum gap.
- [isbn](isbn.md) — verify the check digit of an ISBN-10 or ISBN-13 number.
- [length](length.md) — the value meets a minimum length, or falls within a
  min–max range.
- [match](match.md) — the value equals another named field's value, for
  "confirm password/email" pairs.
- [natural](natural.md) — the value is a natural number (a whole number greater
  than zero).
- [numeric](numeric.md) — the value looks like a number in any form Perl
  accepts.
- [numeric_strict](numeric_strict.md) — the value is a plain signed integer or
  decimal, with no scientific notation or special values.
- [regex](regex.md) — the value matches one or more regular expressions; the
  general-purpose escape hatch.
- [relative_filename](relative_filename.md) — the value is safe as a relative
  filename, with no absolute path or `..` traversal.
- [some_spec](some_spec.md) — a search-specification field holds at least a
  minimum amount of text, guarding against unconstrained searches.
- [required](required.md) — the admin editor's client-side `JavaScriptCheck`
  that blocks submission of a blank generated field (see the note above).
