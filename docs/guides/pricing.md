# Pricing and discounts

Every item in an Interchange catalog has a price, but where that price
comes from is entirely up to you: a plain column in the products table, a
quantity-break table, an option surcharge, a per-customer profile, a bit of
embedded Perl, or any combination of those chained together. This chapter
explains how Interchange computes an item's price — the
[CommonAdjust](../config/CommonAdjust.md) chained-pricing language with
worked examples — and how discounts modify prices at display and at
checkout. It assumes you know the [Interchange Tag Language
(ITL)](templating.md) and how a [catalog is configured](configuration.md).

Prices are always computed from the database, never from the browser: a
shopper can change the quantity and the selected options of a cart line,
but the money comes from your tables and directives. That is a security
guarantee, not just a convention.

## The price of a cart line

An item is a hash: at minimum a `code` (the SKU) and a `quantity`, plus any
options the shopper chose. The routine `Vend::Data::item_price` turns that
hash into a number, and almost everything else — the [price](../tags/price.md)
tag, cart subtotals, order totals — calls it. Its logic is short:

1. If [PriceField](../config/PriceField.md) names a column (the default is
   `price`), read that column for the SKU. Call the result the *raw price*.
2. Pass the raw price — or, if it was empty/zero, the
   [CommonAdjust](../config/CommonAdjust.md) directive's value — to
   `chain_cost`, which interprets it (see below).
3. Divide the result by [PriceDivide](../config/PriceDivide.md) (default
   `1`; used for currency scaling, see
   [Internationalization](internationalization.md)).

So the simplest possible catalog needs no configuration at all: a numeric
`price` column and the default `PriceField price` give you fixed prices.

    # products table
    sku       description     price
    os28005   Trim Brush      9.95

    [price code=os28005]     →   $9.95

`chain_cost` short-circuits when its input is purely digits and dots
(`/^[\d.]*$/`), returning it unchanged — that is why a plain `9.95` costs
`9.95` and nothing more happens. The moment the value contains anything
else, it is treated as a **CommonAdjust string** and interpreted atom by
atom.

Two ways to reach that richer behavior:

- Put a CommonAdjust string directly in the `price` column of a product.
  It overrides the global default for that item.
- Set `PriceField 0` (as the strap demo does) to disable the column lookup
  entirely, and let the [CommonAdjust](../config/CommonAdjust.md) directive
  provide the whole pricing scheme for every product.

## CommonAdjust: the chained pricing language

A CommonAdjust string is a list of **atoms** separated by whitespace. Each
atom either *sets* a price (a number that is added to a running total) or
is a *modifier* that looks something up, does arithmetic, or names a key
for the next atom. `chain_cost` (in `lib/Vend/Data.pm`) walks the atoms
left to right, keeping a running `$final`:

- By default the chain **stops at the first atom that produces a non-zero
  price** — that price is *final*.
- An atom with a **trailing comma** is *chained*: after it sets a price,
  the walk continues so later atoms can adjust the result.
- An atom with a **leading semicolon** is a *fallback*: it is skipped
  entirely if a price has already been found (`next if $final`).

Those three states — final, chained, fallback — are the whole control
structure. Everything else is a kind of settor. This is the strap demo's
default retail scheme (`dist/strap/catalog.cfg`):

    CommonAdjust  pricing:q5,q10 ;:sale_price, ;:price, ;$, :related, ==:options

Read aloud: *try the quantity-break table; else fall back to `sale_price`;
else fall back to `price`; else fall back to the cart line's own price;
then always add the `related` field and any option surcharges.* The
sections below build up to reading that fluently.

### Numeric and percentage atoms

| Atom | Effect on the running price `$final` |
|------|--------------------------------------|
| `N.NN` | add `N.NN` (may be negative: `-2.50` subtracts) |
| `N.NN%` | replace `$final` with `$final * N/100` |
| `N.NN*` | multiply `$final` by `N.NN` |

The percentage and multiply atoms operate on the price computed *so far*,
so they only make sense chained after a price-setting atom.

    10.00, -8%

