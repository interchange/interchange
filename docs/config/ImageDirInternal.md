# ImageDirInternal

> **Obsolete:** this directive is parsed and stored but no current
> Interchange code reads it. Use [ImageDir](ImageDir.md) (and
> [ImageDirSecure](ImageDirSecure.md)) instead.

Historically set the image base location used when Interchange's own
built-in HTTP server served pages, rather than a front-end web server.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    ImageDirInternal  LOCATION

`LOCATION` is stored verbatim (no parser). Default: empty.

## Description

`ImageDirInternal` was intended to hold the value of
[ImageDir](ImageDir.md) to use when Interchange's internal HTTP server was
in use, and was documented as requiring a trailing `/` and a
fully-qualified `http://` prefix.

In the current codebase the value is accepted by the configuration parser
and stored on the catalog config, but no runtime code consults it: image
rewriting uses [ImageDir](ImageDir.md) and
[ImageDirSecure](ImageDirSecure.md) only. Setting `ImageDirInternal` has
no effect. It is documented here for completeness and for readers
maintaining old configuration files.

## Examples

The historical usage was a full URL to the internal server's image tree:

```
ImageDirInternal http://www.example.com/images/
```

## Notes

Because the directive has no current consumer, do not rely on it for new
configurations. Set [ImageDir](ImageDir.md) instead.

## See also

[ImageDir](ImageDir.md), [ImageDirSecure](ImageDirSecure.md),
[ImageAlias](ImageAlias.md).

## Source

Stored raw (no parser) from the `catalog_directives()` table in
`lib/Vend/Config.pm`. A repository-wide search finds no runtime reference
to the stored `ImageDirInternal` value.
