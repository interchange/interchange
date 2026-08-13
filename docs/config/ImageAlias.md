# ImageAlias

Rewrites specific leading path fragments in image references on a served
page, in the manner of a web-server `Alias`. Reach for it to remap a path
prefix (for example `/images/`) to another location without editing every
page.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    ImageAlias  FROM  TO

Parsed as key/value pairs into a hash: `FROM` is the leading path fragment
to match, `TO` is what to substitute for it. Repeat the directive to add
more aliases. Default: empty.

## Description

After the [ImageDir](ImageDir.md) rewrite runs, Interchange makes a second
pass for each `ImageAlias` entry. For every image reference whose value
*begins with* `FROM`, that leading fragment is replaced with `TO`. The
substitution applies to the same elements as `ImageDir`: `src=` on
`<img>`/`<input>`, and `background=` on `<body>`, `<table>`, `<td>`,
`<th>`, and `<tr>`.

Unlike `ImageDir`, `ImageAlias` matches at the start of the reference
regardless of whether the value is otherwise absolute, so it can retarget
paths such as `/images/` that `ImageDir` would leave alone. This makes it
useful when you want pages to remain editable in an external HTML editor
(with real, browsable image paths) while Interchange remaps them at serve
time.

## Examples

Map every reference beginning with `/images/` onto a per-catalog tree:

```
ImageAlias  /images/  /thiscatalog/images/
```

With that in place, `<img src="/images/logo.png">` is served as
`<img src="/thiscatalog/images/logo.png">`.

## Notes

The match is a leading-fragment (prefix) substitution, not a full-path
rewrite: only the matched prefix is replaced, the remainder of the path is
kept. Add a directive line per alias you need.

## See also

[ImageDir](ImageDir.md), [ImageDirSecure](ImageDirSecure.md),
[ImageDirInternal](ImageDirInternal.md), the
[templating](../guides/templating.md) guide.

## Source

Parsed by `parse_hash` in `lib/Vend/Config.pm`; the alias substitution is
performed in `Vend::Interpolate::substitute_image`
(`lib/Vend/Interpolate.pm`).
