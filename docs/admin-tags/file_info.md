# file_info

Report information about a file on the server: its size, modification time,
a formatted description, or the results of file-test operators. It is part
of the administrative UI toolset (loaded only when the admin UI is enabled),
not a storefront tag; the admin uses it to show file sizes and dates on
download and status screens.

## Syntax

    [file_info name]
    [file_info name=... size=1]
    [file_info name=... fmt="..."]

Standalone tag. Interchange treats `-` and `_` as equivalent in tag names,
so the shipped admin writes it as `[file-info ...]`; that is the same tag.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `name`    |         | Path to the file, relative to the catalog directory unless a base option is set. |
| `server`  |         | Resolve `name` relative to the Interchange root (`$Global::VendRoot`). |
| `conf`    |         | Resolve `name` relative to the configuration directory (`$Global::ConfDir`). |
| `run`     |         | Resolve `name` relative to the run directory (`$Global::RunDir`). |
| `size`    |         | If true, return the raw byte size. |
| `time`    |         | If true, return the raw modification time (Unix epoch seconds). |
| `date`    |         | If true, return the modification time formatted with the locale `%c`. |
| `flags`   |         | One or more file-test letters (see below); returns tab-joined results. |
| `fmt`     | see below | `strftime`-style format for the default output. |
| `gmt`     |         | Format times in GMT rather than local time. |

Positional order: `name` (the first parameter).
Alias: `file` for `name`.

## Description

The tag `stat`s the file and, depending on the options, returns one facet of
the result:

- `size` returns the exact byte count; the default format instead shows a
  human-friendly size (`K`/`M` suffixed).
- `time` returns epoch seconds; `date` returns a locale-formatted date.
- `flags` runs Perl file-test operators. Each letter in the value (for
  example `rwx`) becomes a `-r`, `-w`, `-x` test against the file, and the
  results are returned joined by tabs.

With none of those, the tag formats the modification time with `fmt`, whose
default is:

    %f bytes, last modified %Y-%m-%d %H:%M:%S

where `%f` is replaced by the human-friendly size and the remaining
`strftime` codes by the modification time (through the [time](../tags/time.md)
tag, honoring the session locale).

## Examples

Show a download link with the file's size and date (the demo admin does
this on its backup screen):

    [file_info name="[var BACKUP_DIRECTORY]/DBDOWNLOAD.xls" date=1],
    [file_info name="[var BACKUP_DIRECTORY]/DBDOWNLOAD.xls" size=1] bytes

Raw modification time of the server PID file, then formatted with
[calc](../tags/calc.md):

    [calc]scalar localtime([file_info conf=1 name="interchange.pid" time=1])[/calc]

Default one-line description:

    [file_info name="products/products.txt"]

produces something like:

    12.34K bytes, last modified 2026-07-19 09:15:02

## Notes

- Paths are resolved relative to the catalog directory unless `server`,
  `conf`, or `run` selects a different base.
- On a missing file the underlying `stat` fails and the size/time fields are
  empty.

## See also

- [file_navigator](file_navigator.md) — browse and act on files
- [time](../tags/time.md) — date/time formatting
- The [admin UI guide](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/file_info.coretag`. Implemented by the inline
Routine in that file.
