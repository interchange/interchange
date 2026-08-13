# mail

Send an email whose body is the tag body. Reach for it to fire off a
notification, confirmation, or report from within a page or profile.

## Syntax

    [mail to="you@example.com" subject="Hello"]
    Message body here.
    [/mail]

    [mail raw=1]
    To: you@example.com
    Subject: Hello

    Message body here.
    [/mail]

Container tag. The body is the message text; interpolate it with
`interpolate=1` if it should include live values.

## Attributes

| Attribute   | Default | Description |
|-------------|---------|-------------|
| `to`        | (none)  | Recipient address. Required unless supplied via `mv_email_enable`. |
| `from`      | (none)  | `From:` address. |
| `subject`   | `<no subject>` | `Subject:` header. |
| `reply_to`  | (none)  | `Reply-To:` header. |
| `errors_to` | (none)  | `Errors-To:` header. |
| `extra`     | (none)  | Additional raw header lines (`Name: value`, one per line). |
| `raw`       | off     | Treat the body as a complete message (headers included); skip header assembly. |
| `show`      | off     | Return the assembled headers-plus-body instead of just a status. |
| `success`   | send status | Value to return on success. |
| `hide`      | off     | Return empty string on success. |

Positional order: `to`.

## Description

`[mail]` builds an RFC-style message and hands it to the configured
[SendMailProgram](../config/SendMailProgram.md). In normal (non-`raw`) mode
it assembles the `From`, `To`, `Subject`, `Reply-To`, and `Errors-To`
headers from the matching attributes, then appends the body as the message
text. In `raw` mode you supply the entire message — headers, blank line, and
body — and the tag sends it verbatim.

To defeat header injection through submitted form fields, header values
sourced from CGI (`mv_email_*` form fields) are honored only when the
scratch flag `mv_email_enable` is set, and the recipient must match that
flag's value. This lets you build customer-facing "email a friend" forms
without turning your catalog into an open relay. Attribute-supplied headers
(as in the examples here) are not subject to that gate.

The tag refuses to send a message that has no recipient or no body,
returning a formatted error instead. On send failure it returns an error
describing the mail program used and the message that could not be sent.

## Examples

Send a fixed notification:

    [mail to="orders@example.com" subject="New signup"]
    A new account was just created.
    [/mail]

Interpolate the body so it can include order data:

    [mail to="[value email]" subject="Your receipt" interpolate=1]
    Thank you, [value fname]. Your order total was [total-cost].
    [/mail]

Add extra headers:

    [mail to="you@example.com" subject="Report"
          extra="Cc: boss@example.com
    X-Catalog: strap"]
    Daily report attached.
    [/mail]

## Notes

For transactional order email, catalogs normally use the order
[route](../guides/email.md) machinery rather than calling `[mail]` directly.
Use `[mail]` for ad-hoc messages.

## See also

- [email](email.md) — higher-level mail tag with UTF-8/injection protection
- [email-raw](email-raw.md) — send a raw message block
- [SendMailProgram](../config/SendMailProgram.md)
- [email](../guides/email.md)

## Source

Defined in `code/SystemTag/mail.coretag`. Implemented by
`Vend::Interpolate::tag_mail` (`lib/Vend/Interpolate.pm`).
