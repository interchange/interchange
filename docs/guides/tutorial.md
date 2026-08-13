# Catalog-building tutorial

The fastest way to understand Interchange is to build a catalog by hand —
no `makecat`, no demo skeleton, just the files a store actually consists
of, added one at a time. In this tutorial you will install Interchange,
register a catalog with the server, and grow it from a single page into a
small working store — product listing, product pages, a shopping basket,
validated checkout with an order log, and search. Every listing below is
complete; type or paste it exactly and you will have a running store at
the end.

The store is **Brush & Barrel Art Supply**: five products, no frills.
Where this tutorial keeps things deliberately minimal, it links to the
guide that treats the topic in full. (For the opposite approach — start
from the full-featured demo and study it — see
[Catalog anatomy](catalog-anatomy.md).)

## 1. Install Interchange

You need Perl 5.16.3+, a C compiler (only for the optional link programs),
and the CPAN dependencies (`cpanm --installdeps .` in the source tree
handles them). Install as an ordinary user — Interchange never needs to
run as root:

    git clone https://github.com/interchange/interchange.git
    cd interchange
    perl Makefile.PL
    make
    make test
    make install

The git repository is how you get current Interchange — versioned
release tarballs are no longer produced regularly. Clone somewhere other
than `~/interchange`, which is the default *install* directory.

`Makefile.PL` asks where to install (default `~/interchange`) and which
user owns the installation. To script it, pass the answers instead:

    perl Makefile.PL PREFIX=$HOME/interchange INTERCHANGE_USER=$USER force=1

Everything below happens in and under the install directory; `cd` there
now. `bin/` holds the server and utilities, `lib/` the Perl modules, and
`etc/` run state (PID file, sockets, logs). Details and deployment
variants: [Installation](installation.md).

## 2. Configure and start the server

The server reads `interchange.cfg` in the install directory. Create it:

    # interchange.cfg

    # Listen on a TCP socket (no web server needed while learning)
    Inet_Mode  Yes
    Unix_Mode  No
    TcpMap     7786 -

    # Our catalog: name, base directory, URL path
    Catalog  paints  /home/YOU/catalogs/paints  /paints

Adjust the directory to taste (and create it in step 3). The
[Catalog](../config/Catalog.md) line is the server's complete knowledge of
the catalog: its name, where it lives, and the URL prefix that routes
requests to it.

Start, restart, and stop the server with:

    bin/interchange           # start
    bin/interchange -r        # restart (after config changes)
    bin/interchange --stop    # stop

Starting now fails with `Could not open configuration file ... for catalog
'paints'` — good, the server told you exactly what is missing. Every
configuration error is fatal and names the file and line; get used to
reading them, they are the fastest debugging tool you have. The global log
is `error.log` in the install directory.

### Reaching pages while you build

