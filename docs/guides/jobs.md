# Scheduled jobs

Interchange can run catalog pages on a schedule or on demand, with no browser
and no HTTP request behind them — a **job**. Jobs are how you send queued
notification email, roll up nightly reports, import a price feed, expire stale
records, or push transactions to an external service, all inside the running
daemon with full access to the catalog's databases, tags, and
[Variables](../config/Variable.md). This chapter explains what a job is, where
job files live, the two ways to launch one (the `bin/interchange` command line
and the built-in [HouseKeepingCron](../config/HouseKeepingCron.md) scheduler),
how the runner treats a job's output, and how to tune concurrency. It ends
with strap's shipped nightly job as a worked example.

A job is not a separate program. It is ordinary Interchange Tag Language (ITL)
— the same language you write in [pages](templating.md) — executed by the
daemon in a throwaway session. Anything a page can do, a job can do.

## What a job is

Concretely, a job is one or more text files, each interpolated as ITL, grouped
into a directory. That directory is a **job group**, and its name is the job
name you run. A minimal group is a single file:

    etc/jobs/
      hello/
        run                 <- one file, interpolated as ITL

Where a web page returns HTML to a browser, a job's interpolated output is
collected and then logged, emailed, or discarded (see
[Output](#output-logging-and-email) below) — the browser is replaced by a log
file or a mailbox. A job runs with the catalog fully open: `$Db{...}`,
`$Sql{...}`, `$Tag`, `$Variable`, and every tag are available exactly as in a
[Perl embedding](perl-embedding.md) block on a page.

Two directives govern jobs, both documented in the reference and both usable
at either scope:

- [Jobs](../config/Jobs.md) — where a catalog's job files live and what
  happens to their output, plus the global job-server limits.
- [HouseKeepingCron](../config/HouseKeepingCron.md) — an in-server crontab that
  can launch job groups (and other work) on precise schedules.

## Where job files live

Each catalog looks for job groups under the directory named by the `Jobs`
directive's `base_directory` key, relative to the catalog root. The default is
`etc/jobs`:

    Jobs  base_directory  etc/jobs

To run the group `daily`, the runner looks for the directory
`etc/jobs/daily/` and interpolates every **file** directly inside it. The
rules the runner applies (`run_in_catalog` in `lib/Vend/Dispatch.pm`) are:

- **Files only, one level deep.** Subdirectories are skipped; the scan is not
  recursive.
- **Page templates are ignored.** Any file whose name ends in the catalog's
  [HTMLsuffix](../config/HTMLsuffix.md) (default `.html`) is skipped, so you
  can leave ordinary `.html` templates in the directory without them running
  as jobs.
- **Optional suffix filter.** If you set the `suffix` key, only files whose
  names match that suffix run. With no `suffix` set, all remaining files run.
- **Order is filesystem glob order** (effectively alphabetical). Name files so
  that any that must run first sort first.

The file contents are plain ITL. A one-file group that emails a low-stock
warning might be `etc/jobs/daily/lowstock`:

    [query
       table=inventory
       list=1
       sql="SELECT sku, quantity FROM inventory WHERE quantity < 5"
    ][sql-code]: [sql-param quantity] left
    [/query]

Every file in the group contributes to one combined output string; the runner
concatenates them in the order they run.

## Running a job group from the command line

`bin/interchange --runjobs` asks a **running** daemon to run a job group:

    bin/interchange --runjobs=strap=daily

The argument is `catalog=job`. The command does not run the job itself — it
writes a request to the `jobsqueue` file in [RunDir](../config/RunDir.md) and
signals the daemon, then returns immediately (`signal_jobs` in
`lib/Vend/Control.pm`). The daemon picks the request up on its next
**housekeeping** pass (see [Architecture](architecture.md) and
[HouseKeeping](../config/HouseKeeping.md)), so there is a short delay of up to
one housekeeping interval before the job actually runs. The daemon must be up;
`--runjobs` against a stopped server has nothing to signal.

The job name can also be supplied separately with `--jobgroup`, which **must**
come before `--runjobs` on the command line:

    bin/interchange --jobgroup=daily --runjobs=strap     # works
    bin/interchange --runjobs=strap --jobgroup=daily     # does NOT work

To have the results mailed instead of (or in addition to) logged, add
`--email`:

    bin/interchange --runjobs=strap=daily --email=ops@example.com

Because `--runjobs` only queues, this is exactly what you put in a system
crontab when you want the OS `cron` to drive Interchange's jobs:

    # min hour dom mon dow   (standard 5-field Unix crontab)
    12 2 * * *  su -c '/usr/local/interchange/bin/interchange --quiet --runjobs=strap=daily' interch

The daemon keeps running; each crontab line just drops a request into the
queue.

> **Note — the third field.** `--runjobs` accepts an undocumented third
> element, `catalog=job=N`, that `signal_jobs` turns into `now + N`. In the
> housekeeping queue this value is treated as an **expiry deadline**, not a
> start delay: if it has already passed when housekeeping runs, the request is
> dropped as expired; otherwise the job runs at the next pass as usual. It does
> not postpone a job by N seconds. Leave it off unless you specifically want a
> request to self-cancel if the daemon was too busy to service it in time.

## What happens when a job runs

The runner (`run_in_catalog`) executes a job group in this sequence:

1. **Open the catalog** and set the process name to `job CATALOG JOB` (visible
   in `ps`).
2. **Run the `initialize` macro** once, if configured (see
   [macros](#macros-initialize-autoload-autoend) below).
3. **Create a temporary session** unless `initialize` already made one. It is a
   throwaway session (`mv_tmp_session`) with remote address `none` and user
   agent `commandline` — there is no real client, so `[value]`, source
   tracking, and anything IP-based start empty.
4. **For each file in the group:** run the `autoload` macro, interpolate the
   file as ITL and append its output, then run the `autoend` macro.
5. **Filter, assemble, and dispatch the output** (next two sections).
6. **Close the catalog.**

If any file dies during interpolation, the run stops with an error: the failure
is logged, a job flag is furled (see [flag_job](#coordinating-with-flag_job)),
and — unless `ignore_errors` is set — the error message is prepended to the
output.

### Macros: initialize, autoload, autoend

Three `Jobs` keys let you hook Perl or ITL around the run. Each names a
**macro**, which the runner resolves (`run_macro`) as, in order: a catalog
[Sub](../config/Sub.md), a [GlobalSub](../config/GlobalSub.md), a
`tag-profile` name, or literal ITL to interpolate.

| Key | Runs |
|-----|------|
| `initialize` | once, before the session is created |
| `autoload` | once before **each** file in the group |
| `autoend` | once after **each** file in the group |

`initialize` is the place to set up a database handle or acquire a lock for the
whole group; `autoload`/`autoend` wrap each individual file. All three are
optional and most jobs use none of them.

## Configuring the runner: the Jobs directive

[Jobs](../config/Jobs.md) is parsed as `key value` pairs into a hash, so you
write one key per line or several in a here-document. The keys split by scope.

**Catalog scope** (`catalog.cfg`) — where this catalog's jobs are found and
what becomes of their output:

    Jobs <<EOJ
      base_directory  etc/jobs
      log             logs/jobs.log
      email           ops@example.com
      filter          strip
    EOJ

The full key set (`base_directory`, `suffix`, `use_global`, the three macros,
`log`, `filter`, `email`, `from`, `reply_to`, `extra_headers`, `subject`,
`ignore_errors`, `add_session`, `trackdb`) is tabulated on the
[Jobs reference page](../config/Jobs.md); this guide covers the ones you reach
for most.

**Global scope** (`interchange.cfg`) — the server-wide job engine, with the
built-in default `MaxLifetime 600 MaxServers 1 UseGlobal 0`:

    Jobs  MaxServers 2  MaxLifetime 900

- `MaxServers` caps how many job servers run at once. With the default `1`,
  one job runs per housekeeping pass and any others stay in `jobsqueue` for the
  next pass; a queue over 20 entries is refused with a log warning.
- `MaxLifetime` (seconds) bounds a single job server's runtime before the
  daemon reaps it — a runaway import cannot pin a process forever.
- `UseGlobal` turns on the global job directory for every catalog (see
  [Global job directories](#global-job-directories) below).

## Output: logging and email

A job's combined output is passed through a [filter](../filters/README.md)
chain — the `filter` key, default `strip` (trim leading/trailing whitespace).
Then, following the spirit of the Unix cron daemon, **empty output is silently
dropped**: nothing is logged and nothing is mailed. A well-behaved job that has
nothing to report emits nothing and stays quiet. When output is non-empty:

- **`log`** appends the output to the named file (relative to the catalog
  root), via `logData`. strap uses `logs/jobs.log`.
- **`email`** mails the output to the given address. `from` defaults to
  [MailOrderTo](../config/MailOrderTo.md); `subject` defaults to
  `Interchange results for job: %s` (where `%s` is the job name); `reply_to`
  and `extra_headers` fill in the corresponding headers. A `--runjobs --email`
  address, or an `email=` job parameter, overrides the configured `email`.

Two more keys shape what counts as output: `ignore_errors` keeps a job's fatal
error message out of the output (so a failure produces no mail/log unless the
job also printed something), and `add_session` appends a full session dump for
debugging.

If you want a job to record *that* it ran regardless of output, set `trackdb`
to a table with `name`, `begin_run`, `pid`, and `end_run` columns; the runner
writes a row at start and stamps `end_run` at finish.

## Scheduling inside Interchange: HouseKeepingCron

You do not need a system crontab. [HouseKeepingCron](../config/HouseKeepingCron.md)
is a crontab that lives in `interchange.cfg` and is evaluated by the daemon on
every housekeeping wakeup. Setting it **replaces** Interchange's default
housekeeping cycle, so you take on responsibility for the periodic work the
default did — which is why the `:reconfig` and `:jobs` targets exist.

Each line is **six** time fields — seconds, minutes, hours, day-of-month,
month, day-of-week (one more than a standard Unix crontab, note the leading
seconds field) — followed by a target:

    HouseKeeping 1 minute

    HouseKeepingCron <<EOC
    0 0 * * * *  =strap daily
    */5 * * * * * :reconfig
    */5 * * * * * :jobs
    EOC

Targets come in several prefixes (decoded in `lib/Vend/Cron.pm`):

| Prefix | Meaning |
|--------|---------|
| `=cat group` | Run job `group` in catalog `cat` **directly**, in-process, no queue file. |
| `:reconfig` `:jobs` `:restart` | Service the corresponding request file for this pass (reconfig requests, the command-line `jobsqueue`, restart requests). |
| `>macro` | Run a macro (Sub/GlobalSub/ITL) **after** the reconfig/jobs/restart cycle. |
| `macro` / `<macro` | Run a macro **before** that cycle (the default). |

The key distinction for jobs: `=strap daily` launches the `daily` group itself,
directly. `:jobs` instead tells the daemon to service the `jobsqueue` file that
`bin/interchange --runjobs` writes — leave `:jobs` out and command-line
`--runjobs` requests are silently ignored. Interchange warns at startup if
`:reconfig` or `:jobs` is absent:

    WARNING: suggested cron entry ':jobs' not present.

Because there is no browser request, `HouseKeepingCron` targets run at the
global level with no catalog request context; `=cat group` opens the catalog
for the job exactly as `--runjobs` does. `HouseKeepingCron` requires the
`Set::Crontab` Perl module. See its
[reference page](../config/HouseKeepingCron.md) for the full field syntax
(ranges, `*/N` steps, and the `Set::Crontab` `<N`/`>N`/`!N` extensions).

### Which scheduler to use

- **System cron + `--runjobs`** — familiar, visible in `crontab -l`, and the
  requests survive if you are restarting the daemon around them. Runs through
  the queue, so subject to `MaxServers` and up to a housekeeping interval of
  latency.
- **`HouseKeepingCron` with `=cat group`** — no external dependency, schedules
  live in `interchange.cfg`, second-level granularity. But it runs the job
  directly (bypassing the `jobsqueue`/`MaxServers` accounting), and if the
  daemon is down the schedule is down.

## Global job directories

A job group normally lives under one catalog. To share groups across every
catalog on the server, put them under `$Global::ConfDir/jobs` (the server's
`etc/jobs`) and enable the global search. The runner appends the global
directory to its search path when **either** the catalog's `use_global` key or
the global `Jobs UseGlobal` is true:

    # interchange.cfg — every catalog may use global groups
    Jobs  UseGlobal 1

    # or, per catalog in catalog.cfg
    Jobs  use_global 1

The catalog's own `base_directory` is searched first; the global directory is
used only if the group is not found there. Files loaded from the global
directory run under a tightened
[file-access regex](../config/AllowGlobal.md)-style guard scoped to that
directory. The distribution ships example global groups under `dist/etc/jobs/`
(`db/export`, `maintenance/logrotate`, `merchandising/topsellers`).

## Worked example: strap's nightly job

The strap demo ships a ready job. Its `catalog.cfg` configures the runner:

    Jobs  log             logs/jobs.log
    Jobs  base_directory  etc/jobs

and provides the group `etc/jobs/daily/` with one file, `stock_alert`. The file
is a single [perl](perl-embedding.md) block that walks the `stock_alert` table
(customers who asked to be told when an out-of-stock item returns), checks
current `inventory`, emails anyone whose item is back, removes them from the
table, and returns one status line per message sent:

    [perl tables="stock_alert products, inventory"]
        my $db = $Db{stock_alert};
        my @msgs;
        # ... find back-in-stock SKUs, email the waiting customers ...
        return join "\n", @msgs;
    [/perl]

The `return` value is the file's output. On a night when three customers get
notified, the job returns three lines; those lines are `strip`-filtered and
appended to `logs/jobs.log`. On a quiet night the block returns an empty string
and — per the empty-output rule — nothing is logged at all.

Run it by hand against a running strap daemon:

    bin/interchange --runjobs=strap=daily

or schedule it to run at 2:15 every morning from `interchange.cfg`:

    HouseKeepingCron <<EOC
    0 15 2 * * *  =strap daily
    */5 * * * * *  :jobs
    */5 * * * * *  :reconfig
    EOC

strap also ships two on-demand groups used by its tax integration —
`load_tax_averages` and `send_tax_transactions`, each a single `execute` file —
which you run the same way (`--runjobs=strap=send_tax_transactions`) when you
want to push queued tax data.

## Coordinating with flag_job

Long-running or overlapping jobs sometimes need to leave a token that another
process can test — "this import is already in progress." The
[flag_job](../tags/flag_job.md) tag exposes that mechanism, delegating to
`Vend::Server::flag_job`. Its real actions (in `lib/Vend/Server.pm`) are
`raise` (create a flag file for a numeric token, plus a per-PID symlink),
`check` (test whether a numeric token's flag exists, returning 1 or 0), and
`furl` (remove the current process's flag — done automatically when a job dies
with an error). This is advanced and rarely needed; most jobs never touch it.

> **Note.** The [flag_job](../tags/flag_job.md) reference page currently shows
> an example using a `set` action, but `set` is not one of the actions
> `Vend::Server::flag_job` implements (`raise`, `check`, `furl`), and `check`
> requires a numeric token. Prefer the action names above until that page is
> reconciled with the code.

## Troubleshooting

- **The job never runs.** `--runjobs` only queues; confirm the daemon is
  running, that `:jobs` is present if you set `HouseKeepingCron`, and that you
  waited a full [HouseKeeping](../config/HouseKeeping.md) interval.
- **No output appeared.** Empty output is intentionally dropped. Have the job
  emit at least one line while testing, and confirm `log` (or `email`) is set.
- **A `.html` file in the group is skipped.** That is the
  [HTMLsuffix](../config/HTMLsuffix.md) rule; rename the file if it really is a
  job.
- **Jobs pile up.** With `MaxServers 1` only one runs per pass; a long job
  serializes the rest. Raise `MaxServers`, or move heavy work to
  `HouseKeepingCron`'s direct `=cat group` targets.
- **`[value]` and client data are empty.** Correct — a job has a throwaway
  session with no real request. Read what you need from the database, not from
  the (nonexistent) visitor.
- **Watch the logs.** The runner logs `Run jobs group=...` / `Finished jobs
  group=...` to the catalog error log; strap routes those and its output to
  dedicated files with [ErrorDestination](../config/ErrorDestination.md).

## See also

- [Jobs](../config/Jobs.md) — every configuration key, both scopes
- [HouseKeepingCron](../config/HouseKeepingCron.md) — full cron field syntax
- [HouseKeeping](../config/HouseKeeping.md) — the housekeeping interval jobs
  ride on
- [flag_job](../tags/flag_job.md) — the job-flag tag
- [Architecture](architecture.md) — the daemon, forking, and housekeeping
- [Perl embedding](perl-embedding.md) — writing the `[perl]`/`[calc]` logic a
  job file contains
- [Email](email.md) — how job result mail is sent
- [Logging and debugging](logging-debugging.md) — where job output and errors
  land
