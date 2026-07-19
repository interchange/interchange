# dump_session

Show the contents of a stored user session, in whole or in part, or list the
sessions that are currently active. It is part of the administrative UI
toolset (loaded only when the admin UI is enabled), not a storefront tag;
the admin uses it to inspect live sessions for support and debugging.

## Syntax

    [dump_session name]
    [dump_session name=CODE key=PART]
    [dump_session find=1]

Standalone tag. Interchange treats `-` and `_` as equivalent in tag names,
so the shipped admin writes it as `[dump-session ...]`; that is the same tag.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `name`    |         | Session id (code) to dump. |
| `find`    |         | If true, return the list of currently active session ids instead of dumping one. |
| `key`     |         | Restrict the dump to one part of the session (see below). |
| `joiner`  | space   | Separator for the `find` list. |

Positional order: `name` (the first parameter). Other parameters are named.

## Description

The tag works with the two persistent session back ends: file sessions
(`SessionType File`) and database sessions (`SessionType DBI`). For any
other session type it returns an explanatory message and does nothing.

Two modes:

- **Dump a session.** With `name`, the tag loads that session (from the
  session file directory, or the session table for DBI), serializes it with
  `uneval`, and returns the text.
- **Find active sessions.** With `find=1`, the tag returns the ids of
  sessions accessed within the expiry window, joined by `joiner`. The window
  is `SessionExpire` seconds, or `ACTIVE_SESSION_MINUTES` minutes when that
  catalog variable is set.

The `key` option narrows a dump to part of the structure:

- `key=SCALAR` returns only the top-level scalar entries (dropping nested
  references such as the cart and values hashes).
- `key=SOMENAME` returns only that single top-level member.

## Examples

Dump the current visitor's own session (the session id comes from
[data](../tags/data.md)):

    <pre>[dump_session name="[data session id]"]</pre>

Dump only the `browser` element of the current session:

    <pre>[dump_session name="[data session id]" key=browser]</pre>

List active sessions and loop over them with [loop](../tags/loop.md):

    [loop list="[dump_session find=1]"]
      Session: [loop-code]<br>
    [/loop]

## Notes

- `find` support depends on the session back end: file sessions are located
  with a filesystem scan; DBI sessions are queried by `last_accessed`.
- The output is `uneval` (Perl) syntax, intended for inspection, not for
  machine parsing on the page.

## See also

- [Sessions guide](../guides/sessions.md)
- [data](../tags/data.md) — read individual session values
- The [admin UI guide](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/dump_session.coretag`. Implemented by the inline
Routine in that file.
