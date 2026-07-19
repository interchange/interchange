# Architecture

Interchange is a persistent application server, not a per-request CGI
program. One daemon serves any number of independent **catalogs** (stores),
each with its own configuration, pages, and databases, while tiny **link
programs** (or an Apache module) relay requests from your web server to the
daemon. This chapter explains the process model, how a request travels from
browser to rendered page, and how the source tree's modules divide the work.

If you want to *run* Interchange first and understand it second, start with
[Installation](installation.md) and the [tutorial](tutorial.md), then come
back here.

## The three-tier layout

    browser ── web server ── link program ── Interchange daemon ── databases
                (Apache,      (vlink/tlink     (bin/interchange)     (DBM, MySQL,
                 nginx...)     CGI, or                                PostgreSQL,
                               mod_interchange)                       SQLite...)

- The **web server** serves static assets (images, CSS) directly and hands
  catalog URLs to the link program, exactly as it would any CGI program.
- The **link program** is deliberately minimal: it packages the CGI
  environment and request body, writes them to the socket where the daemon
  listens, and streams the response back. Variants live in `dist/src/`:
  `vlink` (UNIX-domain socket), `tlink` (TCP), a mod_perl handler, and the
  `mod_interchange` Apache module which skips CGI entirely.
- The **daemon** (`bin/interchange`, source `scripts/interchange`) holds all
  catalogs, compiled configuration, and cached database handles in memory,
  which is what makes Interchange fast relative to fork-per-request CGI
  applications: page requests hit an already-initialized Perl process.

Because one daemon can serve many catalogs, a catalog is identified by the
URL it is reached through: each `Catalog` line in `interchange.cfg` maps a
script path (for example `/cgi-bin/strap`) to a catalog. At request time the
daemon looks up the requesting script path to select the catalog
(`open_cat()` in `lib/Vend/Dispatch.pm`); an unknown path returns
`404 Undefined catalog`.

## Process model

The daemon listens on a UNIX-domain socket (`etc/socket`), a TCP socket, or
both. The mode is set in `interchange.cfg`:

    Unix_Mode  Yes
    Inet_Mode  No

(`bin/interchange -i` and `-u` select modes from the command line.) UNIX
mode is preferred when the web server is on the same machine: it is faster
and access is controlled by filesystem permissions ([SocketPerms](../config/SocketPerms.md)).
TCP mode ([TcpMap](../config/TcpMap.md), [TcpHost](../config/TcpHost.md))
lets the web server live on another host.

Two forking strategies serve requests (`lib/Vend/Server.pm`):

- **Fork-per-request** (default): the listening process forks a child for
  each connection.
- **Prefork** ([PreFork](../config/PreFork.md) `Yes`): a pool of persistent
  servers is started ahead of time ([StartServers](../config/StartServers.md)),
  each handling up to [MaxRequestsPerChild](../config/MaxRequestsPerChild.md)
  requests before being recycled. This is the right choice for production
  traffic; see [Performance](performance.md).

In either case [MaxServers](../config/MaxServers.md) caps concurrency. A
periodic **housekeeping** pass (`housekeeping()` in `Server.pm`, every
[HouseKeeping](../config/HouseKeeping.md) seconds) reaps dead children,
restarts deficit prefork servers, expires sessions, and runs scheduled
[Jobs](jobs.md). Optional dedicated **SOAP servers**
([SOAP](../config/SOAP.md), `SOAP_StartServers`) listen separately for RPC
requests, and `bin/interchange --runjobs=catalog=group` runs job groups in a
one-shot process.

Signals: `HUP` restarts the server (`bin/interchange -r` sends it for you),
`TERM`/`INT` stop it; `bin/interchange --reconfig=catalog` triggers a
reconfiguration of one catalog without restarting the daemon (config is
re-read during housekeeping — see [Configuration](configuration.md)).

## Interpreter globals: the vocabulary of a request

