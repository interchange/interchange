# email

Send an email whose body is the tag's content, with structured headers,
header-injection protection, optional CC/BCC, attachments, HTML alternatives,
and UTF-8 handling. This is the tag to reach for when sending mail from a page,
a profile, or a receipt template.

## Syntax

    [email to=ADDRESS subject=SUBJECT]MESSAGE BODY[/email]
    [email ADDRESS SUBJECT REPLY FROM EXTRA]MESSAGE BODY[/email]

Container tag (has an end tag). The body is interpolated before sending.

## Attributes

| Attribute | Default            | Description |
|-----------|--------------------|-------------|
| `to`      |                    | Recipient address (first positional). |
| `subject` | `<no subject>`     | Subject line. |
| `reply`   |                    | `Reply-To` address. |
| `from`    | first [MailOrderTo](../config/MailOrderTo.md) address | `From` address. |
| `extra`   |                    | Additional raw header lines, one per line. |
| `cc`      |                    | `Cc` address(es). |
| `bcc`     |                    | `Bcc` address(es). |
| `hide`    |                    | Return the empty string instead of the success flag. |
| `html`    |                    | HTML alternative body (sends a multipart message). |
| `attach`  |                    | File path, hash, or list of files/hashes to attach. |
| `mimetype`|                    | Override the top-level MIME type. |
| `test`    |                    | Return the assembled message instead of sending it (attachment path). |

Positional order: `to`, `subject`, `reply`, `from`, `extra`.

Attachment and body-part behavior is further tunable with `body_mime`,
`body_encoding`, `body_disposition`, and `body_format`; see the source for the
full set.

## Description

The tag assembles headers from the attributes and sends the body via
Interchange's `send_mail` (honoring [SendMailProgram](../config/SendMailProgram.md)).
Every address/subject header is scrubbed for CR/LF injection: folded headers
(RFC 2822) are unfolded and any stray extra lines are stripped and logged, so
hostile form input cannot inject additional recipients or headers. Lines given
in `extra` must themselves be well-formed `Name: value` headers or they are
rejected and logged.

If `attach` or `html` is given and `MIME::Lite` is installed, the message is
built as a MIME multipart (mixed for attachments, alternative for an HTML
counterpart). Without `MIME::Lite` an attachment request is logged and skipped.

When UTF-8 is enabled (`MV_UTF8`), the body and headers are encoded
appropriately -- MIME-encoded headers for multipart messages, and a
`Content-Type: text/plain; charset=UTF-8` plain message otherwise. See
[../guides/email.md](../guides/email.md) and
[../guides/internationalization.md](../guides/internationalization.md).

The tag returns a true value on success (unless `hide` is set), and logs the
full message on failure.

## Examples

A minimal message:

    [email to="orders@example.com" subject="Website inquiry"]
    A visitor left a message.
    [/email]

The strap demo mails an order-copy to the shopper from the receipt template,
suppressing the return value with the interpolated body following the tag:

    [email to="[value email]"
        subject="Thank you for your order #[value mv_order_number]!"
        from=|"Customer Service" <orders@example.com>|
    ]Dear [value fname],

    Thank you for your order.
    [/email]

Send with a CC and an attached file:

    [email to="buyer@example.com" subject="Invoice"
        cc="accounts@example.com" attach="/tmp/invoice-1001.pdf"]
    Your invoice is attached.
    [/email]

## Notes

Use [email-raw](email-raw.md) instead when you need to supply the complete
header block yourself (the body already contains the headers). For a page that
just needs to fire off a quick notification, this tag's structured attributes
are safer because of the built-in header-injection checks.

## See also

[email-raw](email-raw.md), [value](value.md),
[SendMailProgram](../config/SendMailProgram.md),
[MailOrderTo](../config/MailOrderTo.md),
[../guides/email.md](../guides/email.md),
[../guides/internationalization.md](../guides/internationalization.md)

## Source

Defined in `code/UserTag/email.tag`. Implemented by the inline Routine in that
file, which sends via `Vend::Interpolate`'s `send_mail` (and `MIME::Lite` for
attachments/HTML).
