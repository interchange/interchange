# AsciiTrack

Names a file to which a formatted copy of each completed order report is
appended, giving you a plain-text running log of orders. Reach for it when
you want a simple flat-file audit trail of orders in addition to (or
instead of) email or database logging.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    AsciiTrack  filename

A single filename, relative to the catalog directory (an absolute path is
allowed subject to the usual file-access rules). Default: empty (no ASCII
tracking file).

## Description

When set, the order-routing code in `lib/Vend/Order.pm` appends the
rendered order report to the named file as each order is placed, using
Interchange's `logData` mechanism. The file accumulates one formatted
report per order.

## Examples

Append order reports to `etc/tracking.asc` (in `catalog.cfg`):

```
AsciiTrack etc/tracking.asc
```

The strap demo sets it relative to the catalog's log directory:

```
AsciiTrack      logs/tracking.asc
```

## Notes

If an order `Route` is set to `supplant` mode, the standard order report
handling is taken over by the route and this directive's append is
bypassed. See the order routing discussion in the
[cart-and-checkout](../guides/cart-and-checkout.md) guide.

The file grows without bound; rotate or prune it as part of normal log
maintenance.

## See also

[TrackFile](TrackFile.md), [Route](Route.md), [OrderReport](OrderReport.md), [MailOrderTo](MailOrderTo.md), the
[cart-and-checkout](../guides/cart-and-checkout.md) guide.

## Source

Stored unparsed in `lib/Vend/Config.pm` (no parse routine); consumed via
`$Vend::Cfg->{AsciiTrack}` in `lib/Vend/Order.pm`.
