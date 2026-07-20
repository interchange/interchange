# Upgrading Interchange

Interchange is designed to be drop-in compatible within a major version: a
catalog built for 5.0 should keep running on 5.12 with few or no changes.
Between minor versions the occasional incompatible change does land, and the
project records each one. This chapter walks you through the general upgrade
procedure, points you at the two authoritative change logs, and collects the
version-by-version gotchas that most often trip up a working store — with a
5.x focus. When it says "see UPGRADE" or "see WHATSNEW," it means the files in
the distribution root and `doc/`; this guide summarizes and links, it does not
replace them.

## The two primary sources

Two files ship with every release and are the last word on what changed:

- **`UPGRADE`** (distribution root) — the curated, human-facing upgrade guide.
  It opens with a one-line-per-version summary ("what you can expect"), then a
  `KNOWN ISSUES UPGRADING FROM x.y` section for each version family, followed
  by the same-location install procedure, the side-by-side test procedure, and
  the 4.6.x notes. Read the `KNOWN ISSUES` block for every version you are
  crossing, not just the one you land on.
- **`doc/WHATSNEW-5.12`, `doc/WHATSNEW-5.10`, ... `doc/WHATSNEW-5.1`** (and the
  older `WHATSNEW-4.9` family) — the full, chronological change log, one file
  per release branch, newest changes at the top of each file. Every WHATSNEW
  header repeats "See UPGRADE document for a list of incompatible changes," so
  UPGRADE is the short list and WHATSNEW is the exhaustive one. If a behavior
  changed and it is not in UPGRADE, it is almost certainly described in the
  WHATSNEW file for the branch that introduced it.

The historic *Interchange Upgrade Guide* (`icupgrade`) covers MiniVend 3 → 4
and MiniVend 4 → Interchange 4.6 and is effectively frozen; anything running
5.0 or later should track UPGRADE and WHATSNEW instead.

## The general procedure: install in the same location

Interchange keeps the server software and your catalogs in separate trees (see
[Architecture](architecture.md) and [Installation](installation.md)), so a
software upgrade does not touch your catalog data. The steps below mirror the
`INSTALLING INTERCHANGE IN THE SAME LOCATION` section of `UPGRADE`.

**Back up everything first.** Tar the whole software directory, and back up
your catalogs too if you are crossing a major version.

    tar czvf ~/ic_backup.tar.gz /usr/local/interchange

Then unpack the new release and install it over the top of the old one:

    tar xzf interchange-5.12.0.tar.gz
    cd interchange-5.12.0
    perl Makefile.PL          # create the makefile
    make
    make test                 # if this fails, don't panic — see below
    make install              # install to the same location

Two things people expect to do and should not:

- **You do not re-run `bin/makecat`.** Your existing catalog is untouched by a
  software install; `makecat` builds *new* catalogs (see
  [Catalog anatomy](catalog-anatomy.md)).
- **A failing `make test` is not necessarily fatal.** The test suite is
  sensitive to the build host's available Perl modules and can report failures
  on a machine that will run Interchange perfectly well. Investigate, but do
  not treat a red `make test` as a blocked upgrade.

Finish by restarting the daemon (`bin/interchange -r`, see
[Configuration](configuration.md)) and verifying your storefront and admin.

### Testing the new version before you switch

`UPGRADE` describes a full side-by-side procedure that runs the new server on a
second link program and port so you can exercise a real catalog on the new code
without taking the old one down. In outline: install the new tree to a separate
directory, run `bin/compile_link -p 7787` to build a test link program, point a
throwaway CGI link (`test5`) and a `Variable TEST_SERVER 1` guard at it, add an
`ifdef @TEST_SERVER` block to the catalog's `catalog.cfg` that overrides the
URLs and image directories, and start the second server. The catalog then runs
on both versions at once. See the `TO TEST BEFORE YOU UPGRADE` section of
`UPGRADE` for the exact commands and file permissions (the test link program
must match the SUID/permission model of your live one).

## Perl version requirements

The clearest hard gate between versions is the minimum Perl. If your Perl is
older than the target release requires, the daemon will not start.

| Interchange | Minimum Perl |
|-------------|--------------|
| 5.4.x | 5.8.0 (threads allowed only under 5.8.5+) |
| 5.6.x | 5.8.5 unthreaded / 5.8.8 threaded |
| 5.12.x | 5.16.3 |

Running Interchange under a threaded Perl is tolerated but not recommended for
production. Check your interpreter with `perl -v` before you begin.

## Version-by-version notes (5.x)

These are the compatibility highlights, condensed from `UPGRADE` and the
WHATSNEW files. Cross every version between where you are and where you are
going, and read the corresponding UPGRADE block for the full text.

