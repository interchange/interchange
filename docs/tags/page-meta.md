# page-meta

Load a page's stored metadata (title, description, and any other fields
configured for it) into temporary scratch variables so the surrounding
template can emit them. Reach for it at the top of a template to pull
per-page `<title>`/`<meta>` content out of the page-meta store.

## Syntax

    [page-meta]
    [page-meta PAGE]
    [page-meta page="PAGE"]

Standalone tag (no end tag). Produces no direct output; it works by side
effect, setting scratch variables and returning nothing.

## Attributes

| Attribute | Default            | Description |
|-----------|--------------------|-------------|
| `page`    | current page name  | The page whose metadata to load. When omitted, the global variable `MV_PAGE` (the page being rendered) is used. |

The tag accepts arbitrary additional named attributes (`addAttr`), but the
routine reads only `page`.

## Description

`[page-meta]` looks up the meta record for `pages/<page>` (using
`Vend::Table::Editor::meta_record`, the same store the administrative UI
uses for per-page metadata). For every field in that record it does the
following:

- skips the `code` field and any field whose value is empty;
- if the value contains ITL tags (`[word...`) or `__VARIABLE__` references,
  interpolates it first;
- stores the result in a temporary scratch variable named after the field.

The values are set through Interchange's temporary-scratch mechanism, so
each metadata field becomes readable with [scratch](scratch.md) `<field>`
and is automatically cleared at the end of the page. Which fields exist
depends on how the page's metadata was configured (commonly `title`, plus
description/keyword fields).

The tag itself returns the empty string; you read the values it set.

## Examples

Load the current page's metadata, then emit a title and description:

    [page-meta]
    <title>[scratch title]</title>
    <meta name="description" content="[scratch meta_description]">

Load metadata for a specific page:

    [page-meta page="products/os28004"]
    Title: [scratch title]

## Notes

- Values are stored as *temporary* scratch (cleared when the page finishes),
  not as ordinary persistent scratch, so read them on the same page.
- If the page has no meta record, the tag sets nothing and the
  corresponding `[scratch ...]` lookups are empty.

## See also

- [scratch](scratch.md) — read the values this tag sets
- [tmp](tmp.md) — the temporary-scratch setter this tag builds on
- [../guides/admin-ui.md](../guides/admin-ui.md) — where page metadata is
  configured

## Source

Defined in `code/UserTag/page_meta.tag` (registers the tag `page-meta`).
Implemented by an inline Routine that calls
`Vend::Table::Editor::meta_record` and `Vend::Interpolate::set_tmp` (which
writes temporary scratch variables).
