# Frequently asked questions

Short answers to the questions that come up most often when you build and run
an Interchange store, each one pointing at the guide or reference page that
covers the topic in full. The questions are grouped by topic; read a section
top to bottom or jump to the one that matches your problem. Nothing here
replaces the core chapters — [Architecture](architecture.md),
[Configuration](configuration.md), and [Templating with ITL](templating.md)
are the place to start if you are new — but this page is the fastest route
from a specific symptom to the right explanation.

## How Interchange works

### Where are my pages? I can't find them in the web root.

They are not in the web server's document root, and they never will be.
Interchange pages live in the catalog's `pages/` directory (set by
[PageDir](../config/PageDir.md), default `pages`) and are *interpolated* by
the daemon on every request before the finished HTML is sent to the browser —
that interpolation is the whole point of Interchange. A request for
`ord/basket` serves `pages/ord/basket.html`, filtered through the tag engine.
See [Catalog anatomy](catalog-anatomy.md) for the directory layout and
[Templating with ITL](templating.md) for what happens during interpolation.

### Where did my images go? The paths look rewritten.

They are. Because catalog URLs run through a link program under a script path
like `/cgi-bin/strap`, a relative `<img src="ordernow.gif">` would resolve
against that path and break. To prevent it, Interchange rewrites image
references that have no leading `/` by prepending [ImageDir](../config/ImageDir.md).
With `ImageDir /strap/images/`, this in a page:

    <img src="ordernow.gif">

is delivered as:

    <img src="/strap/images/ordernow.gif">

Absolute paths (`/other/images/logo.gif`) are left untouched. On the secure
side the prefix comes from [ImageDirSecure](../config/ImageDirSecure.md)
instead — set it if your images 404 over HTTPS.

### Why does every URL carry a session id and an `mv_pc` number?