### Upgrading from 5.0.x or 5.2.x

`UPGRADE` lists **no** known issues for either. Interchange 5.0 through 5.2 is
close to a straight drop-in.

### Upgrading from 5.4.x

This is the largest incompatible step in the 5.x line — "your code will almost
certainly fail to work properly until you make the necessary changes." The
changes landed *in* 5.4, so you hit them coming *from* 5.4 or earlier. The
headline items:

- **The `[sql]` tag is gone.** Rewrite those queries with the
  [query](../tags/query.md) tag. (The unrelated `sql` *filter* still exists.)
- **`ConfigParseComments` no longer parses commented directives.** Interchange
  now behaves as if `ConfigParseComments No` were set: a config line beginning
  with `#` is a comment, full stop. Constructs like `#include` and `#ifdef`
  must be written bare — `include`, `ifdef` (see the config-file syntax in
  [Configuration](configuration.md)). Note: the directive name is still
  *accepted* by the parser as a deprecation stub (it warns and does nothing),
  so an old `catalog.cfg` will not hard-error on the line, but it also will not
  restore the old behavior.
- **Global `ActionMap` path now includes the action.** Previously a global
  [ActionMap](../config/ActionMap.md) received a path *without* the action
  while a catalog one received it *with*; both now include the action. Strip it
  at the top of the routine:

      ActionMap your_action <<EOR
      sub {
          my ($path) = @_;
          $path =~ s:^[^/]+/::;   # remove the action
          # ...
      }
      EOR

- **Directives removed:** `SOAP_Host`, `RequiredFields`, `HTMLmirror`,
  `UseCode`, plus "all previously deprecated configuration directives." These
  are no longer defined in `lib/Vend/Config.pm`; a leftover reference is a
  startup error.
- **Deprecated pragmas removed:** `compatible_5_2` (kept table-editor error
  text hidden as it was through 5.2) and `no_html_parse` (disabled `MV=`
  parsing inside HTML tags). See the [removed pragmas](../pragmas/README.md)
  list; setting them today has no effect.
- **Tax country variable renamed for tax.** If you used `MV_COUNTRY_FIELD` to
  pick the country for *tax* purposes, switch that use to `MV_COUNTRY_TAX_VAR`.
  `MV_COUNTRY_FIELD` still exists for order-check country validation — the two
  roles were split. See [Taxes](taxes.md).
- **`[either]` no longer reparses its output.** Its body parts are still
  interpolated, but the tag's output is not re-run through the parser.
- **`[fedex-query]` removed** (FedEx retired the web API it called).
- **`[/page]` and `[/order]` removed.** These were never real container tags;
  they were macros that expanded to `</a>`. Use a literal `</a>` in your HTML
  instead — see [page](../tags/page.md) and [Templating](templating.md).
- **`*Robot*` directives moved to `robots.cfg`.** Remove any `Robot*`
  directives from `interchange.cfg` and add `include robots.cfg` in their
  place. A companion `subdomains.cfg` (for [DomainTail](../config/DomainTail.md)
  handling) should likewise be pulled in with `include subdomains.cfg`.
