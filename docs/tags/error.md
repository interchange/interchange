# error

Set, test, and display the form and processing errors held in the
shopper's session. Order profiles and form checks record failures under
named keys; `[error]` is how a page reads them back, whether you want one
field's message, a yes/no test, or a fully formatted list of everything
that went wrong.

## Syntax

    [error name=FIELD]
    [error name=FIELD set="message text"]
    [error name=FIELD text="FIELD is required: %s"]
    [error all=1 show_error=1 joiner="<br>"]
    [error auto=1]

Standalone tag. Errors are stored per session under `name` keys; retrieving
an error deletes it unless you pass `keep`.

## Attributes

| Attribute        | Default                 | Description |
|------------------|-------------------------|-------------|
| `name`           | `default`               | Error key, usually the form field name it belongs to; positional parameter 1. |
| `set`            | (none)                  | Record this text as the error for `name` instead of reading it. |
| `overwrite`      | (off)                   | With `set`, replace any existing message; otherwise the new text is appended after `" AND "`. |
| `param`          | (none)                  | One value or a list, used as `sprintf` arguments for the `set` text. |
| `keep`           | see below               | Preserve the error after display instead of consuming it. |
| `filter`         | `encode_entities`       | Filter(s) applied to each message before output. |
| `all`            | (off)                   | Display every stored error rather than the one named. |
| `auto`           | (off)                   | Preset a formatted HTML list of all errors (see below). |
| `show_error`     | (off)                   | Show the actual message text rather than just a count. |
| `show_var`       | (off)                   | Include the error's key name in the output. |
| `show_label`     | (off)                   | Prefix each message with the label set by an earlier `std_label`. |
| `std_label`      | (none)                  | Store a standardized label for `name` and format the message with it. |
| `required`       | (off)                   | With `std_label`, keep the `{REQUIRED ...}` portions of the label template. |
| `text`           | (none)                  | Template string; `%s` is replaced by the message (appended if no `%s`). |
| `joiner`         | `\n` (`<li>` if `auto`) | Separator when several errors are shown together. |
| `header`         | (none)                  | Text emitted before the joined errors. |
| `footer`         | (none)                  | Text emitted after the joined errors. |
| `list_container` | `ul` (with `auto`)      | HTML element wrapping the `auto` list. |
| `class`, `style`, `extra` | (none)         | Attributes added to the `auto` list container. |

Positional order: `name`.

## Description

Errors live in `$Vend::Session->{errors}`, a hash of key to message.
Interchange's own form and order-profile checking writes into it; you can
also write to it yourself with `set`.

**Setting.** `[error name=email set="Not a valid address"]` records a
message. By default a second `set` for the same key appends after the
literal `" AND "`; pass `overwrite=1` to replace instead. When `set` is
used, `keep` defaults on so the message survives the call. `param` feeds
`sprintf`, so `set="%s is required" param=Email` yields "Email is
required".

**Testing and single display.** `[error name=email]` with no `text`,
`std_label`, or `show_error` returns a boolean: true if that key has an
error. Add `text` to format it — `[error name=email text="Email: %s"]`
substitutes the message for `%s` (or appends it if there is no `%s`).
Reading a key deletes it unless `keep=1`.

**Displaying all errors.** `all=1` walks every key. Without `text` or
`show_error` it returns the count of errors present; with `show_error=1`
it emits the messages joined by `joiner`, wrapped in `header`/`footer`.
`show_var=1` prefixes each with its key name.

**Auto formatting.** `auto=1` is a shortcut that turns on `all` and
`show_error`, sets `show_var`, and builds an HTML `<ul>` list
(`joiner=<li>`), so `[error auto=1]` renders every outstanding error as a
bulleted list with no other configuration. Use `list_container`, `class`,
`style`, and `extra` to style the wrapper.

Each message is passed through `filter` (default `encode_entities`) before
output, so error text is HTML-safe by default.

## Examples

Record an error against a field, then somewhere later show it:

    [error name=email set="Please enter a valid email address"]
    ...
    [error name=email text="<span class='err'>%s</span>"]

Show a bulleted list of everything wrong with the submitted form:

    [error auto=1]

Show all errors as a custom line-broken block, keeping them for a later
retry display:

    [error all=1 show_error=1 keep=1 joiner="<br>"]

Standardized label formatting, as the strap login form does:

    [error filter=e name=mv_username std_label="[L]Username[/L]"]

## Notes

Retrieving an error normally clears it, which is why a message shown once
does not reappear on the next page; add `keep=1` wherever you need it to
persist. The default `encode_entities` filter means literal HTML in a
message is escaped — pass `filter=""` (empty) if you intentionally store
markup.

> **strap note:** strap-derived catalogs define `[edisplay]`, a
> catalog-level extended alias for `[error auto=1 class="alert
> alert-danger list-unstyled"]` (Bootstrap-styled error display). See
> [Catalog anatomy](../guides/catalog-anatomy.md).

## See also

[if](if.md), [value](value.md), the [forms](../guides/forms.md) guide and
the [order-checks](../order-checks/README.md) reference.

## Source

Defined in `code/SystemTag/error.coretag` as an inline `Routine` in package
`Vend::Interpolate` (subs `tag_error` and `set_error`).
