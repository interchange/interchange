# Carts, the order process, and checkout

Everything between "add to basket" and "thank you for your order" is one
subsystem. This chapter explains the shopping cart's in-memory structure and
how items enter, change, and leave it; then the two-phase order process that
runs when a customer submits — **order profiles** validate the form,
**order routes** finalize the order (email it, write it to tables, charge a
card, empty the cart), and a **report** template renders the merchant's copy.
The [tutorial](tutorial.md) builds a minimal working checkout in section 7;
this chapter is the reference behind it. Individual pieces live in the
[directive reference](../config/README.md), the
[order-checks reference](../order-checks/README.md), and the
[tag reference](../tags/README.md); this chapter ties them together.

The code authority is `lib/Vend/Cart.pm` (cart storage and quantity
adjustment), `lib/Vend/Order.pm` (profiles, checks, routes, the order
report), and the `submit` form action in `lib/Vend/Dispatch.pm` (the
process that drives them).

## The cart is a list of line hashes

A cart is a Perl array. Each element is a hashref describing one **order
line** — a SKU, a quantity, and bookkeeping keys. It lives in the
[session](sessions.md) under `carts`, so it persists between requests with
no database of its own:

    $::Carts            # hash of all carts, = $Vend::Session->{carts}
    $Vend::Items        # the current cart (an array), tied to $Vend::CurrentCart
    $Vend::CurrentCart  # name of the current cart, default 'main'

`$Vend::Items` is a *tied* scalar (`Vend::Cart::FETCH`): reading it returns
whichever cart `$Vend::CurrentCart` names, creating an empty one on demand.
Every cart-aware tag — [item-list](../tags/item-list.md),
[nitems](../tags/nitems.md), [subtotal](../tags/subtotal.md) — operates on
the current cart.

A single line is a hash whose keys the checkout machinery reads by name:

