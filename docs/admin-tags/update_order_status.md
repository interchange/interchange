# update_order_status

Mark an order shipped, partially shipped, or canceled: it updates the order's
line-item and transaction status, optionally records tracking numbers, settles
or voids the payment, archives the order, and queues a shipment-notice email.
Reach for it from the admin order-management screens when fulfilling an order.

This tag is part of the administrative UI toolset: it is loaded from
`code/UI_Tag/` when the back-office UI is enabled, and is not a storefront
tag.

## Syntax

    [update_order_status order_number]
    [update_order_status order_number=NN ship_all=1 send_email=1 ...]

Standalone tag (no end tag). It performs the status update as a side effect,
sets status messages in scratch, and adds UI warnings; it returns nothing
useful. Its output is reparsed as Interchange Tag Language (ITL) by default.

The tag name is registered as `update-order-status`; Interchange treats
hyphens and underscores in tag names interchangeably, so
`[update_order_status]` and `[update-order-status]` are the same tag.

## Attributes

| Attribute            | Default          | Description |
|----------------------|------------------|-------------|
| `order_number`       | none             | Transaction/order number to update. Required. Positional parameter 1. |
| `orderline_table`    | `orderline`      | Table holding the order's line items. |
| `transactions_table` | `transactions`   | Table holding the order header. |
| `userdb_table`       | `userdb`         | Table used to look up the customer's email and copy preference. |
| `ship_all`           | CGI `ship_all`   | `1` ships every line; `2` (or a void/cancel) marks the whole order canceled. |
| `lines_shipped`      | CGI `lines_shipped` | Null-separated list of line numbers to mark shipped; when empty the tag derives lines from the `status__N` form fields. |
| `status`             | CGI `status`     | Four-digit status code to store on the transaction; when not a four-digit value the status becomes `shipped`. |
| `tracking_number`    | CGI `tracking_number` | Tracking number stored on the transaction (per-line `tracking_number__N` fields are stored on the lines). |
| `cancel_order`       | CGI `cancel_order` | Cancel the order (lines and header set to `canceled`). |
| `void_transaction`   | CGI `void_transaction` | Void the payment and cancel the order. |
| `settle_transaction` | CGI `settle_transaction` | Settle (capture) the payment before updating status. |
| `archive`            | CGI `archive`    | Set the transaction `archived` flag when the order reaches its target status. |
| `do_archive`         | CGI `do_archive` | Alias source for `archive`. |
| `send_email`         | CGI `send_email` | Send the shipment-notice email; overrides the customer's stored `email_copy` preference. |
| `ship_notice_template` | `etc/ship_notice` | Template file interpolated and mailed as the shipment notice. |
| `auth_code`          | CGI `auth_code`  | Authorization code passed through to the payment settle/void call. |

Positional order: `order_number`.

The tag declares `addAttr`. Where an attribute above is not passed, the tag
falls back to the like-named CGI form value, so it works when driven directly
by an order-management form submission.

## Description

The tag opens the orderline, transactions, and userdb tables (names
overridable), and reads the transaction record for `order_number`; a bad order
number logs an error and returns undef. It determines the customer and whether
a shipment-notice email is wanted (from the userdb `email_copy` column, or
forced by `send_email`).

**Payment.** If `settle_transaction` is set, the tag settles the prior
authorization through the payment route named by
[MV_PAYMENT_MODE](../variables/MV_PAYMENT_MODE.md) using
[charge](../tags/charge.md), and on success marks the order id settled with a
trailing `*`. If `void_transaction` is set instead, it voids the charge and
marks the order id with a trailing `-`. A void or a `ship_all=2` is treated as
a cancellation.

**Line and header status.** The tag decides which order lines to ship: from
`lines_shipped`, from the `status__N` form fields, or all lines when
`ship_all` is set. Each shipped line's `status` becomes `shipped` (or
`canceled` when canceling), and other lines become `backorder`; on non-MySQL
databases it also stamps `update_date`. It then sets the transaction `status`
to `shipped`, `partial`, or `canceled` depending on how many lines shipped,
and sets `archived` when `archive` is requested and the order reached its
target status. A summary message is stored in `[scratch ui_message]` and a
[warning](../tags/warnings.md) is raised for the operator.

**Shipment notice.** When email is wanted and `send_email` is set, the tag
reads `ship_notice_template` (default `etc/ship_notice`), interpolates it, and
sends it with `email_raw`. Order and customer details are placed in the
`ship_notice_*` scratch values for the template to use.

## Examples

Ship an entire order and notify the customer, as an order-management form
submit would:

    [update_order_status order_number="[cgi order_number]" ship_all=1 send_email=1]

Ship only specific line numbers (null-separated), leaving the rest on
backorder:

    [update_order_status order_number=10023 lines_shipped="1
    3"]

Cancel an order and void its payment:

    [update_order_status order_number=10023 void_transaction=1]

Record a custom four-digit status code and a tracking number:

    [update_order_status order_number=10023 status=1200 tracking_number=1Z999AA10123456784]

## Notes

- Most attributes default to the matching CGI value, so the tag is normally
  driven by a form; called bare it will read whatever `status`, `ship_all`,
  and related fields the current request carries.
- Settlement and void depend on a correctly configured payment route in
  [MV_PAYMENT_MODE](../variables/MV_PAYMENT_MODE.md); on failure the tag sets a
  UI error and returns undef without changing status.
- On MySQL the `update_date` line stamp is skipped (MySQL maintains it via the
  column's own default); other databases receive an explicit timestamp.

## See also

- [charge](../tags/charge.md) — the payment operation used for settle/void
- [MV_PAYMENT_MODE](../variables/MV_PAYMENT_MODE.md) — the payment route
- The [cart and checkout guide](../guides/cart-and-checkout.md) and the
  [payments guide](../guides/payments.md)

## Source

Defined in `code/UI_Tag/update_order_status.tag` as an inline Routine. It
updates the `transactions` and `orderline` tables and calls
`Vend::Tags->charge` for settle/void operations.
