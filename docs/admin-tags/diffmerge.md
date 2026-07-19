# diffmerge

Three-way merge of two edits of a common ancestor text, using the system
`diff3`, returning the merged result with conflict markers. It is part of
the administrative UI toolset (loaded only when the admin UI is enabled),
not a storefront tag; the admin uses it to reconcile two versions of a page
or record that were both changed from the same starting point.

## Syntax

    [diffmerge yours older mine]
    [diffmerge yours=... older=... result=scratchname] MINE-TEXT [/diffmerge]

Container tag (has an end tag). Its body, when present, supplies the `mine`
text. Output is interpolated by default. The shipped admin invokes it as
`[diffmerge ...]`.

## Attributes

| Attribute   | Default | Description |
|-------------|---------|-------------|
| `yours`     |         | One edited version: file path or `Table::Column::Key`. |
| `older`     |         | The common ancestor: file path or `Table::Column::Key`. |
| `mine`      |         | The other edited version: file path or `Table::Column::Key`. May instead be given as the tag body. |
| `flags`     |         | Extra flags passed to the `diff3` command line. |
| `ascii`     |         | Normalize CR/LF to LF and ensure a trailing newline before merging. |
| `safe_data` |         | Pull database data raw, without escaping `[` to `&#91;`. |
| `result`    |         | Name of a scratch variable to receive the `diff3` exit code (non-zero means a conflict was detected). |

Positional order: `yours`, `older`, `mine`.
Aliases: `current` and `curr` for `mine`; `previous` and `prev` for `yours`;
`old` for `older`.

## Description

The three inputs follow the `diff3` manual's naming: an `older` ancestor
that both `mine` and `yours` were edited from. Each input may be a filename
or a `table::column::key` database reference; database references are read
with the underlying [data](../tags/data.md) accessor and written to
per-session temporary files under `tmp/`. If the tag has a body, that body
is used as `mine` (overriding a `mine` attribute).

The command run is:

    diff3 -m <flags> <mine-file> <older-file> <yours-file>

`diff3 -m` produces a merged document; where the two edits conflict it
inserts the usual `<<<<<<<` / `=======` / `>>>>>>>` conflict markers. The
merged text is returned.

When `result` names a valid scratch variable, the tag stores `diff3`'s exit
code there (`0` = clean merge, non-zero = conflict), so a page can branch on
whether the merge needs human review. Flags are validated against
`^[-\s\w.]*$`; anything else is refused and logged.

## Examples

Merge three files, capturing the outcome:

    [diffmerge /tmp/mine /tmp/older /tmp/yours result=merge_status]
    [if scratch merge_status]Conflicts were found.[/if]

Merge a newly edited page body (in the tag body) against the current stored
version, using a backup as the common ancestor:

    [diffmerge
        yours="content::pagebody::00001"
        older="backup::pagebody::00001"
        ascii=1
        result=diff_result
        safe_data=1
    ][scratch new_pagebody][/diffmerge]

## Notes

- The tag shells out to `diff3`, which must be installed on the server.
- The exit code is only stored when `result` is a bare word (a valid scratch
  variable name); an invalid name is logged and ignored.

## See also

- [diff](diff.md) — two-way diff
- [data](../tags/data.md) — database field access
- The [admin UI guide](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/diffmerge.coretag`. Implemented by the inline
Routine in that file (which calls the system `diff3 -m`).
