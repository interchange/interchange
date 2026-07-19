# warnings

Record a warning message into the session and/or display the warnings
collected so far. Reach for `[warnings ...]` to queue a "please note" message
during form processing and then show the accumulated list on the next page.

## Syntax

    [warnings message="Something to note"]
    [warnings]
    [warnings auto=1 list_container=ul]

Standalone tag (no end tag).

## Attributes

| Attribute        | Default | Description |
|------------------|---------|-------------|
| `message`        |         | Warning text to record (positional 1). Omit to only display. |
| `param`          |         | Value(s) substituted into `%s` placeholders in `message` (via `errmsg`). |
| `show`           | `0`     | When recording a message, also display the list in the same call. |
| `keep`           | `0`     | Do not clear the warnings after displaying them. |
| `header`         |         | Text emitted before the list. |
| `footer`         |         | Text emitted after the list. |
| `joiner`         | newline (`<li>` when `auto`) | String placed between warnings. |
| `auto`           | `0`     | Wrap the list in an HTML list element. |
| `list_container` | `ul`    | With `auto`, the wrapping element name. |
| `list_class` / `list_style` / `list_extra` |  | With `auto`, attributes added to the container. |

Positional order: `message`.

## Description

Warnings live in `$Session->{warnings}`, an array on the session. Calling
`[warnings message="..."]` appends the message (passed through `errmsg`, so
locale translation and `param` substitution apply) and, unless `show` is set,
returns nothing — the message is queued for later.

Calling `[warnings]` with no `message` returns the accumulated warnings joined
by `joiner`, wrapped by `header`/`footer`, and then **clears** the list unless
`keep` is set. With `auto=1` the warnings are rendered as an HTML list
(`<ul><li>...`) whose container and attributes you control with the
`list_*` options.

This is the counterpart to Interchange's error list (which the system uses for
hard failures); warnings are for advisory, non-fatal notices your own pages
raise. The message text is not interpolated as ITL.

## Examples

Queue a warning during form handling (records only, displays nothing):

    [warnings message="Your cart was empty, so nothing was saved."]

Display and clear all queued warnings at the top of a page:

    [warnings]

Show a confirmation immediately, as the strap member account page does:

    [warnings message=|Information saved. Return to
        <a href="[area member/service]">your account</a>|]

Render the collected warnings as a styled list, kept for a later page too:

    [warnings auto=1 list_container=ul list_class="messages" keep=1]

## Notes

- `[warning ...]` (singular) is an alias of this tag; see
  [warning](warning.md).
- Displaying without `keep` is destructive: the warnings are removed from the
  session, so a second `[warnings]` on the same page shows nothing.

## See also

- [warning](warning.md) — singular alias
- [error](error.md) — the error-message counterpart
- [msg](msg.md) / [loc](loc.md) — locale message translation
- The [logging and debugging guide](../guides/logging-debugging.md)

## Source

Defined in `code/SystemTag/warnings.coretag` (inline `Routine`); records via
`Vend::Interpolate::push_warning`.