Interchange code — including the tags you write — communicates through a
small set of package globals that are re-pointed at the current catalog and
session for each request. You will meet these names throughout the
documentation and in any `[perl]` block you write
(see [Embedded Perl](perl-embedding.md)):

| Global | Meaning |
|--------|---------|
| `$Global::...` | Server-wide (interchange.cfg-level) configuration |
| `$Vend::Cfg` | The current catalog's compiled configuration hash |
| `$Vend::Session` | The current session hash (persisted between requests) |
| `$::Values` | User form values that persist in the session (`[value ...]`) |
| `$::Scratch` | Session scratch space (`[scratch ...]`, `[set ...]`) |
| `$::Variable` | Catalog `Variable` definitions (`__NAME__` substitution) |
| `%CGI::values` | The raw form/query variables of *this* request |

The separation matters for trust: global configuration and `GlobalSub`
routines run with full Perl; catalog-level code runs inside a restricted
Safe compartment unless explicitly granted more (see [Security](security.md)
and [AllowGlobal](../config/AllowGlobal.md)).

## Request lifecycle

`Vend::Server::connection()` reads the marshalled CGI environment from the
link program, populates `%CGI::values` and friends (`map_cgi()`), then calls
`Vend::Dispatch::dispatch()` — the heart of the server
(`lib/Vend/Dispatch.pm`). In order:

1. **CGI adjustment** — `adjust_cgi()` normalizes the requested path into
   `$CGI::path_info` and resolves which catalog the request addresses.
2. **Catalog open** — `open_cat()` points `$Vend::Cfg` and `$::Variable` at
   the catalog, chdirs to its directory, and returns 404 if the script path
   matches no catalog. The catalog's [Preload](../config/Preload.md) macros
   run now, before any session exists.
3. **Session resolution** — the session id is taken from (in priority
   order) `mv_session_id`, the session cookie (`MV_SESSION_ID` by default,
   or [CookieName](../config/CookieName.md)), or — with
   [FallbackIP](../config/FallbackIP.md) — a hash of address and user agent.
   `mv_tmp_session=1` forces a throwaway session. The stored session is
   verified against the client (IP consistency unless
   [WideOpen](../config/WideOpen.md); expiry per
   [SessionExpire](../config/SessionExpire.md)), and defenses fire here:
   [RobotLimit](../config/RobotLimit.md) locks out abusive access rates, and
   too many new sessions from one IP draw a 403. New sessions are created as
   needed. Details: [Sessions](sessions.md).
4. **Source tracking** — the affiliate/ad-source of the visit is resolved
   through [SourcePriority](../config/SourcePriority.md) (`mv_pc`, `mv_source`,
   cookies, or the existing session), optionally persisted in a
   [SourceCookie](../config/SourceCookie.md); with
   [BounceReferrals](../config/BounceReferrals.md) the tracking parameters are
   stripped by a 301 redirect so caches and search engines see clean URLs.
5. **Per-request hooks** — `DispatchRoutines`, CGI input
   [filters](../filters/README.md), one-time feature `Init` blocks, and the
   session's [Autoload](../config/Autoload.md) macros run. Any of these can
   answer the request and end it (a login gate, for example).
6. **Path resolution** — an empty path becomes the `catalog`
   [SpecialPage](../config/SpecialPage.md); session path aliases and the
   [AliasTable](../config/AliasTable.md) database rewrite pretty URLs to real
   pages; a trailing `.html` is dropped.
7. **Action dispatch** — if the form posted `mv_action`, or the *first path
   segment* names an action, the matching routine runs. Built-ins
   (`%action`): `process` (form processing — see [Forms](forms.md)), `scan`
   and `search` (the [search engine](search.md)), `order` (add to cart),
   `silent` (process without output), `ui` (the [admin interface](admin-ui.md)).
   Catalogs add their own with [ActionMap](../config/ActionMap.md) — this is
   how strap's SEO category URLs work. An action returning true falls
   through to page display.
