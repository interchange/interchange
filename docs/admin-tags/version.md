# version

Report Interchange version and system information: the server version, the
database and Perl module inventory, locale and environment details, and the
result of testing whether a named Perl module is installed. Reach for it on an
admin status page, or to probe module availability from a template.

This tag is part of the administrative UI toolset: it is loaded from
`code/UI_Tag/` when the back-office UI is enabled, and is not a storefront
tag.

## Syntax

    [version]
    [version extended=1 modules=1 perl=1 ...]

Standalone tag (no end tag). Its output is HTML (line breaks, links, and
preformatted blocks) and is reparsed as Interchange Tag Language (ITL) by
default; the report itself contains no ITL.

The tag name is registered as `version`.

## Attributes

| Attribute              | Default | Description |
|------------------------|---------|-------------|
| `extended`             | `0`     | Master switch for the detailed report. Positional parameter 1. When false, the tag returns only the bare version number and ignores every other attribute (see Description). |
| `joiner`               | `<br>`  | String placed between report lines. |
| `global_error`         | `0`     | Include the path of the global (`interchange.cfg`) error file. |
| `local_error`          | `0`     | Include the catalog error file, rendered as a link into the admin file viewer. |
| `env`                  | `0`     | Include the names of passed-through environment variables (see [Environment](../config/Environment.md)). |
| `safe`                 | `0`     | Include the [SafeUntrap](../config/SafeUntrap.md) opcode list. |
| `child_pid`            | `0`     | Include the current child process PID. |
| `pid`                  | `0`     | Include the parent PID read from the PID file. |
| `mode`                 | `0`     | Include the server run mode (for example PreFork). |
| `uid`                  | `0`     | Include the process user name and numeric UID. |
| `global_locale_options`| `0`     | Include the configured locale codes and language names. |
| `perl`                 | `0`     | Include the Perl version and the path to the Perl binary. |
| `perl_config`          | `0`     | Include the output of `Config::myconfig()` in a `<pre>` block. |
| `hostname`             | `0`     | Include the machine host name. |
| `modtest`              | none    | Name of a Perl module to test with `require`; the tag emits `1` if it loads, `0` if not. |
| `db`                   | see below | Include database-support information (GDBM, Berkeley DB, LDAP, and the available DBI drivers). |
| `modules`              | `0`     | Include the inventory of Interchange-related Perl modules, marking each found (with version) or not found (with a note on what it affects). |

Positional order: `extended`.

Aliases: `module_test`, `moduletest`, and `require` are all aliases for
`modtest`.

The tag declares `addAttr`, so unrecognized attributes are accepted but
ignored.

## Description

Called with no arguments, `[version]` returns only the Interchange version
string (the value of `$::VERSION`, for example `5.12.0`). This is because the
routine short-circuits and returns immediately unless its first positional
argument, `extended`, is true. **To get any of the detailed sections you must
pass `extended=1`** (or a truthy first positional argument); otherwise the
other switches have no effect.

With `extended` set, each switch above appends its section to the report,
joined by `joiner` (default `<br>`). When `extended` is on but none of the
detail switches are set, the tag defaults to including the version banner and
the `db` section.

The `db` section reports whether GDBM, Berkeley `DB_File`, and LDAP support are
compiled in (with their module versions), and lists the DBI drivers available
on the system. The `modules` section walks a fixed list of optional and
required Perl modules — among them `DBI`, `Digest::SHA`, `Safe::Hole`,
`Business::UPS`, `Spreadsheet::ParseExcel`, and `Set::Crontab` — and for each
reports the installed version or a note describing what breaks without it.

The `modtest` switch is a lightweight availability probe usable outside the
status page: `[version extended=1 modtest=SomeModule]` returns `1` or `0` for
whether `require SomeModule` succeeds.

## Examples

Bare version number:

    [version]

produces (with the strap demo on Interchange 5.12):

    5.12.0

Test whether the `DBI` module is installed:

    [version extended=1 modtest=DBI]

produces:

    1

Full status report, as an admin diagnostics page might invoke it:

    [version
      extended=1
      global_error=1
      local_error=1
      env=1
      safe=1
      pid=1
      child_pid=1
      mode=1
      uid=1
      global_locale_options=1
      perl=1
      perl_config=1
      hostname=1
      db=1
      modules=1
      modtest=DBI
    ]

## Notes

- The `extended` gate is easy to miss: `[version modules=1]` without
  `extended=1` returns just the version number, not the module list. This is
  current code behavior.
- Output is HTML and assumes a browser context (it emits `<br>`, `<a>`, and
  `<pre>` markup).

## See also

- [Environment](../config/Environment.md) and
  [SafeUntrap](../config/SafeUntrap.md) — directives surfaced in the report
- The [logging and debugging guide](../guides/logging-debugging.md)
- The [admin UI guide](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/version.coretag` as an inline Routine. It reads
`$::VERSION`, the `$Global::*` configuration, and probes Perl modules with
`require`.