The session id keeps the shopper's cart and login attached to the request; see
[Sessions](sessions.md). The `mv_pc` component defeats proxy and browser
caching of dynamic pages (so a visitor behind a shared cache does not see
someone else's page), and it doubles as the affiliate/ad source parameter:
`?mv_pc=partner1` records `partner1` as the visit source, readable later with
`[data session source]`. Source resolution and the older `?;;partner1` idiom
are described under the request lifecycle in [Architecture](architecture.md)
(see [SourcePriority](../config/SourcePriority.md)).

### Where is `process.html`? My form posts to a page that does not exist.

It does not exist as a file. When a form's action is [process](../tags/process.md),
Interchange processes the posted variables according to `mv_todo` and then
displays the page named in `mv_nextpage`; the URL it constructs just happens to
end in the imaginary name `process.html`. There is nothing to create or edit.
Form handling is covered in [Forms](forms.md).

### Do I have to restart the server after every change?

For configuration changes, yes — the config files are compiled once at
startup into memory. But you rarely need a full restart: reconfigure a single
catalog in place instead.

    bin/interchange --reconfig=strap    # recompile one catalog, no restart
    bin/interchange -r                  # full restart (HUP)

The admin UI's "Apply Changes" does the same reconfigure. Reconfiguration is
picked up during the next housekeeping cycle, so allow a few seconds. Page
edits under `pages/` take effect immediately — no restart needed — unless you
have caching turned on. See [Configuration](configuration.md#startup-reconfiguration-and-debugging).

### My `[item-field name]` (or `[loop-field]`) is empty, but the column has data.

`[item-field col]` and `[loop-field col]` read only the products table(s)
named in [ProductFiles](../config/ProductFiles.md). If your column lives in
another table, use the `-data` form and name the table explicitly:

    [item-data pricing price_group]

`[PREFIX-field col]` is shorthand over the product tables; `[PREFIX-data table
col]` reaches any table. The distinction and the full sub-tag set are in
[item-list](../tags/item-list.md) and [loop](../tags/loop.md).

### When do I have to quote a tag that is nested inside another tag?

Loop sub-tags resolved by the enclosing list — `[item-code]`,
`[item-field ...]`, `[loop-data ...]`, and their siblings — need no quoting,
because the list tag interpolates them before it runs its body:

    [item-list]
      [page [item-field url]]details</a> — [item-description]
    [/item-list]

A general tag used as another tag's *value* does need quoting, because the
outer tag's positional parser will not interpolate it first:

    [page [value mypage]]              wrong
    [page href="[value mypage]"]       right

When in doubt, use named attributes with quoted values; you cannot go wrong
that way. The interpolation order is explained in
[Templating with ITL](templating.md#interpolation-inside-arguments).

## Installation and startup

### The `makecat` prompts are asking things I don't know.

The single most common installation failure is wrong information given to
[makecat](installation.md#building-a-catalog-with-makecat) — chiefly the web
server's document root and how it runs CGI. Those values are site-specific.
Re-run `bin/makecat` and read the prompts; the examples shown fit most
systems. The full walk-through, including the Apache/nginx wiring, is in
[Installation](installation.md).

### "The Interchange server was not running" / "the server is unavailable."

The link program (`vlink`/`tlink` in your `cgi-bin`) cannot reach the daemon.
Work through, in order:

1. **Is the daemon up?** `bin/interchange -r` to start it; check with
   `ps aux | grep interchange`.
2. **Same user?** In UNIX-socket (VLINK) mode the daemon and the setuid link
   program must run as the same user; see the
   [ownership and permission model](installation.md#the-ownership-and-permission-model).
3. **Socket permissions.** If starting with `bin/interchange -r
   SocketPerms=0666` makes it work, you have a permission problem on
   `etc/socket` ([SocketPerms](../config/SocketPerms.md)); fix ownership rather
   than leaving the socket world-writable.
4. **NFS.** UNIX-domain sockets do not work on NFS-mounted filesystems. Put
   the socket on local disk, or switch to Inet (TCP) mode with `tlink`
   ([TcpMap](../config/TcpMap.md), [Architecture](architecture.md#process-model)).

The web server's error log almost always names the actual cause. See also
[Logging and debugging](logging-debugging.md).

### What Perl version do I need?

Interchange requires Perl 5.16.3 or newer (`require 5.016_003` in
`Makefile.PL`). A threaded Perl is not recommended — it works but carries a
performance penalty and has historically caused module trouble. Run
`perl -V:usethreads` to check.

### Can I run Interchange on Windows or macOS?

Run the *server* on a Unix-like OS — Linux and the BSDs are the tested
platforms; macOS works for development. Interchange is not supported as a
production server on Windows. The daemon relies on `fork()` and the Unix
process model ([Architecture](architecture.md#process-model)). Catalog *files*
(pages, config, database source) are plain text and can be edited anywhere as
long as you transfer them in text/ASCII mode, not binary — see the next
question.

### After an upload, only the middle of each page renders — no header or footer.

Almost always DOS/Windows carriage returns in your config or template files,
introduced by a Windows editor or a binary-mode FTP transfer. Find them:

    grep -lrP '\r' catalog.cfg templates/

and strip them:

    perl -pi -e 's/\r//g' catalog.cfg

Transfer files in text mode, not binary. The symptom appears because a stray
`\r` breaks the parsing of the layout directives that wrap page content.

### How do I start Interchange at boot?

Use your OS service manager (systemd unit, or an init script — the OS packages
install one). The one rule: **Interchange must not run as root** and will
refuse to start if it is. Launch it as the catalog-owning user, e.g. from a
unit file with `User=interch`, or portably with the bundled `bin/restart`
wrapper. See [Installation](installation.md#starting-stopping-and-reconfiguring).

### Can one server run multiple catalogs?

Yes — that is the design. One daemon serves any number of independent
catalogs, each selected by its script path; sites run hundreds on a single
machine. Add a [Catalog](../config/Catalog.md) line per store in
`interchange.cfg`. Capacity is a function of traffic and RAM, not a fixed
limit. See [Running multiple catalogs](installation.md#running-multiple-catalogs)
and [Architecture](architecture.md).

### How do I move a catalog from a test server to production?

The essentials, rewritten for a current tree:

1. Copy the whole catalog root, preserving structure.
2. Make sure the Interchange daemon user has read/write on everything it needs
   (`session/`, `tmp/`, `logs/`, counters, writable tables).
3. Fix host-specific [Variable](../config/Variable.md) values (domain names,
   base URLs) — in strap these live under `variables/`.
4. Point image and error-log paths at the production locations.
5. If you use MySQL/PostgreSQL, create the database and grant access; import
   the tables.
6. Install a link program in the production `cgi-bin`, setuid and owned by the
   daemon user.
7. Add the [Catalog](../config/Catalog.md) line to production `interchange.cfg`
   and restart.
8. Check the global and catalog error logs.

[Catalog anatomy](catalog-anatomy.md) maps what each directory holds, and
[Upgrading](upgrading.md) covers version-to-version moves.

## Doing things on pages

Most "how do I" questions come down to one tag. These are the recurring ones;
[Templating with ITL](templating.md) is the broader reference.

### How do I show the number of items in the cart?

For the total quantity, use [nitems](../tags/nitems.md):

    You have [nitems] item(s).

In Perl, `$Tag->nitems()`. For the number of *lines* (distinct entries)
regardless of quantity:

    [calc]scalar @{$Carts->{main}}[/calc]

`$Carts->{main}` is the main cart, an array of hash references — see
[Cart and checkout](cart-and-checkout.md).

### How do I empty the cart?

Clear the cart array in place:

    [calc] @{$Carts->{$CGI->{mv_cartname} || 'main'}} = (); return; [/calc]

Wrap that in a `[set]` block fired by a "Clear basket" button, or drop the
whole session (cart included) with an `mv_todo=cancel` form. Both patterns and
the cart data model are in [Cart and checkout](cart-and-checkout.md).

### How do I delete a single item from the cart in Perl?

Filter it out by SKU:

    [calc] @$Items = grep { $_->{code} ne 'os28005' } @$Items; return; [/calc]

`$Items` is the current cart inside a `[perl]`/`[calc]` block; see
[Embedded Perl](perl-embedding.md).

### How do I display items in random order?

With an SQL backend, let the database do it:

    [query list=1 sql="SELECT * FROM products ORDER BY RAND() LIMIT 3"]
      [sql-param description]<br>
    [/query]

(`RAND()` is MySQL; PostgreSQL uses `RANDOM()`.) The strap demo also ships a
`random` component under `templates/components/` for a curated random block.
See [query](../tags/query.md) and [Search](search.md).

### How do I add a thumbnail only when the image file exists?

Guard the `<img>` with a file test so a missing thumbnail does not show a
broken image:

    [if file images/thumb/[item-field thumb]]
      <img src="/strap/images/thumb/[item-field thumb]">
    [/if]

### How do I get the number of matches from a search?

`[value mv_search_match_count]` — Interchange sets it after every search
(`lib/Vend/Scan.pm`). For paging through large result sets, use the more-list
mechanism rather than fetching everything; see [Search](search.md).

### Can I use dotted `table.field` names in a multi-table query?

No — DBI does not return `table.field` keys, so `[sql-param orders.id]` will
not work. Alias the column in the SQL and refer to the alias:

    SELECT orderline.quantity AS o_quan, ... 

then `[sql-param o_quan]`. See [query](../tags/query.md) and
[Databases](databases.md).

### Sorting with `[sort table:field]` only sorts the current page.

That is expected: `[sort]` orders the rows already present in the list, not the
whole result set. To sort across an entire multi-page result, sort in the
search or query itself (`mv_orsearch`/`tf=` sort parameters, or `ORDER BY` in
SQL). See [Search](search.md).

### I'm searching for a string I know is there, and it's not found.

Word-match searches split on word boundaries, and Perl does not treat many
non-ASCII characters (accented letters, Cyrillic) — or non-alphanumerics — as
word characters unless the locale is set up for it. Force a substring match:
`mv_substring_match=yes` (`su=yes` in a one-click search). See
[Search](search.md) and [Internationalization](internationalization.md).

## Product options

### How do I attach a size or color to a product?

Use product options. A product with a master record in the `options` table
(strap ships one; `os28005` has bristle, color, and logo options) gets its
selection widgets rendered by [options](../tags/options.md) on a flypage, or by
[accessories](../tags/accessories.md) / the `[item-accessories]` sub-tag on a
basket line. The chosen values ride along with the cart line as *modifiers*.
Setting [SeparateItems](../config/SeparateItems.md) `Yes` (the demo default)
puts each configured item on its own basket line. The full model — simple,
matrix, and modular options — is in
[Cart and checkout](cart-and-checkout.md).

### Can I change the price based on the option chosen?

Yes. The `options` table's `price` column holds per-value adjustments in the
form `S=-1.00,XL=1.00`, applied through the `==:options` atom of your
[CommonAdjust](../config/CommonAdjust.md) pricing chain:

    CommonAdjust  pricing:price, ==:options

Pricing chains, quantity breaks, and option adjustments are covered in
[Pricing](pricing.md). The column names can be remapped with
[MV_OPTION_TABLE_MAP](../variables/MV_OPTION_TABLE_MAP.md).

### What are options, really, and where do they live?

An Interchange cart is an array of hash references, one hash per line. Beyond
the reserved keys (`code`, `quantity`, `mv_ip`, `mv_ib`, `mv_mi`/`mv_si` for
matrix master/sub-items, and so on), every other key on the hash is a product
*modifier* — `size`, `color`, and the like. Display one with
`[item-modifier size]`. The reserved keys and the cart structure are detailed
in [Cart and checkout](cart-and-checkout.md); to inspect a live cart, drop a
[dump](../tags/dump.md) on a page.

## Orders, email, and payments

### How do I email the customer a copy of the receipt?

Send it from the order route or a job with the [email](../tags/email.md) tag.
It is more involved than it looks: handle bad addresses, decide what to
include, and — critically — never mail an unencrypted card number. The receipt
and order-notification machinery ships in strap's `etc/` (`mail_receipt`,
`receipt.html`); see [Email](email.md) and
[Cart and checkout](cart-and-checkout.md).

### How do I change the order number away from the `TEST0001` prefix?

Two ways: in the admin UI, open Administration and edit the last order number;
or edit the counter file `etc/order.number` in the catalog directly. Order
numbering runs through the transaction log; see [Admin UI](admin-ui.md).

### My payment processor isn't supported. Now what?

Interchange ships modules for many gateways under `lib/Vend/Payment/` (see the
[payment gateway reference](../payments/README.md)). If yours is missing, a new
module is needed — write one modeled on an existing module, or engage a
developer. The integration model is in [Payments](payments.md).

### How do I edit an order after it's placed — add an item, change shipping?

There is no built-in re-pricing editor. You can change the stored rows through
the admin UI, but that will not recompute subtotals, tax, and shipping. Most
sites handle post-order changes in their back-office/accounting system rather
than in Interchange. See [Admin UI](admin-ui.md).

## Security and SSL

### How do I email credit card numbers in plain text?

You don't, and the project will not help you do it. Encrypt card data (see
below) or, better, don't store or mail full card numbers at all — hand them to
a [payment gateway](payments.md) and keep them off your disk. See
[Security](security.md).

### PGP/GPG encryption throws a "Server Error."

Check the catalog error log, and look in [ScratchDir](../config/ScratchDir.md)
(usually `tmp/`) for `*.err` files holding the encryption program's own
output. The usual causes:

- **No keyring for the daemon user** — it needs a `.gnupg` (or `.pgp`)
  directory in its home, or `GNUPGHOME`/`PGPPATH` set to point at one.
- **Wrong `EncryptProgram`** — you only need the program name.
  [EncryptProgram](../config/EncryptProgram.md) defaults to trying `gpg`, then
  `pgpe`; the recipient key is set separately in
  [EncryptKey](../config/EncryptKey.md).

Card-data handling and the credit-card template are covered in
[Security](security.md).

### How do I get an SSL certificate?

That is between you, your web server, and a certificate authority — it is
outside Interchange. Any CA and the Apache/nginx/OpenSSL docs will walk you
through a CSR and installation. Self-signed certificates trip browser warnings,
so use a real one in production.

### My shopping cart is dropped when the customer moves to SSL.

This happens when secure and non-secure requests are served from *different
domains*: the session cookie and the client IP no longer match, so the session
is not recognized. The robust fix is to serve the whole storefront over HTTPS
so there is only one domain — the modern default. If you must split domains,
route all cart and order traffic to the secure host with
[AlwaysSecure](../config/AlwaysSecure.md):

    AlwaysSecure  process order ord/basket ord/checkout

and, as a fallback, loosen session-to-IP binding with
[WideOpen](../config/WideOpen.md) `Yes` and a short
[SessionExpire](../config/SessionExpire.md). Make sure `process` is in the list
so form posts stay secure. Session identity and cookies are explained in
[Sessions](sessions.md); the trade-offs, in [Security](security.md).

### How do I lock down a catalog against user-entered data?

Interchange defends you by default — `[value]`, `[cgi]`, and `[data]` output is
not re-parsed for tags, Perl runs in the [Safe](security.md) compartment, and
catalog code cannot do global operations. But tainted data can still bite you
if you store it unfiltered and display it later. In brief:

- Display user fields with [value](../tags/value.md), never by interpolating
  raw input, and filter form fields on input, e.g. `Filter comments
  textarea_put` in `catalog.cfg` (see [Filter](../config/Filter.md)).
- Turn on write control so pages can't write tables without an explicit
  [flag](../tags/flag.md): `Database products WRITE_CONTROL 1`
  ([Database](../config/Database.md)). It is the default for DBM tables but not
  for SQL.
- Enable [NoAbsolute](../config/NoAbsolute.md) `Yes` to forbid `[file /etc/...]`
  and absolute includes. (It is **not** on by default in the current code, so
  set it explicitly — despite older documentation that claimed otherwise.)
- Keep [AllowGlobal](../config/AllowGlobal.md) off in production, and make
  everything the daemon doesn't need to write read-only.

The full treatment is [Security](security.md).

## Performance

### Interchange is slow, or gets slower over time.

Most slowness is memory or session-store, not Interchange itself:

- **RAM.** If the machine swaps, performance collapses. Interchange keeps
  catalogs and database handles in memory; give it enough not to swap.
- **Process model.** For production traffic, run [PreFork](../config/PreFork.md)
  `Yes` with a pool of persistent servers rather than fork-per-request; see
  [Architecture](architecture.md#process-model).
- **Session store.** A session database that has grown to many megabytes slows
  every lookup. Expire old sessions ([SessionExpire](../config/SessionExpire.md),
  run by [housekeeping and jobs](jobs.md)).

The tuning chapter is [Performance](performance.md).

### My SQL searches are slow.

Interchange does not index your tables for you, because every engine does it
differently. Index your key and search columns. You can declare the primary
key through [Database](../config/Database.md) `COLUMN_DEF`:

    Database  products  COLUMN_DEF  code=char(16) PRIMARY KEY

Then select only the columns you display, and drive links from them:

    [query sql="SELECT code, title, price FROM products WHERE category = 'Tools'"]
      <a href="[area [sql-code]]">[sql-param title]</a> —
      [currency][sql-param price][/currency]<br>
    [/query]

See [Databases](databases.md) and [Search](search.md).

### How do I make large product lists render faster?

Inside a big loop, every ITL tag and every `[calc]`/`[if]` costs parsing and a
Safe evaluation. The high-value habits:

- Prefer loop sub-tags to general tags: `[loop-field image]` is much faster
  than `[data products image [loop-code]]`, because the row is already fetched.
- Pre-fetch with `rf=col1,col2` and read via `[loop-param col1]` instead of a
  per-row lookup.
- Use `[loop-alternate N]` for row striping and table breaks instead of
  `[calc]` arithmetic; use `[loop-calc]` (runs during the loop) over `[calc]`.
- Avoid `interpolate=1` and large [scratch](../tags/scratch.md) writes when you
  don't need them; use `[tmp]` for page-local scratch that isn't saved to the
  session.

Worked benchmarks are in [Performance](performance.md); the sub-tag catalog is
in [loop](../tags/loop.md) and [Templating with ITL](templating.md#loops-and-prefix-sub-tags).

## Getting unstuck

### The demo doesn't do *X*.

Strap is a starting point, not a finished store — it demonstrates the moving
parts. Build your store from it, but think hard before rewriting the checkout
schema: the `userdb`, `transactions`, and `orderline` tables and the checkout
flow are the product of long experience, and changes to them can cause subtle
order-logging bugs. Test any such change thoroughly.

### Where do I go for more?

Start from the guide that owns your topic — this FAQ links into all of them —
and the per-item [directive](../config/README.md), [tag](../tags/README.md),
and [filter](../filters/README.md) references for exact syntax. The
[glossary](../glossary.md) defines the vocabulary (ITL, scratch, flypage,
modifiers, CGI variables). For questions this page doesn't answer, the
Interchange community mailing lists remain the place to ask — include your
Interchange version, OS, Perl version, database, and the relevant error-log
lines.

## See also

- [Architecture](architecture.md) — the request lifecycle and process model
- [Configuration](configuration.md) — how the config files are compiled
- [Templating with ITL](templating.md) — the tag language itself
- [Installation](installation.md) — setup, permissions, and web-server wiring
- [Security](security.md) — trust model, Safe, and data handling
- [How-tos](howtos.md) — task-focused recipes that go beyond a single answer
