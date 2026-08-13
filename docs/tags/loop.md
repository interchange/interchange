# loop

Iterate the tag body once for each item in a supplied list, a search result, or
a file — the general-purpose looping tag. Reach for it whenever you need to
repeat markup over a set of values: a fixed list, a database search, a
comma-separated field, or an array handed in from embedded Perl.

## Syntax

    [loop list="item item item"]
    ... body, repeated per item ...
    [/loop]

Container tag (has an end tag). The body is a looping region: it is repeated
once per row and its prefix sub-tags (default prefix `loop`) are interpolated
against each row.

## Attributes

| Attribute        | Default   | Description |
|------------------|-----------|-------------|
| `list`           | none      | The list of items to iterate (positional). |
| `prefix`         | `loop`    | Sub-tag prefix used inside the body. |
| `search`         | none      | Run a one-click search and iterate its matches instead of a literal list. |
| `file`           | none      | Read the list from a file (turns on line/record mode). |
| `object`         | none      | Iterate a pre-built object (`object.mv_results=`...) from Perl or another tag. |
| `fn` / `mv_field_names` | none | Column names for multi-column rows (enables `[loop-param NAME]`). |
| `delimiter`      | `[,\s]+`  | Field separator (a tab in line/record mode). |
| `record_delim`   | newline   | Row separator in line/record mode. |
| `lr`             | off       | Line/record mode: split into rows on `record_delim`, columns on `delimiter`. |
| `quoted`         | off       | Parse the list with shell-style quoting (spaces inside quotes kept). |
| `acclist`        | off       | Parse an accessory list of `option=label` pairs. |
| `ranges`         | off       | Expand ranges such as `1..4` in the list. |
| `head_skip`      | none      | Drop this many leading rows; the last dropped row supplies field names. |
| `ml`, `more`     | none      | Pagination controls, passed through to the list machinery. |

Positional order: `list`.

Aliases: `args` and `arg` for `list`.

The tag declares `addAttr`, so any additional list/region options are accepted
and forwarded.

## Description

`[loop]` builds a result set from whichever source you give it, then iterates
it. In priority order it uses: an `object`, a Perl `list` reference, a `search`,
a `file`, an `extended` metadata lookup, or — the common case — a literal string
in `list`. By default that string is split on commas and whitespace into
single-column rows, so `list="a b c"` yields three items.

Other parsing modes change how the string becomes rows:

- **`lr=1`** (line/record) — each line is a row and tabs separate columns; good
  for pasted or file data. `file=` turns this on automatically.
- **`quoted=1`** — shell-style parsing, so `"two words"` stays one item.
- **`acclist=1`** — parses `opt=Label, opt2=Label2` into two-column rows, the
  format Interchange option lists use.
- **`ranges=1`** — expands `1..4` style ranges in the list.

Supply `fn`/`mv_field_names` (or use `head_skip` to take them from the data) to
name the columns of multi-column rows so `[loop-param NAME]` can address them.

### Prefix sub-tags

Inside the body, each row's data is reached through sub-tags whose prefix is
`loop` (change it with `prefix=`):

- `[loop-code]` — the row's key (its first column)
- `[loop-param NAME]` / `[loop-pos N]` — a column by name or position
- `[loop-field NAME]` — a column from the **products** table for `[loop-code]`
- `[loop-increment]` — the 1-based row counter
- `[loop-change NAME] ... [/loop-change]` — runs only when a column's value
  changes between rows
- `[if-loop-field NAME] ... [/if-loop-field]` — per-row conditional
- `[on-match] ... [/on-match]` / `[no-match] ... [/no-match]` — run when the
  list did or did not produce rows

Loops **nest** by giving the inner loop a different `prefix`, so its sub-tags do
not collide with the outer one. See [templating](../guides/templating.md) for
the complete looping-tag model shared by [item-list](item-list.md),
[query](query.md), and [search-region](search-region.md).

## Examples

Iterate a fixed list — `[loop-code]` is each item:

    [loop list="Small Medium Large"][loop-code] [/loop]

produces:

    Small Medium Large

Build the options of a `<select>` from a numeric range:

    <select name="mv_credit_card_exp_year">
    [loop ranges=1 list="2026..2036"]
    <option>[loop-code]
    [/loop]
    </select>

Nest two loops with different prefixes to make every combination:

    [loop prefix=size list="Small Medium Large"]
      [loop prefix=color list="Red White Blue"]
        [color-code]-[size-code]<br>
      [/loop]
    [/loop]

The first cells of the output are `Red-Small`, `White-Small`, `Blue-Small`, ...

Iterate a database search — here every product whose category contains
`Americana`:

    [loop search="se=Americana/sf=category"]
    [loop-code] [loop-field description]<br>
    [/loop]

Walk every key in a DBM table with the "return all" idiom:

    [loop search="ra=yes/st=db/ml=9999"]
    [loop-code]<br>
    [/loop]

`ra=yes` sets "match everything", `st=db` searches the database directly, and
`ml=9999` caps the matches.

Iterate an array produced in embedded Perl:

    [loop list=`$Scratch->{myrows}`]
    [loop-code]<br>
    [/loop]

where `$Scratch->{myrows}` is an array reference of array references.

## Notes

`[loop]` reads only what you give it; it does not query a table on its own
unless you pass `search=`. For SQL use [query](query.md); for the current cart's
lines use [item-list](item-list.md); for search results already performed use
[search-region](search-region.md). All of these share this page's sub-tag model.

When `st=db` is used, the keys returned can be affected by the table's
`TableRestrict` setting, and both DBM and SQL searches can be ordered with
`[sort ...]` modifiers in the search spec.

## See also

- [item-list](item-list.md), [query](query.md),
  [search-region](search-region.md), [region](region.md), [search](search.md)
- Concepts: [templating](../guides/templating.md),
  [search](../guides/search.md), [databases](../guides/databases.md)

## Source

Defined in `code/SystemTag/loop.coretag`. Implemented by
`Vend::Interpolate::tag_loop_list`, which builds a result object and hands it to
`Vend::Interpolate::region`.
