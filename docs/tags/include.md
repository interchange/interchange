# include

Read another file and interpolate its contents inline as part of the current
page. Reach for it to factor shared page fragments (headers, checkout steps,
snippets) into separate files that are parsed for tags when included.

## Syntax

    [include file]
    [include file=ord/checkout/payment]
    [include file locale]

Standalone tag (no end tag). The included file's contents are interpolated as
Interchange Tag Language (ITL) before insertion.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `file`    | required | Path of the file to include, relative to the catalog directory (or a [TemplateDir](../config/TemplateDir.md)). |
| `locale`  | `1` (on) | Whether to apply locale translation of `[LC]`/`__..__` bits while reading the file. |

Positional order: `file`, `locale`.

## Description

`[include]` inserts the named file's contents into the page, then
interpolates them, so any ITL in the included file is expanded in the current
request's context. The file is searched relative to the catalog root and any
directories named by the [TemplateDir](../config/TemplateDir.md) directive.

File names beginning with `/` or `..` are rejected when the server
administrator has enabled [NoAbsolute](../config/NoAbsolute.md).

To guard against runaway or circular inclusion, the tag enforces a depth
limit. The default is 10 nested includes; it is configurable through the
[Limit](../config/Limit.md) directive using the key `include_depth`. When the
limit is exceeded, the tag logs an error once and returns nothing.

Contents are always interpolated. To insert a file *without* reparsing its
contents as ITL, use [file](file.md) instead.

## Examples

Include a file and reparse it for tags:

    [include ord/checkout/payment]

If `ord/checkout/payment` contains:

    Order total: [total-cost]

then the `[total-cost]` tag is expanded in place when the file is included.

Include a fragment without locale translation:

    [include file=snippets/legal locale=0]

## Notes

Because the included content is interpolated, an included file can itself
include others — hence the depth limit. Raise or lower it with
`Limit include_depth N` in `catalog.cfg` if your templates legitimately nest
deeply.

## See also

- [file](file.md)
- [TemplateDir](../config/TemplateDir.md)
- [Limit](../config/Limit.md)
- [NoAbsolute](../config/NoAbsolute.md)
- Concepts: [templating](../guides/templating.md)

## Source

Defined in `code/SystemTag/include.coretag` as an inline Routine, which reads
the file with `Vend::Util::readfile` and interpolates it with
`Vend::Interpolate::interpolate_html`.