sets the price to 10.00, then to `10.00 * 0.92 = 9.20`. The comma after
`10.00` is essential: without it the chain would stop at 10.00 and never
reach `-8%`.

### Database lookup: `table:column:key`

The workhorse settor. It reads one field from a database table and
re-submits the value as a fresh atom (so a column may itself hold another
CommonAdjust string):

    :price                     column `price`, products table, this SKU
    pricing:list_price         column `list_price` in the `pricing` table
    pricing:common:red         column `common`, keyed by `red`

- **table** is optional; empty means the item's own product table
  (`mv_ib`, or the first of [ProductFiles](../config/ProductFiles.md)).
- **column** is required (empty column falls back to
  [PriceDefault](../config/PriceDefault.md), default `price`).
- **key** is optional; empty means this item's SKU. If the key names a
  column that exists on the item hash, the item's value for it is used —
  this is how `:wholesale:mv_sku` keys the lookup by the line's `mv_sku`
  attribute rather than its `code`.

Because the returned value is re-parsed, `:price` where the `price` column
holds `12.00, -10%` yields 10.80 — the lookup finds a CommonAdjust string
and continues chaining.

### Quantity breaks: `table:col1,col5,col10:key`

When the column part contains commas (or `..` ranges), the atom becomes a
**quantity price break**. Each name is a column whose trailing digits are a
quantity threshold; Interchange picks the highest threshold that does not
exceed the line's quantity and uses that column's value.

    pricing:q1,q5,q10:

is equivalent to writing the ranges out, and

    pricing:q1..q5,q10:

expands `q1..q5` to `q1 q2 q3 q4 q5`. Given this `pricing` table row:

    sku       q1    q5    q10
    99-102    10    9     8

a line for `99-102` costs 10 at quantities 1–4, 9 at 5–9, and 8 at 10 or
more. Two rules from the code worth committing to memory:

- **A blank break column yields zero, not "skip".** If `q5` is empty, a
  quantity of 5 sets the price to 0 for that atom. Populate every break
  column, or rely on a fallback atom after it (below) to recover.
- **Below the lowest break the atom produces nothing** (`redo` with an
  empty price), so the chain moves on to the next atom.

If the first name in the list is non-numeric, it is treated as an
*attribute* whose value selects which cart lines to total for the quantity
comparison — the mechanism behind mix-and-match quantity pricing. The
common case needs only numeric break columns.

### Option and attribute adjustments: `=amount=attribute:table:col:key`

An atom beginning with `=` adds an optional fixed `amount` and then does an
attribute-driven lookup. Two forms appear constantly:

    ==size:pricing            attribute lookup
    ==:options                option surcharge

For `==size:pricing`: the leading `=` carries no amount, then
`size:pricing` means *look up, in the `pricing` table for this SKU, the
column named by the value of the item's `size` attribute*. If the shopper
chose size `XL` and the `pricing` row has `XL 1`, one dollar is added. A
form with three parts, `==color:pricing:common`, instead keys the lookup by
the attribute's value (`red`) and reads a fixed column (`common`).

For `==:options` the attribute and table degenerate to the literal table
`options`, which routes to `Vend::Options::option_cost` — the surcharge for
whatever variant/option the shopper selected on this line. The exact
arithmetic depends on the options module in force (Simple, Matrix, …); see
[Cart and checkout](cart-and-checkout.md) and the `OptionsEnable`
directive. Treat `==:options` as "add the selected options' price
difference."

### Perl, tags, and other settors

| Atom | Meaning |
|------|---------|
| `&PERL` | evaluate Perl (as [calc](../tags/calc.md)); `$s` is the current price, `$q` the quantity, `$item` the line hash |
| `[itl]` or `_VAR_` | interpolate as ITL (with variable substitution), re-submit the result as an atom |
| `$` | use the cart line's `mv_price` attribute as the price (the literal `free` sets it to 0 and stops) |
| `sub=arg:arg` | call a catalog [Sub](../config/Sub.md)/[GlobalSub](../config/GlobalSub.md) or [UserTag](../config/UserTag.md), passing the item hash |
| `>>word` | return `word` verbatim and stop — used when CommonAdjust drives [shipping](shipping.md) modes, not pricing |
| `word` | not a price; remembered as the *key* for the next lookup atom |
| `(atom)` | evaluate `atom`, and use its result as the key for the next atom |

