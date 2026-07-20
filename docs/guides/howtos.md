# HOWTOs: a collection of recipes

This chapter is a cookbook: short, self-contained solutions to problems
that come up while building and running a catalog, grouped by topic. Each
recipe states the problem, gives the smallest code or configuration that
solves it, and links to the reference pages and guide chapters that cover
the mechanism in depth. Where a recipe overlaps a full chapter — taxes,
sessions, forms — it stays deliberately narrow and points you there for
the whole story.

The examples assume the strap demo catalog (tables `products`, `variants`,
`inventory`, `userdb`; see [Catalog anatomy](catalog-anatomy.md)) so you
can paste and run them. Interchange Tag Language (ITL) syntax, the
`[loop]`/`[perl]`/`[calc]` constructs used throughout, and the variable
forms (`__NAME__`, `[var NAME]`) are explained in
[Templating](templating.md) and [Embedded Perl](perl-embedding.md); this
chapter uses them without re-explaining.

Many recipes end with a catalog reconfiguration. Reconfiguring is itself
the first recipe below, and the mechanics are covered in
[Configuration](configuration.md).

---

## Core

### Gating access to pages

You can lock a whole directory of pages behind a per-page rule without any
code, using two dot-files that Interchange looks for in the
[PageDir](../config/PageDir.md) directory that holds the requested page.

Drop an empty file named `.access` into the directory. Its presence turns
gating on for every page in that directory; the *decision* is then made by
one of three mechanisms, checked in this order:

1. If a file named `.access_gate` is also present, it is read and its rules
   decide access (this overrides the other two mechanisms).
2. Otherwise, if [Variable](../config/Variable.md) `MV_USERDB_REMOTE_USER`
   is true, any user logged in through [UserDB](user-database.md) is
   granted access.
3. Otherwise, if `MV_USERDB_ACL_TABLE` names a valid table, UserDB's ACL
   logic decides.

The `.access_gate` file is a list of `PAGE_NAME: CONDITION` lines. The page
suffix (`.html`) is optional. A page name of `*` sets the default, which
has lower precedence than any explicit match; there is no globbing
(`ind*` does not match `index`). The condition is a true/false value, and
it may be produced by ITL that is interpolated per request. The implicit
default is deny, so a page with no matching rule and no `*` rule is closed.

A minimal `.access_gate` — one page open, everything else closed:

    pubview: Yes
    *:       No

A richer one, mixing session tests and scratch:

    members.html: [if session logged_in]Yes[/if]
    preview:      [if session username eq 'editor'][or scratch allow_preview]Yes[/if]
    press:        Yes
    *:            [data session logged_in]

The implementing code is in `lib/Vend/Util.pm` (`readfile`/access checks).
For login-backed access control in general see [User accounts](user-database.md)
and [Security](security.md).

### Displaying and rotating banner ads

The [banner](../tags/banner.md) tag rotates or weights ad content stored in
a database table. It supports two independent ideas:

- **Rotation** — a single field holds several banners separated by a
  delimiter; each visitor is shown them in sequence, one per view, with a
  per-visitor counter.
- **Weighted/categorized display** — banners are chosen at random across a
  category, weighted so higher-weight rows appear more often.

Neither the table nor its seed data ship with strap, so create them. A
tab-delimited `banner.txt` seed:

    code    category    weight  rotate  banner
    hammer1 tools       7       0       <a href="/hammers"><img src="/i/h1.png"></a>
    hammer2 tools       7       0       <a href="/hammers"><img src="/i/h2.png"></a>
    saw1    tools       3       0       <a href="/saws"><img src="/i/s1.png"></a>

Field meanings: `code` is the unique key (and the value `category=` matches
in non-weighted display); `category` groups weighted ads (empty means
`default`); `weight` is an integer ≥ 1 for a row to be eligible when
weighting; `rotate` controls sequential rotation when *not* weighting
(empty = never show, `0` = show the whole field, non-zero = split the field
on the delimiter and rotate); `banner` holds the markup.

Register the table (see [Database](../config/Database.md)) and reconfigure:

    Database   banner   banner.txt   TAB
    Database   banner   NUMERIC      weight

Then in a page:

    [banner weighted=1 category=tools]   weighted pick within a category
    [banner weighted=1]                  weighted pick across all categories
    [banner category=tools]              categorized/rotated (rotate field)

