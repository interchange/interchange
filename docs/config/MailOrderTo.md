# MailOrderTo

Sets the email address that completed order reports are sent to. Reach for it
in every catalog that emails orders, since it is the default recipient for the
order-mail routine.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    MailOrderTo  email-address

An email address, stored verbatim (no parser is run). The special value `none`
suppresses order email. Default: empty.

## Description

When Interchange sends an order report it uses `MailOrderTo` as the recipient
whenever no explicit `to` address is supplied. The value is read in
`lib/Vend/Order.pm` (order routing), in `lib/Vend/Util.pm` (the mail-building
helper), and in `lib/Vend/Dispatch.pm` as the fallback `from`/report address
for job mail:

```perl
$email = $Vend::Cfg->{MailOrderTo} unless $email;
```

Setting the value to `none` results in no order email being generated. This is
a per-catalog setting evaluated at catalog configuration time.

`MailOrderTo` is one of the basic directives written into a catalog's
`catalog.cfg` when the catalog is created; the standard makecat/strap templates
fill it from the address you supply.

## Examples

Send completed orders to a fixed address (as in the strap `catalog.cfg`, where
the value comes from an expanded variable):

```
MailOrderTo orders@example.com
```

Suppress order email entirely:

```
MailOrderTo none
```

## See also

[OrderReport](OrderReport.md), [SendMailProgram](SendMailProgram.md),
[MimeType](MimeType.md), the [cart-and-checkout](../guides/cart-and-checkout.md)
and [email](../guides/email.md) guides.

## Source

Stored unparsed (no `parse_*` routine) in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{MailOrderTo}` in `lib/Vend/Order.pm`, `lib/Vend/Util.pm`, and
`lib/Vend/Dispatch.pm`.
