# MV_MAILFROM

Sets the default sender (`From:`) address for mail Interchange sends over SMTP.
Reach for it to control the envelope/from address without setting it on every
mail call.

**Scope:** catalog (`catalog.cfg`) or global (`interchange.cfg`)

## Syntax

    Variable  MV_MAILFROM  address@example.com

An email address. Default: the value of the
[MailOrderTo](../config/MailOrderTo.md) directive.

## Description

When the mail routine needs a default sender and none was supplied on the call,
it uses the first defined value of the catalog `MV_MAILFROM`, the global
`MV_MAILFROM`, and finally the `MailOrderTo` directive:

```perl
my $from = $::Variable->{MV_MAILFROM}
        || $Global::Variable->{MV_MAILFROM}
        || $Vend::Cfg->{MailOrderTo};
```

## Examples

Set a catalog-wide default sender:

    Variable  MV_MAILFROM  store@example.com

## See also

[MV_SMTPHOST](MV_SMTPHOST.md), [MV_HELO](MV_HELO.md),
[MailOrderTo](../config/MailOrderTo.md), the [email](../guides/email.md) guide.

## Source

Consumed in `lib/Vend/Util.pm` via `$::Variable->{MV_MAILFROM}` /
`$Global::Variable->{MV_MAILFROM}`.
