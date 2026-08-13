# Logging and debugging

When a page misbehaves, an order fails, or the server will not start, the
answer is almost always in a log file. This chapter is a tour of everything
Interchange writes and how to make it write more: the per-catalog error log
and the global server log, the `[log]` tag and your own log files, debug
tracing, the on-page inspection tags, user tracking, the common startup
errors, and the `iclint` page checker. It assumes you know how a request is
served ([Architecture](architecture.md)) and how catalogs are configured
([Configuration](configuration.md)); the individual directives and tags each
have a reference page linked from here.

## The logs at a glance

Interchange keeps two independent streams of log output — one for the daemon
as a whole, one per catalog — plus several optional files you turn on
explicitly.

| File | Scope | Turned on by | Written by | Holds |
|------|-------|--------------|------------|-------|
| global error log | server | [ErrorFile](../config/ErrorFile.md) in `interchange.cfg` (or [SysLog](../config/SysLog.md)) | `logGlobal()` | startup, config, and server-level messages |
| catalog error log | catalog | [ErrorFile](../config/ErrorFile.md) in `catalog.cfg` (default `error.log`) | `logError()` | request-level errors and warnings for one store |
| catalog log | catalog | [LogFile](../config/LogFile.md) (default `etc/log`) | `logData()`, the [log](../tags/log.md) tag | delimited data you log yourself |
| debug file | server | [DebugFile](../config/DebugFile.md) in `interchange.cfg` | `logDebug()`, the [debug](../tags/debug.md) tag | developer trace output |
| tracking log | catalog | [TrackFile](../config/TrackFile.md) | `Vend::Track` | one line per qualifying page view |
| order report log | catalog | [AsciiTrack](../config/AsciiTrack.md) | order routing | a copy of every completed order report |

All log paths are resolved and permission-checked the same way other files
are: global paths relative to the Interchange root, catalog paths relative to
the catalog directory, and absolute paths refused unless
[NoAbsolute](../config/NoAbsolute.md) permits them. The server user must be
able to create and append to each file; the containing directory must already
exist.

## The catalog error log

Every catalog logs its request-level errors and warnings to its own
[ErrorFile](../config/ErrorFile.md), which defaults to `error.log` in the
catalog directory. The strap demo points it at a `logs/` subdirectory:

    ErrorFile  __LOGDIR__/error.log

Anything that calls `logError()` — a failed database lookup, a bad payment
response, a caught `[perl]` error, a page that logged with `[log type=error]`
— lands here. Each message is written as one space-delimited line
(`format_log_msg()` in `lib/Vend/Util.pm`):

    127.0.0.1 pRoFcQzD-somesess - [19/July/2026:11:02:14 -0500] strap /cgi-bin/strap/ord/checkout Safe: Undefined subroutine

The fields are the client host (or IP), the session name, the remote user (or
`-`), the timestamp, the catalog name, the script path plus path info, and
then the message. The timestamp format is set by
[LogTimeFormat](../config/LogTimeFormat.md) (a global directive, default
`[%d/%B/%Y:%H:%M:%S %z]`). A multi-line message is folded onto continuation
lines prefixed with `> ` so each record stays greppable.

The file only grows; rotate it yourself (`logrotate`, a [job](jobs.md), or a
cron entry). Interchange never truncates it.

### Routing specific errors elsewhere

[ErrorDestination](../config/ErrorDestination.md) diverts messages whose text
(or explicit `tag`) matches a key to a different file, leaving everything else
in the main log:

    ErrorDestination  "Safe: failed"  logs/safe-errors.log

### Showing errors to the developer

By default a fatal page error is logged and the shopper sees a generic page.
While developing you can surface the real error instead. Two directives named
[DisplayErrors](../config/DisplayErrors.md) — one global, one catalog —
together install a `__DIE__` handler that renders the Perl error into the
response:

    DisplayErrors  Yes     # in catalog.cfg *and* interchange.cfg

Turn it off before the store goes live; it exposes internals to anyone who can
trigger an error.

## The global server log

The daemon itself logs through `logGlobal()` to the global
[ErrorFile](../config/ErrorFile.md) named in `interchange.cfg` — startup and
shutdown banners, config parse errors, catalog (re)configuration, and anything
logged before a catalog context exists. The line format is the same as the
catalog log.

