# email-raw

Send an email whose body already contains the complete header block --
headers, a blank line, then the message text -- exactly as it should be
delivered. Reach for it when you need full control over the raw message and do
not want the header assembly that [email](email.md) performs.

## Syntax

    [email-raw]To: someone@example.com
    Subject: Hello

    Message body here.[/email-raw]

Container tag (has an end tag). The body is interpolated before sending.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `hide`    |         | Return the empty string instead of the success flag. |

Positional order: none. Any other attributes are collected but the routine uses
only `hide`.

## Description

Leading whitespace is trimmed from the body, then the message is sent through
the configured [SendMailProgram](../config/SendMailProgram.md):

- `none` -- mail is silently discarded (treated as success).
- `Net::SMTP` -- the header block (everything up to the first blank line) is
  split off and passed with the body to `send_mail`.
- otherwise -- the body is piped to the mail program with `-t`, which reads the
  recipients from the message's own `To`/`Cc`/`Bcc` headers.

If `MV_EMAIL_CHARSET` is set (catalog or global), the body is encoded to that
character set before sending.

If `MV_EMAIL_INTERCEPT` is set, all outgoing mail is re-routed to that address:
the tag rewrites each `To`/`Cc`/`Bcc` header to the intercept address, records
the original as an `X-Intercepted-*` header, and logs the substitution. This is
useful on staging catalogs so test orders never reach real customers.

The tag returns a true value on success, or the empty string when `hide` is
set. Failure is logged with the full message.

## Examples

Send a raw message:

    [email-raw]To: customer@example.com
    From: orders@example.com
    Subject: Order received

    Your order has been received and is being processed.
    [/email-raw]

Suppress the return value in the page:

    [email-raw hide=1]To: ops@example.com
    Subject: Nightly job complete

    Done.
    [/email-raw]

## Notes

Because you supply the headers verbatim, `email-raw` does *not* perform the
header-injection scrubbing that [email](email.md) does. Never build its header
block directly from untrusted input. The first blank line is the header/body
boundary, so make sure your headers are followed by exactly one blank line.

## See also

[email](email.md),
[SendMailProgram](../config/SendMailProgram.md),
[../guides/email.md](../guides/email.md)

## Source

Defined in `code/UserTag/email_raw.tag` (registers the tag `email-raw`).
Implemented by the inline Routine in that file.
