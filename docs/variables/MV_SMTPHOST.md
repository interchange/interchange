# MV_SMTPHOST

Sets the SMTP server Interchange connects to when sending mail over SMTP. Reach
for it when mail should go through a specific relay rather than the default.

**Scope:** catalog (`catalog.cfg`) or global (`interchange.cfg`)

## Syntax

    Variable  MV_SMTPHOST  hostname

A hostname or IP address of an SMTP server. Default: none from this variable
(a per-call `host` option takes precedence if given).

## Description

When Interchange sends mail via SMTP, it resolves the mail host by taking the
first defined value of the per-call catalog and global `host` options, then the
catalog `MV_SMTPHOST`, then the global `MV_SMTPHOST`:

```perl
my $mhost = $cc->{host} || $gc->{host}
        || $::Variable->{MV_SMTPHOST}
        || $Global::Variable->{MV_SMTPHOST};
```

## Examples

Route catalog mail through a relay:

    Variable  MV_SMTPHOST  smtp.example.com

## See also

[MV_HELO](MV_HELO.md), [MV_MAILFROM](MV_MAILFROM.md),
the [email](../guides/email.md) guide.

## Source

Consumed in `lib/Vend/Util.pm` via `$::Variable->{MV_SMTPHOST}` /
`$Global::Variable->{MV_SMTPHOST}`.
