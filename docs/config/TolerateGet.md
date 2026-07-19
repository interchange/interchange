# TolerateGet

Makes Interchange also parse the query-string (GET) parameters of a POST
request, instead of only the POST body. Reach for it when forms are submitted by
POST but you still need to read variables passed in the URL of the same request.

**Scope:** global (`interchange.cfg`)

## Syntax

    TolerateGet  Yes|No

A boolean (`Yes`/`No`, `1`/`0`, `on`/`off`). Default: `No`.

## Description

By default a POST request is read from the request body only, and any parameters
in the URL query string are ignored. With `TolerateGet` set, Interchange also
parses the query string of a POST request and merges those parameters in, so a
form that posts to `process?mv_action=refresh&id=5` still sees `id`.

This has to be a global setting because at the time the request URL is parsed
the daemon does not yet know which catalog will handle it (catalog aliases are
resolved later).

## Examples

Parse both GET and POST parameters on POST requests (in `interchange.cfg`):

```
TolerateGet  Yes
```

## Notes

Accepting parameters from both the URL and the body widens what a form
submission carries; enable it only when you rely on that behavior, and be aware
that URL parameters can be supplied by anyone who crafts the link.

## See also

[EnableJSONPost](EnableJSONPost.md), [UnpackJSON](UnpackJSON.md), the
[forms](../guides/forms.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Server.pm` via `$Global::TolerateGet` during request parsing.
