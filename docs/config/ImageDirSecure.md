# ImageDirSecure

Sets the base location Interchange prepends to relative image paths when
the page is being served over a secure (HTTPS) connection. Reach for it
when your HTTP and HTTPS servers cannot share the same image directory
path.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    ImageDirSecure  LOCATION

`LOCATION` is stored verbatim (no parser), usually a URL path such as
`/images.ssl/`. Default: empty. When empty, secure requests fall back to
[ImageDir](ImageDir.md).

## Description

`ImageDirSecure` works exactly like [ImageDir](ImageDir.md) but applies
only when the current request is secure. During the page's image-rewrite
pass Interchange chooses `ImageDirSecure` (if set) for HTTPS requests and
`ImageDir` for plain HTTP requests, then prepends the chosen value to
relative `src=` and `background=` references (`<img>`, `<input>`,
`<body>`, and table elements). Values that are already absolute (begin
with `/` or a URL scheme) are left unchanged.

Use it when separate HTTP and HTTPS servers cannot present images at the
same path -- point `ImageDirSecure` at the path that works under the
secure server.

## Examples

Serve secure-page images from a distinct path:

```
ImageDirSecure   /images.ssl/
```

## Notes

Include the trailing `/`; the value is concatenated directly in front of
the relative path.

If you leave `ImageDirSecure` unset and rely on the fallback to
`ImageDir`, do not give `ImageDir` an `http://` value -- secure pages
would then load images over plain HTTP.

## See also

[ImageDir](ImageDir.md), [ImageAlias](ImageAlias.md),
[ImageDirInternal](ImageDirInternal.md), [SecureURL](SecureURL.md),
[VendURL](VendURL.md).

## Source

Stored raw (no parser) from the `catalog_directives()` table in
`lib/Vend/Config.pm`; consumed in
`Vend::Interpolate::substitute_image` (`lib/Vend/Interpolate.pm`) and
`lib/Vend/Dispatch.pm`.
