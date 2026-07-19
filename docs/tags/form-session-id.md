# form-session-id

Emit a hidden `mv_session_id` form field so a submitted form carries the
Interchange session, but only when it is actually needed. Reach for it in any
`<form>` that must preserve the session for users who are not accepting
cookies.

## Syntax

    [form-session-id]

Standalone tag (no end tag, no attributes). It returns either an HTML hidden
input or an empty string.

## Attributes

This tag takes no attributes and no positional parameters.

## Description

Interchange normally tracks a shopper's [session](../guides/sessions.md)
either through a browser cookie or through a session ID carried in URLs and
form submissions. When a form is posted, the session ID must travel with it,
or the shopper loses their cart and login.

`[form-session-id]` handles this automatically. It expands to:

    <input type="hidden" name="mv_session_id" value="SESSIONID">

using the current session ID. The trailing `>` follows the catalog's XHTML
setting (`$Vend::Xtrailer`), so it renders as ` />` when XHTML output is
enabled.

The tag returns an empty string — omitting the field entirely — when the
request arrived with a cookie (`$Vend::Cookie` is true) and the scratch
variable `mv_no_session_id` is set. In that case the cookie already carries
the session, so no hidden field is needed and the session ID is kept out of
the page source. In every other case the field is written.

## Examples

A minimal login form that preserves the session:

    <form action="[process secure=1]" method="POST">
      <input type="hidden" name="mv_todo"  value="return">
      <input type="hidden" name="mv_click" value="Login">
      [form-session-id]
      Username: <input name="mv_username">
      Password: <input type="password" name="mv_password">
      <input type="submit" value="Log In">
    </form>

When the shopper has a session cookie and `mv_no_session_id` is set, the tag
contributes nothing to the output. Otherwise it emits, for example:

    <input type="hidden" name="mv_session_id" value="mR8sd0Kk">

## See also

- [process](process.md)
- [area](area.md)
- Concepts: [sessions](../guides/sessions.md),
  [forms](../guides/forms.md)

## Source

Defined in `code/SystemTag/form_session_id.coretag` as an inline Routine.
