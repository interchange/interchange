# UnpackJSON

Controls whether a JSON POST body whose top level is an object is unpacked into
individual CGI variables. Reach for it to decide whether JSON request fields
appear as ordinary form values or only as the decoded structure.

**Scope:** global (`interchange.cfg`)

## Syntax

    UnpackJSON  Yes|No

A boolean (`Yes`/`No`, `1`/`0`, `on`/`off`). Default: `Yes`.

## Description

When [EnableJSONPost](EnableJSONPost.md) is on and a request arrives with
content type `application/json`, Interchange decodes the body with the `JSON`
module. The decoded structure is always available to code as
`$CGI::json_ref`. In addition, if `UnpackJSON` is set and the decoded value is a
JSON object (a hash), each of its top-level keys is copied into the CGI variable
space, so `{"sku":"os28004","quantity":2}` becomes the CGI variables `sku` and
`quantity` that pages and actions read like any posted form field.

With `UnpackJSON` off, the decoded data is reachable only through
`$CGI::json_ref`; the top-level keys are not exposed as CGI variables. The
setting has no effect unless [EnableJSONPost](EnableJSONPost.md) is enabled and
the `JSON` module is installed.

## Examples

Keep JSON fields out of the CGI variable space (in `interchange.cfg`):

```
EnableJSONPost  Yes
UnpackJSON      No
```

With the default `UnpackJSON Yes`, a body of `{"sku":"os28004"}` makes `sku`
readable as an ordinary request variable.

## See also

[EnableJSONPost](EnableJSONPost.md), [TolerateGet](TolerateGet.md), the
[forms](../guides/forms.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Server.pm` via `$Global::UnpackJSON` during POST parsing.
