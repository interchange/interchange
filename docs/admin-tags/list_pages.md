# list_pages

List the catalog's page files, walking the page directory recursively. Reach
for it to build a page picker in admin UI tools such as the content editor.

`[list_pages]` is part of the admin UI tag set in `code/UI_Tag/`, loaded when
the administrative interface is enabled; it is not a storefront tag.

## Syntax

    [list_pages]
    [list_pages options=1 keep=1 ext=.html base=subdir]

Standalone tag (no end tag). The default return value is the page names joined
with spaces.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `options` | off | When set (the positional argument), wraps the result in HTML `<OPTION>` tags for direct use in a `<select>`. |
| `keep` | off | When set, keeps the file-name suffix on each page name instead of stripping it. |
| `ext` | value of `HTMLsuffix` (usually `.html`) | The file-name suffix used to select and (unless `keep`) strip page files. |
| `base` | value of `PageDir` | Directory to search, relative to the catalog `VendRoot`; defaults to the catalog page directory. |
| `arrayref` | off | When set, returns an array reference of names (for use from Perl) instead of a string. |

Positional order: `options`.

Because the tag declares `addAttr`, the remaining attributes (`keep`, `ext`,
`base`, `arrayref`) are read from the option hash.

## Description

`[list_pages]` delegates to `UI::Primitive::list_pages`, which uses
`File::Find` to walk `base` (the catalog page directory by default). It
collects every regular file whose name ends in the `ext` suffix, removes the
`base` prefix so names are page-relative, and — unless `keep` is set — strips
the suffix so each name is a usable page reference. The names are returned
sorted.

The output form depends on the options: `options=1` produces an
`<OPTION>`-prefixed list, `arrayref=1` returns an array reference, and
otherwise the names are joined with single spaces.

## Examples

List every page in the catalog as a space-separated string:

    [list_pages]

might produce:

    index flypage ord/basket ord/checkout results

Build a select box of pages directly:

    <select name="ui_page">
    [list_pages options=1]
    </select>

List only the pages under a subdirectory, keeping the `.html` suffix:

    [list_pages base=admin keep=1]

## Notes

`[list_pages]` finds page source files on disk; it does not include pages
generated purely from database `page` tables or from Autoload. The suffix
defaults to the catalog's `HTMLsuffix`, so catalogs using a non-default suffix
list correctly without setting `ext`.

## See also

- [list_glob](list_glob.md) — non-recursive glob of arbitrary files
- Concepts: [templating](../guides/templating.md),
  [admin UI](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/list_pages.coretag` (`UserTag list_pages`); the routine
delegates to `UI::Primitive::list_pages` in `dist/lib/UI/Primitive.pm`.