Interchange sits behind a web server in production: a small CGI **link
program** relays each request to the daemon's socket
([Architecture](architecture.md)). Wire that up now if you like —
`bin/compile_link` builds it and [Installation](installation.md) shows the
Apache config — but for this tutorial a shell one-liner speaking CGI to
the TCP socket is enough. Save as `req` and `chmod +x` it:

    #!/bin/bash
    # usage: ./req PATH [QUERY] [POSTDATA]   e.g.  ./req /index
    export SCRIPT_NAME=/paints PATH_INFO="$1" QUERY_STRING="${2:-}" \
      REQUEST_METHOD=GET SERVER_NAME=localhost SERVER_PORT=7786 \
      REMOTE_ADDR=127.0.0.1 HTTP_HOST=localhost GATEWAY_INTERFACE=CGI/1.1 \
      REQUEST_URI="/paints$1"
    if [ -n "$3" ]; then
      export REQUEST_METHOD=POST CONTENT_LENGTH=${#3} \
        CONTENT_TYPE=application/x-www-form-urlencoded
      printf '%s' "$3" | perl -T src/tlink.pl
    else
      perl -T src/tlink.pl
    fi

(`src/tlink.pl` ships with the installation and defaults to port 7786.)
With a browser pointed at a real web server the experience is identical;
the transcripts below use `./req`.

## 3. The smallest possible catalog

Create the catalog directory with its two required pieces — a
configuration file and a page:

    mkdir -p ~/catalogs/paints/{pages,products,special_pages,etc,session,variables}
    cd ~/catalogs/paints

`products/products.txt` — the product database, TAB-separated with a
header row (be careful: those are real tabs):

    sku	description	price
    80015	Umber Oil Paint 150ml	8.99
    80016	Cerulean Oil Paint 150ml	12.99
    80101	Hog Bristle Brush No. 6	4.50
    80102	Sable Detail Brush No. 1	7.25
    80201	Stretched Canvas 40x50cm	11.00

`catalog.cfg`:

    # catalog.cfg for the "paints" tutorial catalog

    Variable   COMPANY  Brush & Barrel Art Supply

    VendURL    http://localhost:7786/paints
    SecureURL  http://localhost:7786/paints

    Database      products  products.txt  TAB
    Database      products  KEY           sku
    ProductFiles  products

Three ideas here, each with its own guide: a
[Variable](../config/Variable.md) is a named string usable in every page
([Configuration](configuration.md)); the
[Database](../config/Database.md) lines turn the text file into a queryable
table named `products` keyed by `sku` ([Databases](databases.md)); and
[ProductFiles](../config/ProductFiles.md) marks that table as "the
catalog".

`pages/index.html` — the first page:

    <h2>Welcome to __COMPANY__</h2>

Restart (`bin/interchange -r` back in the install directory — do this
after *every* config change; page edits, by contrast, are picked up
immediately) and fetch:

    $ ./req /index
    ...
    <h2>Welcome to Brush & Barrel Art Supply</h2>

The catalog is live. `__COMPANY__` was substituted during page
interpolation ([Templating](templating.md)).

## 4. Page chrome with Variables

Real pages share a header and footer. Rather than paste them into every
page, put them in Variables — and because multi-line values are easier to
edit in their own files, load them from a directory. Add to `catalog.cfg`:

    DirConfig  Variable variables

Every file in `variables/` becomes a Variable named after the file.
`variables/TOP`:

    <html>
    <head><title>[var COMPANY]</title></head>
    <body>
    <h1>[var COMPANY]</h1>
    <p>
    [page index]Home</a> |
    [page ord/basket]Basket ([nitems])</a>
    </p>
    <hr>

`variables/BOTTOM`:

    <hr>
    <p><small>&copy; [var COMPANY] &mdash; powered by Interchange</small></p>
    </body>
    </html>

Two things to notice, both learned the hard way:

- **`[var COMPANY]`, not `__COMPANY__`.** Variable substitution is one
  textual pass — text *inside* a substituted Variable is not scanned for
  further `__NAME__` forms. The [var](../tags/var.md) tag looks the value
  up at runtime, so it works anywhere. (Tags inside a Variable's content,
  like `[nitems]` above, run normally.)
- **`[page ...]` is not a container tag.** It emits only the opening
  `<a href="...">`; you close the link with an ordinary `</a>`. Write
  `[/page]` and it appears literally in your HTML. The generated URL
  carries the visitor's session id — never hand-write catalog URLs
  ([Sessions](sessions.md) explains why).

Rewrite `pages/index.html` to use the chrome, and list the products
while you're there:

    __TOP__

    <h2>Welcome to __COMPANY__</h2>

    <table border="1">
    <tr><th>Item</th><th>Price</th><th></th></tr>
    [loop search="ra=yes"]
    <tr>
      <td>[page [loop-code]][loop-field description]</a></td>
      <td align="right">[loop-price]</td>
      <td>[order [loop-code]]Order</a></td>
    </tr>
    [/loop]
    </table>

    <p>[page ord/basket]Show your basket</a> ([nitems] items)</p>

    __BOTTOM__

`[loop search="ra=yes"]` runs a return-all [search](search.md) over the
products table and repeats its body per row; `[loop-code]` and
`[loop-field ...]` are the loop's prefix sub-tags
([Templating](templating.md)). `[order sku]` builds an
add-to-basket link. Restart (DirConfig is config) and fetch `/index`:
five products, each row linking to its product page with an Order link.

Note `[loop-price]` rather than `[loop-field price]`. Both reach the same
column, but `[loop-price]` renders it as money — applying the active
locale's decimal places, separators, and currency symbol, and the
rounding the pricing system expects. Always display prices through
`[PREFIX-price]` (or [`[price]`](../tags/price.md) outside a loop); reach
for `[PREFIX-field price]` only when you need the raw number for
arithmetic. This catalog defines no locale yet, so prices render bare
(`8.99`); [Internationalization](internationalization.md) covers adding
one.

## 5. The flypage

Product detail pages need no per-product files. When a URL names a SKU
(`/paints/80015`) and no such page exists, Interchange displays the
**flypage** with that product loaded. `pages/flypage.html`:

    __TOP__

    <h2>[item-field description]</h2>

    <p>SKU: [item-code]<br>
    Price: [item-price]</p>

    <p>[order [item-code]]Add to basket</a></p>

    __BOTTOM__

    $ ./req /80015
    ...
    <h2>Umber Oil Paint 150ml</h2>

While you are at it, give visitors a friendlier 404 than the built-in
one. `special_pages/missing.html`:

    __TOP__

    <h2>Page not found</h2>

    <p>Sorry, that page doesn't exist. Try the [page index]front page</a>.</p>

    __BOTTOM__

`special_pages/` holds the pages Interchange shows on its own initiative;
[SpecialPage](../config/SpecialPage.md) remaps them individually.

## 6. The shopping basket

The Order links point at `ord/basket`, so create
`pages/ord/basket.html`:

    __TOP__

    <h2>Your basket</h2>

    [if items]
    <form action="[process]" method="post">
    [form-session-id]
    <input type="hidden" name="mv_todo" value="refresh">

    <table border="1">
    <tr><th>Qty</th><th>Item</th><th>Each</th><th>Subtotal</th></tr>
    [item-list]
    <tr>
      <td><input name="[quantity-name]" value="[item-quantity]" size="3"></td>
      <td>[item-field description]</td>
      <td align="right">[item-price]</td>
      <td align="right">[item-subtotal]</td>
    </tr>
    [/item-list]
    <tr><td colspan="3" align="right">Total:</td>
        <td align="right">[subtotal]</td></tr>
    </table>

    <p>
    <input type="submit" value="Update quantities">
    (set a quantity to 0 to remove an item)
    </p>
    </form>

    <p>[page checkout]Check out</a></p>
    [else]
    <p>Your basket is empty. [page index]Keep shopping</a>.</p>
    [/else]
    [/if]

New pieces:

- `[if items] ... [else] ... [/else] [/if]` — a
  [conditional](../tags/if.md) on whether the cart holds anything.
- `[item-list]` loops over the cart with `item-` sub-tags;
  `[quantity-name]` names each quantity input so Interchange can match
  it to its line.
- The form posts to `[process]` — the built-in form-processing action —
  with `mv_todo=refresh`, meaning "update the cart from these fields".
  `[form-session-id]` carries the session in a hidden field. All of the
  `mv_*` form machinery is covered in [Forms](forms.md).

Click Order on the front page, then view the basket; change a quantity to
3 and submit — the subtotal updates (3 × 8.99 = 26.97). Set it to 0 and
the line disappears.

## 7. Checkout

A real checkout validates input before accepting an order. Declare a
validation profile in `catalog.cfg`:

    # Require these fields before an order is accepted
    OrderProfile  etc/profiles.order

`etc/profiles.order`:

    __NAME__ tutorial

    fname=required Please give your first name
    lname=required Please give your last name
    address1=required We need your street address
    city=required We need your city
    zip=required We need your zip code
    email=email Please give a valid email address

    &fatal = yes
    &final = yes

Each line is `field=check message`; `required` and `email` are two of the
built-in [order checks](../order-checks/README.md). `&fatal` bounces the
order on failure, `&final` completes it on success
([Carts and checkout](cart-and-checkout.md)).

Tell the catalog what a completed order should *do* — write a report and
empty the basket. In `catalog.cfg`:

    # Log each completed order to a flat file
    AsciiTrack  etc/tracking.asc

    # The order report; "none" skips emailing it for now
    OrderReport  etc/report
    MailOrderTo  none

    # Order route: log the report and empty the basket; no email yet
    Route  default  report  etc/report
    Route  default  email   none
    Route  default  empty   1

`etc/report` is an ITL template for the merchant's copy of the order:

    Order from: [value fname] [value lname] <[value email]>
    Ship to:    [value address1], [value city] [value zip]

    [item-list]
    [item-quantity] x [item-code] [item-field description] @ [item-price]
    [/item-list]

    Total: [total-cost]

In production you would set [MailOrderTo](../config/MailOrderTo.md) to a
real address (and delete `email none`) so each order is emailed — see
[Sending email](email.md). [Routes](../config/Route.md) are the order
pipeline; real stores add database transaction logging and payment here
([Carts and checkout](cart-and-checkout.md),
[Payments](payments.md)).

Now the page, `pages/checkout.html`:

    __TOP__

    <h2>Checkout</h2>

    [if items]

    <p>[error all=1 show_error=1 show_label=1 joiner="<br>"]</p>

    <form action="[process]" method="post">
    [form-session-id]
    <input type="hidden" name="mv_todo"          value="submit">
    <input type="hidden" name="mv_order_profile" value="tutorial">

    <p>Name:    <input name="fname" value="[value fname]">
                <input name="lname" value="[value lname]"></p>
    <p>Address: <input name="address1" value="[value address1]" size="40"></p>
    <p>City:    <input name="city" value="[value city]">
       Zip:     <input name="zip" value="[value zip]" size="10"></p>
    <p>Email:   <input name="email" value="[value email]" size="30"></p>

    <p>Order total: [total-cost]</p>

    <input type="submit" value="Place order">
    </form>

    [else]
    <p>Your basket is empty. [page index]Keep shopping</a>.</p>
    [/else]
    [/if]

`mv_todo=submit` runs the named profile and, on success, the order route.
The inputs echo `[value ...]` so the visitor's entries survive a failed
validation, and [error](../tags/error.md) displays what the profile
rejected. Two more special pages complete the flow —
`special_pages/receipt.html` (success):

    __TOP__

    <h2>Thank you for your order, [value fname]!</h2>

    <p>We will ship to:</p>
    <p>[value fname] [value lname]<br>
    [value address1]<br>
    [value city] [value zip]</p>

    <p>[page index]Return to the front page</a></p>

    __BOTTOM__

and `special_pages/failed.html` (a route failure — mail refused, disk
full):

    __TOP__

    <h2>Order problem</h2>

    <p>Something went wrong while processing your order. Please try again,
    or contact us. [page checkout]Back to checkout</a>.</p>

    __BOTTOM__

Restart and place an order. Submitting half a form re-shows checkout
with the messages from your profile:

    (address1): We need your street address
    (lname): Please give your last name
    ...

A complete submission lands on the receipt ("Thank you for your order,
Vincent!"), the basket empties (the receipt itself still sees the ordered
items — handy for showing an order summary), and the order is on disk:

    $ cat etc/tracking.asc
    ##### BEGIN ORDER 8Ce9RdAs.1784484139 #####
    Order from: Vincent van Gogh <vincent@example.com>
    Ship to:    1 Yellow House, Arles 13200

    2 x 80016 Cerulean Oil Paint 150ml @ 12.99

    Total: 25.98
    ##### END ORDER 8Ce9RdAs.1784484139 #####

## 8. Search

Add a search box to the bottom of `pages/index.html`:

    <form action="[area search]" method="get">
    <input type="hidden" name="mv_session_id" value="[data session id]">
    Find a product: <input name="mv_searchspec">
    <input type="submit" value="Search">
    </form>

(`[area]` is `[page]`'s URL-only sibling — right for a form `action`.
A GET form needs the session id as a field, since the browser drops the
URL's query string.) Results appear on the default search results page,
`pages/results.html`:

    __TOP__

    <h2>Search results</h2>

    [search-region]

    [search-list]
    <p>[page [item-code]][item-field description]</a> &mdash;
    [item-price] [order [item-code]]Order</a></p>
    [/search-list]

    [no-match]
    <p>No products matched. [page index]Try again</a>.</p>
    [/no-match]

    [/search-region]

    __BOTTOM__

Searching for "brush" finds both brushes (matching is case-insensitive
by default); nonsense hits the `[no-match]` branch. The search engine
goes far beyond this — fielded searches, ranges, paging with
`[more-list]`, saved profiles: see [The search engine](search.md).

## 9. When something goes wrong

- **Server won't start / restart** — a config syntax error; the message
  names the file and line. Fix and `bin/interchange -r`.
- **Page shows your tag literally** — the tag name is wrong (unknown tags
  pass through untouched), or you expected `[/page]`/`[/order]` to work
  (close with `</a>`).
- **A tag silently outputs nothing** — usually a bad argument (missing
  table, misspelled column). Check the *catalog* error log
  (`error.log` in the catalog directory), and see
  [Logging and debugging](logging-debugging.md) for `[dump]` and
  friends.
- **Changes don't appear** — config (catalog.cfg, `variables/` files,
  profiles) needs a restart or
  `bin/interchange --reconfig=paints`; page files do not.
- **Session id in every URL** — normal until the client returns the
  session cookie ([Sessions](sessions.md)).

## 10. Where to go from here

Each next step has a guide waiting:

- **Real database** — move `products` to SQLite/MySQL/PostgreSQL by
  swapping the Database type; the flat file becomes seed data
  ([Databases](databases.md)).
- **Customer accounts** — logins, saved addresses, order history with
  [UserDB](user-database.md).
- **Payments** — replace `email none` with a payment
  [Route](../config/Route.md) and a gateway module
  ([Payments](payments.md)).
- **The admin interface** — order and catalog management in the browser
  ([Admin UI](admin-ui.md)).
- **A real web server** — compile the link program and go behind Apache
  or nginx ([Installation](installation.md)).
- **Study the full demo** — everything this store lacks, strap has:
  layouts, components, multi-page checkout, i18n
  ([Catalog anatomy](catalog-anatomy.md)).

You built this store one directive and one page at a time — which is,
in the end, all any Interchange catalog is.
