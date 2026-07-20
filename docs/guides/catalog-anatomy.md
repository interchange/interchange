# Catalog anatomy

A **catalog** is one store: a directory tree owning its configuration,
pages, templates, and data, registered with the server by a
[Catalog](../config/Catalog.md) line in `interchange.cfg`. This chapter
tours that tree using **strap**, the demo catalog that `bin/makecat` builds
from `dist/strap/` — both to orient you in your own catalogs and because
the rest of the documentation draws its examples from strap's files and
sample data.

Build one to follow along ([Installation](installation.md)):

    cd ~/interchange
    bin/makecat

## The directory tree

    catalog.cfg          the catalog's configuration
    config/              extra config: usertags, filters, makecat build hooks
    dbconf/              database table definitions, per SQL backend
    etc/                 order machinery: report, receipt, jobs, counters
    html/                static assets served by the web server (css, js)
    images/              product and site images (also web-served)
    include/             reusable ITL fragments: checkout steps, menus, profiles
    pages/               the ITL page tree — the storefront itself
    products/            seed data: flat files imported into the tables
    special_pages/       error/interaction pages (missing, violation, ...)
    templates/           page chrome: layouts and components
    upload/              file-upload spool
    variables/           file-backed Variables (TOP, BOTTOM, CSS, JS, ...)

Two kinds of content, two servers: `pages/` (and everything ITL) is
delivered through Interchange; `html/` and `images/` are served directly by
the web server. That split is why a page reference like `ord/basket` has no
directory prefix — it is resolved inside `pages/`.

## catalog.cfg

strap's `catalog.cfg` (~800 lines) reads top-to-bottom as a themed tour of
catalog configuration — worth reading in full once. Its sections, in
order: file-backed Variables (`DirConfig Variable variables`), module
`Require`s, UTF-8 setup, log/session paths, **database backend selection**
(`ifdef MYSQL/PGSQL/SQLITE` each `include dbconf/<engine>/<engine>.cfg`),
URLs (`VendURL`/`SecureURL`), locale setup, `SpecialPage` maps and
[pragmas](../pragmas/README.md), an extensive
[UserDB](../config/UserDB.md) block (bcrypt passwords, email-as-login),
payment and order [Routes](../config/Route.md), sales tax, order counters
and [Profiles](../config/OrderProfile.md), pricing profiles and
[CommonAdjust](../config/CommonAdjust.md), a few inline
[UserTags](../config/UserTag.md), shipping databases, and
[Jobs](jobs.md). See [Configuration](configuration.md) for the syntax it
uses.

Among the inline UserTags, note three **extended aliases** — catalog-level
`UserTag ... Alias` definitions whose expansion presets attributes on a
core tag (the same mechanism as the built-in
[evalue](../tags/evalue.md)):

    UserTag ecgi     Alias cgi keep=1 filter=encode_entities name=
    UserTag edisplay Alias error auto=1 class="alert alert-danger list-unstyled"
    UserTag wdisplay Alias warnings auto=1 list_class="alert alert-success list-unstyled"

`[ecgi foo]` expands to `[cgi name=foo filter=encode_entities keep=1]` —
an entity-encoded, non-mutating read of a CGI variable, the safe way to
echo request input (the trailing `name=` captures the positional).
`[edisplay]` and `[wdisplay]` render [error](../tags/error.md) and
[warnings](../tags/warnings.md) output pre-styled with strap's Bootstrap
alert classes; strap's pages call them with further attributes
(`[edisplay show_var=0 show_label=1]`), which combine with the presets.
These exist only in strap-derived catalogs — they are `catalog.cfg`
definitions, not core tags — but the pattern is worth stealing for your
own catalogs.

## How a page is assembled

strap composes every page from four layers:

1. **Variables** — `variables/TOP` and `variables/BOTTOM` hold the site
   header/footer markup; `CSS`, `JS`, `TOP_MENU`, `LINE_MENU` and friends
   are spliced in as `__TOP__`-style substitutions
   ([Templating](templating.md)). Editing a file in `variables/` restyles
   the whole site (after a catalog reconfig, or immediately under
   `Pragma dynamic_variables`).
2. **Layouts** — `templates/layout/` provides the region arrangements
   (`leftright`, `leftonly`, `rightonly`, `noleft`); a page selects one via
   the `display_class` scratch value.
3. **Components** — `templates/components/` holds drop-in storefront
   widgets: `cart_tiny`, `product_tree`, `category_vertical_tree`, `cross`
   (cross-sell), `upsell`, `best`, `random`, `promo`, `search_box_small`.
   Pages place them via `[control-set]` blocks and the layout pulls them
   into regions — see `pages/index.html` for the pattern.
4. **The page body** — the file in `pages/` with the page-specific content.