| Key | Meaning |
|-----|---------|
| `code` | the SKU ordered (the line's product key) |
| `quantity` | how many; `0` marks the line for deletion |
| `mv_ib` | which [ProductFiles](../config/ProductFiles.md) table this SKU came from |
| `mv_ip` | the line's position (index) in the cart |
| `mv_mi` | master-item id — groups the lines of a kit/modular order |
| `mv_si` | sub-item flag — true for a component line under a master |
| `mv_ci` | container id — links a sub-item to its master line |
| `mv_mp` | modular pointer — set when items are ordered as a modular group |
| *anything else* | a **modifier** (size, color, `mv_shipmode`, ...) — an arbitrary column stored on the line |

`code`, `quantity`, and the modifiers are what most stores touch; the `mv_*`
grouping keys matter only for kits and modular orders, and Interchange
maintains them for you. A minimal one-line cart is just:

    [ { code => '80016', quantity => 2, mv_ib => 'products', mv_ip => 0 } ]

You rarely build this by hand. You reach it through the `order` action and
the checkout forms below; a `[perl]` block can inspect it as
`$Vend::Items` (see [Embedded Perl](perl-embedding.md)).

## Adding items: the order action

The [order](../tags/order.md) tag emits a link to the built-in `order`
action, which adds a SKU to the current cart and then displays the
`order` [SpecialPage](../config/SpecialPage.md) (`ord/basket` by
convention):

    [order 80016]Add to basket</a>

Like [page](../tags/page.md), `[order]` produces only the opening
`<a href="...">`; close it with `</a>`. Its positional arguments are
`code` and `quantity` (`[order 80016 3]` adds three).

Under the hood (`Vend::Order::do_order` → `add_items`, `lib/Vend/Order.pm`)
the action reads a family of `mv_order_*` CGI variables, so a form can add
items too:

| CGI variable | Effect |
|--------------|--------|
| `mv_order_item` | SKU(s) to add (NUL-separated for several) |
| `mv_order_quantity` | quantity per item |
| `mv_order_mv_ib` | source table per item |
| `mv_cartname` | add to a named cart instead of `main` |
| `mv_separate_items` | give each add its own line even for the same SKU |
| `mv_order_fly` | build an on-the-fly item (requires [OnFly](../config/OnFly.md)) |

Adding a SKU that is already in the cart normally increases that line's
quantity. Set `mv_separate_items=1` (or the catalog default
[SeparateItems](../config/SeparateItems.md)) to keep each add on its own
line — needed when the same SKU carries different modifiers.

## Updating and removing: the refresh action

The basket page posts back to the [process](../tags/process.md) action with
`mv_todo=refresh` to re-read quantities from the form
(`update_quantity` in `lib/Vend/Order.pm`). Name each quantity input with
the loop's `[item-quantity-name]` sub-tag so Interchange can match a field
to its line:

    <form action="[process]" method="post">
    [form-session-id]
    <input type="hidden" name="mv_todo" value="refresh">
    [item-list]
      <input name="[item-quantity-name]" value="[item-quantity]" size="3">
      [item-description]
    [/item-list]
    <input type="submit" value="Update">
    </form>

Setting a quantity to `0` deletes the line. That deletion, and the
minimum/maximum clamping below, happen in `toss_cart` (`lib/Vend/Cart.pm`),
which runs after every cart change: it walks the cart, splices out
zero-quantity lines (cascading to sub-items of a deleted kit master), and
applies quantity limits.

The `[form-session-id]` tag and the wider `mv_*` form vocabulary
(`mv_todo`, `mv_nextpage`, `mv_click`, ...) belong to [Forms](forms.md);
this chapter uses them without re-explaining them.

## Displaying a cart with item-list

[item-list](../tags/item-list.md) is the cart's counterpart to
[loop](../tags/loop.md): it repeats its body once per line, exposing the
line through `item-` prefix sub-tags. The everyday ones:

- `[item-code]` / `[item-sku]` — the line's SKU
- `[item-quantity]` — the ordered quantity; `[item-quantity-name]` names its input
- `[item-field col]` — a column from the products table for this SKU
- `[item-description]` — shorthand for the description field
- `[item-price]` — the unit price; `[item-subtotal]` the line extension
- `[item-modifier name]` — a modifier stored on the line
- `[item-increment]` — the line's 1-based counter within the list
- `[if-item-field col] ... [/if-item-field]` — per-line conditional

Cart-total tags stand outside the loop: [subtotal](../tags/subtotal.md),
[shipping](../tags/shipping.md), [handling](../tags/handling.md),
[salestax](../tags/salestax.md), and [total-cost](../tags/total-cost.md)
(everything, formatted). [nitems](../tags/nitems.md) counts units in the
cart. A complete basket table is in [tutorial](tutorial.md) section 6; the
strap demo's `include/checkout/shopping_cart` is the fuller, styled
version.

## Quantity limits and modifiers

Several catalog directives shape what `toss_cart` does to each line:

- [MinQuantityField](../config/MinQuantityField.md) /
  [MaxQuantityField](../config/MaxQuantityField.md) name product columns
  that clamp a line's quantity; a clamped line gets `mv_min_under` or
  `mv_max_over` set so a page can explain the adjustment.
- [UseModifier](../config/UseModifier.md) lists the extra per-line
  attributes (size, color, ...) Interchange carries on each line and reads
  from `mv_order_<attr>` inputs.
- [AutoModifier](../config/AutoModifier.md) auto-populates modifiers from
  product data on every recalculation — strap uses
  `AutoModifier nontaxable` so each line knows its own tax status.
- [SeparateItems](../config/SeparateItems.md) sets the catalog-wide default
  for one-line-per-add.
- [OrderLineLimit](../config/OrderLineLimit.md) caps how many distinct
  lines a cart may hold (strap sets `200`), a cheap defense against cart
  flooding.

For live side effects when the cart changes, [CartTrigger](../config/CartTrigger.md)
(with [CartTriggerQuantity](../config/CartTriggerQuantity.md)) names a
[Sub](../config/Sub.md) or [GlobalSub](../config/GlobalSub.md) that
`toss_cart` calls on every add, update, and delete
(`trigger_add`/`trigger_update`/`trigger_delete` in `lib/Vend/Cart.pm`) —
the hook for real-time inventory reservation or logging.

## Multiple carts

A session can hold any number of named carts at once; `main` is the default.
Route items to another cart with `mv_cartname`, and switch which cart the
cart tags read by setting `$Vend::CurrentCart` (a `[perl]` block) or passing
`cart=` to the cart tags:

    [order 80016]Add to main basket</a>
    <input type="hidden" name="mv_cartname" value="wishlist">

    Wishlist holds [nitems cart=wishlist] items.
    [item-list cart=wishlist] ... [/item-list]

Named carts drive wishlists, saved-for-later lists, and quote baskets. All
of them live under `$Vend::Session->{carts}` and persist exactly as the main
cart does. The checkout process below always finalizes the *current* cart
(or the one named by `mv_cartname` on the submitting form).

## The order process at a glance

When a form posts to [process](../tags/process.md) with `mv_todo=submit`,
the `submit` action in `lib/Vend/Dispatch.pm` runs a fixed sequence. The
[tutorial](tutorial.md) shows the minimal case; here is the whole path:

1. **Absorb the form** — `update_user()` copies inputs into
   [`[value]`](../tags/value.md) space, `update_quantity()` re-reads cart
   quantities.
2. **Pick the master route** — if the form did not set `mv_order_route`,
   Interchange selects the route marked `master` (usually `default`).
3. **Run the order profile** — if `mv_order_profile` is set, `check_order()`
   runs that profile's checks. Its two outcomes are *status* (did every
   check pass?) and *final* (is this profile allowed to complete the order,
   i.e. did it declare `&final`?).
