# Sending email

Interchange sends email for order receipts, shipment notices, contact forms,
password resets, and any notification a page or [job](jobs.md) wants to fire
off. Every one of them funnels through a single low-level routine,
`send_mail`, wrapped by two tags you use from pages and templates —
[email](../tags/email.md) and [email-raw](../tags/email-raw.md). This chapter
covers how mail is transported (a local `sendmail` binary versus `Net::SMTP`),
how the two tags differ and when to reach for each, how order receipts are
mailed, attachments and HTML mail, choosing the `From` address, and how to
intercept all outgoing mail on a staging system so test orders never reach real
customers.

The code authority is `send_mail` in `lib/Vend/Util.pm`, the tag definitions in
`code/UserTag/email.tag` and `code/UserTag/email_raw.tag`, and the
transport directives [SendMailProgram](../config/SendMailProgram.md) and
[SMTPConfig](../config/SMTPConfig.md).

## How mail leaves Interchange

Everything Interchange mails passes through `send_mail`
(`lib/Vend/Util.pm`), which builds the message and hands it to one of two
transports chosen by [SendMailProgram](../config/SendMailProgram.md):

- **A local `sendmail` binary** — the value is a path such as
  `/usr/sbin/sendmail`. `send_mail` opens it as a pipe with `-t`
  (`sendmail` reads the recipients from the message's own `To`/`Cc`/`Bcc`
  headers) and writes the message into it.
- **`Net::SMTP`** — the value is the literal string `Net::SMTP`. `send_mail`
  connects to an SMTP server (from [SMTPConfig](../config/SMTPConfig.md) or
  `MV_SMTPHOST`) and speaks the protocol directly, with optional
  authentication and TLS.

At server start the global [SendMailProgram](../config/SendMailProgram.md)
is *resolved* to the first usable entry in a candidate list —
`$Global::SendMailLocation`, then `/usr/sbin/sendmail`,
`/usr/lib/sendmail`, then the `Net::SMTP` module — so on a normal Unix host
with `sendmail` installed you configure nothing and mail works. Set it
explicitly to override that search:

    SendMailProgram /usr/sbin/sendmail       # force the binary
    SendMailProgram Net::SMTP                 # force SMTP delivery

A catalog inherits the resolved global value and can override it in
`catalog.cfg`. Most `sendmail` replacements (Postfix, Exim, ssmtp) install a
command-line-compatible binary, so the binary path works with them unchanged.

### The special value `none`

`SendMailProgram none` is the resolved value when no binary was found at
startup. Inside `send_mail` it behaves *exactly* like `Net::SMTP`: mail is
delivered over SMTP if — and only if — an SMTP host is configured. With a
host set, `none` sends. With no host set, `send_mail` reports success but
sends nothing, silently. That silent-success case is the usual reason a
freshly installed catalog "sends" order mail that never arrives: there is no
`sendmail` binary and no SMTP host.

## SMTP delivery

To deliver over SMTP, set [SendMailProgram](../config/SendMailProgram.md) to
`Net::SMTP` (the `Net::SMTP` Perl module must be installed) and point
Interchange at a server. The quickest way is the
[MV_SMTPHOST](../variables/MV_SMTPHOST.md) variable:

    SendMailProgram Net::SMTP
    Variable  MV_SMTPHOST  mail.example.com

For anything beyond a plain relay — a non-standard port, authentication, or
TLS — use [SMTPConfig](../config/SMTPConfig.md), a hash of connection
settings:

    SendMailProgram Net::SMTP
    SMTPConfig  host smtp.example.com port 587 user mailer pass secret ssl STARTTLS

The recognized keys are `host`, `port`, `user`, `pass`, `helo`, `timeout`,
and `ssl` (the value is passed straight to `Net::SMTP`; an explicit `0`
disables TLS). Both directives exist at global and catalog scope; `send_mail`
prefers the catalog value, then the global one, key by key, and the host
additionally falls back to `MV_SMTPHOST` (catalog then global). If a `user` is
given, Interchange issues SMTP AUTH with `user`/`pass`.