`include/` supplies mid-size fragments shared between pages: the multi-step
checkout is literally assembled from `include/checkout/*`
(`shipping_address`, `payment_select`, ...), navigation menus from
`include/menus/`, and form-validation profiles from `include/profiles/`
(loaded by `Profiles include/profiles/*.*`).

## The storefront flow

| Stage | Pages |
|-------|-------|
| Browse | `pages/index.html`, category listings via `results.html` |
| Product detail | `pages/flypage.html` — the **flypage**, shown for any SKU without a dedicated page |
| Search | `results.html`, `advancedsearch.html` ([Search](search.md)) |
| Cart | `pages/ord/basket.html` |
| Checkout | `pages/ord/`: `shipping.html` → `billing.html` → `shipmode.html` → `finalize.html` (or single-page `checkout.html`) |
| Accounts | `login.html`, `new_account.html`, `pages/member/*`, token-based reset at `query/pw_reset.html` |
| Extras | gift certificates (`pay_cert/`), affiliates (`affiliate/`), stock alerts (`function/stock_alert.html`), soft-goods delivery (`deliver.html`) |

The *flypage* deserves emphasis: a URL naming a SKU
(`/cgi-bin/strap/os28005`) matches no page file, so Interchange falls back
to the flypage, which renders the product from the database
(`[item-field ...]`). One template serves the whole product tree.

`special_pages/` holds what visitors see on trouble: `missing.html` (404s
inside the catalog), `violation.html`, `interact.html` — mapped by the
[SpecialPage](../config/SpecialPage.md) directive. strap's SEO category
URLs (`/Tools/Hand-Saws`) are implemented by `SpecialSub missing` handing
unresolved paths to `config/ncheck_category.tag`; the general mechanisms
are described in [Architecture](architecture.md) step 6.

## Data: dbconf/ and products/

`dbconf/<engine>/` (mysql, pgsql, sqlite) declares the same ~21 tables per
backend — each file a [Database](../config/Database.md) block naming the
table's source file, key, and SQL column definitions. The core commerce
tables: `products`, `variants`, `options`, `pricing`, `inventory`, `tree`
(category tree), `userdb`, `access` (admin logins), `transactions`,
`orderline`, `country`, `state`, plus supporting tables (`affiliate`,
`pay_certs`, `stock_alert`, `gateway_log`, `tax_averages`).

`products/` holds the tab-delimited seed files (`products.txt`,
`variants.txt`, `inventory.txt`, `userdb.txt`, ...) imported into those
tables at catalog build, shipping-rate tables under `products/ship/`, and
`mv_metadata.asc` — the column metadata that drives the
[admin UI's](admin-ui.md) table editor and [widgets](../widgets/README.md).
How the table/file relationship works — imports, exports, editing data in
place — is the subject of [Databases](databases.md).

## etc/: the order machinery

- `etc/report` — the order report emailed to the merchant
  ([OrderReport](../config/OrderReport.md))
- `etc/receipt.html` — the customer receipt page
- `etc/log_transaction` — the order [Route](../config/Route.md) that writes
  `transactions`/`orderline` and decrements inventory
- `etc/mail_receipt`, `etc/ship_notice` — customer emails
- `etc/order.number`, `return.number`, `rma.number` — counters
  ([OrderCounter](../config/OrderCounter.md))
- `etc/jobs/` — scheduled [job](jobs.md) groups (`daily`, tax jobs)

These are ordinary ITL files: customizing a receipt is an edit to
`etc/receipt.html`, not code. See
[Carts and checkout](cart-and-checkout.md).

## From skeleton to catalog: makecat

`bin/makecat` interviews you (paths, URLs, server user, SQL backend),
copies `dist/strap/` into place with substitutions, imports `products/`
into the chosen database, and appends the `Catalog` line to
`interchange.cfg`. The build-time hooks live in the skeleton's `config/`
directory (`precopy_commands`, `postcopy_commands`, `additional_fields` for
extra questions). Any catalog directory can serve as a skeleton — building
your own store by copying and carving strap is a supported workflow, and
the [tutorial](tutorial.md) builds one from scratch instead so you meet
each piece in isolation.

## The admin interface, briefly

The back office is *not* part of the catalog tree: it is a shared library
(`lib/UI/` in the install, from `dist/lib/UI/`) layered onto every catalog
where `Variable UI` is set — admin pages come from `TemplateDir`, admin
logins from the catalog's `access` table, permissions from its UserDB `ui`
profile. strap wires it in with `ifdef @UI Autoload admin_links` and
protects `admin*`/`ui*` paths with
[AlwaysSecureGlob](../config/AlwaysSecureGlob.md). Details:
[The admin interface](admin-ui.md).

## See also

- [Configuration](configuration.md) · [Templating](templating.md) ·
  [Databases](databases.md) · [Tutorial](tutorial.md)
- `dist/strap/README.md` in the source tree for strap-specific notes
