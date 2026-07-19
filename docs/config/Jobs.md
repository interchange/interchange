# Jobs

Configures Interchange's batch **jobs** facility -- scheduled or on-demand
runs of catalog pages executed outside a normal web request. Reach for it
to set global job-server limits and, per catalog, where job files live and
how their output is logged or emailed.

**Scope:** both (`interchange.cfg` global, `catalog.cfg` catalog)

## Syntax

    Jobs  KEY  VALUE

Parsed as key/value pairs into a hash (often written as a here-document for
several keys). The available keys differ by scope. Global default:
`MaxLifetime 600 MaxServers 1 UseGlobal 0`. Catalog default: empty.

## Description

A *job* is a catalog page (or set of pages) run by the Interchange daemon
without a browser -- used for periodic tasks such as importing data,
sending queued email, or rolling up reports. Jobs are launched from the
command line (`interchange --runjobs=CATALOG=DIRECTORY`) or scheduled with
[HouseKeepingCron](HouseKeepingCron.md), and executed by the job runner.

### Global

The global `Jobs` directive governs the server-wide job engine:

| Key | Default | Effect |
|-----|---------|--------|
| `MaxLifetime` | 600 | Maximum seconds a job server is allowed to run before it is reaped. |
| `MaxServers` | 1 | Maximum number of concurrent job servers; excess jobs queue. |
| `UseGlobal` | 0 | If true, always also search for global job definitions. |

### Catalog

The catalog `Jobs` directive controls how one catalog's jobs are found and
what happens to their output:

| Key | Default | Effect |
|-----|---------|--------|
| `base_directory` | `etc/jobs` | Directory (relative to catalog root) searched for job files. |
| `use_global` | false | Also search the global job directory. |
| `autoload` | none | Macro run before each individual file in the job. |
| `autoend` | none | Macro run after each individual file in the job. |
| `initialize` | none | Macro run once before the job starts. |
| `suffix` | none | Restrict the job to files matching this suffix. |
| `log` | none | Write job output to this log file. |
| `filter` | `strip` | Filter(s) applied to job output. |
| `email` | none | Email job output to this address. |
| `from` | [MailOrderTo](MailOrderTo.md) | "From" address for job email. |
| `reply_to` | none | "Reply-To" address for job email. |
| `extra_headers` | none | Additional email headers. |
| `subject` | `Interchange results for job: %s` | Subject line (`%s` is the job name). |
| `ignore_errors` | false | Exclude fatal errors from job output. |
| `add_session` | false | Append a session dump to job output. |
| `trackdb` | none | Database table in which to record job tracking. |

When run from the command line, jobs are only queued and the shell returns
before they execute. A shared temporary session is created for the queued
files (remote IP `none`, user agent `commandline`) and closed when the
job completes.

## Examples

Catalog-level job settings, from the strap demo `catalog.cfg`:

```
Jobs  log    logs/jobs.log
Jobs  base_directory  etc/jobs
```

A fuller catalog block written as a here-document:

```
Jobs <<EOJ
  log             logs/jobs.log
  base_directory  jobs
  email           root@example.com
EOJ
```

Global job-server tuning (put in `interchange.cfg`):

```
Jobs MaxServers 2 MaxLifetime 900
```

Run a catalog's jobs from a Unix crontab entry:

```
12 2 * * * su -c '/path/to/interchange --quiet --runjobs=mycat=etc/jobs' ic
```

## Notes

Files in the jobs directory whose names end in the catalog's
[HTMLsuffix](HTMLsuffix.md) are silently ignored, so ordinary page
templates left in the directory do not run as jobs.

## See also

[HouseKeepingCron](HouseKeepingCron.md), [MailOrderTo](MailOrderTo.md),
[HTMLsuffix](HTMLsuffix.md), the [jobs](../guides/jobs.md) guide.

## Source

Parsed by `parse_hash` in `lib/Vend/Config.pm`. Global keys are consumed
in `lib/Vend/Server.pm`; catalog keys drive the job runner in
`lib/Vend/Dispatch.pm`.
