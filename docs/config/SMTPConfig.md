# SMTPConfig

Supplies the connection settings Interchange uses when sending mail through
`Net::SMTP` -- the host, port, authentication, and TLS options. Reach for it
when [SendMailProgram](SendMailProgram.md) is `Net::SMTP` (or `none`) and you
need to talk to a specific mail server, especially one requiring a login.

**Scope:** both (`interchange.cfg` global, `catalog.cfg` catalog)

## Syntax

    SMTPConfig  key value [key value ...]

A hash of `key value` pairs. Recognized keys are:

| Key       | Meaning                                                     |
|-----------|-------------------------------------------------------------|
| `host`    | SMTP server hostname or address                             |
| `port`    | Server port                                                 |
| `user`    | Username for SMTP AUTH                                       |
| `pass`    | Password for SMTP AUTH                                       |
| `helo`    | Name sent in the SMTP HELO/EHLO greeting                     |
| `timeout` | Connection timeout in seconds                               |
| `ssl`     | TLS/SSL mode passed to `Net::SMTP` (set `0` to disable)     |

Default: empty. The directive exists at both scopes; catalog values take
precedence over global ones, key by key.

## Description

When Interchange delivers mail via `Net::SMTP` (chosen through
[SendMailProgram](SendMailProgram.md)), `send_mail` in `lib/Vend/Util.pm`
assembles the connection from `SMTPConfig`. For each setting it prefers the
catalog `SMTPConfig` value, then the global one; the host additionally falls
back to the `MV_SMTPHOST` variable at catalog and then global scope. If a `user`
is given, Interchange authenticates with `user`/`pass`.

Because a value of `0` is meaningful for `ssl` (to disable TLS), that key is
treated specially so an explicit `0` is honored rather than skipped.

## Examples

Point a catalog at an authenticating SMTP server over TLS. In `catalog.cfg`:

```
SendMailProgram Net::SMTP
SMTPConfig      host smtp.example.com port 587 user mailer pass secret ssl STARTTLS
```

Set a server-wide default relay in `interchange.cfg`:

```
SMTPConfig  host mail.example.com
```

## See also

[SendMailProgram](SendMailProgram.md), [MailOrderTo](MailOrderTo.md), the
[email](../guides/email.md) guide.

## Source

Parsed by `parse_hash` in `lib/Vend/Config.pm` at both scopes. Consumed in
`lib/Vend/Util.pm` (`send_mail`, the `SMTP` block), with global
`$Global::SMTPConfig` as the fallback for the catalog `$Vend::Cfg->{SMTPConfig}`.