Two variables tune the SMTP conversation without a full `SMTPConfig`:
[MV_HELO](../variables/MV_HELO.md) sets the name sent in the HELO/EHLO
greeting (some servers reject a mismatched greeting), and
[MV_MAILFROM](../variables/MV_MAILFROM.md) sets the envelope sender — see
[Choosing the From address](#choosing-the-from-address) below.

The SMTP path is also where `send_mail` synthesizes a `Date:` header and, if
absent, a `From:` header. The `sendmail`-binary path leaves both to the local
mailer.

## The two email tags

Two tags send mail from [ITL](templating.md). They wrap the same `send_mail`
but take opposite approaches to the message headers.

[email](../tags/email.md) builds the headers *for* you from attributes and
treats its body as just the message text. It is the safe, everyday choice —
notably because it scrubs the header fields for injection (below).

[email-raw](../tags/email-raw.md) sends its body *verbatim*: the body must
already be a complete message — header lines, one blank line, then the text.
Reach for it only when you need total control over the raw message, or when
you already have a fully-formed message template (as strap's shipment notice
does).

### [email]

A minimal notification from a contact page:

    [email to="orders@example.com" subject="Website inquiry"]
    A visitor left a message on the contact form.
    [/email]

The tag's positional order is `to subject reply from extra`; the common
attributes:

| Attribute | Default | Purpose |
|-----------|---------|---------|
| `to` | | recipient address(es) |
| `subject` | `<no subject>` | subject line |
| `reply` | | `Reply-To:` address |
| `from` | first [MailOrderTo](../config/MailOrderTo.md) address | `From:` address |
| `extra` | | additional raw header lines, one per line |
| `cc` / `bcc` | | `Cc:` / `Bcc:` recipients |
| `hide` | | return `''` instead of the success flag |
| `html` | | HTML alternative body (see [Attachments and HTML mail](#attachments-and-html-mail)) |
| `attach` | | file(s) to attach |

Because the body is [interpolated](templating.md) first, an `[email]` block is
a normal ITL template — pull the recipient and content from
[value](../tags/value.md) space, the database, or scratch:

    [email to="[value email]" subject="Your password reset"]
    Hello [value fname],

    Follow this link to reset your password:
    [area href=reset form="code=[scratch reset_code]"]
    [/email]

The tag returns a true value on success and logs the full message on failure;
add `hide=1` to keep that flag out of the page output when you call it inline.

### [email-raw]

`[email-raw]` sends exactly what you give it. The body is a raw message — the
header block, a single blank line, then the text:

    [email-raw]To: [value email]
    From: orders@example.com
    Subject: Order received

    Your order has been received and is being processed.
    [/email-raw]

Leading whitespace is trimmed, and the first blank line is the header/body
boundary, so make sure exactly one blank line separates them. The only
attribute the tag reads is `hide`.

`[email-raw]` performs **no** header scrubbing — it cannot, because it does not
parse the headers apart from the recipients. Never build its header block from
untrusted input; a newline smuggled into a `To:` value becomes a new header.
When any header field comes from a form, use [email](../tags/email.md) instead.

## Header-injection protection

Order and contact forms are a classic header-injection target: a value like
``customer@x.com%0ABcc: spam-list`` tries to smuggle a `Bcc:` header into the
message. The [email](../tags/email.md) tag defends against this in
`code/UserTag/email.tag`:

- Every address/subject field (`to`, `subject`, `reply`, `from`, `cc`, `bcc`)
  is *unfolded* per RFC 2822 and then has any remaining embedded newline (and
  everything after it) stripped — a stripped line is written to the catalog
  error log as `Header injection attempted in email tag`.
- Each line of `extra` must match a strict `Name: value` header pattern or it
  is dropped and logged as `Invalid header given to email tag`.

So with `[email]` a hostile form value can at worst break its own field, never
add recipients or headers. This is the concrete reason to prefer `[email]`
over [email-raw](../tags/email-raw.md) for anything a visitor can influence.

## Order receipts and the customer copy

Order confirmations are not sent by calling `[email]` at checkout by hand —
they fall out of the [order-routing](cart-and-checkout.md#order-routes)
machinery. A [Route](../config/Route.md) with an `email` attribute mails its
rendered [report](cart-and-checkout.md#the-order-report-and-receipts) to that
address; [MailOrderTo](../config/MailOrderTo.md) is the fallback recipient when
the built-in handling sends the merchant copy. That is the *merchant's* copy,
and it is covered in [Carts and checkout](cart-and-checkout.md).

The *customer's* copy is sent differently, and it is the best worked example of
the [email](../tags/email.md) tag in the distribution. strap's `copy_user`
route renders `etc/mail_receipt`, whose entire body is one big `[email]` block
guarded by a check that the shopper asked for a copy
(`dist/strap/etc/mail_receipt`):

    [if value email_copy][and value email]
    [email to="[value email]"
        subject="Thank you for your order #[value mv_order_number]!"
        from=|"__COMPANY__ Customer Service" <__ORDERS_TO__>|
    ]Dear [value fname],

    Thank you for your order #[value mv_order_number].

    Quan  Item No.    Description                            Price     Extension
    [item-list][row 82]
    [column width=5 align=right][item-quantity][/column]
    [column width=12][item-code][/column]
    [column width=32 wrap=1][item-description][/column]
    [column width=15 align=r][item-discount-price][/column]
    [column width=17 align=r][item-discount-subtotal][/column]
    [/row][/item-list]
    ...
    Regards and thanks for your business!
    __COMPANY__
    [/email]
    [/if]

Two things are worth copying from this pattern. First, the report is plain ITL,
so the receipt is built with the same [item-list](../tags/item-list.md),
[row](../tags/row.md)/`[column]`, [subtotal](../tags/subtotal.md), and
[total-cost](../tags/total-cost.md) tags a receipt page would use — the cart is
still populated while a route's report renders, so `[item-list]` works. Second,
the quoting: the `from=|...|` form uses `|` as the quote character so the value
itself can contain the double-quotes of a display-name address,
`"Name" <addr>`.

The bracketing `[if value email_copy][and value email]` matters: without it, an
order with no email address would call `[email]` with an empty `to`, and the
message would go nowhere (or, under interception, appear to succeed). Guard
your receipt sends on having a real recipient.

## Attachments and HTML mail

Give [email](../tags/email.md) an `attach` or `html` attribute and it switches
from a plain `send_mail` to building a MIME multipart message with
`MIME::Lite` (which must be installed — otherwise the attachment request is
logged and skipped, and a plain message is sent). This path is only in the
`[email]` tag; [email-raw](../tags/email-raw.md) has no notion of attachments.

Attach a single file by path:

    [email to="buyer@example.com" subject="Your invoice"
        attach="/var/catalogs/strap/tmp/invoice-1001.pdf"]
    Your invoice is attached.
    [/email]

`attach` also accepts a hash (to set `filename`, `type`, `disposition`,
`data`, or inline `data` instead of a `path`) or a list of files/hashes for
several attachments. When a file has no `filename`, the basename of its path is
used, and the MIME type is auto-detected unless you set `type`.

Send an HTML alternative alongside the plain-text body with `html`:

    [email to="[value email]" subject="Order #[value mv_order_number] confirmed"
        html="<p>Thank you, [value fname]. Your order is confirmed.</p>"]
    Thank you, [value fname]. Your order is confirmed.
    [/email]

With both a text body and `html`, the message is `multipart/alternative` so the
recipient's client picks one; with `html` and no text body, it is sent as
`text/html`. The `body_mime`, `body_encoding`, `body_disposition`, and
`body_format` attributes tune the text part when you need to; the defaults
(`text/plain`, `quoted-printable`, `inline`) suit ordinary mail. To preview the
assembled message instead of sending it, set `test=1` — the tag returns the
full header-plus-body string.

## Choosing the From address

Which `From:` a message carries depends on which path builds it, and this
trips people up:

- The [email](../tags/email.md) tag **always** sets `From:` itself. If you pass
  `from=`, that wins; otherwise it defaults to the first address in
  [MailOrderTo](../config/MailOrderTo.md). It does **not** consult
  `MV_MAILFROM`.
- The [email-raw](../tags/email-raw.md) tag uses whatever `From:` you wrote
  into the header block (over SMTP; the `sendmail` binary supplies its own if
  you omit it).
- `send_mail` itself — used by `[email-raw]` over SMTP and by code that calls
  it directly — fills a missing `From:` on the **SMTP path only** from the
  first defined of catalog [MV_MAILFROM](../variables/MV_MAILFROM.md), global
  `MV_MAILFROM`, then `MailOrderTo`.

So [MV_MAILFROM](../variables/MV_MAILFROM.md) is the server- or catalog-wide
default sender for SMTP delivery, but it has no effect on `[email]`, which
always stamps its own `From:`. If you want a catalog-wide sender for `[email]`
messages, set [MailOrderTo](../config/MailOrderTo.md) (or pass `from=` on each
call); if you want it for raw/SMTP mail, set `MV_MAILFROM`. When in doubt,
pass `from=` explicitly and there is no ambiguity.

## Intercepting mail on staging

On a development or staging catalog you rarely want real customers to receive
the test orders you push through it. Set
[MV_EMAIL_INTERCEPT](../variables/MV_EMAIL_INTERCEPT.md) and every message
`send_mail` handles is re-routed to that address instead of its real
recipients:

    Variable  MV_EMAIL_INTERCEPT  dev@example.com

Interchange rewrites each `To:`, `Cc:`, and `Bcc:` to the intercept address,
preserves the original in an `X-Intercepted-To:` (etc.) header, and logs the
substitution to the catalog error log. Several addresses may be given,
comma-separated. Both the [email](../tags/email.md) tag (via `send_mail`) and
[email-raw](../tags/email-raw.md) (which applies the same interception in its
own routine) honor it, so a staging catalog needs only this one line.

Two cautions. Interception only affects mail sent through Interchange's own
routines — code that shells out to `sendmail` or opens its own SMTP connection
is not intercepted. And because an intercept substitutes a *valid* recipient, a
message that would have failed for lacking a real `To:` now appears to succeed;
verify true destinations through the `X-Intercepted-*` headers before you turn
interception off for launch.

## Character sets and UTF-8

Set [MV_EMAIL_CHARSET](../variables/MV_EMAIL_CHARSET.md) and `send_mail` adds a
`Content-type: text/plain; charset=...` header (unless the caller already
supplied a content-type), and [email-raw](../tags/email-raw.md) encodes its
body to that character set before sending. For fuller Unicode handling — the
[email](../tags/email.md) tag MIME-encodes headers and the body when `MV_UTF8`
is on, and forces UTF-8 mail through MIME — see
[Internationalization](internationalization.md).

## Sending mail from Perl

Inside a [GlobalSub, catalog Sub, or job](perl-embedding.md) you can call the
tags through `$Tag`, or call `send_mail` directly. The tag route gets you the
injection scrubbing and MIME handling for free:

```perl
$Tag->email({
    to      => 'ops@example.com',
    subject => 'Nightly reconciliation complete',
    hide    => 1,
}, "Processed $count orders with no errors.\n");
```

`send_mail` (exported from `Vend::Util`) is the lower-level call. Its signature
is `send_mail($to, $subject, $body, $reply, $use_mime, @extra_headers)`, and it
also accepts an array-ref first argument holding a complete header block — the
form [email-raw](../tags/email-raw.md) uses:

```perl
Vend::Util::send_mail(
    'buyer@example.com',
    'Backorder update',
    "Two items on your order have shipped.\n",
);
```

Calling `send_mail` directly still honors
[SendMailProgram](../config/SendMailProgram.md), interception, and (on the SMTP
path) the `MV_MAILFROM` default, so it is the right primitive for a
[job](jobs.md) that mails a report.

## Troubleshooting

- **Mail silently vanishes.** The commonest cause is `SendMailProgram none`
  (no `sendmail` binary was found at startup) with no SMTP host configured:
  `send_mail` returns success but sends nothing. Set an explicit binary path
  or configure SMTP.
- **`Unable to send mail using ...` in the error log.** `send_mail` logs the
  transport it tried plus the whole message (`To`, `Subject`, body) on
  failure. For the `sendmail` binary that means the pipe or the program
  failed; for SMTP it means the connection, AUTH, or a `RCPT`/`DATA` step
  failed — the SMTP block logs the specific step (bad recipients, auth
  failure).
- **`Header injection attempted` / `Invalid header`.** The
  [email](../tags/email.md) tag rejected an address field or an `extra` line —
  expected when it is fending off hostile input, but also fires on a legitimate
  multi-line value you meant to fold. Fold long headers with a leading space
  per RFC 2822.
- **Test order mailed a real customer.** You forgot
  [MV_EMAIL_INTERCEPT](../variables/MV_EMAIL_INTERCEPT.md) on the staging
  catalog.
- **SMTP server rejects the greeting.** Set
  [MV_HELO](../variables/MV_HELO.md) (or `SMTPConfig helo`) to a name the
  server accepts.

More general logging is in [Logging and debugging](logging-debugging.md).

## See also

- [email](../tags/email.md), [email-raw](../tags/email-raw.md) — the tags,
  with full attribute lists
- [SendMailProgram](../config/SendMailProgram.md),
  [SMTPConfig](../config/SMTPConfig.md) — transport configuration
- [MailOrderTo](../config/MailOrderTo.md),
  [MV_MAILFROM](../variables/MV_MAILFROM.md),
  [MV_SMTPHOST](../variables/MV_SMTPHOST.md),
  [MV_HELO](../variables/MV_HELO.md),
  [MV_EMAIL_INTERCEPT](../variables/MV_EMAIL_INTERCEPT.md),
  [MV_EMAIL_CHARSET](../variables/MV_EMAIL_CHARSET.md) — the mail variables
- [Carts and checkout](cart-and-checkout.md) — order routes, reports, and the
  merchant copy
- [Internationalization](internationalization.md) — UTF-8 and encoded mail
- [Jobs](jobs.md), [Embedded Perl](perl-embedding.md) — sending mail from code
