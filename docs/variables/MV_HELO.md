# MV_HELO

Sets the HELO string Interchange presents when sending mail over SMTP. Reach for
it when the receiving mail server requires a specific HELO/EHLO hostname.

**Scope:** global (`interchange.cfg`)

## Syntax

    Variable  MV_HELO  hostname

The HELO hostname string. Default: the value of the `SERVER_NAME` variable when
`MV_HELO` is unset.

## Description

When opening an SMTP connection, Interchange chooses the HELO string from the
first defined value of the per-call `helo` options, the global `MV_HELO`, and
finally the `SERVER_NAME` variable:

```perl
Hello => $cc->{helo} || $gc->{helo}
      || $Global::Variable->{MV_HELO}
      || $::Variable->{SERVER_NAME},
```

## Examples

Present a specific HELO hostname:

    Variable  MV_HELO  mail.example.com

## See also

[MV_SMTPHOST](MV_SMTPHOST.md), [MV_MAILFROM](MV_MAILFROM.md),
the [email](../guides/email.md) guide.

## Source

Consumed in `lib/Vend/Util.pm` via `$Global::Variable->{MV_HELO}`.