With the sample data the total weight is 17, so a `weight=7` banner shows
about 41% of the time. Multilevel categories fall back on the colon:
`[banner category=tools:hand:saws]` tries `tools:hand:saws`, then
`tools:hand`, then `tools`. Weighted builds are cached under
`tmp/Banners/`. Source: `code/SystemTag/banner.coretag`.

### Dumping the full catalog configuration

To inspect the compiled configuration ($Vend::Cfg) of a running catalog,
interpolate this on a protected page with the [uneval](../admin-tags/uneval.md)
tag — `$Config` is the Safe-compartment alias for the catalog config:

    [uneval ref=`$Config`]

That produces a Perl `Data::Dumper`-style dump of every directive as
compiled. It is large; put it behind [gating](#gating-access-to-pages) or
`[if session logged_in]`, never on a public page.

For a dump written at startup instead of on demand, set the global
[DumpStructure](../config/DumpStructure.md) directive; Interchange then
writes each catalog's structure to a file under
[RunDir](../config/RunDir.md) when it compiles. The related
[DumpAllCfg](../config/DumpAllCfg.md) writes the raw config lines it read
(includes expanded) — see [Configuration](configuration.md) and
[Logging and debugging](logging-debugging.md).

### Overriding admin UI pages per catalog

The admin interface ("UI") serves its pages from the shared library
directory (`dist/lib/UI/pages/admin/` in the distribution,
`lib/UI/pages/admin/` once installed). To customize one, copy just that
page into your catalog's own `pages/admin/` directory and edit the copy.
Interchange serves the catalog copy when present and falls back to the
library version for every page you did not override, so you never fork the
whole UI. See [Admin interface](admin-ui.md).

---

## Databases

Table declaration, imports, the flat-file/SQL split, and `[query]` are the
subject of [Databases](databases.md); these are point recipes.

### Counting rows in a table

With a SQL table, ask the database:

    Rows: [query sql="select count(*) as n from products" type=list]
    [sql-param n]
    [/query]

or, more directly with [perl](../tags/perl.md):

    [perl tables=products]
      return $Db{products}->query("select count(*) from products")->[0][0];
    [/perl]

For a solution that works over *any* backend (DBM included), a small
[UserTag](../config/UserTag.md) that walks the table:

    UserTag  db-count  Order      table
    UserTag  db-count  PosNumber  1
    UserTag  db-count  Routine <<EOF
    sub {
        my ($table) = @_;
        $table ||= 'products';
        my $ref = Vend::Data::database_exists_ref($table)
            or return "Bad table $table";
        $ref = $ref->ref();
        my $count = 0;
        while ($ref->each_record()) { $count++ }
        return $count;
    }
    EOF

Used as `[db-count inventory]`. The walk is O(rows); on SQL prefer the
`count(*)` query. (Adapted from a long-standing MiniVend-era tip.)

### Re-importing after editing a text source file

How a source file edit reaches the live table depends on the backend
([Databases](databases.md)):

- **DBM tables** re-import automatically: the next request after the
  `.txt` file's mtime changes rebuilds the DBM copy. Suppress this with
  [NoImport](../config/NoImport.md).
- **SQL tables** import the seed file only when the table is first created.
  To force a fresh import, delete the table's `.sql` marker file from the
  catalog's [ProductDir](../config/ProductDir.md) and reconfigure; the
  table is re-seeded from the text file.

Because SQL edits made through the admin UI are *not* written back to the
text file, re-importing overwrites SQL-only data with the file's contents.
If you maintain data in both places, [export](../tags/export.md) the table
to text before editing and re-importing, so the file is current first.

### MySQL: statements that fail after an idle period

If SQL statements start failing on a catalog that has been idle — typically
"MySQL server has gone away" — the server's `wait_timeout` is closing the
persistent connection. Raise it in `my.cnf`:

```
[mysqld]
wait_timeout = 3000
```

Then restart MySQL. (Interchange also reconnects on its own in most
builds, but a longer timeout avoids the first-request failure.)

---

## Email

Sending mail from Interchange — the [email](../tags/email.md) and
[email-raw](../tags/email-raw.md) tags, order receipts, and the
[SendMailProgram](../config/SendMailProgram.md)/SMTP options — is covered in
[Email](email.md).

### Validating an email address more strictly

Interchange ships two order checks, [email](../order-checks/email_only.md) and
[email_only](../order-checks/email_only.md), that apply a pragmatic regex.
To run either against an arbitrary value outside a form, use
[run-profile](../admin-tags/run_profile.md), or test inline:

    [if type=explicit compare=`
        $Values->{email} =~ /^[^\s\@]+\@[^\s\@]+\.[^\s\@]+$/
    `]
      Looks like an address.
    [else]
      That does not look like an email address.
    [/else]
    [/if]

If you need RFC-grade validation, do not hand-roll it: install the
`Email::Valid` CPAN module and call it from a global
[GlobalSub](../config/GlobalSub.md) or usertag:

    [perl]
      use Email::Valid;
      return Email::Valid->address($Values->{email}) ? 1 : 0;
    [/perl]

(The historic howto embedded Jeffrey Friedl's ~150-line
"Mastering Regular Expressions" address grammar. That regex is dropped
here in favor of `Email::Valid`, which encodes the same rules and is
maintained; see the "Not ported" list.)

### Non-blocking mail delivery

By default [SendMailProgram](../config/SendMailProgram.md) runs your MTA in
the foreground, so order processing waits for the mail to be handed off. To
return control immediately, point `SendMailProgram` at a wrapper that
spools the message and forks the MTA:

```perl
#!/usr/bin/perl
# /usr/local/bin/sendmail-bg
use File::Temp;
my $basedir  = '/tmp/sendmail';
my $sendmail = '/usr/sbin/sendmail -t';
umask 2;
mkdir $basedir unless -d $basedir;
my $tmp    = File::Temp->new(DIR => $basedir);
my $tmpnam = $tmp->filename;
open OUT, "> $tmpnam" or die "Cannot create $tmpnam: $!\n";
print OUT $_ while <>;
close OUT;
system("$sendmail < $tmpnam &");
die "Failed to fork sendmail: $!\n" if $?;
```

```
SendMailProgram /usr/local/bin/sendmail-bg
```

The cleaner modern alternative is to hand mail to a local queue you already
run: set [SMTPHost](../variables/MV_SMTPHOST.md) so Interchange talks SMTP to a
listener (Postfix/Exim on `localhost`) that queues and delivers
asynchronously. See [Email](email.md).

---

## Forms

Form processing, profiles, `mv_metadata`-driven widgets, and the
[error](../tags/error.md) machinery are covered in [Forms](forms.md).

### Sizing a textarea widget

In [mv_metadata](../config/UserDB.md), the generic `width` and `height`
fields do not size an HTML `<textarea>`. Encode the rows and columns in the
widget name instead — `textarea_ROWS_COLS`:

    fieldname:
      widget: textarea_5_50
      height:
      width:

`textarea_5_50` renders a 5-row by 50-column box. The widget name is parsed
by `lib/Vend/Form.pm` (the `^textarea(?:_(\d+)_(\d+))?` pattern), so any
dimensions work: `textarea_10_80`, `textarea_3_40`. See the
[widget reference](../widgets/README.md).

### Detecting and displaying form errors

After a form submission runs its [profile](../config/Profiles.md), any
failed checks are recorded as errors in the session. Test for them with the
`errors` conditional and render them with [error](../tags/error.md):

    [if errors]
      <div class="form-errors">
        [error all=1 show_error=1 joiner="<br>"]
      </div>
    [/if]

`[if errors]` is true when any error is set (`lib/Vend/Interpolate.pm`);
`[error all=1 ...]` collects them all, `show_error=1` includes each error's
message, and `joiner=` separates them. Source:
`code/SystemTag/error.coretag`.

---

## Ordering

The cart, `[item-list]`, order profiles, and checkout flow are in
[Cart and checkout](cart-and-checkout.md).

### Editable quantity on the basket page

A bare `[item-quantity]` shows the ordered quantity as text; to let the
shopper edit it, emit a form field named with
[quantity-name](../tags/item-list.md) inside the cart form, and give them a
recalculate button. The whole cart display must be inside a
`[process]` form:

    <form method="post" action="[process]">
      [item-list]
        [item-field description]
        <input type="text" size="2"
               name="[quantity-name]" value="[item-quantity]">
        <br>
      [/item-list]
      [button text="Recalculate"]
        mv_todo=refresh
      [/button]
    </form>

`[quantity-name]` expands to `quantity0`, `quantity1`, ... for each cart
line automatically. Submitting with `mv_todo=refresh` re-reads the
quantities; setting a line to `0` removes that item. The strap basket
(`pages/ord/basket.html`) already does this — use it as the worked example.

### Capping ordered quantity to available stock

To stop shoppers ordering more than you have on hand, the supported control
is [MaxQuantityField](../config/MaxQuantityField.md), which names an
inventory column the cart enforces automatically (strap sets
`MaxQuantityField inventory:quantity`).

For custom handling — say, silently clamping instead of refusing and
telling the shopper — run this at the top of the basket and checkout pages:

    [perl tables=inventory]
      my $cart = $Carts->{main};
      for my $item (@$cart) {
        my $on_hand = tag_data('inventory', 'quantity', $item->{code});
        next if $on_hand >= $item->{quantity};
        $item->{quantity}  = $on_hand;
        $item->{q_message} = "Quantity adjusted to fit available stock.";
      }
      return;
    [/perl]

Then show the note per line with `[item-modifier q_message]` in the
item-list body. Source: `lib/Vend/Cart.pm`.

---

## Search

The search engine, the `sf`/`se`/`op` search parameters, and
`[loop search=...]` are documented in [Search](search.md).

### Never embed a raw search in href=

Do not build a search into an HTML `href=`, where you have to worry about
escaping and it breaks easily:

    <!-- fragile: don't do this -->
    [area href="scan/lf=category/ls=%Hot Dogs"]

Pass the specification through `search=` or `arg=` instead, one parameter
per line — Interchange encodes it safely:

    [area search="
        lf=category
        ls=%Hot Dogs
    "]

    [area href=scan arg="
        lf=category
        ls=%Hot Dogs
    "]

### Custom search operators for mv_column_op

Beyond the built-in comparison operators (`eq`, `rm`, `<=`, ...), you can
define your own and name it in `mv_column_op`. Register a `SearchOp` with
[CodeDef](../config/CodeDef.md) (see that page for a complete SearchOp
example), then reference it by name in an ad-hoc search:

    [loop search="
        se=rubber hammer
        sf=description
        fi=products
        st=db
        co=yes
        rf=*
        op=find_hammer
    "]
      [loop-code] [loop-param description]<br>
    [/loop]

`op=find_hammer` invokes your SearchOp. Source: `lib/Vend/Config.pm`
(`SearchOp` code type), applied in `lib/Vend/DbSearch.pm`.

### AND / OR and advanced query syntax

Install the `Text::Query` CPAN module to get boolean and proximity search
operators, then set `op=aq` (advanced parsing) or `op=tq` (simple
parsing):

    [loop search="
        se=hammer -framing
        sf=description
        fi=products
        st=db co=yes rf=*
        op=tq
    "]
      [loop-code] [loop-param description]<br>
    [/loop]

    [loop search="
        se=hammer NEAR framing
        sf=description
        fi=products
        st=db co=yes rf=*
        op=aq
    "]
      [loop-code] [loop-param description]<br>
    [/loop]

`Text::Query` honors the usual search variables: `mv_case` (`-case`),
`mv_all_chars` (`-regexp`), `mv_substring_match` (`-whole`) and
`mv_exact_match` (`-litspace`). To degrade gracefully when the module is
absent, choose the operator conditionally:

    <input type="hidden" name="mv_column_op"
      value="[if module-version Text::Query]aq[else]rm[/else][/if]">

Source: `lib/Vend/Search.pm` (`op eq 'aq'` / `'tq'`). See
`Text::Query::ParseAdvanced(3pm)` and `Text::Query::ParseSimple(3pm)` for
the query languages.

---

## Sessions

What a session holds, the storage backends, and expiry are covered in
[Sessions](sessions.md).

### Reading and writing a session from Perl

To hand a session to an external Perl program, serialize it to a named file
with the `uneval` tag and the `writefile` method
(`Vend::Util::writefile`, exposed on `$Tag`):

    [perl]
      my $string = $Tag->uneval({ ref => $Session });
      $Tag->writefile("tmp/$Session->{id}.save", $string);
      return;
    [/perl]

To read it back in your own global usertag (globals are not
Safe-restricted, so `reval` works there):

```perl
my $safe        = Safe->new;
my $string      = $Tag->file("tmp/$id_to_retrieve.save");
my $session_ref = $safe->reval($string);
```

For read-only inspection there is a ready-made session reader in
`eg/Interchange/Session.pm`, plus `eg/ic-session-print`.

### Storing sessions in SQL

For a multi-server or load-balanced deployment, keep sessions in a database
rather than files by setting [SessionType](../config/SessionType.md) `DBI`
and pointing [SessionDB](../config/SessionDB.md) at a table:

    SessionType DBI

    Database  session  session.txt  dbi:mysql:mydb:localhost
    Database  session  USER         username
    Database  session  PASS         password
    Database  session  KEY          code
    Database  session  COLUMN_DEF   "code=varchar(64) NOT NULL PRIMARY KEY"
    Database  session  COLUMN_DEF   "session=blob"
    Database  session  COLUMN_DEF   "sessionlock=varchar(64) DEFAULT ''"
    Database  session  COLUMN_DEF   "last_accessed=timestamp"

strap ships ready-made session table definitions
(`dist/strap/dbconf/*/sessions.*`) you can enable instead of writing the
schema by hand, and supports `Redis` as well. `eg/migrate-sessions-to-dbi`
moves an existing file store into SQL. See [Sessions](sessions.md) and
[Performance](performance.md).

---

## Users

User accounts, the `userdb` table, login, and ACLs are covered in
[User accounts](user-database.md).

### Searching the userdb

Searching the user database is blocked by default via
[NoSearch](../config/NoSearch.md) (which lists `userdb`), so customer data
is not exposed through ordinary search URLs. To run a deliberate,
server-side lookup, clear the restriction for the duration of the request
and search directly:

    [calcn]
      $Config->{NoSearch} =~ s/\buserdb\b//;
      return;
    [/calcn]

    [loop search="
        st=db
        fi=userdb
        ml=1
        sf=email
        se=[value email]
        rf=username,password
    "]
      [seti found_username][loop-field username][/seti]
    [/loop]

Because `$Config` changes are per-request only ([Configuration](configuration.md)),
`NoSearch` is restored automatically on the next request. Keep such lookups
on protected pages.

---

## Taxes

Sales tax and VAT — [SalesTax](../config/SalesTax.md), the `salestax`
table, `TaxShipping`, and the modern averages/gateway options — are covered
in [Taxes](taxes.md). Two classic recipes:

### Country- or category-based VAT via a usertag

When a flat rate per zone is not enough, compute tax in a usertag and call
it from the tax table. A tag that sums per-item tax from a rate column:

    UserTag  vat-calc  Order    table field
    UserTag  vat-calc  addAttr
    UserTag  vat-calc  Routine <<EOR
    sub {
        my ($table, $field, $opt) = @_;
        my $tax = 0;
        for my $item (@$Vend::Items) {
            my $rate = tag_data($table, $field, $item->{code});
            $tax += $rate * $item->{quantity};
        }
        return $tax;
    }
    EOR

Set [SalesTax](../config/SalesTax.md) to look up by country and put the tag
call in the `salestax` table rows:

    SalesTax country

    default [vat-calc products tax]
    UK      [vat-calc products tax]
    FR      [vat-calc products tax]
    US      0

For category-dependent rates, make the tag consider
`$item->{category}` and enable the modifier so it is loaded onto each cart
line:

    AutoModifier products:category

If you define `vat-calc` in `catalog.cfg` rather than globally, make sure
the `products` table is open before the tag runs (a bare
`[perl products][/perl]` earlier on the page does it).

### Tax-exempt users

To exempt individual accounts, add a `tax_exempt` field to the `userdb`
table and copy it into scratch at login, then clear
[SalesTax](../config/SalesTax.md) for that request:

    UserDB default scratch tax_exempt

    Autoload <<EOL
    [calc]
      if ($Scratch->{tax_exempt}) {
          $Config->{SalesTax} = ' ';
      }
      return;
    [/calc]
    EOL

Configure `SalesTax` normally as if no one were exempt; the
[Autoload](../config/Autoload.md) routine unsets it per request for the
exempt user. See [Taxes](taxes.md) and [User accounts](user-database.md).

---

## Web servers

Interchange sits behind a web server that runs the CGI link program or
proxies to the daemon; the overall wiring is in
[Installation](installation.md) and [Architecture](architecture.md).

### Apache: per-vhost logs

Give each virtual host its own logs in the vhost block:

```apache
ErrorLog  /var/log/apache/store.example.com.error.log
CustomLog /var/log/apache/store.example.com.log \
  "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\""

<IfModule mod_ssl.c>
  CustomLog /var/log/apache/store.example.com.ssl.log \
    "%t %h %{SSL_PROTOCOL}x %{SSL_CIPHER}x \"%r\" %b"
</IfModule>
```

### Apache: drop /cgi-bin/ from URLs

To serve the catalog at the site root instead of under `/cgi-bin/name/`,
rewrite requests to the link program, letting real files pass through:

```apache
RewriteEngine on

RewriteRule ^/?$              /cgi-bin/shop/  [L,NS,PT]
RewriteRule ^/index\.html$    /cgi-bin/shop/  [L,NS,PT]

# let existing files/dirs in the docroot serve normally
RewriteCond /home/shop/www/html%{REQUEST_URI} -f [OR]
RewriteCond /home/shop/www/html%{REQUEST_URI} -d
RewriteRule ^ - [L,NS]

# everything else goes to the catalog
RewriteCond %{REQUEST_URI} !^/cgi-bin/shop
RewriteRule ^/(.+)$ /cgi-bin/shop/$1 [L,NS,PT]
```

Adjust the docroot path and link-program name to your install. See
[Installation](installation.md) for the `SCRIPT_NAME`/[VendURL](../config/VendURL.md)
side of this.

### Producing XHTML-compliant markup

Interchange's internally generated non-container tags close with `>` by
default. Turn on the [XHTML](../config/XHTML.md) directive to emit `/>`
instead:

    XHTML Yes

In your own tag or usertag code, the package variable `$Vend::Xtrailer`
holds `/` or the empty string according to that directive, so code you
write emits the same style:

```perl
# inside a usertag/GlobalSub
return qq{<br$Vend::Xtrailer>};   # "<br/>" when XHTML is on, else "<br>"
```

Validate the result with the W3C markup and CSS validators.

---

## Operations

### Managing the daemon: test, start, reconfigure, stop

Run these as the Interchange user, not root (use
`sudo -u interch ...` if needed). From the server root:

```sh
bin/interchange --test                 # check config, don't touch running procs
bin/interchange -r                      # (re)start
bin/interchange --reconfig=strap        # recompile one catalog, no restart
bin/interchange --stop                  # stop
bin/interchange --kill                  # stop with prejudice if it won't
```

A catalog can also be reconfigured without shell access: use the
[reconfig](../admin-tags/reconfig.md) tag / the admin UI's "Apply Changes",
or `touch` a file named after the catalog in `etc/reconfig/` under the
server root. Reconfiguration is picked up on the next
[HouseKeeping](../config/HouseKeeping.md) cycle, so allow a few seconds.
Full detail in [Configuration](configuration.md). Packaged installs also
provide the usual service scripts (`/etc/init.d/interchange restart`,
`systemctl restart interchange`).

### Adjusting the time zone

Interchange formats dates in the server process's time zone. Set `TZ` in
the environment before starting the daemon:

```sh
# sh/bash/ksh
TZ=America/Los_Angeles; export TZ
# csh/tcsh
setenv TZ America/Los_Angeles

bin/interchange -r
```

### Monitoring the log files

To watch everything at once during development:

```sh
cd /var/log
tail -f interchange/error.log apache2/*log \
        /path/to/catalogs/*/var/log/*.log
```

Point the logs where you want them with [ErrorFile](../config/ErrorFile.md)
and [DebugFile](../config/DebugFile.md) globally, and per catalog:

    ErrorFile var/log/error.log
    TrackFile var/log/track.log

with `Variable DEBUG 1` to raise verbosity. What each log contains, and
`[log]`/`[debug]`/`Pragma perl_warnings_in_page`, are covered in
[Logging and debugging](logging-debugging.md).

---

## Larger integrations

These are full add-ons rather than snippets; each has its own bundle in the
distribution. Included here as pointers.

### Product forums and blogs

The [forum](../tags/forum.md) tag (`code/UserTag/forum.tag`) renders
threaded comments from a `forum` table and can be dropped onto product
flypages so customers comment on items. It takes a required `top=` (the
thread id) plus templating parameters (`show-level`, `scrub-score`,
`template`, `date-format`, ...) using the `{KEY}` substitution style. A
minimal product forum on the flypage:

    [if variable FORUM_PRODUCTS]
      [forum top="[item-code]" display-page="forum/display"]
    [/if]

The supporting pages (`pages/forum/`), include fragments, table definition,
and metadata are created for you when you build a catalog with the forum
feature enabled. See the tag reference for the full parameter and template
list.

### QuickBooks (IIF) export

`extensions/quickbooks/` integrates order and item data with QuickBooks via
Intuit's IIF import/export format. It supplies usertags
(`export_quicken_items`, `import_quicken_items`, `get_quicken_orders`), an
admin menu, and a `quickbooks` order route; installed, it generates
`orders/qbYYYYMMDD.iif` files you import into QuickBooks. Sales-tax and
shipping line items must exist in your QuickBooks company file (or be named
via `QB_SALES_TAX_ITEM` / `QB_SHIPPING_ITEM`). Follow
`extensions/quickbooks/README` for the current install steps.

### Example overlays: news and surveys

Two ready-to-graft mini-features live in `eg/`:

- `eg/news_feature/` — a news/blog add-on: a `news` table, a `news` page,
  and a `templates/components/news` component to drop into a layout.
- `eg/survey_wizard/` — a survey builder with its own coretag
  (`survey_wizard.coretag`), an upload-helper widget, and admin pages.

Each is a small catalog overlay (pages, `dbconf/`, components) you copy in
and register. The shipped `quickpoll` feature under `dist/features/` is a
cleaner, current template for the same pattern (see
[Admin interface](admin-ui.md)).

---

## Not ported

The following recipes from the historic HOWTO collection, the SDF HOWTOs,
and `eg/` were dropped as obsolete, superseded, or too narrow to carry
forward; each is listed with the reason.

- **Interchange + CVS HOWTO** (`ic_howto_cvs.sdf`, ~1000 lines) — entirely
  about using CVS to version a catalog. CVS is superseded by git; the whole
  document's tooling and workflow no longer apply. Version a catalog the way
  you version any project.
- **Finding inconsistencies in table-definition files** (a Perl script that
  scanned `dbconf/*/` and emitted an HTML diff table) — a fragile one-off
  developer script that shells out to `head`/`grep`/`cut` and hard-codes
  four engines; not a catalog recipe. Per-engine `dbconf` files are now
  generated consistently by `makecat`.
- **Friedl "Mastering Regular Expressions" email grammar** (~150 lines of
  assembled regex) — dropped in favor of the `Email::Valid` recipe above,
  which encodes the same RFC rules and is maintained. The pointer is kept.
- **`Tie::ShadowHash` "modifiable" usertag** — a Perl trick to make a config
  hash temporarily writable. The original text already noted it is
  "generally not needed in Interchange," since per-request `$Config`
  modification (shown in the tax-exempt recipe) already does this. Niche;
  dropped.
- **MiniVend 4.02 error test** (`[if type=explicit compare="[error all=1
  keep=1]"]`) — a compatibility shim for MiniVend 4; the modern
  `[if errors]` form (ported above) replaces it.
- **"Expiring" sessions entry** — the source entry only pointed at a
  glossary definition. Folded into [Sessions](sessions.md); not a standalone
  recipe.
- **Automatic `etc/CATNAME.structure` dump on startup** — the old claim that
  a structure file is written automatically at startup is no longer true;
  it is now gated behind the global [DumpStructure](../config/DumpStructure.md)
  directive, which is the mechanism given in the config-dump recipe above.

## See also

- [Configuration](configuration.md) · [Templating](templating.md) ·
  [Embedded Perl](perl-embedding.md) — the mechanisms these recipes build on
- [Databases](databases.md) · [Search](search.md) · [Forms](forms.md) ·
  [Sessions](sessions.md) · [User accounts](user-database.md) ·
  [Taxes](taxes.md) · [Email](email.md) — the full chapters behind the
  point recipes here
- [Logging and debugging](logging-debugging.md) ·
  [Performance](performance.md) — operations
- Reference: [tags](../tags/README.md), [directives](../config/README.md),
  [widgets](../widgets/README.md), [order checks](../order-checks/README.md)