The `&PERL` form runs inside the [Safe compartment](perl-embedding.md), so
it has the same restrictions as any catalog Perl. A price expressed as a
tag is handy for one-offs:

    &return $s * 1.05           add 5% in Perl instead of `5%`

### Fallbacks, chaining, and limits together

Putting it together, trace the strap default for an ordinary retail
shopper buying one `os28005`:

    pricing:q5,q10 ;:sale_price, ;:price, ;$, :related, ==:options

1. `pricing:q5,q10` — quantity 1 is below the lowest break (`q5`), so the
   atom yields nothing.
2. `;:sale_price,` — fallback runs because no price yet; `sale_price` is
   empty for this SKU, so still nothing. The trailing comma keeps the
   chain alive.
3. `;:price,` — fallback runs; `price` is `9.95`, so `$final = 9.95`. The
   comma means the walk continues rather than stopping here.
4. `;$,` — fallback is now **skipped** because a price exists.
5. `:related,` — not a fallback, so it always runs; the `related` column
   holds text (SKUs), which adds 0 numerically — harmless.
6. `==:options` — adds surcharges for any selected options (0 here).

Final price: 9.95. Raise the quantity to 5 and step 1 instead reads the
`q5` column, taking precedence over `price`.

Endless chains are possible (a column that references itself), so a
[Limit](../config/Limit.md) caps the work. The
`chained_cost_levels` limit (default `32`) bounds both the number of atoms
and the number of iterations; exceeding it logs an error and abandons the
price. (Historic manuals cite "16 initial strings / 32 iterations"; the
current code uses the single `chained_cost_levels` value for both, falling
back to 64 only if the limit is unset.)

## Pricing profiles: per-customer schemes

A [Profile](../config/Profile.md) is a named bundle of directive overrides
that a page or the order process can switch on. Pricing profiles let one
catalog charge retail, dealer, and distributor prices from the same
products table. The strap demo defines dealer and distributor profiles that
swap in a wholesale-oriented CommonAdjust:

    Profile dealer <<EOR
    {
        CommonAdjust => <<EOF,
            pricing:w5,w10:,
            ;:wholesale,
            ;:wholesale:mv_sku,
            ;$,
            ==:options
    EOF
        NonTaxableField => 'nontaxable',
    }
    EOR

This reads the wholesale quantity breaks (`w5`, `w10`), falling back to the
`wholesale` column, then to a wholesale price on the line's `mv_sku`, then
to `mv_price`, plus options. The distributor profile is the same with a
trailing `-10%` chained on. Which profile is active is decided by your
logic — typically a [UserDB](user-database.md) flag checked at login — and
applied with the standard profile machinery (see
[Profile](../config/Profile.md)). Note the strap `Profile default` block
restores the retail `CommonAdjust` and `PriceField 0`, so switching back is
explicit.

The demo also wires up an [AutoModifier](../config/AutoModifier.md):

    AutoModifier pricing:price_group

which, before pricing runs, copies each product's `price_group` from the
`pricing` table onto the item hash. AutoModifiers are the general way to
make a database value available to CommonAdjust atoms (and to the cart)
without the shopper submitting it.

## The `[price]` tag

[price](../tags/price.md) is the display face of `item_price`. Outside a
loop you give it a SKU; the return is currency-formatted through
[currency](../tags/currency.md) unless you ask for a raw number.

    [price code=os28005]                     $9.95
    [price code=os28005 quantity=10]         price at quantity 10
    [price code=99-102 noformat=1]                8.00  (unformatted)
    [price code=os28005 discount=1]          apply this session's discounts