- **Per-IP session counters changed format.** Delete the old counter files:

      rm -rf catroot/tmp/addr_ctr/*

  (Type that carefully.)
- **New CSS class.** The [error](../tags/error.md) and `[formel]` tags emit a
  `mv_contrast` class (overridable with the `CSS_CONTRAST` Variable); add a
  rule for it, e.g. `.mv_contrast { color: #FF0000; }`.
- **`special_pages/missing.html` admin check.** If that file contains
  `[if type=explicit compare="q{[subject]} =~ m{^admin/}"]`, replace it with:

      [tmpn missing_subject][subject][/tmpn]
      [if scratch missing_subject =~ /^admin/]

### Upgrading from 5.5.1 / 5.5.2

- **`SpecialSub catalog_init` was renamed to `request_init`.** Rename the
  directive in your `catalog.cfg`.
- **`UserTrack` now defaults to "no."** If you rely on the `X-Track` HTTP
  response header, add `UserTrack yes` explicitly. `UserTrack` also no longer
  drives `TrackFile`; control tracking-file output with the
  [TrackFile](../config/TrackFile.md) directive directly.
- **`set_slice()` array form removed.** `$db->set_slice($key, $f1, $v1)` no
  longer works; use the array-ref form `$db->set_slice($key, [$f1], [$v1])`.
- **`sql_counter` syntax changed.** The custom SQL counter now takes a full
  `SELECT`: `UserDB default sql_counter "userdb:SELECT
  custom_counter('userdb_username_seq')"` (the old bare-function form clashed
  with MySQL pseudo-sequences).
- **Bundled CPAN modules removed from `extra/`** (`Business::UPS`,
  `File::Spec`, `Tie::ShadowHash`, `URI::URL`). If the daemon will not start
  after upgrading, confirm those modules are installed system-wide (see
  `Bundle::Interchange` / `Bundle::InterchangeKitchenSink`).

### Upgrading from 5.6.x

- **`AdminUser` directive removed.** (`AdminUserDB` is a different, current
  directive — do not confuse them.)
- **PostgreSQL 8.3+ dropped many implicit type casts** that Interchange or your
  own SQL may have relied on. The distribution ships
  `eg/pg83-implicit-casts.sql` to restore the ones the demo needs.
- **`Digest::SHA` is now the recommended password digest**, falling back to
  `Digest::SHA1` if absent. See [Security](security.md).

### Upgrading from 5.10.x

- **`[area]` bug fix.** A fully qualified URL passed as the `href` together with
  the `form` attribute no longer has its `protocol://domain` overwritten by
  [VendURL](../config/VendURL.md). If your code depended on the old (buggy)
  overwrite, adjust it. See [area](../tags/area.md).
- **`[email-raw]` now honors `MV_EMAIL_CHARSET`** to convert Unicode data. If
  you previously worked around Unicode handling in `[email-raw]` yourself while
  also setting [MV_EMAIL_CHARSET](../variables/MV_EMAIL_CHARSET.md), remove your
  workaround so it does not double-convert. See [Email](email.md).
- **Month/year date-adjustment rollover fixed** (a 5.7-era bug): adjusting to a
  month where the target day does not exist now clamps to that month's last day
  instead of rolling into the next month (May 31 − 1 month → April 30, not
  May 1). Update any code that relied on the old rollover.

### Upgrading from 5.10.x to 5.12.x

- **Perl 5.16.3 is now the minimum** (see the table above).
- **Session IDs in URLs are gone; cookies are always required.** The option to
  carry the session id in the URL was removed. A client that does not accept
  cookies can no longer hold a session — verify your flows (and any bots you
  care about) accept cookies. See [Sessions](sessions.md).
- **Redis sessions require `MoreDBTable`.** If you store sessions in Redis, you
  must now set [MoreDBTable](../config/MoreDBTable.md).
- **Defunct code removed:** old mod_perl artifacts, vestigial Windows and Irix
  support, an unintegrated `Vend::Email` module, and the never-integrated
  bits are gone. If you referenced any of them directly, they are no longer
  present.
- **Payment gateway logging changed default.** Gateway request/response logging
  is now off unless explicitly requested (Route param, `[charge]` option
  `gwl_enabled`, or a global setting). See [Payments](payments.md).

The 5.12 WHATSNEW also documents the project's move from `icdevgroup.org` to
`https://www.interchangecommerce.org/` and the canonical Git repository at
`https://github.com/interchange/interchange`. Older documentation URLs and
support links point at the retired site.

## The 5.7.2 remote-search security fix

Independently of which version you are on, one change deserves its own
callout because it affects *every* prior release. A vulnerability let an
unauthenticated visitor search any configured table via a crafted search
request. The fix introduced [AllowRemoteSearch](../config/AllowRemoteSearch.md),
which whitelists the tables a remote search may touch and defaults to:

    AllowRemoteSearch products variants options

After upgrading, audit your catalog for the `search`/`scan` form actions and
any page that submits to a page named `search` or `scan`. If such a search
targets a table not in the whitelist, either add the table deliberately (never
one with sensitive data) or — better — rewrite the page to accept only search
*terms* via CGI and build the search server-side with the
[search](../tags/search.md) tag, which is not subject to the
`AllowRemoteSearch` restriction. `UPGRADE` gives worked `ActionMap` and
`Sub ncheck_category` rewrites, and notes that the standard/foundation "lost
password" pages used remote search and should be replaced with the current
`lost_password.html`. See [Search](search.md) and [Security](security.md) for
the full picture.

## Removed and renamed items: a cross-reference

The reference sections of this documentation track what current code actually
consults, so they are the fastest way to confirm whether an old name still
does anything. Setting a removed directive, pragma, or variable is silently
inert (or, for directives, a startup error) — not an error you want to discover
in production.

- **Removed pragmas** — `compatible_5_2`, `no_html_parse`, and
  `substitute_table_image` are listed, with what replaced them, in the
  [removed pragmas](../pragmas/README.md) section. The current pragma set is in
  the same index and is set with the [Pragma](../config/Pragma.md) directive or
  a `[pragma]` tag (see [Templating](templating.md)).
- **Removed / renamed variables** — `MV_PAYMENT_SERVER`, `MV_CURRENCY`,
  `MV_STATE_FIELD`, `MV_DHTML_BROWSER`, and `MV_ECML_FIELD_MAP` appear in
  historic docs but are not read by current code; see the
  [removed and renamed variables](../variables/README.md) table for the current
  equivalents.
- **Removed pricing directives** — `PriceBreaks`, `MixMatch`, and
  `PriceAdjustment` are not present in current Interchange; quantity breaks and
  attribute pricing are both expressed through
  [CommonAdjust](../config/CommonAdjust.md) instead. The
  [Pricing](pricing.md) guide's upgrading note shows the translation.
- **Removed configuration directives** — beyond the 5.4 list above, if the
  daemon reports "Unknown directive" at startup, the name has been retired;
  check the [directive reference](../config/README.md) for the current
  spelling or replacement.

## Template migration: foundation, standard, and strap

Interchange has shipped three generations of demo/skeleton catalog, and the
older two are gone from the distribution:

- **foundation** was the original skeleton; it was removed and replaced by
  **standard** during the 5.3 development series.
- **standard** was in turn superseded by **strap**, the Bootstrap-based demo
  that is now the *only* catalog skeleton shipped in `dist/` and the one
  `bin/makecat` builds. All examples in this documentation use strap (see
  [Catalog anatomy](catalog-anatomy.md)).

There is no automated converter between skeletons: a catalog's pages,
templates, and admin wiring are yours, and Interchange upgrades the *engine*,
not your storefront markup. Practically:

- **You are not forced to adopt strap.** A foundation- or standard-based
  catalog keeps working as long as you apply the engine-level changes above
  (removed tags/directives, `AllowRemoteSearch`, the Perl minimum). `UPGRADE`
  includes a `UPGRADE NOTES FOR FOUNDATION-STYLE CATALOGS` section for exactly
  this case — for example, adding an `extended` column to
  `products/mv_metadata.asc`, and repointing or removing the `UI_IMAGE_DIR` /
  `UI_IMAGE_DIR_SECURE` variables at the current admin image location.
- **The static-page build facility is gone.** Interchange 5 no longer supports
  static page building; remove `NoCache` and any `Static*` directives from
  `catalog.cfg` to stop the startup warnings. If you built static pages,
  reproduce it with an external script.
- **Adopting strap means porting**, not upgrading: copy your look and feel into
  a fresh strap catalog rather than editing the old one in place. The retail /
  dealer / distributor pricing, the multi-page checkout, and the SEO category
  URLs in strap are all worth studying as the current idiom
  ([Pricing](pricing.md), [Cart and checkout](cart-and-checkout.md),
  [Admin UI](admin-ui.md)).

## Usertag conflicts after an upgrade

Global UserTags moved to `code/UserTag/` in the 4.9 era, and old installations
that still `include` a legacy `usertags/` directory can clash with the shipped
ones. Two messages are common at (re)start:

- **`Duplicate usertag xxxx found`** — usually a global `usertags/` directory
  still included from `interchange.cfg` colliding with the current
  `code/UserTag/` definition. Delete the stale copy named in the message.
- **`Local usertag xxxx overrides global definition`** — most often a local
  `history_scan` in `catalog.cfg`, which is now a shipped global and can be
  deleted. In general this is only a warning: your local
  [UserTag](../config/UserTag.md) wins. If the override is unintended, rename
  your tag.

If you are coming from 4.6.x, also change `#include usertag/*` to
`include usertag/*.tag` (the leading `#` is obsolete since
`ConfigParseComments` stopped honoring commented directives), and give any
hand-written usertag files a `.tag` extension so the glob picks them up.

## After upgrading: a short checklist

- [ ] Daemon starts clean — no "Unknown directive," no "no longer supported"
      warnings in the error log (see [Logging and debugging](logging-debugging.md)).
- [ ] `AllowRemoteSearch` is set and lists only safe tables.
- [ ] Storefront: browse, search, add to cart, and complete a test checkout.
- [ ] Admin UI loads and applies changes (its look and feel may differ across
      major versions).
- [ ] Payment runs against the gateway's test mode before you take live orders
      ([Payments](payments.md)).
- [ ] Sessions persist — confirm cookies are accepted (required from 5.12).

## See also

- `UPGRADE` and `doc/WHATSNEW-*` — the authoritative, per-version change logs
- [Installation](installation.md) — the install procedure in full, and the
  permission model
- [Configuration](configuration.md) — `interchange.cfg` / `catalog.cfg`,
  `include`, and reconfiguration
- [Architecture](architecture.md) — why a software upgrade leaves catalogs
  untouched
- [Directive reference](../config/README.md),
  [pragma reference](../pragmas/README.md),
  [variable reference](../variables/README.md) — what current code consults
- [Security](security.md) — the remote-search fix and the trust model behind it
