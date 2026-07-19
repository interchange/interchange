# child-process

Run the body's Interchange Tag Language (ITL) in a forked, detached child
process so the current request can return without waiting for it. Reach for it
to off-load a long task — a slow report query, a bulk email run — that would
otherwise make the shopper's page hang.

## Syntax

    [child-process filename="tmp/report.txt"]
    ...ITL to run in the background...
    [/child-process]

Container tag. The body is **not** interpolated in the parent request
(`Interpolate 0`); it is passed as source to the child, which interpolates it
itself.

## Attributes

| Attribute    | Default              | Description |
|--------------|----------------------|-------------|
| `filename`   |                      | Catalog-relative path to write the child's rendered output to. |
| `label`      | `child-process tag`  | Descriptive label set as the child's OS process name. |
| `notifyname` |                      | Catalog-relative path for a zero-length "done" flag file, created after `filename` is written successfully. |

This tag has no positional parameters.

## Description

The tag double-forks: the request process forks a child, which forks again and
exits its intermediate parent, leaving a fully detached grandchild in its own
session (`setsid`). The grandchild severs its inherited database handles and
session, renames its process (using `label`), then interpolates the body with
`interpolate_html`. The original request `waitpid`s only briefly on the
intermediate child and returns nothing to the page — so the page finishes
immediately while the work continues in the background.

If `filename` is given, the child writes its rendered output there (the name is
run through the `filesafe` filter and the catalog's relative-file writer). If
that write succeeds and `notifyname` is given, an empty file is created at
`notifyname` — a signal another process (or a polling page) can watch for to
know the output is ready.

The tag does nothing if the body is empty or whitespace only.

## Examples

Run a long report query in the background and drop the result in a file:

    This is the parent process; it returns right away.

    [child-process filename="tmp/report_[time]%Y%m%d%H%M%S[/time].txt"]
    [query
        list=1
        sql="SELECT ... some long-running query ..."
    ][sql-line]
    [/query]
    [/child-process]

    The parent page continues here without waiting.

Signal completion for a page that polls for the flag file:

    [child-process
        filename="pub/export.csv"
        notifyname="pub/export.done"
        label="nightly export"
    ]
    ... export markup ...
    [/child-process]

## Notes

- The child has no browser connection; its output must go to `filename` (or
  whatever the body itself writes). Nothing it produces reaches the shopper's
  current page.
- Because the child severs the parent's database handles, it opens its own —
  design the body to be self-contained.
- Forking has real cost; use this for genuinely long tasks, not routine
  rendering.

## See also

- [query](query.md) — the typical long-running body content
- [timed-build](timed-build.md) / [capture_page](capture_page.md) — other
  ways to precompute output
- The [jobs guide](../guides/jobs.md) and
  [performance guide](../guides/performance.md)

## Source

Defined in `code/UserTag/child-process.tag` (inline `Routine`); renders the
body with `Vend::Interpolate::interpolate_html`.