When the server runs in the foreground (see
[Debug mode](#running-in-the-foreground), below) `logGlobal` and `logError`
also echo their messages to the terminal, which is what makes `--DEBUG=1` and
`-t` useful for watching a startup.

### Sending the global log to syslog

Set [SysLog](../config/SysLog.md) and global logging stops writing the flat
file and hands each message to the system logger instead — by default by
piping to `logger(1)`, or through `Sys::Syslog` with `internal 1`:

    SysLog  facility  local3
    SysLog  tag       interchange
    SysLog  warn      local3.info

The `facility`/`tag`/level keys map Interchange's message levels
(`info`, `warn`, `err`, `debug`, ...) onto whatever your syslog configuration
expects. Because a `command` is invoked you can also point it at a wrapper
script. See the [SysLog](../config/SysLog.md) reference for the full key list;
where the messages ultimately land is your syslog daemon's business, not
Interchange's.

Note that `SysLog` governs *global* logging (and, because catalog `logError`
falls through to `logGlobal` when `SysLog` is set, catalog errors too). It
does not touch the debug file or the tracking logs.

## Logging from a page: the [log] tag and LogFile

The [log](../tags/log.md) tag appends a message to a log file from inside a
page or Perl fragment. With no `file` it writes to the catalog
[LogFile](../config/LogFile.md) (default `etc/log`); the `type` attribute
selects the format.

Record a delimited data line to the default log:

    [log]order [value mv_order_number] shipped[/log]

Write an error-formatted line to the catalog error log, interpolating the body
first so it can carry live values:

    [log type=error interpolate=1]
    Checkout failed for [value email].
    [/log]

Append to a log file of your own (the path is access-checked like any file):

    [log file=logs/promo.log]coupon [cgi coupon] applied[/log]

The four `type` values are `text` (verbatim), `quot` (shell-quoted fields),
`error` (through `logError`), and `debug` (through `logDebug`); with no `type`
the body is split into delimited records. The body is **not** interpolated
unless you add `interpolate=1`. See the [log](../tags/log.md) reference for
the delimiter and record-splitting options — and note the documented
`delimiter`-escaping quirk there.

## Surfacing errors and notices on the page

Two session-backed lists let a page collect messages during processing and
render them later.

[warnings](../tags/warnings.md) queues advisory, non-fatal notices in
`$Session->{warnings}` and displays them on a later page:

    [warnings message="Your cart was empty, so nothing was saved."]

    [warnings]          shows and clears the accumulated list

[error](../tags/error.md) is the counterpart for form-validation errors keyed
by field name — the mechanism [order profiles](forms.md) use to report a
failed check:

    [if errors]
      Please fix: [error all=1 show_error=1 joiner="<br>"]
    [/if]

Both take the message text as data, not as ITL, and both integrate with locale
translation ([msg](../tags/msg.md)/[loc](../tags/loc.md)); see
[Internationalization](internationalization.md).

## Inspecting live state with [dump]

[dump](../tags/dump.md) prints the current session, the HTTP environment, and
the CGI/form variables as text — the fastest way to see exactly what
Interchange is holding for a shopper. Wrap it in `<pre>` for a browser:

    <pre>[dump]</pre>

Limit it to one section of the session (for example the carts) by naming a
key, and skip the noisy sections when you only want the session:

    <pre>[dump carts]</pre>
    <pre>[dump no_env=1 no_cgi=1 sort=1]</pre>

`[dump]` suppresses the CGI variables listed in `@Global::HideCGI` (card and
password fields) unless you pass `show_all=1`. Its output can contain
everything a shopper has typed — never leave it on a shopper-facing page and
never ship `show_all=1`.

## Debug tracing

Developer trace output is separate from the error logs and off by default.
Interchange's internal `::logDebug()` calls, and the [debug](../tags/debug.md)
tag, all write to one file named by [DebugFile](../config/DebugFile.md) in
`interchange.cfg`:

    DebugFile debug.log

`logDebug()` short-circuits immediately when `$Global::DebugFile` is unset, so
leaving the directive empty disables debug tracing at essentially no cost. The
daemon opens the file once and redirects a dedicated `Vend::DEBUG` stream to
it (`setup_debug_log()` in `lib/Vend/Server.pm`), writing a
`Start DEBUG at ...` banner. When [SysLog](../config/SysLog.md) is configured,
debug output goes to syslog at `debug` level instead of the file.

Emit your own trace line from a page with [debug](../tags/debug.md) (its body
is interpolated):

    [debug]cart now has [nitems] items[/debug]

From Perl, call `::logDebug()`:

    [calc]
      ::logDebug("coupon lookup: %s", $Scratch->{coupon});
      return;
    [/calc]

A line written without a [DebugTemplate](../config/DebugTemplate.md) looks
like:

    Vend::Interpolate:debug: coupon lookup: SAVE10

that is, the calling package, `:debug:`, and the message.
[DebugTemplate](../config/DebugTemplate.md) replaces that with a format string
of your own, with `{page}`, `{tag}`, `{host}`, `{pid}`, `{session.KEY}`, and
`strftime` fields available.

> **A common surprise:** setting `DebugFile` alone does not make Interchange
> chatty. The `::logDebug()` calls scattered through the shipped source are
> commented out. The file fills only from the `[debug]` tag, your own
> `logDebug` calls, or the features below — enabling the file is necessary,
> not sufficient.

### Narrowing what gets traced

On a busy server the debug file floods. Restrict which requests write to it:

- [DebugHost](../config/DebugHost.md) — only requests from matching client IPs
  produce debug output.
- A `debug_qualify` [SpecialSub](../config/SpecialSub.md) — an arbitrary
  predicate; return false to skip the line.

### DBI and search tracing

Two subsystems route their diagnostics to the same `DebugFile`:

- [DataTrace](../config/DataTrace.md) turns on DBI-level SQL tracing, writing
  every database call to the debug file. It is verbose; the distribution ships
  it commented out.
- A [search](search.md) carrying the `debug` flag emits its parsed
  specification and progress to the debug file — but only when `DebugFile` is
  set.

## Perl warnings

Interchange runs with Perl warnings off in production. To see undefined-value
and similar warnings from `[perl]`, `[calc]`, and embedded Perl during page
interpolation, turn on the
[perl_warnings_in_page](../pragmas/perl_warnings_in_page.md) pragma for a page
or a catalog:

    [pragma perl_warnings_in_page]
    [calc]$undefined + 1[/calc]

The warnings are emitted through the normal error log. Treat it as a
development aid; left on in production it only adds log noise.

For warnings during *startup and config parsing*, run the daemon in the
foreground with warnings enabled (below).

## Catching page errors: [try] and [catch]

A die inside `[perl]`/`[calc]` normally aborts the interpolation of the
enclosing region. Wrap the risky part in [try](../tags/try.md) to trap it, and
report it with [catch](../tags/catch.md):

    [try]
    [calc]
        die "no gateway configured\n" unless $Scratch->{gateway};
        # ... risky work ...
    [/calc]
    [/try]
    [catch]
    Sorry, that could not be processed: $ERROR$
    [/catch]

`[try]` stores any error in the session under its `label` (default `default`);
`[catch]` with the same label runs its body only when an error was trapped and
substitutes it for `$ERROR$`. This keeps a single failing fragment from
blanking the rest of a page while still surfacing the cause to your log or the
developer.

## User tracking

Interchange can record what shoppers view for traffic and affiliate
reporting. The accumulator is `Vend::Track` (`lib/Vend/Track.pm`), created per
request when either [TrackFile](../config/TrackFile.md) or
[UserTrack](../config/UserTrack.md) is on (and, for admin requests, only if
`MV_TRACK_ADMIN` is set). It records page views, product views, add-to-cart
actions, and completed orders as the request runs, then emits them two ways:

- **[TrackFile](../config/TrackFile.md)** writes one line per request to a
  flat log at cleanup time. Setting the path turns tracking on:

      TrackFile  logs/usertrack

  Each line carries the date (formatted by
  [TrackDateFormat](../config/TrackDateFormat.md)), the session name, the
  username, the client host, the epoch time, the traffic
  [source](../config/SourcePriority.md), and the accumulated actions
  (`VIEWPAGE=...`, `ADDITEM=...`, `ORDER=...`), joined with tabs. Which request
  variables ride along on a `VIEWPAGE` record is selected per page by
  [TrackPageParam](../config/TrackPageParam.md) (credit-card fields are always
  excluded).

- **[UserTrack](../config/UserTrack.md)** (a yes/no toggle) instead adds the
  same accumulated data as an `X-Track` HTTP response header, for a front-end
  or log processor to consume. It is off in the strap demo.

You can push a custom action into the current request's tracking data from a
page with the `usertrack` tag (`code/UserTag/usertrack.tag`):

    [usertrack SEARCH [cgi mv_searchspec]]

[AsciiTrack](../config/AsciiTrack.md) is a separate facility despite the name:
it appends a full copy of every completed **order report** to a log, wrapped
in `##### BEGIN ORDER n #####` / `##### END ORDER n #####` banners — a durable
audit trail of orders independent of the backend database. The strap demo
enables it:

    AsciiTrack  __LOGDIR__/tracking.asc

## Starting the server and reading startup errors

Configuration errors are fatal on purpose ([Configuration](configuration.md)),
and they are reported with the file and line number to the global log — and to
the terminal when you start in the foreground. A few command-line facilities
of `bin/interchange` make startup problems visible:

    bin/interchange -t                     # test config, do not start
    bin/interchange --DEBUG=1              # run in the foreground, verbose
    bin/interchange -e problemcat          # start, excluding one catalog

- `-t`/`--test` performs a complete configuration and reports problems without
  starting the server — run it after editing config.
- `--DEBUG=1` runs the daemon in the foreground with warnings on and log
  output echoed to the terminal, so you watch every message as it happens. In
  the shipped `interchange.cfg` an `ifdef @DEBUG` block also switches on
  `DebugFile debug.log` and [DumpStructure](../config/DumpStructure.md).
- `-e name`/`--exclude=name` skips a catalog whose own config is broken so the
  rest of the server can come up while you fix it.

### Common startup messages

- **`Unknown directive`** — a catalog directive placed in `interchange.cfg` or
  vice versa, or a typo. Directives are level-specific; see
  [Configuration](configuration.md).
- **`Unable to open ... error.log`** / permission errors — the log directory
  does not exist yet or the server user cannot write it. Create the directory
  and fix ownership.
- **catalog `config error ... Skipping`** — one catalog failed to compile; the
  server continues without it (this is the message `-e` lets you pre-empt).
- **`Missing global sub`, `Safe: ...`** — code-bearing directives or catalog
  Perl failed; the [Require](../config/Require.md) and
  [Suggest](../config/Suggest.md) directives assert dependencies up front so
  these fail loudly at config time rather than mysteriously at request time.

[DumpAllCfg](../config/DumpAllCfg.md) (every config line the server read, with
includes expanded) and [DumpStructure](../config/DumpStructure.md) (the
compiled config as a data structure) are the heavy tools when a directive is
not taking effect and you need to see what the parser actually built.

## Linting pages before deploy

`eg/iclint` is a standalone static checker for ITL pages. It reads a page,
strips comment/`[perl]`/`[calc]` blocks, and walks the remaining tags to catch
the everyday mistakes — an unknown tag name, a container tag left unclosed (or
closed when it should not be), a missing required argument, or the classic
`[if foo]` where `[if scratch foo]` was meant:

    perl eg/iclint pages/ord/checkout.html

    Checking pages/ord/checkout.html...
    ERROR: Tag: "if" Problem: Invalid argument "foo"

Useful options: `--dietag=1` to stop on the first unknown tag, `--warntagonce=1`
to collapse repeats, `--errorexit=0` to report everything without exiting, and
`--verbose=1` for a running trace. It works from a hand-maintained tag table in
its own `__DATA__` section, so it knows the core tags but not your custom
usertags — an unknown-tag warning for one of your own tags is expected, not a
real problem. Treat it as a fast lint pass, not a substitute for exercising the
page.

## See also

- [Configuration](configuration.md) — how config is parsed, and the reconfig
  and startup-debugging directives ([DumpAllCfg](../config/DumpAllCfg.md),
  [Message](../config/Message.md), [Require](../config/Require.md))
- [Templating](templating.md) — the interpolation pipeline these tags run in
- [Security](security.md) — why `[dump]`, `DisplayErrors`, and `show_all` must
  stay off public pages
- Reference pages: [ErrorFile](../config/ErrorFile.md),
  [DebugFile](../config/DebugFile.md), [SysLog](../config/SysLog.md),
  [TrackFile](../config/TrackFile.md), [LogFile](../config/LogFile.md);
  tags [log](../tags/log.md), [debug](../tags/debug.md),
  [dump](../tags/dump.md), [warnings](../tags/warnings.md),
  [error](../tags/error.md), [try](../tags/try.md), [catch](../tags/catch.md)
</content>
</invoke>
