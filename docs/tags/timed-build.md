# timed-build

Cache the interpolated output of its body in a file and reuse it until a
timeout expires. Reach for it to avoid re-running expensive page fragments
(menus, category trees, reports) on every request.

## Syntax

    [timed-build file="FILE" minutes=N]BODY[/timed-build]

Container tag. The body is interpolated the first time (or after the cache
expires) and written to `FILE`; subsequent requests within the timeout return
the cached file contents without re-interpolating.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `file`    |         | Cache file path (relative to the catalog, or absolute). With `auto`, the name is generated automatically. |
| `minutes` | see below | Cache lifetime in minutes; `0` means never expire (rebuild only when the file is missing). |
| `period`  |         | Cache lifetime as an Interchange interval string (e.g. `1 day`); alternative to `minutes`. |
| `if`      |         | When present and false, skip caching and just interpolate the body inline. |
| `force`   | `0`     | Build/serve the cache even for sessions that would normally be excluded (see Notes). |
| `login`   | `0`     | Allow caching for logged-in sessions. |
| `auto`    | `0`     | Generate the cache filename automatically under `ScratchDir/auto-timed`; implies `login` and defaults `minutes` to 60. |
| `new`     | `0`     | Build under a fresh, session-less scratch context. |
| `scan`    | `0`     | Cache a search-results (`scan`) page, keyed by the search. |
| `umask`   | `22`    | umask used when writing the cache file. |

Positional order: `file` (`PosNumber 1`).

## Description

On each request the tag checks the cache file. If the file is missing, or its
modification time is older than the timeout (`minutes` × 60, or `period`
converted to seconds), the body is interpolated and written to the file with
`writefile_atomic`, and the fresh output is returned. Otherwise the file's
existing contents are returned unchanged.

By default caching is bypassed — the body is simply interpolated inline —
unless the session has a cookie and is not a logged-in user, or `force` is set.
This keeps per-user dynamic content out of a shared cache. `login` opts
logged-in sessions into caching; `auto` turns on automatic, per-key cache
files (and sets `login`); `new` builds the fragment in a clean scratch space so
session state does not bleed into the cached output.

Files are written under the catalog's allowed-file rules; a disallowed path is
refused and logged.

## Examples

Cache a navigation menu for a day (24 hours = 1440 minutes):

    [timed-build file="timed/bootmenu" login=1 force=1 minutes=1440]
      [menu name="catalog/menu" timed=1][/menu]
    [/timed-build]

Cache a fragment for five minutes using an automatic filename:

    [timed-build auto=1 minutes=5]
      [query sql="SELECT count(*) FROM orders"][sql-code][/query] orders so far
    [/timed-build]

## Notes

- A `minutes=0` cache never expires on its own; delete the file to force a
  rebuild.
- Because the cached text is served verbatim, do not cache fragments that
  contain per-user data unless you scope them with `auto`/`new`.

## See also

[menu](menu.md), [timed-display](timed-display.md),
the [performance](../guides/performance.md) guide.

## Source

Defined in `code/SystemTag/timed_build.coretag`. Implemented by
`Vend::Interpolate::timed_build` in `lib/Vend/Interpolate.pm`.
