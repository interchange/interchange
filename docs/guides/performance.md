# Performance and tuning

Interchange is a persistent server, so most of the classic CGI overhead is
already gone — but a busy catalog can still be made much faster (or much
slower) by how you size the process pool, how you write your list-producing
pages, what you cache, and where sessions and searches read their data. This
chapter is a practical tour of those levers: tuning the fork model, cutting
the cost of interpolating large lists, caching built pages, choosing a
session backend, keeping searches cheap, and profiling a request to find out
which of these actually matters for your store.

A rule to keep in mind throughout: **measure first.** The single biggest win
is almost always a page that loops over thousands of rows, and the second is
a session or search backend mismatched to your traffic — but which one is
biting *you* is a question for [profiling](#profiling-a-request), not
guesswork. Nearly every technique below is a trade, and applying all of them
to a page that renders in 5 ms wastes your time.

If you have not yet read [Architecture](architecture.md) (the process and
request model) and [Templating](templating.md) (how a page is interpolated),
read them first — this chapter tunes what they describe and does not
re-explain it.

## Where the time goes

Three cost centers dominate a request:

1. **The process model** — whether a server process is waiting to take your
   request or has to be forked first, and how many can run at once. Tuned in
   `interchange.cfg`; see [the process model](#tuning-the-process-model).
2. **Page interpolation** — the per-tag cost of parsing
   [Interchange Tag Language (ITL)](templating.md) and evaluating embedded
   Perl in the [Safe](perl-embedding.md) compartment. This is linear in the
   number of tags *executed*, which is why lists dominate; see
   [cheaper lists](#making-lists-cheap).
3. **Data access** — session reads/writes every request, and the row scans
   behind searches and `[loop]`; see [sessions](#session-backend-choice) and
   [data access](#data-access-and-indexing).

## Tuning the process model

By default the listening daemon **forks a fresh child for every
connection** ([Architecture](architecture.md)). Forking a warmed-up
Interchange process is far cheaper than starting a Perl interpreter from
scratch, but under sustained load it is still per-request overhead you can
remove.

### PreFork: a warm pool

[PreFork](../config/PreFork.md) `Yes` switches to a standing pool of
persistent children, started ahead of time and waiting on the socket, so a
request is handed to an already-running process:

    PreFork             Yes
    PreForkSingleFork   Yes
    StartServers        5
    MaxServers          0
    MaxRequestsPerChild 100

- [StartServers](../config/StartServers.md) is the target pool size (default
  `0`, i.e. no pool). The housekeeping pass keeps the pool topped up to this
  number as children exit, and trims it back down when there are too many.
- [PreForkSingleFork](../config/PreForkSingleFork.md) `Yes` spawns each new
  server with a single fork; turn it off only if zombie processes accumulate
  on your platform.
- [MaxRequestsPerChild](../config/MaxRequestsPerChild.md) (default `50`) caps
  how many requests a child serves before it exits and is replaced —
  cheap insurance against slow memory growth in long-lived processes. A
  higher value recycles less often; `0` disables recycling entirely.
- [ChildLife](../config/ChildLife.md) retires a child after a wall-clock
  interval even if it never won a request. It matters *only* in PreFork mode,
  where an idle pooled server may never reach its request count and so would
  otherwise never be recycled:

      PreFork   Yes
      ChildLife 30 minutes

This is the right mode for production traffic. The distributed
`interchange.cfg` (`dist/interchange.cfg.dist`) ships it as the `rpc`
traffic profile, selected by the `TRAFFIC` build variable:

    ifdef TRAFFIC =~ /rpc/i
    PreFork             Yes
    StartServers        5
    MaxServers          0
    MaxRequestsPerChild 100
    HouseKeeping        2
    PIDcheck            120
    endif

### MaxServers: capping concurrency

[MaxServers](../config/MaxServers.md) (nominal default `10`) was intended
to cap how many page-serving processes run at once — but its
running-server accounting rides on Perl `USR1`/`USR2` signal handlers,
and Perl signal delivery is not reliable enough for it. The count drifts,
so the cap misfires; **leave it at `0`** (which disables the accounting
entirely), exactly as every shipped traffic profile (`low`, `high`,
`rpc`) does. Control concurrency where it works instead: in PreFork mode,
[StartServers](../config/StartServers.md) *is* the concurrency knob —
set it to the actual number of pre-forked daemons you want running — and
in fork-per-request mode, shape load at the front-end web server or load
balancer.

### The housekeeping heartbeat

[HouseKeeping](../config/HouseKeeping.md) (default `60` seconds) is how often
the master wakes to reap dead children, top up the PreFork pool, expire
sessions, notice reconfigure/stop requests, and run scheduled
[Jobs](jobs.md). Busy sites shorten it (the shipped profiles use `2` or `3`)
so the pool refills and stop/reconfigure act promptly; the cost is more
frequent wakeups. [PIDcheck](../config/PIDcheck.md) sets a companion limit
that kills a child stuck on one request for too long.

### The 150 ceiling

The pool size has a hard upper bound. When the server tries to spawn servers
to reach `StartServers` and the batch exceeds **150**, it dies with

    Ridiculously large number of StartServers: <n>

The check is in `start_page()` in `lib/Vend/Server.pm`, evaluated at the
moment the pool is spawned (which, for the initial pool, is at server launch
in PreFork mode) — it is not a validation performed while `interchange.cfg`
is parsed. In practice this means a `StartServers` above 150 fails the daemon
at startup; treat 150 as the maximum warm-pool size. The same ceiling applies
to [SOAP_StartServers](../config/SOAP_StartServers.md). Real deployments want
far fewer servers than this anyway — sized to available RAM and CPU, not to
peak request count.

### A starting point

There is no universal setting, but a serviceable production baseline for a
single busy catalog on a dedicated box is: `PreFork Yes`, `StartServers`
tuned so the pool comfortably fits in RAM (often single or low double
digits), `MaxRequestsPerChild` around `100`, and `MaxServers 0` with
concurrency shaped upstream. Then [profile](#profiling-a-request) under real
load and adjust one directive at a time.

## Making lists cheap

Interchange's list-producing tags — [loop](../tags/loop.md),
[item-list](../tags/item-list.md), [query](../tags/query.md), and
[search-region](../tags/search-region.md) — interpolate their body once per
row. A tag that is trivial on a [flypage](templating.md) or in a cart of
three lines becomes the whole cost of the page when the list has thousands of
rows, because **every ITL tag executed costs parser time, and every embedded
Perl block costs a [Safe](perl-embedding.md) evaluation.** Safe can manage
only a few thousand evaluations per CPU second even on fast hardware, and the
tag parser only thousands of tags per second, so the goal in a large loop is
to do less parsing and fewer Safe evaluations per row.

The techniques below are ordered roughly from "always do this" to "reach for
under real load," and they compound. The
[templating guide](templating.md#loops-and-prefix-sub-tags) introduces the
prefix sub-tags; here we use them for speed.

### Prefer prefix sub-tags to re-parsed tags

Prefix sub-tags (`[loop-code]`, `[loop-field ...]`, `[loop-param ...]`) are
resolved by the looping tag itself with fast regular-expression scans of the
loop body, and they fetch the whole row in one operation. A standalone
[data](../tags/data.md) tag inside the loop, by contrast, is left for the
general parser to find *after* the loop, then argument-built and run as a
separate lookup per occurrence. From fastest to slowest, these all display
the same field:

    [loop prefix=foo search="ra=yes"]
      [foo-field description]                              fastest
      [foo-data products description]                      slightly slower
      [data products description [foo-code]]               slower
      [data table=products column=description key="[foo-code]"]   slowest
    [/loop]

With repeated references to the same field in one row, the speedup can be 10x
or more.

### Pre-fetch the columns you will use

A search returns only the key by default; asking `[loop-field ...]` for each
column then does a row lookup per field. Name the columns you need up front
with `mv_return_fields` (the `rf` parameter in search URLs) and read them
back with `[PREFIX-param name]` or `[PREFIX-pos N]` (0-based). The second
form below is much faster because the data is already in hand:

    [loop search="ra=yes/st=db"]
      [loop-code] price: [loop-field price]
    [/loop]

    [loop search="ra=yes/st=db/rf=sku,price"]
      [loop-code] price: [loop-param price]
    [/loop]

### Let the loop do the row arithmetic

Building a grid by counting columns with per-row [calc](../tags/calc.md) tags
pays a Safe evaluation on every iteration. The loop's own counters do the same
job with no Perl:

    [loop search="ra=yes"]
      [loop-change 1][condition]1[/condition]<tr>[/loop-change 1]
      [loop-alternate 3]</tr>[/loop-alternate]
    [/loop]

`[PREFIX-alternate N]` fires every Nth row; `[PREFIX-change col]` fires only
when a column's value changes between rows (subtotal breaks). Closing the
final row cleanly is a matter of `[on-match]`/`[no-match]` around the
`[list]` body rather than a running count — see the
[loop reference](../tags/loop.md).

### Use [PREFIX-calc], not [calc] or [perl], inside a loop

When a row genuinely needs Perl, `[PREFIX-calc] ... [/PREFIX-calc]` runs it
*during* the loop scan instead of leaving a [calc](../tags/calc.md) or
[perl](../tags/perl.md) tag for the general parser to find and re-parse
afterward. It has the same access to `$Values`, `$Scratch`, `$Tag`, and the
rest of the [embedded-Perl](perl-embedding.md) objects. To reach data tables
from inside the loop, open them once *above* it:

    [perl tables="products pricing" /]
    [loop search="ra=yes"]
      [loop-calc]
          return $Tag->data('products', 'description', '[loop-code]');
      [/loop-calc]
    [/loop]

### Precompile repetitive Perl with [PREFIX-sub] and [PREFIX-exec]

For a routine run on every row, compile it once and call it directly. With
`[PREFIX-sub NAME] ... [/PREFIX-sub]` a single Safe evaluation compiles the
body; each `[PREFIX-exec NAME]arg[/PREFIX-exec]` is then a plain subroutine
call. This can be 10x faster than separate `[calc]` calls, or ~5x faster than
separate `[PREFIX-calc]` calls:

    [loop search="st=db/fi=country/ra=yes"]
      [loop-sub country_compare]
          my $code = shift;
          return "code '$code' reversed is " . reverse($code);
      [/loop-sub]
      [loop-exec country_compare][loop-code][/loop-exec]
    [/loop]

### The fastest list: [query arrayref] plus one Perl block

For a read-only list you fully control, run the query once into a Perl
reference and format the rows in a single [perl](../tags/perl.md) block. The
`arrayref` (or `hashref`) attribute stores the result set in
`$Tmp->{NAME}` — no per-row ITL parsing at all:

    [query arrayref=myref sql="select sku,price,description from products" /]
    [perl]
        my $out = '';
        for my $row (@{ $Tmp->{myref} }) {
            my ($sku, $price, $desc) = @$row;
            $out .= "sku: $sku price: $price desc: $desc\n";
        }
        return $out;
    [/perl]

This is the fastest way to render a large list, at the cost of writing Perl
instead of tags. Reserve it for hot pages; for ordinary lists the readability
of `[query] ... [sql-param ...] ... [/query]` is worth more than the cycles.

### Take advantage of implicit true/false

An `[if]` test with no operator does not invoke Perl — it simply checks
whether the value is blank or `0` and treats anything else as true:

    [if scratch KEY] ... [/if]          no Perl evaluation
    [if scratch KEY == '1'] ... [/if]   spawns a Safe evaluation

Repeated across a large loop, the operator-free form measures 20–35% faster.
The catch is that your code must return blank or `0` for false (not `No` or a
space). See [if](../tags/if.md).

### Avoid needless re-parsing

Every `interpolate=1` or `reparse=1` you add spins up another pass of the tag
parser over that text. They are sometimes necessary (see
[Templating](templating.md#the-interpolation-pipeline-interpolate-and-reparse)),
but they are frequently pasted in without need. Drop them where the body
contains no tags that must run, and use [pragma](../pragmas/README.md)
controls rather than blanket re-parsing when you can.

## Caching built pages

The cheapest interpolation is the one you skip. When a page fragment is
expensive to build but changes rarely — a category tree, a top-sellers panel,
a rendered report — cache its output and reuse it.

### timed-build

[timed-build](../tags/timed-build.md) interpolates its body the first time,
writes the result to a file, and serves that file verbatim until a timeout
expires:

    [timed-build file="timed/bootmenu" login=1 force=1 minutes=1440]
      [menu name="catalog/menu" timed=1][/menu]
    [/timed-build]

    [timed-build auto=1 minutes=5]
      [query sql="SELECT count(*) FROM orders"][sql-code][/query] orders so far
    [/timed-build]

By default caching is bypassed for logged-in sessions and sessions without a
cookie, so per-user content does not leak into a shared cache; `login`,
`auto`, and `new` opt in or isolate the scratch context (details on the
[reference page](../tags/timed-build.md)). `minutes=0` never expires on its
own — delete the file to rebuild. Its sibling
[timed-display](../tags/timed-display.md) does the analogous thing for a piece
of display markup. Because the cached text is served as-is, **never cache a
fragment containing per-user data** unless you scope it with `auto`/`new`.

### capture_page

[capture_page](../tags/capture_page.md) captures a rendered page's output to a
file — useful for pre-building static-ish landing pages or exporting content
on a schedule from a [job](jobs.md). Like `timed-build`, it writes only to
paths allowed by the catalog's [file rules](security.md).

> **Removed feature — do not expect it.** Older Interchange (and MiniVend)
> had an *automatic* static-page build system driven by directives such as
> `StaticPage`, `StaticAll`, `StaticDBM`, `StaticDir`, and a `[flag build]`
> mode of the [flag](../tags/flag.md) tag, which pre-rendered whole catalogs
> to flat HTML. **None of that exists in the current code** — those
> directives are not defined and `[flag build]` is not a recognized flag
> operation (the flag tag now handles `write`, `read`, `transactions`,
> `commit`, `rollback`, and `checkhtml` only). Use `timed-build`,
> `capture_page`, and a front-end cache instead.

### Query and redirect caches

[QueryCache](../config/QueryCache.md) answers repeated, public query results
(the kind an AJAX widget fires) directly from a cache table over a lightweight
path, *before* a full session is established — keeping cheap lookups off the
page-serving path entirely. [RedirectCache](../config/RedirectCache.md)
caches computed redirects similarly. Both are catalog directives; reach for
them when the same cheap answer is requested over and over.

## Session backend choice

Every request reads the session at the start and writes it back at the end
(see [Sessions](sessions.md)), so the session store sits on the critical path
of *every* page. [SessionType](../config/SessionType.md) selects it:

| Type | Storage | When to use |
|------|---------|-------------|
| `File` (default) | one file per session under `session/` | single server; simple and fine for most stores |
| `NFS` | files with NFS-safe locking | sessions on a shared mount |
| `GDBM` / `DB_File` | one DBM file, whole-file locked | legacy; the single-file lock serializes concurrent writers |
| `DBI` | a `sessions` SQL table | multiple app servers behind a load balancer |
| `Redis` | a Redis server (`Vend::SessionRedis`) | multi-server, with fast native expiry |

For a single box, `File` is usually the right answer and needs no tuning
beyond [SessionHashLevels](../config/SessionHashLevels.md) to keep any one
directory from growing huge. The moment you run **more than one Interchange
host** against one catalog, sessions must live somewhere shared: `DBI` or
`Redis`. The DBM types serialize writers on a single file lock and do not
scale — prefer them only for legacy setups.

### Keep sessions small

Because the whole session is serialized and rewritten every request, its size
is a per-request tax. Two habits keep it down:

- **Do not park large values in scratch.** `[set]`/`[seti]` write to the
  session; for data you only need for the current page use
  [tmp](../tags/tmp.md)/[tmpn](../tags/tmpn.md), which live in `$Tmp` and are
  discarded before the session is saved. Read-and-delete a one-shot value with
  [scratchd](../tags/scratchd.md).
- **Keep generated blobs out.** Search result sets and built HTML do not
  belong in the session — cache them with [timed-build](../tags/timed-build.md)
  instead.

[SessionExpire](../config/SessionExpire.md) (strap default `4 hours`) bounds
how long idle sessions linger; File/DBM sessions are reaped by housekeeping
and the `expireall` utility, while DBI/Redis expire natively.

### A note on dynamic_variables

[Pragma dynamic_variables](../pragmas/dynamic_variables.md) makes `__NAME__`
and friends resolve per request from a
[VariableDatabase](../config/VariableDatabase.md) or
[DirConfig](../config/DirConfig.md) directory, so admin edits take effect
without a reconfigure. That convenience is a per-request lookup on every
variable reference — genuinely useful, but it is overhead. Turn it on only
where you actually store variables outside `catalog.cfg`, and consider
[dynamic_variables_file_only](../pragmas/dynamic_variables_file_only.md) to
skip the database leg.

## Data access and indexing

Interchange's [search](search.md) engines are **row walkers, not full-text
indexes**: `Vend::TextSearch` scans a flat file line by line and
`Vend::DbSearch` iterates rows of a table. There is no built-in inverted
index. Two consequences for performance:

- **Push filtering into the database.** For products in an SQL table, a `db`
  search's row iteration runs against live rows, so an SQL index on the
  columns you filter and sort by is what makes it fast — that indexing lives
  in your database schema, not in an Interchange directive. Better still, for
  a genuinely selective lookup use [query](../tags/query.md) with a real
  `WHERE` clause and let the database's optimizer and indexes do the work,
  rather than scanning every row in ITL. (Note that a text search's `sq`
  parameter is *pseudo*-SQL over a flat file, not a database passthrough — see
  [Search](search.md).)
- **For large free-text corpora, use an external index.** Point
  [Glimpse](../config/Glimpse.md) (`st=glimpse`) or the Swish-e integration
  (`Vend::Swish`) at a pre-built index when row-walking tens of thousands of
  documents per query becomes the bottleneck.

Table backend also matters. `Vend::Table::InMemory` and the DBM backends
(`GDBM`/`SDBM`/`DB_File`) are fast for small read-mostly lookup tables;
`DBI`-backed SQL tables scale to large data and give you the query planner
and indexes. Restrict which tables a public search may traverse with
[NoSearch](../config/NoSearch.md), and keep [ProductFiles](../config/ProductFiles.md)
to the tables that really back product lookups. See
[Databases](databases.md) for the data layer as a whole.

## Profiling a request

Do not tune blind. Interchange gives you enough to find the slow part.

### Timing a fragment

The `benchmark` usertag (ships in `eg/usertag/benchmark.tag`, install it as
any [usertag](../config/UserTag.md)) measures CPU time between two points,
which is ideal for A/B-testing two ways of writing the same list:

    Approach A: [benchmark start=1]
      ... first version of the list ...
      TIME: [benchmark]

    Approach B: [benchmark start=1]
      ... second version ...
      TIME: [benchmark]

Wrap each variant in the pair and read the elapsed CPU seconds; the list
techniques [above](#making-lists-cheap) are exactly the kind of change worth
measuring this way.

### Finding slow queries

[DataTrace](../config/DataTrace.md) turns on DBI-level SQL tracing to the
[DebugFile](../config/DebugFile.md), logging every database call — verbose,
so it ships commented out, but the fastest way to see which query on a page is
slow and how often it runs. A [search](search.md) carrying the `debug` flag
likewise dumps its parsed specification and progress. Narrow the flood to one
client with [DebugHost](../config/DebugHost.md). The whole toolkit — enabling
the debug file, `[debug]`, `Pragma perl_warnings_in_page`, and reading the
logs — is covered in [Logging and debugging](logging-debugging.md).

### System-level

Under load, watch process count against [MaxServers](../config/MaxServers.md)
and resident memory per child; if children grow, lower
[MaxRequestsPerChild](../config/MaxRequestsPerChild.md). If requests queue
while CPU is idle, the pool is too small ([StartServers](../config/StartServers.md))
or a downstream resource (database, payment gateway) is the real limit — the
profiling above tells which.

## See also

- [Architecture](architecture.md) — the process and request model this
  chapter tunes
- [Templating](templating.md) — the interpolation pipeline behind list cost
- [Sessions](sessions.md) — session storage in depth
- [Search](search.md) and [Databases](databases.md) — the data layer
- [Logging and debugging](logging-debugging.md) — the debug and trace tools
- [Jobs](jobs.md) — moving expensive work off the request path
- Directives: [PreFork](../config/PreFork.md) ·
  [StartServers](../config/StartServers.md) ·
  [MaxServers](../config/MaxServers.md) ·
  [MaxRequestsPerChild](../config/MaxRequestsPerChild.md) ·
  [ChildLife](../config/ChildLife.md) ·
  [HouseKeeping](../config/HouseKeeping.md) ·
  [SessionType](../config/SessionType.md) · [QueryCache](../config/QueryCache.md)
- Tags: [timed-build](../tags/timed-build.md) ·
  [timed-display](../tags/timed-display.md) ·
  [capture_page](../tags/capture_page.md) · [query](../tags/query.md)
