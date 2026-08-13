# flex_select

Render a full tabular overview of a database table for the admin: a
searchable, sortable, paged grid of records with per-row checkboxes and
edit/delete controls. It is part of the administrative UI toolset (loaded
only when the admin UI is enabled), not a storefront tag; it is the engine
behind the admin's generic table-listing screen.

## Syntax

    [flex_select init=1]
    [flex_select table=... options... ] BODY [/flex_select]

Container tag (has an end tag). Output is produced by the tag; the body is
used as the template scaffold that the tag fills in.

## Attributes

`flex_select` takes a very large option set (dozens of parameters covering
layout, class names, buttons, paging, and metadata). The load-bearing ones:

| Attribute        | Default | Description |
|------------------|---------|-------------|
| `table`          | current data table | The table to list. |
| `init`           |         | Run the initialization pass instead of rendering (see below). |
| `sql_query`      |         | Use this SQL query to select the rows and derive the table. |
| `mv_form_profile`|         | Form profile (validation spec) to attach to the generated form. |
| `label`          |         | Search label for the generated search. |
| `edit_page`      |         | Admin page the per-row edit link targets. |
| `no_checkbox`    |         | Omit the per-row selection checkboxes. |
| `no_group`       |         | Omit the grouping/letter navigation. |
| `no_top` / `no_bottom` |   | Suppress the top or bottom button bar. |
| `more_list`      |         | Template for the paging ("more") navigation. |
| `ui_meta_view`   |         | Metadata view used to decide which columns show and how. |
| `href`           |         | Base href for the generated form/links. |
| Many `*_class`, `*_width`, `*_border` options | | CSS class names and table-layout attributes for headers, rows, and groups. |

Positional order: `table` (the first parameter).
Alias: `ml` for `height`.

## Description

`flex_select` is used in two passes on the admin's table-listing page:

1. **Initialization** (`init=1`). This pass (routine `flex_select_init`)
   prepares the search: it reconciles the requested table, applies any
   `sql_query`, honors "like" text filters, and processes record deletions
   requested from a prior submission (guarded by an
   [if_mm](if_mm.md) `tables` `=d` permission check). It returns without
   rendering a grid.

2. **Rendering.** A second call (without `init`) builds the results grid:
   a form containing a table of matching records. Each column is chosen from
   the table's metadata / requested view; each row gets a checkbox and links
   to edit (and, with permission, delete) the record. Sorting controls,
   letter/group navigation, and a paging ("more") bar are generated around
   the grid, styled by the many class and layout options.

The tag reads and writes several CGI and session values to carry state
(current table, return-to stack, sort field, page) between requests, which
is why it is designed to run inside the admin's own pages rather than
standalone.

## Examples

The initialization call, exactly as the shipped admin page begins:

    [flex_select init=1]

Render the grid with a form-validation profile attached:

    [flex_select mv_form_profile=some_spec]

List a specific table (here the demo `products` table) without the
selection checkboxes:

    [flex_select table=products no_checkbox=1]

## Notes

- This tag is tightly coupled to the admin UI: it emits admin-specific
  markup, consults UI metadata, and depends on UI permission checks and
  session state. Treat it as the admin table lister rather than a
  general-purpose reporting tag; use [query](../tags/query.md) or
  [loop](../tags/loop.md) for ad-hoc listings.
- The full option list is extensive and largely presentational. Only the
  widely used options are documented here; the definitive list is the
  routine in the source file. Behavior of the rarer layout options is best
  confirmed against that code.

## See also

- [table_editor](table_editor.md) — the per-record edit form
- [if_mm](if_mm.md) — the permission checks it enforces
- [loop](../tags/loop.md), [query](../tags/query.md) — general listings
- The [admin UI guide](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/flex_select.coretag`. Implemented by the inline
Routine (with a `flex_select_init` helper) in that file.
