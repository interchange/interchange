# tree

Walk a self-referential (parent/child) table and iterate the body over the
resulting tree, depth-first, exposing each node's level and children. Reach for
it to render navigation trees, category outlines, and threaded/hierarchical
data.

## Syntax

    [tree table=TABLE master=PARENT_COL subordinate=CHILD_COL start=ROOT]
       ... [item-param FIELD] ... [if-item-param mv_level] ... [/if-item-param] ...
    [/tree]

Container tag. It is a looping tag: the body is a region that is interpolated
once per node, using the `item-*` sub-tag namespace (see below).

## Attributes

| Attribute        | Default | Description |
|------------------|---------|-------------|
| `table`          |         | Table holding the tree (required unless `file` is used). |
| `master`         |         | Column naming each row's parent (the "up" pointer). |
| `subordinate`    |         | Column whose value links a row to its children (the "down" pointer). |
| `start`          |         | Key of the root node to begin from. |
| `sort`           |         | Sort spec applied at each level (`ORDER BY` clause or field list). |
| `where`          |         | Extra SQL `WHERE` condition applied to every level. |
| `spacing`        | `10`    | Indent units added to `mv_spacing` per level. |
| `spacer`         |         | String repeated `mv_spacing` times to build `mv_spacer` indentation. |
| `outline`        |         | Outline-numbering scheme (e.g. `1A1a`) exposed via `mv_increment`. |
| `full`           | `0`     | Expand the entire tree regardless of memo/toggle state. |
| `explode`        |         | Name of a CGI variable that, when set, expands all nodes. |
| `collapse`       |         | Name of a CGI variable that, when set, collapses the tree. |
| `memo`           |         | Scratch key storing per-node expand/collapse state across requests. |
| `toggle`         |         | CGI variable naming a node to toggle open/closed. |
| `stop` / `continue` | | Field controlling where descent stops or continues. |
| `autodetect`     |         | Count children per node (sets `mv_children`) automatically. |
| `multiple_start` |         | Treat `start` as several root keys (whitespace/comma separated). |
| `pedantic`       |         | Make an endless-tree loop a fatal error instead of a logged warning. |
| `file`           |         | Read a tab-separated file instead of a table (uses `level_field`, default `msort`). |
| `delimiter`      | tab     | Field delimiter when reading from `file`. |
| `level_field`    | `msort` | Level column when reading from `file`. |
| `code_field`     | key     | Field used as each node's code (defaults to the table key). |

Positional order: `table`, `master`, `subordinate`, `start`. Alias: `sub` for
`subordinate`. Additional named attributes (`addAttr`) are accepted and passed
to the list machinery.

## Description

Starting at `start`, the tag selects that row (or rows, with
`multiple_start`), then repeatedly queries `master = <child value>` to descend
into each node's children, building a flat, depth-first ordered list of node
records. Descent is guarded against endless loops: a cycle is logged (or, with
`pedantic`, made fatal).

Each node record is augmented with iteration metadata before the body sees it:

| Field          | Meaning |
|----------------|---------|
| `mv_level`     | Depth of the node (root = 0). |
| `mv_spacing`   | `mv_level` × `spacing`. |
| `mv_spacer`    | `spacer` repeated `mv_spacing` times (indent string). |
| `mv_increment` | Outline counter for the level (from `outline`). |
| `mv_ip`        | Sequential index of the node in the flattened list. |
| `mv_children`  | Set when the node has children (a count under `autodetect`). |
| `mv_last`      | True on the last node of a level. |
| `mv_toggled`   | True when the node is currently expanded per `memo`. |

The augmented list is then rendered with Interchange's list machinery
(`labeled_list`), so the body uses the same looping sub-tags as
[item-list](item-list.md) and [loop](loop.md), under the default `item`
prefix: `[item-param FIELD]` and `[if-item-param FIELD]...[/if-item-param]`
read a node's own columns and the `mv_*` fields above; `[item-field]`,
`[if-item-field]`, `[item-increment]`, and the rest of the namespace are also
available. See the [templating](../guides/templating.md) guide for the full
sub-tag model.

The tag can also read a pre-ordered tab-separated `file` instead of a table, in
which case `level_field` supplies each row's depth directly.

## Examples

A vertical category tree, indenting each level with non-breaking spaces
(adapted from the strap demo's `category_vertical_tree` component):

    [tree table=tree
          master=parent_fld
          subordinate=code
          start="[control menu_set]"
          sort=code
          spacing=2
          spacer="&nbsp;"
          full=1]
      [item-param mv_spacer][if-item-param page]<a
        href="[area href='[item-param page]']">[item-param name]</a>[else][item-param
        name][/else][/if-item-param]<br>
    [/tree]

Each deeper level is indented two `&nbsp;` more than its parent, and nodes with
a `page` value become links.

## Notes

- `full=1` renders the whole tree on every request; for large trees use
  `memo`/`toggle`/`explode` to expand nodes on demand instead.
- Circular parent/child data is detected. By default the cycle is logged and
  traversal continues; add `pedantic` to make it an error.

## See also

[item-list](item-list.md), [loop](loop.md), [menu](menu.md),
[area](area.md), the [templating](../guides/templating.md) guide.

## Source

Defined in `code/SystemTag/tree.coretag` as an inline `Routine`; the per-node
rendering is done by `Vend::Interpolate::labeled_list`.
