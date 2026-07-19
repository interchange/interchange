# soap

Make a SOAP client call from a page: invoke a remote method over a URI and
proxy, and return (or store) the result. Reach for it when Interchange needs
to consume a SOAP web service.

## Syntax

    [soap call="METHOD" uri="URI" proxy="PROXY" param=... result=...]

Standalone tag (no end tag). Requires the `SOAP::Lite` Perl module to be
installed; without it the tag cannot run.

## Attributes

| Attribute         | Default | Description |
|-------------------|---------|-------------|
| `call`            |         | Remote method name to invoke. If empty, an `init` call is made against the service. |
| `uri`             |         | The SOAP URI (namespace) of the service. |
| `proxy`           |         | The SOAP proxy (transport endpoint URL). |
| `param`           |         | Argument(s) to pass to the method. A scalar is passed as-is; an array reference is expanded to a positional list; a hash reference is expanded to key/value pairs. |
| `object`          |         | A pre-built `SOAP::Lite` object to reuse instead of constructing a new one. |
| `result`          |         | Name of a scratch variable in which to also store the returned result. |
| `init`            |         | When true, return the empty string instead of the result (fire-and-forget). |
| `trace_transport` |         | Name of a configured `Sub`/`GlobalSub` to install as a `SOAP::Trace` transport callback for debugging. |

Positional order: `call`, `uri`, `proxy` (`PosNumber 3`).

## Description

The tag builds a `SOAP::Lite` request from `uri` and `proxy`, calls the named
method with any `param` arguments, and returns the call's `result`. When `call`
is empty an `init` call is issued instead. Any error raised during the call is
logged with `logError` and the tag returns undef (an empty string in the page).

Interchange Tag Language (ITL) has no native complex-type builder, so nested
SOAP arguments are constructed with the companion tag
[soap_entity](soap_entity.md), whose return value (a `SOAP::Data` object) is
passed through `param`.

If `result` is given, the returned value is additionally stored in the named
scratch variable, readable later with [scratch](scratch.md).

## Examples

Call a method that takes no arguments and print the result:

    [soap call="getServerVersion"
          uri="http://www.example.com/StatusService"
          proxy="http://www.example.com/soap"]

Pass a single scalar argument and stash the result in scratch:

    [soap call="lookupZip"
          uri="urn:GeoService"
          proxy="http://api.example.com/soap"
          param="90210"
          result=city_state]
    You are in: [scratch city_state]

## Notes

- The SOAP subsystem must be available (`SOAP::Lite` installed). Server-side
  SOAP is configured separately with the `SOAP*` global directives.
- Errors are logged, not shown; check the catalog error log if a call returns
  nothing unexpectedly.

## See also

[soap_entity](soap_entity.md), [scratch](scratch.md), the
[perl-embedding](../guides/perl-embedding.md) guide.

## Source

Defined in `code/SystemTag/soap.coretag`. Implemented by
`Vend::SOAP::tag_soap` in `lib/Vend/SOAP.pm`.