| Attribute | Purpose |
|-----------|---------|
| `code` | SKU to price (positional param 1) |
| `quantity` | quantity for break/discount math (default 1) |
| `base` (alias `mv_ib`) | product table to read from |
| `discount` | if true, run the result through session discounts |
| `discount_space` (alias `space`) | evaluate in a named [discount space](../tags/discount.md) |
| `noformat` | return a bare number, no currency symbol |

Inside a looping tag like [item-list](../tags/item-list.md), use the
prefix sub-tags instead, which already know the current line: `[item-price]`
(plain), `[discount-price]` (after discounts), and `[discount-subtotal]`
(discounted line total). The strap flypage and cart templates use these:

    [L]Price[/L]: <b>[item-price]</b>

Currency formatting is governed by the active [Locale](internationalization.md)
and by [PriceCommas](../config/PriceCommas.md) (default `Yes`, inserts
thousands separators). Never format prices by hand; let
[currency](../tags/currency.md) do it so locale and rounding stay
consistent.

## Discounts

Pricing decides what an item is worth; **discounts** modify that at display
and at checkout. A discount is a Perl formula stored per item-code (or for
special keys) in the session. Interchange applies them when totaling the
cart, and on demand through tags.

Set a discount with the [discount](../tags/discount.md) container tag. The
body is a formula evaluated in the [Safe compartment](perl-embedding.md)
with `$s` = the item subtotal (price × quantity) and `$q` = quantity; it
must return the new subtotal for all units of that code.

    [discount ALL_ITEMS] $s * .8 [/discount]      20% off everything
    [discount os28005]   $s * .75 [/discount]      25% off one SKU
    [discount ENTIRE_ORDER] $s - 5 [/discount]     $5 off the order total

Three special keys and one attribute drive discounting:

| Key / attribute | Scope | `$s` is |
|-----------------|-------|---------|
| a product code | all units of that SKU | that line's subtotal |
| `ALL_ITEMS` | every line, per code | each line's subtotal |
| `ENTIRE_ORDER` | the whole order once | the running order subtotal |
| `mv_discount` (line attribute) | that one cart line | that line's subtotal |

Item-level and `ALL_ITEMS` discounts stack (both formulas run, in that
order). `ENTIRE_ORDER` is applied last, after every line is totaled; its
formula uses `$s` for the subtotal and `$q` for the total item count. A
`mv_discount` attribute set on a line carries a per-line formula.

An empty discount value clears that key, so `[discount os28005][/discount]`
removes the SKU's discount. Two convenience options generate common
formulas for you:

    [discount code=os28005 subtract=2.00][/discount]   $2 off, floored at 0
    [discount code=os28005 level=3][/discount]          one unit free at qty 3+

To *show* a discounted price, either pass `discount=1` to
[price](../tags/price.md), or use the loop sub-tags `[discount-price]` and
`[discount-subtotal]` mentioned above. `[item-difference]` and
`[item-discount]` report the amount saved. The strap coupon component is a
compact real example:

    [discount ENTIRE_ORDER] $s - $Scratch->{coupon_amount}; [/discount]

Discounts are per-session and per-user by design: you gate them however you
like — a coupon code, club membership, a value in [UserDB](user-database.md)
— and only the current shopper sees them. They apply *after* CommonAdjust
pricing, so a discount formula sees the already-computed item price.

### Discount spaces

By default all discounts live in one session hash, which is a problem if
you run multiple carts ([`mv_cartname`](cart-and-checkout.md)) that share
item codes — one cart's discounts leak into another. **Discount spaces**
give each cart its own namespace. Turn the feature on and, optionally, tie
a space to a variable:

    DiscountSpacesOn  Yes
    DiscountSpaceVar  mv_discount_space

Then switch spaces with the [discount-space](../tags/discount.md) tag
(or the `discount_space`/`space` attribute on
[discount](../tags/discount.md) and [price](../tags/price.md)):

    [discount-space wholesale]
    [discount ALL_ITEMS] $s * .9 [/discount]     10% off, wholesale space only

