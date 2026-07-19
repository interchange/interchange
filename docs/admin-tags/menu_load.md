# menu_load

Generate tab-delimited menu data from a database table, ready to load into the
Interchange menu system. Reach for it in the admin UI menu loader to seed a
navigation menu from your product groups, categories, or an existing HTML
navigation block.

`[menu_load]` is part of the admin UI tag set in `code/UI_Tag/`, loaded when
the administrative interface is enabled; it is not a storefront tag.

## Syntax

    [menu_load type=tree table=products ...]
    [menu_load type=html html="..."]

Standalone tag (no end tag). It returns a multi-line, tab-separated block: a
header row of field names followed by one row per menu entry. The output is
not reparsed as Interchange Tag Language (ITL).

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `type` | `tree` | Which builder to run: `tree`, `category_file`, `comb_category`, `cat_menu`, or `html` (see Description). |
| `menu_fields` | the standard menu column set | Space/comma-separated list of the columns emitted per row and named in the header. |
| `table` | depends on `type` | Source table (`products` for `tree`/`comb_category`, `category` for `category_file`, `area` for `cat_menu`). |
| `first_field` | `prod_group` | Top-level grouping column. |
| `second_field` | `category` | Second-level grouping column. |
| `desc_field` | `description` | Description/leaf column. Alias: `description_field`. |
| `key_field` | table key | Key column; defaults to the table's configured key. |
| `sort_fields` | grouping fields | Columns used in the `ORDER BY`. |
| `no_leaves` | off | (`tree`) Omit the individual product leaf rows, building only the group levels. |
| `even_large` | off | Permit building from a table flagged `LARGE`; otherwise the tag refuses. |
| `comb_field` | `comb_category` | (`comb_category`) Combined-category column parsed on `:` into levels. |
| `cat_table` | `cat` | (`cat_menu`) Second-level category table joined to `area`. |
| `sel` | none | (`cat_menu`) Filter the `area` table on its `sel` column. |
| `html` | none | (`html`) Existing HTML whose `<a>` links become menu rows. |

Positional order: `type`. Because the tag declares `addAttr`, all other
attributes are read from the option hash. Most callers pass a hash from Perl,
as the menu editor does.

## Description

`[menu_load]` produces the tab-delimited text the menu system expects: the
first line is the header of `menu_fields`, and each following line is a menu
row with those fields tab-joined. The `type` selects the builder:

- **`tree`** — Queries `table` (default `products`) for key, `first_field`,
  `second_field`, and `desc_field`. It emits a group row when the top-level
  value changes, a subgroup row when the second-level value changes, and
  (unless `no_leaves`) a leaf row per record. Group rows carry a `scan`
  search URL in their `page` field so the menu entry runs the corresponding
  search.
- **`category_file`** — Like `tree` but sourced from a `category` table and
  built around a `sku_field`; leaf rows are not emitted, only the group levels.
- **`comb_category`** — Reads a single `comb_field` (default `comb_category`)
  whose values encode a hierarchy separated by `:`, and builds one menu level
  per path segment, with a search `form` for each.
- **`cat_menu`** — Joins an `area` table to a `cat` table (`cat_table`),
  turning each area and its categories into menu rows, resolving each row's
  link from its `link_type` (`external`, `internal`, `simple`, or `complex`).
- **`html`** — Parses the `<a>` anchors out of an existing HTML block, turning
  each link into a menu row with `page`, `form`, `name`, and `description`
  taken from the href, query string, anchor text, and `title`.

If a source table cannot be opened, is empty, or is `LARGE` without
`even_large`, the builder records an error via `[error]` and returns empty.

## Examples

Build a tree menu from the strap `products` table's `prod_group` and
`category` fields:

    [menu_load type=tree table=products
        first_field=prod_group second_field=category]

The result is a tab-delimited block beginning with the field header, for
example (tabs shown as spaced columns):

    code  mgroup  msort  ...  name         ...
    0     ...     0            Hand Tools
    0     ...     1            Hammers
    ...   ...     2            16 oz Hammer

From Perl in a `[perl]` or `[calc]` block, as the menu editor does:

    [calc]
        my %opt = (
            type => 'tree',
            table => 'products',
            no_leaves => 1,
        );
        return $Tag->menu_load(\%opt);
    [/calc]

## Notes

The generated rows feed the Interchange menu/tree display machinery; the exact
menu-field semantics (`mgroup`, `msort`, `indicator`, and so on) belong to the
menu system, not to this tag. `[menu_load]` only assembles the data.

Group-row search URLs are built as `scan/...` search specifications; the
matching menu entry runs that search when clicked.

## See also

- Concepts: [admin UI](../guides/admin-ui.md),
  [search](../guides/search.md), [databases](../guides/databases.md)

## Source

Defined in `code/UI_Tag/menu_load.coretag` as an inline `UserTag` Routine
(registered `UserTag menu-load`, `addAttr`).
