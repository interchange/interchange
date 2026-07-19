# SendMailProgram

Selects the program (or method) Interchange uses to send email such as order
receipts and administrative notices. Reach for it to point Interchange at your
system's `sendmail` binary, or to switch mail delivery to `Net::SMTP`.

**Scope:** both (`interchange.cfg` global, `catalog.cfg` catalog)

## Syntax

    SendMailProgram  program

A path to a `sendmail`-compatible binary, the literal `Net::SMTP`, or the
literal `none`.

### Global

In `interchange.cfg` the value is resolved to an actual executable or module:
the parser takes the first usable entry from a candidate list. The default list
is `$Global::SendMailLocation`, then `/usr/sbin/sendmail`,
`/usr/lib/sendmail`, and finally the `Net::SMTP` module. Default: the first of
those found on the server.

### Catalog

In `catalog.cfg` the value is stored as a raw string and defaults to the
resolved global `SendMailProgram`. A catalog inherits the server-wide choice
unless it overrides it.

## Description

When Interchange sends mail through `send_mail` (`lib/Vend/Util.pm`), it looks at
`SendMailProgram`:

- A binary path (such as `/usr/sbin/sendmail`) is opened as a pipe and the
  message is fed to it with `-t`.
- `Net::SMTP` (or `none`) skips the local binary and delivers through an SMTP
  server -- see [SMTPConfig](SMTPConfig.md) and the `MV_SMTPHOST` variable. If no
  SMTP host is configured, `none` means no mail is sent.

Interchange expects a `sendmail`-compatible command-line interface; most
`sendmail` replacements (Postfix, Exim) ship a compatible binary.

## Examples

Use the system `sendmail` binary. In `interchange.cfg` (or `catalog.cfg`):

```
SendMailProgram /usr/sbin/sendmail
```

Deliver via SMTP instead of a local binary:

```
SendMailProgram Net::SMTP
```

## Notes

If no binary is found at startup and no SMTP host is configured, Interchange
cannot send email through its standard facilities; you would then have to
retrieve orders from a tracking file or log (see [AsciiTrack](AsciiTrack.md)).

## See also

[SMTPConfig](SMTPConfig.md), [MailOrderTo](MailOrderTo.md),
[AsciiTrack](AsciiTrack.md), [EncryptProgram](EncryptProgram.md), the
[email](../guides/email.md) guide.

## Source

Parsed by `parse_executable` (global) in `lib/Vend/Config.pm`; stored as a raw
string (catalog) defaulting to `$Global::SendMailProgram`. Consumed in
`lib/Vend/Util.pm` (`send_mail`).
