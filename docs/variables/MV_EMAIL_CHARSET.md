# MV_EMAIL_CHARSET

Sets the character set declared on email that Interchange sends. Reach for it
when order reports or other mail contain non-ASCII text and need a correct MIME
charset so recipients' mail clients decode them properly.

**Scope:** catalog (`catalog.cfg`) or global (`interchange.cfg`)

## Syntax

    Variable  MV_EMAIL_CHARSET  charset

`charset` is a charset name such as `UTF-8`. Default: empty (no explicit
charset added by this variable).

## Description

When Interchange's built-in mail routine builds a message, it checks
`$::Variable->{MV_EMAIL_CHARSET}` (falling back to the global value) and, if
set, uses it as the charset for the message body. This governs the MIME charset
declaration on mail the server generates itself.

## Examples

Send catalog email as UTF-8:

    Variable  MV_EMAIL_CHARSET  UTF-8

## Notes

This affects Interchange's built-in email sending only. Mail sent by other
means (calling `sendmail` directly, or a custom global subroutine) must set its
own charset.

## See also

[MV_HTTP_CHARSET](MV_HTTP_CHARSET.md), [MV_UTF8](MV_UTF8.md),
[MV_MAILFROM](MV_MAILFROM.md), the [email](../guides/email.md) guide.

## Source

Consumed in `lib/Vend/Util.pm` (mail-building helper) via
`$::Variable->{MV_EMAIL_CHARSET}` / `$Global::Variable->{MV_EMAIL_CHARSET}`.
