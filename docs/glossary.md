# Glossary

Short definitions of the terms and concepts used throughout the Interchange
documentation. Interchange-specific entries link to the reference page or
guide that covers the topic in depth; cross-references to other glossary
entries link within this page. Terms are alphabetized ignoring case.

## ActionMap

A catalog configuration mechanism that maps the leading part of a request
URL to Perl code or Interchange Tag Language (ITL) code, creating "virtual
pages" that run an action instead of displaying a static page. Interchange
ships predefined actions such as `process` (form processing), `order`,
`scan`, and `search`; you add your own with the
[`ActionMap`](config/ActionMap.md) directive. See also
[dispatch](#dispatch) for where action resolution happens in the request
cycle.

## affiliate

A partner who sends traffic to your catalog through a link carrying an
identifying code, so visits and orders can be credited back to them. Pass
the code in the `mv_source` CGI variable; it is then readable as
`[data session source]`. The [`BounceReferrals`](config/BounceReferrals.md)
directive can strip the code from the visible URL after the visitor arrives.

## array

A list of elements. In Perl a "list" is an unnamed sequence of values while
an "array" is a named variable holding one; Interchange documentation uses
the terms loosely as synonyms. Note that several configuration directives
Interchange labels `boolean` are actually arrays of values (see
[boolean](#boolean)).

## attribute

A per-item option or modifier attached to an ordered product, such as a
t-shirt's size or color. Attributes let one product SKU carry varying
choices without a separate SKU for each combination; they are enabled with
[`UseModifier`](config/UseModifier.md) (or the `mv_UseModifier` scratch
variable) and displayed in item lists with
`[item-modifier attribute]` and
[`[accessories]`](tags/accessories.md). Avoid attribute names beginning
with `mv_` or the reserved words `code`, `quantity`, and `group`. Also
called a *modifier*, *option*, or *param*.

## AVS

Address Verification System. A check used during credit-card authorization
that compares the billing address the customer supplies against the address
on file with the card issuer, to gauge whether the cardholder is legitimate.

## boolean

In general programming, a value that is either [true](#true) or
[false](#false). In Interchange configuration parlance, however, a directive
of type `boolean` actually holds an [array](#array) of values you test for
presence or absence; genuine two-state directives are typed `yesno`. This
naming quirk is confined to the directive-type vocabulary.

## captcha

A challenge-response test (typically a distorted image of characters) used
to distinguish a human visitor from an automated script, most often on
forms. Interchange provides the [`[captcha]`](tags/captcha.md) tag to
generate and verify one.

## cart

A shopping cart: an ordered list of the items a session has selected for
purchase. Internally each cart is a Perl array of hash references, one hash
per line item, whose keys include `code` (the SKU), `quantity`, `mv_ip`
(line number), and any product [attributes](#attribute). A session may hold
several named carts; the default is `main`.

## catalog

The basic functional unit of an Interchange server: one catalog is to
Interchange what one web site is to a web server. Each catalog is registered
in the global `interchange.cfg` with the [`Catalog`](config/Catalog.md)
directive and configured by a `catalog.cfg` file in its own root directory.
See the [catalog anatomy guide](guides/catalog-anatomy.md).

## CATROOT

The catalog root directory: the top-level directory of a single
[catalog](#catalog), holding its `catalog.cfg`, `pages/`, `products/`, and
other per-catalog files. Its location is set as a parameter of the
[`Catalog`](config/Catalog.md) directive. Contrast with [ICROOT](#icroot).

## CGI variable

A value submitted by the browser in an HTTP request, usually as
`key=value` form fields sent by the GET or POST method. Interchange reads
CGI values with the [`[cgi]`](tags/cgi.md) tag (or `$CGI` in Perl), but
only on the page immediately following submission; wanted values are then
copied into the persistent [value](#value) space unless listed in
[`FormIgnore`](config/FormIgnore.md). CGI input is untrusted user data and
must be filtered (for example with
[`encode_entities`](filters/encode_entities.md)) before it is displayed or
stored.

## checkout

The order-completion process in which the customer fills in billing and
shipping information and Interchange validates it against one or more
[profiles](#profile) before submitting the order. Profiles live in
`etc/profile.*` files (activated with
[`OrderProfile`](config/OrderProfile.md)) or in
[scratch](#scratch) variables, and only input that passes the profile check
may proceed. A successful checkout typically emails an order report and, if
enabled, assigns an order number from the
[`OrderCounter`](config/OrderCounter.md).

## configuration

Interchange splits its settings into a global part in `interchange.cfg`
(affecting every catalog on the server) and a per-catalog part in each
catalog's `catalog.cfg`. Directives are written with the directive name
first on a line followed by its value; the syntax also supports `<file`
includes, here-documents, `ifdef`/`ifndef` blocks, and
`__VARIABLE__` expansion. See the [configuration guide](guides/configuration.md).

## cookie

A short key/value pair the HTTP protocol lets a server store in and read
back from the browser, used to carry the [session](#session) ID across
otherwise stateless requests. Whether Interchange sets session cookies is
controlled by [`Cookies`](config/Cookies.md) and their lifetime by
[`SaveExpire`](config/SaveExpire.md). Interchange does not require cookies:
if the browser rejects them it falls back to embedding the session ID in
generated URLs.

## coretag

A tag that ships with Interchange as part of the core distribution, defined
in the `code/SystemTag/` directory (files with the `.coretag` extension) or
historically in `lib/Vend/Interpolate.pm`. Coretags such as
[`[loop]`](tags/loop.md) and [`[cgi]`](tags/cgi.md) use the same
[`UserTag`](config/UserTag.md) definition format and
[MapRoutine](#maproutine) mechanism as add-on [usertags](#usertag); the
distinction is only one of packaging and support, not function. Also called
a *system tag*.

## CyberCash

A payment gateway that Interchange supported historically. The CyberCash
payment module was removed in the Interchange 5.7 series and is no longer
available; use one of the current [payment gateways](#payment-gateway)
instead.

## database

A source of tabular data — rows of records, columns of fields — that
Interchange reads through a uniform interface regardless of the underlying
store. In Interchange usage "database" and "database table" mean the same
thing: a single table. Each table is registered per catalog with the
[`Database`](config/Database.md) directive giving a name, a text source
file, and a type; supported types include DBM stores (GDBM, Berkeley DB,
[SDBM](#sdbm)), in-memory, and [SQL](#sql). See the
[databases guide](guides/databases.md).

## dereference

Following a reference (a pointer to a data structure) to reach the actual
data it points to, as opposed to copying the reference itself. The
distinction matters in Perl and in Interchange list handling: copying a
reference gives two names for one shared structure, while dereferencing
lets you read or duplicate the underlying values.

## discount

A per-session price reduction that applies only to the customer who receives
it, so you can grant discounts by club membership or any other rule.
Discounts are defined with the [`[discount]`](tags/discount.md) tag and can
adjust item prices, quantities, or the order subtotal. See also
[levy](#levy) for the newer, more general charge mechanism.

## dispatch

The sequence Interchange follows to process a request once it has been
assigned to a [catalog](#catalog): running [`Preload`](config/Preload.md)
macros, checking authorization, handling the session, cookie, and
[robot](#robot) status, resolving any [ActionMap](#actionmap) action, and
finally interpolating and returning the page.

## DOCROOT

The web server's document root — the directory tree from which the HTTP
server serves static files such as images and generated static pages. It is
distinct from Interchange's own [ICROOT](#icroot) and [CATROOT](#catroot),
which hold the application rather than the served files.

## DSN

Data Source Name: the connection string that identifies a database and its
connection parameters, in the DBI form
`dbi:DriverName:database=name;host=...`. You supply it as the third field
of an [SQL](#sql) [`Database`](config/Database.md) directive.

## epoch

The Unix epoch: 00:00:00 UTC on 1 January 1970, the zero point from which
system time is counted in seconds. Interchange time filters and tags convert
between epoch seconds and formatted dates.

## expire

The periodic cleanup of ended or timed-out user [sessions](#session) so the
session store does not grow without bound. Run the `expire` script against a
catalog (`expire -c CATALOG`), or `expireall` for every catalog in
`interchange.cfg`; the [`SessionExpire`](config/SessionExpire.md) directive
sets how long a session may sit idle before it is eligible.

## External

A family of directives —
[`External`](config/External.md), `ExternalFile`, and `ExternalExport` —
that export Interchange variables so other languages such as PHP, Ruby, or
Python can read them. The facility is a proof of concept; its interface is
not considered production-ready.

## false

A value that evaluates as untrue: `0`, the empty string `""`, or (in Perl)
`undef`. Everything else is [true](#true) — including a string of only
whitespace.

## feature

A packaged unit of add-on functionality that can be installed into a catalog
or the global configuration, introduced in Interchange 5.3.0 to make
extensions easy to drop in. A feature module supplies `.global`, `.init`,
and `.uninstall` files; see the [`Feature`](config/Feature.md) and
[`Capability`](config/Capability.md) directives.

## filter

A small routine that transforms a string — trimming it, making it
display- or storage-safe, changing case, formatting numbers, and so on.
Filters are applied inline with the [`[filter]`](tags/filter.md) tag, as the
`filter=` attribute of many tags, or as input filters on form fields;
Interchange ships dozens (see the `filters/` reference directory) and you
add your own with the [`Filter`](config/Filter.md) directive.

## flypage

A special catalog page that displays a single product "on the fly" from its
SKU, without a hand-built page for each item. `flypage` is one of
Interchange's default [special pages](#special-page) (see
[`SpecialPage`](config/SpecialPage.md)); requesting a product code that has
no page of its own falls through to it, and the strap demo ships a
`flypage.html` template.

## form action

A Perl subroutine executed when a form is submitted, selected by the
`mv_action` (or `mv_todo`) form variable. A form action returns [true](#true)
to have Interchange display the page named in `mv_nextpage`, or
[false](#false) to display nothing; define or override actions with the
[`FormAction`](config/FormAction.md) directive. Sometimes called a
*form processor*.

## gate

Controlling access to pages so that only permitted visitors may view them
("gating"). A `.access` file in a [`PageDir`](config/PageDir.md)
subdirectory, or the [`gate`](filters/gate.md) filter, governs whether a
page is served. Prior to Interchange 5.7.0 a `.access` file placed directly
in the top-level `pages/` directory was ignored.

## hash

A collection of values indexed by string keys (an associative array). Perl
hashes underlie many Interchange structures — the [Values](#value) space,
the [scratch](#scratch) space, and each line item of a [cart](#cart) are all
hashes.

## ICROOT

The Interchange software root: the directory where the Interchange server
itself is installed (its `interchange.cfg`, `bin/`, and `lib/` live here).
Files included from the global config are resolved relative to it. Contrast
with [CATROOT](#catroot), the root of an individual catalog.

## internationalization

Abbreviated *I18N*: the features that let a catalog serve localized
messages, currencies, prices, and other region-specific formats. Interchange
implements its own I18N system driven by the [`Locale`](config/Locale.md)
directive, layered over Perl's POSIX `setlocale`, and lets a visitor switch
[locale](#locale) at any time. See also [locale](#locale).

## interpolate

To process a string of Interchange Tag Language (ITL), replacing each tag
with the output it produces. Some contexts pass their body through
uninterpolated (for example [`[set]`](tags/set.md)) while others interpolate
it (for example [`[seti]`](tags/seti.md)); the `interpolate` attribute on
many tags forces interpolation of a body that would otherwise be left as
literal text.

## ITL

The Interchange Tag Language: the bracketed markup (`[tag] ... [/tag]`)
embedded in catalog pages to produce dynamic content and reach Interchange
functions. ITL is a superset of the older MiniVend Markup Language (MML);
there are 200-plus built-in tags ([coretags](#coretag)) and you can add your
own [usertags](#usertag). See the [templating guide](guides/templating.md).

## jobs

Batch tasks run outside the normal page-request cycle, triggered from the
command line (`interchange --runjobs=CATALOG=GROUP`) or a cron job. Jobs run
asynchronously — the launching command returns before the job finishes.
See the [`Jobs`](config/Jobs.md) directive.

## levy

A general mechanism for defining additional order charges — taxes,
handling, fees, shipping — in one place. When you use
[`Levies`](config/Levies.md), the ordinary salestax, shipping, and handling
tags are bypassed in favor of levy definitions (see also
[`Levy`](config/Levy.md)). Contrast with the older, separate
[shipping](#shipping) and [tax](#tax) calculations.

## link program

The small CGI helper that bridges the web server and the always-running
Interchange daemon. Interchange listens on a UNIX and/or INET socket; the
link program (for example `vlink` or `tlink`) is invoked by the web server
for catalog requests and relays them to that socket and the response back.
See the [architecture guide](guides/architecture.md).

## locale

A named set of regional definitions — message translations, currency and
number formats, sort order — that a catalog can select at runtime.
Localization (*L10N*) is the act of applying a specific locale to an
I18N-enabled catalog; Interchange locales are configured with
[`Locale`](config/Locale.md). See also
[internationalization](#internationalization).

## macro

Reusable executable code attached to a catalog: a global subroutine
([`GlobalSub`](config/GlobalSub.md)), a catalog subroutine
([`Sub`](config/Sub.md)), or a block of Interchange Tag Language (ITL).
Macros can be run at defined points such as [`Preload`](config/Preload.md).

## MapRoutine

The mechanism that binds a tag definition to the Perl subroutine that
implements it. In a [`UserTag`](config/UserTag.md) or [coretag](#coretag)
definition, `MapRoutine Vend::Interpolate::tag_loop_list` (for example)
points the tag at an existing named subroutine rather than an inline
`Routine` body — useful when several tags share one implementation or the
code lives in a module.

## MiniVend

The e-commerce server that Interchange grew out of. MiniVend's page markup,
MML (MiniVend Markup Language), is the ancestor of Interchange's
[ITL](#itl), and much Interchange terminology and internal naming (the
`mv_` prefix, the `Vend::` module namespace) descends from it.

## modifier

See [attribute](#attribute).

## mv_ variables

The reserved namespace of special CGI and form variables that control
Interchange processing — `mv_action`, `mv_todo`, `mv_nextpage`,
`mv_searchspec`, `mv_order_item`, and many more. Because Interchange gives
these names specific meaning, do not use `mv_` as a prefix for your own
[attribute](#attribute) or form-field names.

## namespace

A group within which names must be unique, so identical names can coexist in
different groups without collision. Interchange uses several — for example
the Perl package namespace (`Vend::`, `Global::`) and the reserved
[`mv_`](#mv-variables) form-variable namespace.

## order

The record of what a customer is buying, built up in the [cart](#cart) and
finalized at [checkout](#checkout). Interchange's ordering scheme is fully
configurable through the order pages, [profiles](#profile), and — for
splitting an order across fulfillment destinations — order
[routes](#route).

## order check

A validation rule applied to a form field during [checkout](#checkout) or
other form processing, named in a [profile](#profile). Interchange ships
order checks such as [`required`](order-checks/required.md),
[`email`](order-checks/email_only.md), and [`isbn`](order-checks/isbn.md)
(see the `order-checks/` reference directory), and you can add your own.

## payment gateway

A third-party service that authorizes and captures credit-card and other
electronic payments. Interchange integrates with many through
`Vend::Payment::*` modules (see the `payments/` reference directory, for
example [`AuthorizeNet`](payments/AuthorizeNet.md)); a module is enabled
globally with [`Require`](config/Require.md) and configured with
`MV_PAYMENT_*` variables. See also [CyberCash](#cybercash), a gateway that
was removed.

## pragma

A setting that controls how a page or block is parsed and displayed,
processed before normal page interpolation begins. Pragmas can be set at
catalog scope with the [`Pragma`](config/Pragma.md) directive or per page or
block with the `[pragma ...]` tag; a catalog-wide pragma behaves as though
`[pragma]` were placed on every page but is initialized once at startup.
Every pragma is documented in the [pragma reference](pragmas/README.md).

## price

The base price of an item, kept in the `price` field of the `products`
database (the three required fields being `code`, `price`, and
`description`). The field names are configurable with
[`PriceField`](config/PriceField.md) and
[`DescriptionField`](config/DescriptionField.md), and complex pricing is
built with [`CommonAdjust`](config/CommonAdjust.md).

## profile

A named set of validation rules or presets. Interchange uses several kinds:
*form profiles* (validate submitted form input during [checkout](#checkout),
activated with [`OrderProfile`](config/OrderProfile.md)), *search profiles*,
*user profiles* ([`Profile`](config/Profile.md)), and *UserDB profiles*
([`UserDB`](config/UserDB.md)). A form profile lists fields and the
[order checks](#order-check) each must pass.

## reconfigure

Reloading a single catalog's configuration and non-instant files (such as
`catalog.cfg` and `etc/profile.*`) without restarting the whole server;
changes to pages and databases take effect on the next request, but
config-level files do not. Changes to the global `interchange.cfg` still
require a full server restart.

## regular expression

A pattern that describes a set of strings, used for matching and
substitution. Interchange relies on Perl regular expressions throughout —
in [order checks](#order-check), configuration conditionals, and filters
such as [`filter_select`](filters/filter_select.md).

## robot

An automated client such as a search-engine crawler. Interchange classifies
a request as a robot by matching its User-Agent against the
[`RobotUA`](config/RobotUA.md) list (and related `Robot*` directives) and
then alters its behavior — for example suppressing session IDs in URLs — so
the crawler indexes clean, cacheable content.

## rotated banner

Sequential display of one banner at a time from a set stored in the banner
database's `banner` field, with an independent position pointer kept per
client so each visitor cycles through them in turn. Enable it by putting a
positive integer in the `rotate` field; display with the
[`[banner]`](tags/banner.md) tag.

## route

An order route: a named destination and handling recipe for a submitted
order, letting one order be delivered to several places (for example
different suppliers or fulfillment houses) or logged and mailed in different
ways. Routes are defined with the [`Route`](config/Route.md) directive
(optionally sourced from a [`RouteDatabase`](config/RouteDatabase.md)), and
an item can be steered to a specific route via `mv_order_route`.

## Safe

Interchange evaluates embedded Perl inside a `Safe` compartment — a
restricted Perl namespace that blocks dangerous operations (file access,
system calls, and so on) unless you explicitly permit them. Operators are
opened or closed with [`SafeUntrap`](config/SafeUntrap.md) and
[`SafeTrap`](config/SafeTrap.md); see the
[Perl embedding guide](guides/perl-embedding.md).

## salt

A short random string mixed into a password before hashing so that identical
passwords produce different hashes, defeating precomputed-dictionary
attacks. Traditional Unix `crypt` uses a two-character salt; Interchange's
[UserDB](#userdb) supports salted MD5, SHA1, and bcrypt password hashing.

## scalar

A single value — a number or a string — as opposed to a [list](#array) or
[hash](#hash). In Interchange configuration, a directive of type SCALAR
holds one such value.

## scratch

The scratch space (or *scratchpad*): a per-[session](#session) area of
named variables the catalog programmer controls freely, initialized empty
(or from [`ScratchDefault`](config/ScratchDefault.md)) and lasting until the
variable is deleted or the session ends. Set values with
[`[set]`](tags/set.md)/[`[seti]`](tags/seti.md) and read them with
[`[scratch]`](tags/scratch.md); "temp" scratch variables set with
[`[tmp]`](tags/tmp.md)/[`[tmpn]`](tags/tmpn.md) are discarded automatically
when page processing ends. In Perl the space is `$Scratch`.

## SDBM

An in-file, non-[SQL](#sql) database format (similar to GDBM) usable as a
`Database` type. Interchange can layer SQL-style access over any of its DBM
backends, so a catalog needs no external database engine to function; when
no SQL source is configured, text source files are still imported into a
file-based DBM store automatically.

## session

The per-visitor state Interchange keeps across requests, identified by a
session ID carried in a [cookie](#cookie) or URL. A session holds the
[cart](#cart) contents, [CGI](#cgi-variable) and [value](#value) variables,
the [scratch](#scratch) space, pending errors and warnings, and more.
Sessions are stored per catalog (files or a DBM/SQL table) and periodically
[expired](#expire); see the [sessions guide](guides/sessions.md).

## shipping

The calculation of delivery charges for an order, configured through the
[`Shipping`](config/Shipping.md) and `CustomShipping` directives and the
`shipping` database, and displayed with the
[`[shipping]`](tags/shipping.md) family of tags. Where
[`Levies`](config/Levies.md) are in use, shipping is computed as a levy
instead. See also [levy](#levy).

## SKU

Stock Keeping Unit: the unique code identifying a product, stored in the
`code` field of the `products` database and used as the key throughout the
[cart](#cart) and order.

## SOAP

A remote-procedure protocol Interchange can expose so external programs
invoke catalog actions as web services. Enable the SOAP server globally with
[`SOAP`](config/SOAP.md) and authorize actions with
[`SOAP_Control`](config/SOAP_Control.md).

## special page

A page Interchange looks up by role rather than by literal file name, so its
behavior can be redirected without changing links. Roles such as `catalog`,
`order`, `search`, `results`, `missing`, and [flypage](#flypage) are mapped
to actual pages with the [`SpecialPage`](config/SpecialPage.md) directive,
and the pages themselves live under [`SpecialPageDir`](config/SpecialPageDir.md).

## SQL

Structured Query Language, and by extension a relational database engine
(PostgreSQL, MySQL, and so on) reached through Perl DBI. An SQL table is
registered with the [`Database`](config/Database.md) directive giving type
`SQL` and a [DSN](#dsn); SQL is recommended for order and other write-heavy
tables. Interchange remains database-independent, so pages need no changes
when moving a table between SQL and a DBM backend.

## SSL

Secure Sockets Layer (and its successor TLS): the encryption underlying
`https:` URLs. Interchange has features for secure ordering over SSL,
including the [`SecureURL`](config/SecureURL.md) and
[`AlwaysSecure`](config/AlwaysSecure.md) directives that route sensitive
pages through the HTTPS server.

## static page

A page Interchange builds ahead of time into a plain HTML file served
directly by the web server from [DOCROOT](#docroot), rather than
interpolating it on each request. Static building trades dynamic freshness
for speed; the [`[timed-build]`](tags/timed-build.md) tag provides related
partial static caching of page fragments.

## strap

The lightweight demo catalog shipped with current Interchange, found under
`dist/strap/` in the source tree and used as the starting point for a new
catalog and for the runnable examples in this documentation. Its tables
include `products`, `variants`, `inventory`, and `userdb`, and it provides
template pages such as [`flypage`](#flypage) and `ord/basket`.

## tax

The calculation of sales tax on an order. Interchange supports a simple
`salestax.asc` table method, the
[`SalesTax`](config/SalesTax.md)/[`SalesTaxFunction`](config/SalesTaxFunction.md)
directives, and (in newer catalogs) computing tax as a [levy](#levy). Tax is
displayed with the [`[salestax]`](tags/salestax.md) tag.

## true

Any value that is not [false](#false) — that is, anything other than `0`,
the empty string, or `undef`. A string containing only whitespace counts as
true.

## UserDB

The built-in set of features for the user database: the table that stores
customer and administrator accounts plus the functions that log users in,
save and restore their session data, and manage passwords. It is configured
with the [`UserDB`](config/UserDB.md) directive and works best with the
conventional `userdb` table layout. See the
[user-database concepts](guides/sessions.md) and password
[hashing](#salt) support.

## usertag

A custom Interchange Tag Language tag you define yourself with the
[`UserTag`](config/UserTag.md) directive, indistinguishable in use from a
built-in [coretag](#coretag). Add-on usertags live as `.tag` files in
`code/UserTag/` (UI-specific ones in `code/UI_Tag/`); a definition names the
tag's attributes and points at its implementation via a `Routine` body or a
[MapRoutine](#maproutine).

## value

The Values space: the persistent, per-[session](#session) store of named
variables that survives from one request to the next, distinct from
transient [CGI](#cgi-variable) input. Form fields submitted by the user are
copied here (unless listed in [`FormIgnore`](config/FormIgnore.md)); read a
value with the [`[value]`](tags/value.md) tag or `$Values` in Perl, and set
defaults with [`ValuesDefault`](config/ValuesDefault.md).

## variable

A named holder of data. Interchange distinguishes several kinds: global and
catalog *config variables* (set with [`Variable`](config/Variable.md), read
with `[var NAME]` or `__NAME__`/`@_NAME_@`/`@@NAME@@` expansion — the
special `MV_*` names are cataloged in the
[variables reference](variables/README.md)),
[session](#session), [scratch](#scratch), [value](#value), and
[CGI](#cgi-variable) variables, and plain Perl variables. Config variables
normally keep the value set in `interchange.cfg` or `catalog.cfg` but can be
changed at runtime, typically in an [`Autoload`](config/Autoload.md) routine.

## widget

A reusable form-input control — a select menu, radio group, date picker,
file upload, and so on — generated by name instead of hand-written HTML.
Widgets are produced with the [`[widget]`](admin-tags/widget.md) tag and the
`o_widget` option field, and back the product-[option](#attribute) system;
see the `widgets/` reference directory (for example
[`select`](widgets/select.md)).
