# EnableJSONPost

Lets Interchange accept request bodies posted with a JSON content type, decoding
the JSON into request variables. Reach for it when a front-end or API client
sends `application/json` POST data instead of form-encoded data.

**Scope:** global (`interchange.cfg`)

## Syntax

    EnableJSONPost  yes|no

A yes/no boolean (`yes`/`no`, `1`/`0`, `on`/`off`, `true`/`false`). Default:
`No`.

## Description

By default Interchange handles form-encoded and multipart POST bodies. With
`EnableJSONPost` on, a POST whose `Content-Type` is `application/json` is parsed
as JSON: the raw body is decoded with `JSON::decode_json`, and the parsed
structure is made available as `$CGI::json_ref` (`lib/Vend/Server.pm`).

If the decoded JSON is a hash and [UnpackJSON](UnpackJSON.md) is enabled (its
default), the top-level keys of that hash are merged into the ordinary CGI
values, so JSON fields behave like posted form fields. This requires the Perl
`JSON` module to be installed; without it, a JSON POST is rejected as an invalid
request and a message is logged.

## Examples

Accept JSON POST bodies in `interchange.cfg`:

```
EnableJSONPost Yes
```

A client posting `{"mv_todo":"refresh","sku":"os28004"}` with content type
`application/json` then has `mv_todo` and `sku` available as request variables
(with [UnpackJSON](UnpackJSON.md) on).

## Notes

Decoding errors are caught and logged rather than aborting the request. Access
the full decoded structure through `$CGI::json_ref` when you need nested data
that top-level unpacking does not expose.

## See also

[UnpackJSON](UnpackJSON.md), [TolerateGet](TolerateGet.md), the
[forms](../guides/forms.md) guide.

## Source

Parsed by `parse_yesno` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Server.pm` (`$Global::EnableJSONPost`, `parse_cgi`).
