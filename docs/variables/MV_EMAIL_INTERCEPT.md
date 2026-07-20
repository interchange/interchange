# MV_EMAIL_INTERCEPT

Redirects all outgoing Interchange email to one or more fixed addresses. Reach
for it on development and staging systems so test orders and notifications never
reach real customers.

**Scope:** catalog (`catalog.cfg`) or global (`interchange.cfg`)

## Syntax

    Variable  MV_EMAIL_INTERCEPT  address@example.com

One address, or several separated by commas. Default: unset (no interception).

## Description

When `MV_EMAIL_INTERCEPT` is set, Interchange's built-in mail routine reroutes
every outgoing message to the given address(es) instead of the intended
recipients. It records the original destination in an `X-Intercepted-To:`
header and notes the interception in the catalog error log. The catalog value
is checked first, then the global value.

## Examples

Send all catalog email to a developer inbox:

    Variable  MV_EMAIL_INTERCEPT  dev@example.com

Send to two addresses:

    Variable  MV_EMAIL_INTERCEPT  dev@example.com, qa@example.com

## Notes

This only affects Interchange's built-in email sending. Mail sent by other means
(calling `sendmail` directly, or talking to an SMTP server yourself) is not
intercepted.

Interception can mask errors: a message that would normally fail for lacking a
`To:` address appears to succeed because a valid address is substituted. Before
turning interception off, verify the real destinations via the
`X-Intercepted-To:` header or the error log.

## See also

[MV_MAILFROM](MV_MAILFROM.md), the [email](../guides/email.md) and
[logging-debugging](../guides/logging-debugging.md) guides.

## Source

Consumed in `lib/Vend/Util.pm` via `$::Variable->{MV_EMAIL_INTERCEPT}` /
`$Global::Variable->{MV_EMAIL_INTERCEPT}`.