8. **Page display** — `do_page()` (`lib/Vend/Page.pm`) locates the page file
   under `pages/`, or falls back to the **flypage** (`ItemAction`/flypage
   handling) for product SKUs, interpolates the ITL (see
   [Templating](templating.md)), and `respond()` streams the result with
   cookies and headers back through the link program.
9. **Cleanup** — `CleanupRoutines`, tracking writes
   ([TrackFile](../config/TrackFile.md)), the session is written back, and
   the catalog is closed.

A useful mental model: **every request is (catalog, session, path) → action
→ page**, with hooks before and after each arrow.

## Module map

The ~100 modules under `lib/` divide into subsystems. The complete
per-module map with entry points is in the project inventory; the load-bearing
ones:

- **Server & dispatch** — `Vend::Server` (sockets, forking, housekeeping),
  `Vend::Dispatch` (the lifecycle above), `Vend::Page` (page location and
  display), `Vend::Control` (start/stop/signal handling), `Vend::ModPerl`,
  `Vend::SOAP`, `Vend::Cron` (jobs), `Vend::External`.
- **Configuration** — `Vend::Config` parses both config files and defines
  all ~300 [directives](../config/README.md); `Vend::MakeCat` backs
  `bin/makecat`.
- **Templating** — `Vend::Parse`/`Vend::Parser` tokenize ITL,
  `Vend::Interpolate` implements the core tags and filter engine,
  `Vend::Tags` exposes tags to Perl code, `Vend::Safe` guards untrusted
  code, `Vend::Form`/`Vend::Menu`/`Vend::Options` render form widgets,
  menus, and product options.
- **Sessions** — `Vend::Session` with pluggable stores (`Vend::SessionFile`,
  `Vend::SessionDB`, `Vend::SessionRedis`).
- **Data layer** — `Vend::Data` (table open/import/export, product lookups)
  over `Vend::Table::*` backends: `DBI` (SQL), `GDBM`/`SDBM`/`DB_File`
  (DBM), `InMemory`, `LDAP`, `Shadow` (per-locale overlays); plus
  `Vend::SQL_Parser` for SQL-on-flat-file emulation.
- **Search** — `Vend::Search` dispatching to `Vend::TextSearch` (flat file),
  `Vend::DbSearch` (database), `Vend::RefSearch`, with `Vend::Scan` parsing
  search/scan URLs.
- **Commerce** — `Vend::Cart`, `Vend::Order` (profiles, routes, checks),
  `Vend::Ship` (+ `Ship::*` carrier lookups), `Vend::Tax` (+ Avalara,
  TaxJar), `Vend::Payment` (+ 20-odd [gateway modules](../payments/README.md)),
  `Vend::UserDB`/`Vend::UserControl` (accounts), `Vend::Accounting`,
  `Vend::Track`.
- **Utilities** — `Vend::Util` (URLs, encoding, file read/write, mail),
  `Vend::File` (safe file ops), `Vend::Error`, `Vend::CharSet`.

## Where things live at runtime

An installed server (default `~/interchange` or `/usr/local/interchange`)
holds `bin/` (relocated `scripts/`), `lib/`, `etc/` (run state: PID file,
sockets, error log), and your catalogs elsewhere (conventionally
`~/catalogs/<name>`), each with the layout toured in
[Catalog anatomy](catalog-anatomy.md). The daemon runs as one non-root user
that owns all catalog files; the link program runs as the web server user
and needs only socket access. See [Installation](installation.md) for the
permission model and [Security](security.md) for why it matters.

## See also

- [Configuration](configuration.md) — how interchange.cfg and catalog.cfg
  are parsed into `$Global::` and `$Vend::Cfg`
- [Templating](templating.md) — what happens inside page interpolation
- [Sessions](sessions.md) — session storage and lifetime in detail
- [Performance](performance.md) — tuning the process model
