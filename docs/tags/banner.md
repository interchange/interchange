# banner

Return an advertising banner (or any rotating snippet) from the `banner` table,
chosen either by sequential rotation or by weighted random selection. Reach for
it to drop house ads or promo messages into a page from a database-driven pool.

## Syntax

    [banner category]
    [banner category=name weighted=1 table=banner]

Standalone tag (no end tag). The return value is the banner text stored in the
table (typically an HTML `<a><img></a>` snippet); whether it is further
interpolated depends on the surrounding page.

## Attributes

| Attribute   | Default   | Description |
|-------------|-----------|-------------|
| `category`  | `default` | In weighted mode, the category to draw from; in unweighted mode, the banner table key (`code`) to display. |
| `weighted`  | `0`       | Use the weighted random system instead of sequential rotation. |
| `table`     | `banner`  | Name of the banner table. |
| `b_field`   | `banner`  | Column holding the banner text. |
| `r_field`   | `rotate`  | Column (boolean) that enables rotation of multiple banners in one row. Unweighted mode only. |
| `w_field`   | `weight`  | Column holding the relative weight. Weighted mode only. |
| `c_field`   | `category`| Column holding the category. Weighted mode only. |
| `separator` | `:`       | Separator within the key for multi-level categorized keys. Unweighted mode only. |
| `delimiter` | `{or}`    | Delimiter between multiple banner texts stored in one `b_field`. Unweighted mode only. |
| `once`      | `0`       | Weighted mode: do not rebuild the pre-built banner pool until its `total_weight` file is removed by hand. |

Positional order: `category`.

Because the tag declares `addAttr`, the options above are read from the passed
attribute hash.

## Description

`[banner]` has two modes.

**Unweighted (default) — rotation.** The tag reads `r_field` for the row keyed
by `category`. If that flag is true, `b_field` may contain several banner texts
joined by `delimiter`; the tag keeps a per-visitor counter in scratch
(`rotate_<category>`) and returns them in sequence, cycling. If `r_field` is
false it simply returns the `b_field` value. When no row matches and the key
contains the `separator`, the tag strips the last `:`-delimited level and
retries, finally falling back to the `default` key — this supports
hierarchical keys like `sports:tennis`.

**Weighted (`weighted=1`) — random by weight.** On first use after a catalog
restart or reconfigure, the tag pre-builds a directory of banner files under
`ScratchDir/Banners/` (one file per weight point): a banner with weight 7 gets
seven copies, weight 2 gets two, and so on. It then returns a randomly chosen
file, so display frequency is proportional to weight. Give every banner weight
`1` for equal random rotation. With a `category`, each category maintains its
own weighted pool. The `once` option freezes the pre-built pool until you
remove the `total_weight` file manually.

## Examples

Display the banner stored under key `default`:

    [banner]

Display a specific banner by key:

    [banner main_header]

Weighted random ad from the `promo` category:

    [banner category=promo weighted=1]

Rotate through several messages held in one row (with `rotate` set true and the
`banner` field holding `Msg 1{or}Msg 2{or}Msg 3`):

    [banner news]

## Notes

The banner table is an ordinary Interchange table; the defaults (`banner`,
`rotate`, `weight`, `category`) match the schema the demo ships. Point the
`*_field` options at other columns if your table differs.

Weighted mode writes files under the catalog's scratch directory, so that
directory must be writable by the Interchange daemon.

## See also

- [data](data.md)
- Concepts: [databases](../guides/databases.md)

## Source

Defined in `code/SystemTag/banner.coretag` (inline Routine). Reads the banner
table via `Vend::Interpolate::tag_data` and, for weighted banners, files under
`$Vend::Cfg->{ScratchDir}/Banners`.
