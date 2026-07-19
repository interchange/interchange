# diff

Run the system `diff` program between two texts and return its output. Each
side may be a file path or a database field addressed as
`Table::Column::Key`. It is part of the administrative UI toolset (loaded
only when the admin UI is enabled), not a storefront tag; the admin uses it
to show what changed between a stored page or record and a backup.

## Syntax

    [diff current previous]
    [diff current=... previous=... unified=1]

Standalone tag. The shipped admin invokes it as `[diff ...]`.

## Attributes

| Attribute   | Default | Description |
|-------------|---------|-------------|
| `current`   |         | The "new" side: a file path or `Table::Column::Key`. |
| `previous`  |         | The "old" side: a file path or `Table::Column::Key`. |
| `flags`     |         | Extra flags passed to the `diff` command line. |
| `context`   |         | If true, add `-c` (context diff). |
| `unified`   |         | If true, add `-u` (unified diff). |
| `ascii`     |         | Normalize CR/LF to LF and ensure a trailing newline before diffing. |
| `safe_data` |         | Pull database data raw, without escaping `[` to `&#91;`. |

Positional order: `current`, `previous`.
Alias: `curr` for `current`; `prev` for `previous`.

## Description

Either argument may be given directly as a filename, or in the form
`table::column::key` (matched loosely as word characters, then column, then
key). When a database reference is given, the tag reads that field with the
underlying [data](../tags/data.md) accessor and writes it to a temporary
file under `tmp/` named for the session before diffing.

The final command run is:

    diff <flags> <previous-file> <current-file>

so additions in `current` appear as added lines. Flags are validated against
`^[-\s\w.]*$`; anything else is refused and logged as a security violation.

The return value is the raw output of `diff` (empty when the two sides are
identical).

## Examples

Compare two files on disk:

    [diff current="pages/flypage.html" previous="backup/flypage.html"]

Unified diff between a live content field and its backup copy, tolerating
different newline conventions:

    [diff
        current="content::pagebody::00001"
        previous="backup::pagebody::00001"
        unified=1
        ascii=1]

## Notes

- The tag shells out to the external `diff` binary, which must be on the
  server's `PATH`.
- Temporary files are written under the catalog's `tmp/` directory keyed by
  session name, so concurrent requests in one session reuse the same names.

## See also

- [diffmerge](diffmerge.md) — three-way merge with conflict markers
- [data](../tags/data.md) — database field access
- The [admin UI guide](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/diff.coretag`. Implemented by the inline Routine in
that file (which calls the system `diff`).
