# SOAP_Enable

Turns on individual SOAP-RPC features for a catalog. Currently it controls
whether SOAP methods are allowed to interpolate Interchange Tag Language (ITL)
content.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    SOAP_Enable  KEY  VALUE

Values are collected as a hash (parser type `hash`): each `key value` pair sets
one flag. Quotes around the key or value are optional for word characters.
Default: empty (no features enabled).

The recognized key is:

- `interpolate` -- when true, SOAP methods may interpolate ITL and page
  content; when false or unset, interpolation-based SOAP calls are refused.

## Description

`SOAP_Enable` is a per-catalog feature switch consulted while a SOAP request is
served. It complements [SOAP_Control](SOAP_Control.md), which decides *who* may
reach a subject: `SOAP_Enable` decides *whether* a whole class of behavior
(interpolation) is available in the catalog at all.

SOAP must first be enabled globally with [SOAP](SOAP.md) and a socket provided
with [SOAP_Socket](SOAP_Socket.md); `SOAP_Enable` then refines what the catalog
exposes.

## Examples

Allow SOAP clients to interpolate ITL for this catalog:

```
SOAP_Enable interpolate 1
```

## Notes

The directive stores a general-purpose hash, so additional keys may be honored
by custom SOAP code; the only key the shipped server checks is `interpolate`.

## See also

[SOAP](SOAP.md), [SOAP_Control](SOAP_Control.md),
[SOAP_Action](SOAP_Action.md), [SOAP_Socket](SOAP_Socket.md).

## Source

Parsed by `parse_hash` in `lib/Vend/Config.pm` (stored in
`$Vend::Cfg->{SOAP_Enable}`); consumed in `lib/Vend/Server.pm` (the
`interpolate` flag).