4. **Pre-check the route** — the chosen route is run in `check`-only mode
   (`route_order(..., 'check')`) so a route can carry its own profile and
   veto before anything irreversible happens.
5. **Branch on the result.** If a check failed, `mv_nextpage` becomes
   `mv_failpage` (or the `needfield` special page) and the form is
   redisplayed with errors — nothing is finalized. If checks passed but no
   profile declared `&final`, the action returns and simply shows the next
   page (this is how a multi-page checkout advances step to step).
6. **Finalize** — only when *final* is true: `route_order()` runs the route
   for real (emailing, table writes, payment, receipts). If no route
   `supplant`ed the built-in handling, `mail_order()` writes the fallback
   report and [AsciiTrack](../config/AsciiTrack.md) log.
7. **Receipt and cleanup** — the `receipt` special page is displayed unless
   the route set `no_receipt`, the [OrderCleanup](../config/OrderCleanup.md)
   macro runs, and the cart is emptied.

The pivot is *final*. A checkout can post `submit` many times — one per
page — and only the profile that declares `&final = yes` triggers steps 6–7.
Everything else just validates and moves on.

## Order profiles

An **order profile** is a named block of validation checks and value
defaults, applied when a form is submitted. You load profile files with
[OrderProfile](../config/OrderProfile.md) (alias
[Profiles](../config/Profiles.md) at catalog scope); a form selects one by
setting `mv_order_profile` to its name. Profiles are compiled at
configuration time, so editing one needs a
[reconfig](configuration.md#startup-reconfiguration-and-debugging).

A profile file holds one or more profiles, each introduced by `__NAME__`
and separated by `__END__`:

    __NAME__ checkout

    fname=required   Please give your first name
    lname=required   Please give your last name
    email=email      Please give a valid email address
    zip=required     We need your ZIP code

    &fatal = yes
    &final = yes
    __END__

Two kinds of line appear:

**Field checks** — `field=check message`. The named
[order check](../order-checks/README.md) runs against the submitted value of
`field`; on failure `message` is recorded. A failed check sets
`$Vend::Session->{errors}{field}` and `mv_error_field`, which the
[error](../tags/error.md) tag displays:

    [error name=email std_label="Email" show_error=1]

**Ampersand directives** — `&name = value` control the profile itself
(parsed by `%Parse` in `lib/Vend/Order.pm`). The load-bearing ones:

| Directive | Effect |
|-----------|--------|
| `&fatal = yes` | stop at the first failed check and reject the submission |
| `&final = yes` | this profile may complete the order (see the process above) |
| `&and` / `&or` | combine the next check(s) with the previous, instead of ANDing all |
| `&set = var value` | set a `[value]` field unconditionally |
| `&setcheck = var value` | set a field *and* treat it as a check (fails if false) |
| `&calc = ...` / `&perl = ...` | run [embedded Perl](perl-embedding.md) mid-profile |
| `&credit_card = standard ...` | validate/encrypt card data (below) |
| `&charge = mode` | run a real-time [payment](payments.md) charge |
| `&success` / `&fail` | override the next page for this profile |
| `&fatal` without `&final` | validate a step without completing the order |

Because a profile is [interpolated](templating.md) before it runs, ITL can
build checks conditionally. The strap demo leans on this heavily — its
`credit_card` profile branches on `MV_PAYMENT_MODE`, its `cod` profile
rejects PO-box addresses, its `purchase_order` profile checks a credit
limit — all in `include/profiles/profiles.order`, the best worked example
of profile writing.

### Credit-card and charge directives

`&credit_card = standard [keep] accepted_types` runs
`encrypt_standard_cc` (`lib/Vend/Order.pm`): it validates the card with the
Luhn algorithm, checks the expiration, and leaves the results in
`mv_credit_card_valid`, `mv_credit_card_info` (the assembled, to-be-encrypted
block), `mv_credit_card_type`, `mv_credit_card_reference` (a masked number),
and friends. `keep` retains the number in memory for a following charge.
`&charge = mode` hands off to [Vend::Payment](payments.md); a gateway
failure fails the check. Card details, gateways, and the `MV_PAYMENT_*`
variables are the subject of [Payments](payments.md).

## Order checks

The check named on the right of a `field=check` line is resolved in this
order (`Vend::Order::_format`):

1. an `&`-directive from the profile parser (`&credit_card`, `&charge`, ...);
2. a `CodeDef ... OrderCheck` routine loaded from `code/OrderCheck/*.oc`
   — these are the pluggable, documented checks in the
   [order-checks reference](../order-checks/README.md):
   [numeric](../order-checks/numeric.md),
   [length](../order-checks/length.md),
   [regex](../order-checks/regex.md),
   [match](../order-checks/match.md),
   [unique](../order-checks/unique.md),
   [filter](../order-checks/filter.md),
   [isbn](../order-checks/isbn.md),
   [future](../order-checks/future.md),
   [always_pass](../order-checks/always_pass.md) /
   [always_fail](../order-checks/always_fail.md), and others;
3. a built-in fallback `_name` subroutine in `lib/Vend/Order.pm`.

The built-in fallbacks are not separate CodeDef files but are always
available: `required` and `mandatory` (non-blank), `email`, `phone`,
`phone_us`, `state`/`province`/`state_province`, `zip`,
`ca_postcode`/`postcode`, `true`/`false`, `defined`, `luhn` (card number),
and `multizip`/`multistate` (per-country address validation). This is why
`fname=required` and `email=email` in the tutorial work with no `CodeDef` in
sight. (Note the naming overlap: the file `code/JavaScriptCheck/required.jsc`
documented at [required](../order-checks/required.md) is a *different*
mechanism — an admin-UI client-side validator — not the profile keyword
`required`, which is the built-in `_required`.)

Checks combine with `&and`/`&or`. By default every check on the form must
pass; `&or` before a run of checks makes them alternatives:

    check_routing=required You must supply your ABA routing number.
    &and
    check_routing=length 9-9 ABA routing numbers are always 9 digits.

Write your own with [CodeDef](../config/CodeDef.md) — a `.oc` file, or an
inline definition — registering an `OrderCheck` routine that returns
`($ok, $fieldname, $message)`.

## Order routes

A **route** is a named bag of attributes describing one way to finalize an
order. Define routes with [Route](../config/Route.md), one attribute per
line or many in a here-document:

    Route  log  <<EOF
        empty      1
        report     etc/log_transaction
        supplant   0
        track      logs/log
    EOF

When an order finalizes, `route_order` (`lib/Vend/Order.pm`) runs one or
more routes. The attributes that steer it:

| Attribute | Effect |
|-----------|--------|
| `report` | the report template to render for this route |
| `email` | address (or `[value]` field name) to mail the rendered report to |
| `attach` | attach the report to the next route instead of mailing |
| `empty` | empty the cart after this route |
| `track` | append the rendered report to this file |
| `individual_track` | write the report to a per-order file in this directory |
| `supplant` | this route replaces the built-in order handling (suppress `mail_order`) |
| `write_tables` | put these tables in write mode for the route |
| `transactions` | run these tables transactionally, commit on success / roll back on failure |
| `credit_card` / `encrypt` | PGP-encrypt the card block / whole report |
| `payment_mode` | run a real-time [payment](payments.md) charge |
| `counter` / `counter_tid` | source of the order number / transaction id |
| `increment` | whether to draw a new order number |
| `profile` / `inline_profile` | a profile the route runs itself |
| `master` | this route orchestrates a `cascade` |
| `cascade` | space-separated list of routes to run in turn (quote it) |
| `error_ok` / `continue` | a failure of this route does not fail the order |

**Cascades and the master route.** A store usually defines one `master`
route that `cascade`s through several workers. strap's `default` route is
the model:

    Route  default  master    1
    Route  default  cascade   "log main copy_user"
    Route  default  supplant  1
    Route  default  empty     1
    Route  default  email     you@example.com

Submitting an order with no explicit `mv_order_route` selects the master
route (step 2 of the process), which runs `log` (writes the transaction and
orderline tables), `main` (emails the report and card block, keeps
failsafe copies), and `copy_user` (emails the customer their receipt) in
order. The route named `default` is the fallback when nothing else is
chosen, and by convention is defined last.

**Transactions across a cascade.** With `transactions` set on the cascaded
routes and on the master, table writes are committed only after every route
succeeds and rolled back if any fails (`Vend::Interpolate::flag` calls at the
end of `route_order`) — so a failed card charge does not leave a half-written
order in the database.

**Dynamic and expandable routes.** `dynamic_routes` reads a route's
attributes at run time from the table named by
[RouteDatabase](../config/RouteDatabase.md) instead of the compiled config;
`expandable` interpolates ITL inside route values. Both are off by default;
strap ships them commented out.

**Numbering.** [OrderCounter](../config/OrderCounter.md) names the file that
issues sequential order numbers; a route's `counter_tid` issues a separate
transaction id. `mv_order_number` and `mv_transaction_id` end up in
`[value]` space for the report to print.

## The order report and receipts

Every route renders a **report** — an ITL template interpolated with the
order in `[value]` space and the cart still populated (the cart is emptied
only after routing). The template is chosen per route (`report`), falling
back to [OrderReport](../config/OrderReport.md):

    Order [value mv_order_number] from [value fname] [value lname]
    Ship to: [value address1], [value city] [value state] [value zip]

    [item-list]
    [item-quantity] x [item-code] [item-description] @ [item-price]
    [/item-list]

    Subtotal: [subtotal]  Tax: [salestax]  Total: [total-cost]

strap's `etc/report` is the full merchant copy — a fixed-column layout using
[row](../tags/row.md)/`[column]`, billing vs. shipping
address handling, and the masked card block. A route with an `email`
attribute mails this report; [MailOrderTo](../config/MailOrderTo.md) is the
fallback recipient when the built-in `mail_order` handles the order (no route
`supplant`ed it). Set `MailOrderTo none` to skip the email while developing,
as the tutorial does.

**The fallback log.** [AsciiTrack](../config/AsciiTrack.md) names a flat file
to which `track_order` appends every order's report, wrapped in
`##### BEGIN ORDER ... #####` markers. It is the zero-setup order log — the
tutorial reads its store's whole order history out of `etc/tracking.asc`. A
route's own `track` and `individual_track` attributes write the same
rendered report to route-specific files.

**Receipts.** After finalizing, the `submit` action displays the `receipt`
[SpecialPage](../config/SpecialPage.md) (or a route's `receipt` attribute, or
`mv_order_receipt`), unless the route set `no_receipt`. On a route failure it
shows the `failed` special page. The receipt page still sees the just-ordered
items, so it can print an order summary before the cart clears.

## Writing orders to database tables

Production stores persist orders in tables rather than only a flat log. The
convention (and strap's default) is two tables:

- **transactions** — one row per order: order number, customer and billing
  addresses, ship mode, subtotal/tax/shipping/total, payment method and
  authorization, status, and timestamps. strap's header row lists ~60
  columns (`dist/strap/products/transactions.txt`).
- **orderline** — one row per ordered line: `order_number`, `sku`,
  `quantity`, `price`, `subtotal`, tax fields, options, and a per-line
  status.

The writing is done in ITL by the report template named on the `log` route,
`etc/log_transaction`. It is worth reading in full
(`dist/strap/etc/log_transaction`) as the canonical example of a
database-backed checkout: it puts the tables in write mode with
[flag](../tags/flag.md), processes payment inside
[try](../tags/try.md)/[catch](../tags/catch.md) blocks, issues the order
number, then uses [import](../tags/import.md) with `type=LINE` to insert one
transactions row and one orderline row per [item-list](../tags/item-list.md)
iteration, optionally decrementing an `inventory` table. Because the `log`
route participates in the cascade's `transactions`, all of these writes
commit together or not at all.

You do not need this complexity to take orders — the tutorial's flat-file
report is a complete, working checkout — but every real store grows into
something like `log_transaction`.

## Returns and RMAs

Interchange has no built-in returns engine; strap implements returns as
ordinary pages over an `order_returns` table
(`dist/strap/products/order_returns.txt`, with SQL variants under
`dbconf/`). The customer-facing flow is a small set of pages —
`pages/query/order_return.html` starts a return,
`pages/member/returns.html` lists a logged-in customer's returns, and
`pages/member/process_return.html` records one — each an
[OrderProfile](../config/OrderProfile.md)-validated form writing to the
returns table, exactly like the checkout above. `etc/return.number` and
`etc/rma.number` are the counters. Treat these as a worked pattern to copy,
not a framework to configure.

## See also

- [Forms](forms.md) — the `mv_*` form vocabulary, `[process]`, input
  filters, and multi-page form flow
- [Payments](payments.md) — gateways, `&charge`, card encryption, and the
  `MV_PAYMENT_*` variables
- [Pricing](pricing.md), [Shipping](shipping.md), [Taxes](taxes.md) — how
  `[item-price]`, `[shipping]`, and `[salestax]` are computed
- [Sessions](sessions.md) — where the cart is stored and how long it lives
- [Route](../config/Route.md), [OrderProfile](../config/OrderProfile.md),
  [OrderReport](../config/OrderReport.md),
  [AsciiTrack](../config/AsciiTrack.md) — the directive reference
- [order-checks reference](../order-checks/README.md) — every pluggable check
- [item-list](../tags/item-list.md), [order](../tags/order.md),
  [total-cost](../tags/total-cost.md), [error](../tags/error.md) — the tags
  used above
