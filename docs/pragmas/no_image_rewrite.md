# no_image_rewrite

Disables Interchange's automatic rewriting of image locations in page output.
Set it when your pages already contain final image URLs and you do not want
`ImageDir` prepended to them.

**Default:** off — image locations are rewritten to point at
[ImageDir](../config/ImageDir.md).

## Syntax

Catalog-wide, in `catalog.cfg`:

    Pragma no_image_rewrite

Page-wide, anywhere in an Interchange page:

    [pragma no_image_rewrite]
    [pragma no_image_rewrite 0]

Block-wide, around an Interchange Tag Language (ITL) block:

    [tag pragma no_image_rewrite]1[/tag]

This is a boolean pragma: set it (value `1`) to disable rewriting, or set it to
`0` to re-enable rewriting where it was turned off.

## Description

Interchange normally rewrites relative image locations in output to point at
[ImageDir](../config/ImageDir.md) (or `ImageDirSecure` for secure requests).
This applies to `src=` in `<img>` and `<input>` tags and to `background=` in
`<body>`, `<table>`, `<tr>`, `<th>`, and `<td>` tags. With
`ImageDir` set to `/foundation/images`, the tag:

    <img src="fancy.gif">

is rewritten to:

    <img src="/foundation/images/fancy.gif">

When `no_image_rewrite` is set, this substitution is skipped and the markup is
left unchanged. The pragma is checked in two places: when installing the default
output filter in `Vend::Parse`, and inside `substitute_image()` itself.
`ImageAlias` substitutions are applied independently of this pragma.

A single tag can suppress rewriting for just its own output with the
`no_image_parse` attribute, without setting the pragma page-wide.

## Examples

Turn image rewriting off for an entire catalog. In `catalog.cfg`:

    Pragma no_image_rewrite

Turn it off for one page that hand-codes its image URLs:

    [pragma no_image_rewrite]
    <img src="https://cdn.example.com/promo/banner.png">

## Notes

Added in Interchange 4.7.0 to give a single switch for all image-path rewriting
(a predecessor, `substitute_table_image`, controlled only table backgrounds and
has since been removed).

## See also

- [post_page](post_page.md) (a `post_page` routine can also suppress rewriting)
- [ImageDir](../config/ImageDir.md)
- [Pragma](../config/Pragma.md)

## Source

The `Pragma` directive is parsed by `boolean_value` in
`lib/Vend/Config.pm`. This pragma is consumed in `add_filter()` in
`lib/Vend/Parse.pm` and in `substitute_image()` in `lib/Vend/Interpolate.pm`.
