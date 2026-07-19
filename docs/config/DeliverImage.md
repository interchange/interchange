# DeliverImage

Lets Interchange serve image files directly by redirecting to them under
[ImageDir](ImageDir.md), before any session or database work happens.
Reach for it when clients (notably some HTML editors) request images
through the Interchange link program and you want those requests handled
quickly and without a session.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    DeliverImage  yes|no

A boolean (`parse_yesno`): `Yes`, `No`, `1`, `0`, and so on. Default:
`No`.

## Description

When enabled, and the request is a `GET` whose path ends in an extension
whose [MimeType](MimeType.md) begins with `image/`, Interchange rewrites
the path to prepend [ImageDir](ImageDir.md) (or
[ImageDirSecure](ImageDirSecure.md) for a secure request) and issues an
HTTP 302 ("Moved temporarily") redirect to it:

```perl
if($Vend::Cfg->{DeliverImage}
    and $CGI::request_method eq 'GET'
    and $CGI::path_info =~ /\.(\w+)$/
    and $mt = Vend::Util::mime_type($CGI::path_info)
    and $mt =~ m{^image/}
  )
{ ... }
```

This happens early in dispatch, before databases or the session are
opened, so it is fast. Interchange sets `$Vend::tmp_session`, so no
session cookie is issued for the image request. Paths beginning with
`admin/` are never resent this way.

## Examples

Enable direct image delivery:

```
DeliverImage Yes
```

A request for `interchange.png` then redirects to that file under
[ImageDir](ImageDir.md), provided the file exists there.

## Notes

The redirect target depends on [ImageDir](ImageDir.md) /
[ImageDirSecure](ImageDirSecure.md) and on [MimeType](MimeType.md)
correctly mapping the extension to an `image/*` type. This feature was
added to cope with clients that fetch images through the catalog link
program.

## See also

[ImageDir](ImageDir.md), [ImageDirSecure](ImageDirSecure.md),
[MimeType](MimeType.md), the
[templating](../guides/templating.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{DeliverImage}` in `lib/Vend/Dispatch.pm`.
