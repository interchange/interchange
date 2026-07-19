# weight

Add up the shipping weight of everything in the shopping cart and return the
total. Reach for `[weight]` when a custom shipping calculation, a page display,
or a carrier-API tag needs the cart's total weight in one number, rather than
letting the built-in [shipping](shipping.md) machinery derive it.

## Syntax

    [weight]
    [weight attribute]
    [weight cart=cartname field=weight table=weights ...]

`[weight]` is a standalone tag (no end tag, no body). Its output is the
numeric total; the result is not reparsed as Interchange Tag Language (ITL).
As a side effect it also stores the total in a scratch variable (default
`total_weight`) unless you turn that off.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `attribute` | *unset* | If true, read each item's weight straight from the item hash (the field named by `field`) instead of the database. Fastest, but the field must be pre-filled (see `AutoModifier`). |
| `cart` | current cart | Name of the cart to total. Defaults to the shopping cart in use. |
| `field` | `weight` | Column (and item-hash key) that holds a single unit's weight. |
| `table` | ordered-from table | Table to look weights up in. Defaults to the table each item was ordered from, falling back to the first `ProductFiles` table. |
| `fill_attribute` | *unset* | Name of an item-hash key. Looks the weight up in the database the first time, caches it in that key, and reuses it thereafter. |
| `matrix` | *unset* | If an item's own weight is empty, fall back to the weight of its base SKU (`mv_sku`) from `ProductFiles`. For variant/matrix products. |
| `options` | *unset* | Also scan the options table and adjust each item's weight by its selected "Simple" options. Requires an SQL/DBI options table. |
| `options_table` | `options` | Table to scan when `options` is set. |
| `exclude_attribute` | *unset* | `attr=regex` (scalar) or dotted-hash form; items whose attribute `attr` matches `regex` contribute no weight. |
| `zero_unless_attribute` | *unset* | `attr=regex`; the whole total is `0` unless **every** item matches. |
| `tot_adder` | *unset* | Add a flat number of pounds to the final total, optionally only within a weight range. See Description. |
| `no_free_shipping` | *unset* | If true, include items flagged `mv_free_shipping`; by default they are skipped. |
| `no_set` | *unset* | Do not store the result in scratch. |
| `weight_scratch` | `total_weight` | Name of the scratch variable to set with the total. |
| `hide` | *unset* | Compute and store the total but return nothing (empty output). |

Positional order: `attribute` (the only positional parameter). Attribute
names may be written with hyphens in a page (`fill-attribute`,
`no-free-shipping`); Interchange converts them to the underscore forms above.

## Description

`[weight]` walks the items in a cart and returns the sum of
`quantity * unit-weight` over all of them. By default it also assigns that
total to the scratch variable named by `weight_scratch` (default
`total_weight`), so a later `[scratch total_weight]` or a shipping formula can
read it back.

Where the per-item unit weight comes from depends on the attributes:

- With no attributes, each item's weight is read from the database: the
  `field` column (default `weight`) of the item's own table, or `table` if you
  name one.
- With the positional `attribute` set (any true value), the weight is taken
  from the item hash key named by `field` — no database access. This is the
  fastest form but requires the value to already be present on the item, which
  is what `AutoModifier weight` in `catalog.cfg` arranges.
- With `fill_attribute`, the first lookup hits the database and the value is
  cached on the item hash for subsequent calls in the same request.
- With `matrix`, an empty item weight falls back to the base SKU's weight, so
  variants that don't set their own weight inherit it.

Items marked `mv_free_shipping` are excluded from the total unless you pass
`no_free_shipping`.

**Filtering by attribute.** `exclude_attribute` drops any item whose named
attribute matches a regular expression; `zero_unless_attribute` forces the
whole total to `0` unless every item matches. Both accept either a scalar
`attr=regex` or a dotted-hash form, and the dotted form may be repeated:

    [weight
        exclude-attribute.prod_group="Gift Certificates"
        exclude-attribute.category="Downloads"
    ]

The value is a Perl regular expression, so you can group alternatives with
`|` or make it case-insensitive with `(?i)`. Because these tests read the
attribute from the item hash, the attribute must be pre-filled (again via
`AutoModifier`); no database lookup is done for them. A regex that fails to
compile is logged and simply not applied.

**Adding a surcharge weight.** `tot_adder` adds pounds to the final total in
one of three ways:

- a bare number adds that many pounds unconditionally
  (`[weight tot_adder=1]` adds 1 lb);
- a single `low_high=add` range adds `add` pounds only when the computed
  total is above `low` and up to and including `high`
  (`[weight tot_adder.k0_25=2]`);
- the dotted-hash form with several ranges applies the first matching range.

Range bounds may be written with a leading `k` (`k0_25`), which is stripped.

## Examples

Total weight of the current cart, using the database `weight` field:

    [weight]

Display it on a page and reuse the stored scratch value:

    Estimated shipping weight: [weight] lb
    (also stored as [scratch total_weight])

Read weights directly from the item hash for speed. In `catalog.cfg`:

    AutoModifier  weight

then on the page:

    [weight attribute=1]

Exclude gift certificates from the shipping weight (with
`AutoModifier prod_group` set so the attribute is available):

    [weight exclude-attribute="prod_group=Gift Certificates"]

Only charge weight-based shipping when every item is a book, otherwise return
zero:

    [weight zero-unless-attribute="prod_group=Books"]

Include free-shipping items in the weight anyway (as the strap test page
does):

    [weight no-free-shipping=1]

## Notes

- The stored scratch variable makes `[weight]` useful even when you `hide` its
  output: compute once at the top of a page, then read `[scratch
  total_weight]` wherever needed. Setting both `hide=1` and `no-set=1` computes
  a total that is neither shown nor stored, which is rarely what you want.
- The `options` mode only adjusts weight for options whose item attribute
  named by `OptionsAttribute` equals `Simple`, and it queries the options
  table's `o_group` and `weight` columns directly through DBI — it does nothing
  for flat-file options tables.
- The tag definition carries `Version 1.9`. Its embedded documentation heads
  the surcharge option `totadder`, but the option the code reads is
  `tot_adder` (page form `tot-adder`); use that name.
- The `no_free_shipping` option is honored by the code and used by the strap
  demo's `test/ship` page, but does not appear in the tag's older embedded
  documentation or the xmldocs writeup.

## See also

- [shipping](shipping.md) — the built-in shipping-mode calculator that
  normally consumes the cart weight.
- [item-list](item-list.md) and [item-field](item-field.md) — iterate cart
  items and read individual item fields.
- [scratch](scratch.md) — read back the `total_weight` value this tag sets.
- The [shipping guide](../guides/shipping.md) for how weight feeds shipping
  modes.

## Source

Defined in `code/UserTag/weight.tag` as a UserTag with an inline `Routine`
(not a MapRoutine). It reads the cart from `$Vend::Items` or
`$Vend::Session->{carts}{...}`, uses `tag_data` / `Vend::Data::product_field`
for database lookups, and writes the total to `$::Scratch`.
