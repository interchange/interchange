# OrderReport

Names the template file used to build the plain order report that is mailed to
the store when a simple (non-route) order is placed. Reach for it to point
Interchange at a custom report layout.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    OrderReport  filename

A single file path, resolved relative to the catalog root. Default: `etc/report`.

## Description

When an order is submitted through the classic order-report path,
`lib/Vend/Order.pm` reads the file named by `OrderReport`, interpolates it as an
Interchange page, and uses the result as the body of the order notification
mailed to the store. The template typically lists the ordered items, customer
details, and totals.

The file is read with Interchange's file-access checks; a request that points
`mv_order_report` outside allowed locations is refused and logged. If the file
cannot be found, an error is logged and no report is produced.

## Examples

Use the default report template (shown explicitly in `catalog.cfg`):

```
OrderReport etc/report
```

Point at a custom template under the catalog's `etc` directory:

```
OrderReport etc/order_report.txt
```

## See also

[OrderCounter](OrderCounter.md), [MailOrderTo](MailOrderTo.md),
[Route](Route.md), the [email](../guides/email.md) and
[cart-and-checkout](../guides/cart-and-checkout.md) guides.

## Source

Parsed with no parser (raw string) in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{OrderReport}` in `lib/Vend/Order.pm`.
