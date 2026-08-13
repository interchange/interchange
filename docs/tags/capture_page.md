# capture_page

Render an Interchange page and capture its finished output — into a scratch
variable, a file, or both — instead of sending it to the browser. Reach for it
to pre-build a static copy of a page, snapshot a page for email, or cache
expensive output.

## Syntax

    [capture_page page="pagename" file="path/to/output.html"]
    [capture_page page="pagename" scratch=varname]

Standalone tag (no end tag). Returns a status value (true on success), not the
captured content.

## Attributes

| Attribute         | Default | Description |
|-------------------|---------|-------------|
| `page`            |         | Page to render (positional 1). |
| `file`            |         | Path to write the rendered output to (positional 2). |
| `scratch`         |         | Scratch variable to store the rendered output in. |
| `scan`            |         | A search spec to run (via `do_scan`) before rendering, so the page sees search results. |
| `expiry`          |         | If `file`'s mtime is newer than this epoch time, skip rendering. |
| `touch`           | `0`     | With `expiry`, update the file's mtime when skipping. |
| `auto_create_dir` | `0`     | Create parent directories for `file` if missing. |
| `umask`           |         | umask used when creating `file`. |

Positional order: `page`, `file`.

## Description

`[capture_page]` renders `page` through the normal page-display machinery but
with output redirected: it temporarily saves and clears Interchange's output
buffers, calls `display_page` with `return => 1`, collects the resulting HTML
(running image substitution on it), then restores the original buffers. The
current request's own output is untouched — the captured page never reaches the
browser through this tag.

The captured HTML goes wherever you point it: into the `scratch` variable
(readable afterward with [scratch](scratch.md)), and/or written to `file`. When
neither is given, the render happens but nothing is kept. Writing to `file` is
subject to the catalog's file-access rules; a disallowed path is logged and the
tag returns `0`.

`expiry` provides simple file caching: if the target `file` is already newer
than the supplied epoch time, the render is skipped entirely (optionally
`touch`-ing the file to refresh its timestamp). The tag sets `mv_no_count` so
the captured render is not counted as a page view.

## Examples

Capture a page into a scratch variable and use it:

    [capture_page page="email/receipt" scratch=receipt_html]
    [scratch receipt_html]

Write a rendered page to disk, creating directories as needed:

    [capture_page
        page="reports/daily"
        file="tmp/daily.html"
        auto_create_dir=1
    ]

Render a search-results page for a specific spec and save it:

    [capture_page page="results" scan="se=hat/fi=products" scratch=hits]

## Notes

- The return value is a status flag, not the page text; read the captured
  content from the `scratch` variable or the file you named.
- Rendering a page has the same side effects as visiting it (database reads,
  counters, any `[perl]` it runs), so avoid capturing pages with destructive
  actions.

## See also

- [scratch](scratch.md) — read back a captured page
- [include](include.md) / [page](page.md) — other page-composition tags
- [timed-build](timed-build.md) — cache interpolated output on a schedule
- The [performance guide](../guides/performance.md)

## Source

Defined in `code/UserTag/capture_page.tag` (inline `Routine`).
