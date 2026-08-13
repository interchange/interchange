# MimeType

Maps filename extensions to MIME content types for files Interchange serves or
mails. Reach for it when the built-in type table does not cover an extension
you use, or to override a default type.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    MimeType  extension type

Whitespace-separated `extension type` pairs (`parse_hash`), accumulated into a
hash. The extension is given without a leading dot; the special extension
`default` sets the type used for unknown content. Default: empty (only the
built-in table applies).

## Description

Interchange's `mime_type` routine in `lib/Vend/Util.pm` resolves a file's
content type from its extension. It consults, in order, the catalog's
`MimeType` map, the built-in `%MIME_type` table, the catalog's
`MimeType default`, and finally the built-in default:

```perl
return $Vend::Cfg->{MimeType}{$val}
            || $MIME_type{$val}
            || $Vend::Cfg->{MimeType}{default}
            || $MIME_type{default};
```

Because the catalog map is checked first, a `MimeType` entry overrides the
built-in type for the same extension. Extensions are compared in lower case.
This type is used, for example, when [DeliverImage](DeliverImage.md) streams a
file and when building content types for mailed attachments.

## Examples

Serve `.itl` files as plain text and set the fallback type for unknown
extensions:

```
MimeType itl text/plain
MimeType default text/plain
```

## See also

[DeliverImage](DeliverImage.md), [MailOrderTo](MailOrderTo.md),
[HTMLsuffix](HTMLsuffix.md), the [email](../guides/email.md) guide.

## Source

Parsed by `parse_hash` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{MimeType}` in `mime_type` in `lib/Vend/Util.pm`.
