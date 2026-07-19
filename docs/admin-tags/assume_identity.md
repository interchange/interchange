# assume_identity

Read a disk file and interpolate it as though it were a named Interchange page,
temporarily setting the current page name. Used inside the admin UI to render a
page or template file in the context of another page. This tag is part of the
Interchange admin UI toolset (the tags in `code/UI_Tag/`, loaded when the admin
UI feature is enabled), not a storefront tag.

## Syntax

    [assume_identity file]
    [assume_identity file locale]
    [assume_identity file=path name=pagename locale=1]

Standalone tag (no end tag). The return value is the fully interpolated result
of the file, so its Interchange Tag Language (ITL) has already been processed.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `file`    | none    | Path to the file to read and interpolate. |
| `locale`  | `1`     | Passed to the file reader as its locale flag; when true, locale substitutions in the file are applied. |
| `name`    | derived | Page name to assume while interpolating. When unset it is derived from `file` by stripping a leading `pages/` and the file extension. |

Positional order: `file`, `locale` (two positional parameters).

The tag declares `addAttr`, so `name` is read from the options hash.

## Description

`[assume_identity]` sets the global variable `MV_PAGE` to the assumed page
name, then returns
`Vend::Interpolate::interpolate_html(Vend::Util::readfile(file, undef, locale))`.
The effect is that any ITL in the file that depends on the current page name
(for example `[var MV_PAGE]`) behaves as if the reader had requested that page
directly.

The assumed page name comes from `name` if supplied. Otherwise the tag takes
`file`, removes a trailing `.extension`, and strips a leading `pages/`, so
`pages/admin/foo.html` becomes `admin/foo`.

`locale` defaults to `1` when not given.

## Examples

Interpolate a page file, letting the tag derive the page name from the path:

    [assume_identity pages/help/shipping.html]

Interpolate a file but present it under a specific page name:

    [assume_identity file=lib/UI/pages/admin/preview.html name=admin/preview]

## Notes

`MV_PAGE` is changed globally for the remainder of the request; the tag does
not restore the previous value. Reach for it only where taking on the target
page's identity is the intended effect.

## See also

- [page](../tags/page.md), [include](../tags/include.md)
- [base_url](base_url.md)
- Concepts: [templating](../guides/templating.md),
  [admin UI](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/assume_identity.tag` (registered as the tag
`assume-identity`; ITL treats hyphen and underscore in tag names as
equivalent). Implemented by the inline Routine, which calls
`Vend::Util::readfile` and `Vend::Interpolate::interpolate_html`.