`[discount-space name=x clear=1]` empties a space; `current=1` returns the
active space name without switching. With spaces off (the default), all of
this collapses to the single `main` space and behaves as before.

## Quantity pricing at a glance

Interchange gives you two distinct mechanisms; pick per catalog:

- **Break columns in CommonAdjust** (`pricing:q1,q5,q10:`) set the *unit
  price* by quantity from a table. This is the modern, flexible route and
  the one the strap demo uses.
- **Discount formulas** keyed on quantity (via `$q` in a
  [discount](../tags/discount.md) body, or the `level` option) reduce an
  already-priced line. Use these for "buy 3, get one free" style rules that
  are about the *total*, not the unit price.

> **Upgrading note.** Older Interchange/MiniVend catalogs configured
> quantity breaks with `PriceBreaks`/`MixMatch` and attribute pricing with
> `PriceAdjustment`. Those directives are **not present in current
> Interchange** — both jobs are done by CommonAdjust (quantity-break
> columns and the `==attribute:...` settor respectively). If you are
> porting an old catalog, translate them to a CommonAdjust string rather
> than looking for the old directives. `UseModifier` still exists for
> declaring item attributes.

## Notes and edge cases

- **PriceField vs. CommonAdjust.** `item_price` uses the `CommonAdjust`
  directive only when the `PriceField` column is empty or zero for the
  item. Setting `PriceField 0` disables the column so every price comes
  from `CommonAdjust`; leaving `PriceField price` lets individual products
  override the default by putting a CommonAdjust string in their `price`
  cell.
- **The `related` atom in the strap default** adds the `related` column
  numerically. Because that column holds SKUs (text), it contributes 0 —
  it is effectively a no-op left in place for catalogs that repurpose the
  column. Do not assume every atom in a shipped CommonAdjust string is
  load-bearing.
- **Option surcharge math is delegated.** `==:options` routes to the
  options module's `price_options` routine; the precise surcharge depends
  on whether you use Simple or Matrix options and how the `options`/
  `variants` tables are filled. This chapter documents the routing, not
  each module's formula.
- **The `(atom)` / bare-`word` key mechanism** for feeding one atom's
  result as the next atom's lookup key is powerful but rarely needed; if a
  CommonAdjust string is getting hard to read, an
  [AutoModifier](../config/AutoModifier.md) or a `&PERL` atom is usually
  clearer.

## See also

- [CommonAdjust](../config/CommonAdjust.md),
  [PriceField](../config/PriceField.md),
  [PriceDivide](../config/PriceDivide.md),
  [PriceDefault](../config/PriceDefault.md),
  [PriceCommas](../config/PriceCommas.md) — the pricing directives
- [Profile](../config/Profile.md),
  [AutoModifier](../config/AutoModifier.md),
  [ProductFiles](../config/ProductFiles.md) — profiles and item data
- [DiscountSpacesOn](../config/DiscountSpacesOn.md),
  [DiscountSpaceVar](../config/DiscountSpaceVar.md),
  [Limit](../config/Limit.md) — discount spaces and the chain limit
- [price](../tags/price.md), [discount](../tags/discount.md),
  [discount-space](../tags/discount.md),
  [currency](../tags/currency.md), [item-list](../tags/item-list.md) — the tags
- [Cart and checkout](cart-and-checkout.md), [Taxes](taxes.md),
  [Shipping](shipping.md) — where prices become an order total
- [Databases](databases.md), [Templating](templating.md),
  [Embedded Perl](perl-embedding.md) — the machinery pricing builds on

## Source

- `lib/Vend/Data.pm` — `item_price` and `chain_cost` (the CommonAdjust
  interpreter)
- `lib/Vend/Interpolate.pm` — `discount_price`, `discount_subtotal`,
  `apply_discount`, `subtotal`
- `lib/Vend/Options.pm` — `option_cost` (the `==:options` settor)
- `code/SystemTag/price.coretag`, `discount.coretag`,
  `discount_space.coretag` — the tags
- `dist/strap/catalog.cfg` — the demo's retail, dealer, and distributor
  pricing schemes
