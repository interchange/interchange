# ImageDir

Sets a base location that Interchange prepends to relative image paths
found in a page's HTML. Reach for it so page authors can write
`<img src="test.png">` and have it resolve to the correct web-accessible
image directory at serve time.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    ImageDir  LOCATION

`LOCATION` is stored verbatim (no parser). It is usually a URL path such
as `/images/`, but may be a full URL. Default: empty (no rewriting).

## Description

As Interchange finishes building a page, it rewrites *relative* image
references so they point under `ImageDir`. The rewrite applies to:

- `src="..."` on any `<i...>` element (`<img>`, `<input>`);
- `background="..."` on `<body>`;
- `background="..."` on `<table>`, `<td>`, `<th>`, and `<tr>`.

Only relative values are rewritten -- a value that begins with `/` or with
a URL scheme (`http:`, `https:`, `//`) is left untouched. With
`ImageDir /images/`, a tag `<img src="test/test.png">` becomes
`<img src="/images/test/test.png">`.

If the current request is being served securely (HTTPS),
[ImageDirSecure](ImageDirSecure.md) is used instead when it is set,
falling back to `ImageDir` otherwise. Rewriting is suppressed entirely by
the `no_image_rewrite` pragma. A separate substitution pass performed by
[ImageAlias](ImageAlias.md) can remap specific leading path fragments
after this step.

## Examples

A web-server path, the most common form (from the strap demo, where
`__IMAGE_DIR__` is filled in by `makecat`):

```
ImageDir          /images/
```

A full URL, e.g. to serve images from a separate host:

```
ImageDir http://images.example.com/images/
```

## Notes

Include the trailing `/`. Because the value is concatenated directly in
front of the relative path, `ImageDir /images` (no slash) would turn
`test.png` into `/imagestest.png`.

If you rely on `ImageDirSecure` being unset and falling back to `ImageDir`
on secure pages, do not give `ImageDir` an `http://` value, or secure
pages would reference images over plain HTTP.

## See also

[ImageDirSecure](ImageDirSecure.md), [ImageAlias](ImageAlias.md),
[ImageDirInternal](ImageDirInternal.md), [VendURL](VendURL.md),
[SecureURL](SecureURL.md), the [templating](../guides/templating.md)
guide.

## Source

Stored raw (no parser) from the `catalog_directives()` table in
`lib/Vend/Config.pm`; the image rewrite is performed in
`Vend::Interpolate::substitute_image` (`lib/Vend/Interpolate.pm`).
