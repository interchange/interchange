# soap_entity

Build a `SOAP::Data` object to use as a structured argument in a
[soap](soap.md) call. Reach for it when a SOAP method needs typed or nested
parameters that a plain scalar cannot express.

## Syntax

    [soap_entity name=... value=... type=... tree=...]

Standalone tag (no end tag). Requires the `SOAP::Lite` Perl module.

## Attributes

The tag accepts arbitrary named attributes (`addAttr`) and passes them
directly to `SOAP::Data->new(%opt)`, so any `SOAP::Data` constructor key is
valid (commonly `name`, `value`, `type`, `uri`, `attr`).

| Attribute | Default | Description |
|-----------|---------|-------------|
| `value`   |         | The entity's value. May itself be a list of nested entities when `tree` is set. |
| `tree`    |         | When true, each element of `value` is treated as another `soap_entity` result and built recursively, producing a nested structure. |

Positional order: none (`PosNumber` unset; use named attributes).

## Description

The tag calls `SOAP::Data->new` with the supplied attributes and returns the
resulting object. That object is not meant to be printed into a page; it is
captured (typically into a scratch/Perl value) and handed to
[soap](soap.md) through its `param` attribute to form a complex argument.

When `tree` is true, the tag walks `value` as a list of sub-entities and builds
each one with a recursive `soap_entity` call, allowing arbitrarily nested SOAP
structures. If construction fails, the error is logged with `logError` and the
tag returns nothing.

## Examples

Because the return value is a Perl object, `soap_entity` is normally used from
embedded Perl or as the `param` of a `soap` call rather than emitted inline:

    [perl tables=""]
        my $arg = $Tag->soap_entity({ name => 'zip', value => '90210' });
        return $Tag->soap({
            call  => 'lookup',
            uri   => 'urn:GeoService',
            proxy => 'http://api.example.com/soap',
            param => $arg,
        });
    [/perl]

## Notes

Requires `SOAP::Lite`. This is a low-level building block; most catalogs that
consume SOAP services drive the whole exchange from embedded Perl using
`SOAP::Lite` directly.

## See also

[soap](soap.md), [perl](perl.md), the
[perl-embedding](../guides/perl-embedding.md) guide.

## Source

Defined in `code/SystemTag/soap.coretag`. Implemented by
`Vend::SOAP::tag_soap_entity` in `lib/Vend/SOAP.pm`.
