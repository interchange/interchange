# The search engine

Interchange has a built-in search engine that runs over the same tables the
rest of the catalog uses — no separate index server required. One compact
specification language drives every kind of search: a keyword box, a
click-through category listing, a numeric price filter, a multi-field
"advanced search" form, and paged result sets. This chapter explains how a
search is specified, the engines that run it, the several ways to launch one,
and how results are sorted, paged, and displayed. It builds on
[Templating](templating.md) (looping regions and prefix sub-tags) and
[Databases](databases.md) (the tables being searched); read those first if the
looping-tag model is unfamiliar.

A first taste, run inline on any page against the strap demo's `products`
table:

    [search-region search="se=Brush/sf=description/ml=10"]
    [search-list]
    [item-code]: [item-field description] — [item-price]<br>
    [/search-list]
    [/search-region]

That single container performs the search and loops its matches. Everything
else in this chapter is variations on the search specification (`se=.../sf=...`)
and on where you put it.

## The two search engines

Every search runs through one of a few engine classes, selected by the
`mv_searchtype` parameter (two-letter code `st`):

| `st=` | Engine | What it does |
|-------|--------|--------------|
| `db` / `sql` | `Vend::DbSearch` | Iterates rows of a database table (DBM or SQL). |
| `text` | `Vend::TextSearch` | Scans the flat source text files line by line. |
| `ref` | `Vend::RefSearch` | Re-searches the result set of a previous search. |
| `glimpse` | `Vend::Glimpse` | Delegates to an external Glimpse index (if configured). |

When `st` is not given, the default depends on the
[MV_DEFAULT_SEARCH_DB](../variables/MV_DEFAULT_SEARCH_DB.md) Variable: if it is
true (strap sets it to `1`), an unspecified search is a **database** search;
otherwise it is a **text** search. In practice modern catalogs search the
database, so the examples here assume `st=db` behavior unless noted.

Both `db` and `text` share the entire specification language below — the same
`mv_*` parameters, the same operators, the same sorting and paging. The
difference is only the data source:

- **db** searches read live table data (the current SQL rows, or the built DBM
  table). This is what you almost always want; results reflect edits
  immediately, and column names come from the table.
- **text** searches read the tab-delimited source file named by `mv_search_file`
  under `ProductDir`. They exist for searching data that lives only in a text
  file, or for very large read-only line indexes. A text search skips one header
  line by default (`mv_head_skip`) and takes its column names from that header
  or from `mv_field_names`.

The important thing is that neither engine is a full-text index: both walk the
candidate rows and apply your match criteria to each. For catalogs with tens of
thousands of products this is fine on indexed SQL columns; for very large
corpora, reach for [Glimpse](../config/Glimpse.md) or an external index (see
[Notes on external engines](#external-engines) below).

## The search specification

A search is described by a set of `mv_*` variables. They can be written three
ways, all equivalent:

1. **Long form**, as form fields (the natural way from an HTML form):

       <input type="hidden" name="mv_search_field" value="description">
       <input type="text"   name="mv_searchspec">

2. **Compact form**, a slash-separated string of two-letter codes, passed to a
   tag or embedded in a URL:

       se=hammer/sf=description/ml=20

3. **Named attributes** on a search tag, where each `mv_*` variable (or its
   code) is an attribute.

The compact form is what you pass to [search-region](../tags/search-region.md)
and [loop](../tags/loop.md), and what appears in a scan URL. Its two-letter
codes are aliases for the full `mv_*` names — `se` is `mv_searchspec`, `sf` is
`mv_search_field`, and so on. The mapping is defined in `lib/Vend/Scan.pm`
(the `%Scan` hash) and reproduced in the [reference table](#parameter-reference)
below.

The three cornerstone parameters:

- **`se` — `mv_searchspec`** — the string(s) to search *for*.
- **`sf` — `mv_search_field`** — the column(s) to search *in*. Omit it and the
  engine matches against the whole row (every returned field joined together).
- **`fi` — `mv_search_file`** — the table (db search) or file (text search) to
  search. Defaults to the [ProductFiles](../config/ProductFiles.md) tables, so a
  bare `se=hammer` searches the product catalog.

Minimal searches, each self-contained:

    [search-region search="se=hammer"]...            all product fields
    [search-region search="se=hammer/sf=description"]...   just description
    [search-region search="se=Paintbrushes/sf=category/fi=products"]...

### Words, substrings, and exact matches

By default a search is **word-based and case-insensitive**: `se=brush` matches a
row whose searched field contains the whole word "brush" (in any case), but not
"brushes". A few switches change that:

| Code | Variable | Effect when set |
|------|----------|-----------------|
| `su` | `mv_substring_match` | Match anywhere in the field, not just whole words (`brush` matches `brushes`). |
| `cs` | `mv_case` | Case-sensitive. |
| `em` | `mv_exact_match` | Treat the spec as a quoted phrase; match it exactly. |
| `bs` | `mv_begin_string` | The spec must match at the *beginning* of the field. |
| `ne` / `ng` | `mv_negate` | Invert: return rows that do **not** match. |
| `os` | `mv_orsearch` | Multiple words match if *any* is present (default is all). |

    [search-region search="se=brush/sf=description/su=1"]...   substring
    [search-region search="se=brush hammer/sf=description/os=1"]...  either word

Because a multi-word `se` is split into words, `se=framing hammer` (no
`os`/`em`) matches rows containing both "framing" and "hammer" anywhere in the
field, in any order.

## Ways to run a search

There are four routes to the same engine. They differ only in where the
specification comes from and where results are displayed.

### 1. A search form (the `search` action)

A form whose action is the built-in `search` action submits its `mv_*` fields,
Interchange runs the search, stores the result set, and displays the catalog's
`search` results page (or the page named by `mv_search_page`). This is the
classic keyword box:

    <form action="[area search]" method="get">
      <input type="hidden" name="mv_search_file" value="products">
      <input type="hidden" name="mv_search_field" value="description">
      <input type="text"   name="mv_searchspec" value="">
      <input type="submit" value="Search">
    </form>

The results page then iterates the stored result object with an
[item-list](../tags/item-list.md) or [search-region](../tags/search-region.md).
The action is implemented by `Vend::Page::do_search`; the
[search](../tags/search.md) tag is the same routine callable from a page. Use
`method="get"` when you want the search to be bookmarkable and to page cleanly
(see [Paging](#paging-results)).

### 2. Scan URLs and one-click searches

A **scan URL** encodes the specification directly in the path, so any link can
run a pre-built search without a form. The path is `scan/` followed by the
slash-separated codes:

    scan/se=Paintbrushes/sf=category/st=db

Because a scan URL carries the whole specification, it is called a **one-click
search** — the user clicks a link, not a form button. You never hand-build the
URL; [page](../tags/page.md) and [area](../tags/area.md) generate it from a
`search=` attribute, handling session id and escaping:

    [page search="se=Paintbrushes/sf=category"]Paintbrushes</a>

    <a href="[area search='se=Hammers/sf=category/ml=20']">Hammers</a>

This is how category browse pages, "see all on sale" links, and manufacturer
listings are built: each is a stored specification behind a link. Scan URLs are
dispatched by `Vend::Page::do_scan`, which parses the path with
`find_search_params` and runs the identical engine as a form search.

In a one-click search there is no form, so there is no place for the user's
session `[value ...]` variables to come from. The `va` — `mv_value` — parameter
fills that gap: it assigns a value variable as part of the search, so the
results page can display, say, a heading naming the category:

    [page search="
        se=Renaissance
        se=Impressionists
        os=1
        va=category_name=Renaissance and Impressionist Paintings
    "]Renaissance &amp; Impressionist</a>

Note that the compact specification can be written one code per line (whitespace
around the slashes/newlines is ignored), which is far more readable for anything
non-trivial.

### 3. Inline: `[search-region]` and `[loop search=...]`

To search *and* display in one place, with the specification passed directly and
no dependence on submitted form variables, use
[search-region](../tags/search-region.md):

    [search-region search="se=Brushes/sf=category/ml=25"]
    [search-list]
      [item-code] — [item-field description]<br>
    [/search-list]
    [no-match]No products found.[/no-match]
    [/search-region]

[loop](../tags/loop.md) accepts the same `search=` attribute and is
interchangeable for the common case:

    [loop search="se=Brushes/sf=category"]
      [loop-code] [loop-field description]<br>
    [/loop]

Both render the result rows through the shared looping-region machinery
described in [Templating](templating.md), so every `[PREFIX-*]` sub-tag and
`[if-PREFIX-*]` conditional works inside them. The only difference is the
default prefix (`item` for `search-region`, `loop` for `loop`).

A useful idiom is "return everything" — the `ra` — `mv_return_all` — parameter
ignores the search string and returns every row, which turns a search into a
plain table walk:

    [loop search="ra=1/st=db/ml=9999"]
      [loop-code]<br>
    [/loop]

### 4. From Perl

Embedded Perl ([Embedded Perl](perl-embedding.md)) can run a search and get the
raw rows back, bypassing display. The database object's `array`, `hash`, and
`list` methods take a compact spec and return the results:

    [perl tables=products]
        my $rows = $Db{products}->array('se=Brushes/sf=category/rf=sku,description');
        return scalar(@$rows) . " matches";
    [/perl]

These map straight onto `Vend::DbSearch` (`array`/`hash`/`list` in
`lib/Vend/DbSearch.pm`), which sets `mv_list_only` so the search returns its
result array with no display step.

## Choosing and shaping the results

`mv_return_fields` (`rf`) selects which columns each result row contains, in the
order you name them; `:*` or `*` means all fields. The **first** return field is
the row's key (`[item-code]`), so `rf` also controls what `[item-code]` yields.

    rf=sku,description,price      code + two columns
    rf=*                          every column

Related shaping parameters:

- **`un` — `mv_unique`** — drop duplicate rows, compared on the first return
  field.
- **`ml` — `mv_matchlimit`** — results **per page** (default 50; `none`/`all`
  for unlimited — never `0`). With paging on, this is the page size.
- **`mm` — `mv_max_matches`** — a hard cap on total matches regardless of
  paging (default unlimited).
- **`fm` — `mv_first_match`** — start returning from the Nth match.
- **`ms` — `mv_min_string`** — reject search strings shorter than this many
  characters (default 1; text searches default higher). Set `ms=0` to allow an
  empty search (used to "list all").

## Sorting

Sort the returned rows with `mv_sort_field` (`tf`) and `mv_sort_option` (`to`).
`tf` names one or more columns (by name if column names are known, or by numeric
index from 0); `to` gives a sort style per field:

| `to` value | Order |
|------------|-------|
| `f` | case-insensitive ascending (default text) |
| `fr` / `rf` | case-insensitive descending |
| `n` | numeric ascending |
| `nr` | numeric descending |
| `r` | case-sensitive descending |
| `none` | plain `cmp`, ascending |

    [search-region search="
        se=Brushes
        sf=category
        rf=sku,description,price
        tf=price
        to=n
    "]
    [search-list][item-field description]: [item-price]<br>[/search-list]
    [/search-region]

A shorthand attaches the option to the field name with a colon: `tf=price:n` is
`tf=price/to=n`. Multiple `tf`/`to` pairs sort by the first field, then the
second as a tie-breaker. Sorting is applied by `sort_search_return` in
`lib/Vend/Search.pm`, and honors the session locale for collation.

Two independent sort tools exist for cases the search sort does not cover: the
`[PREFIX-sort]` region modifier and the standalone sort of an already-built
list; both are variations of `tag_sort_ary` and are documented with the looping
tags. For SQL tables you may also let the database sort by writing the search as
a [query](../tags/query.md) with an `ORDER BY` clause.

## Coordinated (multi-field) searches

An ordinary search applies one set of options to one or more search strings. A
**coordinated** search (`co` — `mv_coordinate`) pairs up multiple `sf`
fields with multiple `se` strings positionally: the *first* `se` is matched
against the *first* `sf`, the second against the second, and so on. This is how
an advanced-search form with a field-per-input is built:

    [search-region search="
        co=1
        sf=artist  se=[cgi artist]
        sf=title   se=[cgi title]
    "]
    ...
    [/search-region]

With `co=1`, per-field options may be repeated so each field gets its own
treatment. If you set one instance of an option (say one `su=1`) it applies to
all fields; if you set as many as there are fields, each is used independently:

    co=1
    sf=description  se=hammer  su=1     (substring)
    sf=category     se=Hammers          (whole word)

Coordination is automatically and silently **disabled** when the number of `se`
strings does not equal the number of `sf` fields — which happens naturally when
a user leaves some inputs blank. To force it to stay on (padding missing specs
with the last one, or discarding extras), add `fc=1` — `mv_force_coordinate`.
Blank specs in a coordinated search are dropped along with their paired field,
so empty inputs simply narrow the search rather than breaking it. The pairing
logic lives in `spec_check`/`get_limit` in `lib/Vend/Search.pm`.

### Per-field operators

Coordinated searches unlock `mv_column_op` (`op`), which sets the comparison
operator for a field instead of the default word match. This is what powers
price ranges, "greater than" filters, and SQL-style comparisons:

| `op=` | Meaning |
|-------|---------|
| `rm` | regexp match (the default) |
| `em` | exact match (whole field) |
| `eq` / `==` | equal (string or, with `nu`, numeric) |
| `<` `<=` `>` `>=` `!=` | comparisons |
| `=~` / `!~` | regexp match / not-match |
| `tq` / `aq` | `Text::Query` simple / advanced query |

Add `nu=1` — `mv_numeric` — for a field to make its comparisons numeric rather
than string:

    [search-region search="
        co=1
        sf=price  se=50  op=<=  nu=1
        sf=category  se=Brushes
    "]
    ... products in Brushes under $50 ...
    [/search-region]

The `tq`/`aq` operators require the optional `Text::Query` Perl module and give
Google-style boolean queries within a field.

## Paging results

When a search finds more rows than `mv_matchlimit`, Interchange saves the extra
matches and hands out the results one page at a time. The saved search is keyed
so that "next page" requests re-fetch from the stored set instead of
re-searching. Two region tags render the navigation, and go *inside* the
search/results region:

- **`[more-list]` `... [/more-list]`** — renders the numbered page navigation
  (first/prev/1/2/3/next/last). It is empty unless there are more matches than
  the match limit. Its optional arguments customize the next/prev/page anchors
  and highlighting.
- **`[more]`** — the simpler previous/next link pair.

A results region with paging:

    [search-region search="se=Brush/sf=description/ml=10"]
    [search-list]
      [item-field description]<br>
    [/search-list]
    [no-match]Nothing found.[/no-match]
    <p>[matches] of [match-count] shown.
       [more-list][more-list]</p>
    [/search-region]

`[matches]` and `[match-count]` report the current-page and total counts. For
paging to work across requests the search must be repeatable, which is why
paged searches are normally reached through the `search` action or a scan URL
(GET), not an inline region built from volatile `[cgi]` values. The paging
machinery is `tag_more_list` and `save_more`/`more_matches`
(`lib/Vend/Interpolate.pm`, `lib/Vend/Search.pm`); related tuning parameters are
`mv_more_matches` (`MM`), `mv_more_id` (`mi`), `mv_no_more` (`nm`), and
`mv_more_permanent` (`pm`).

## Search profiles

Rather than repeat a long specification in every form or link, store it once as
a named **search profile** and invoke it with `mv_profile` (`mp`). A profile is
a block of `mv_*` parameters, one per line, loaded from a file named by the
[SearchProfile](../config/SearchProfile.md) directive (or held in a scratch
variable). The form then needs only the parts that vary:

    <input type="hidden" name="mv_profile" value="category_browse">
    <input type="hidden" name="mv_searchspec" value="Hammers">

Profiles keep pages clean and let one definition drive many searches — the
search-side counterpart of the [OrderProfile](../config/OrderProfile.md) that
validates form submissions. A profile may also set a `mv_last` line to stop
further processing, and its parameters are interpolated (so `[...]`/`__VAR__`
inside a profile run before the search). Profiles are parsed by `parse_profile`
in `lib/Vend/Scan.pm` and configured by `SearchProfile` in `lib/Vend/Config.pm`.

## Displaying results: the sub-tags

However a search is launched, its rows are rendered through the standard
looping-region model. Inside a [search-region](../tags/search-region.md) (or a
[loop](../tags/loop.md)/[item-list](../tags/item-list.md) over search results)
the current row is reached through prefix sub-tags — default prefix `item` for
`search-region`:

- `[item-code]` — the row key (first return field)
- `[item-field COL]` — a column from the products table for this key
- `[item-param COL]` / `[item-pos N]` — a returned column by name / position
- `[item-increment]` — the 1-based counter within the page
- `[if-item-field COL] ... [/if-item-field]` — per-row conditional
- `[on-match] ... [/on-match]` / `[no-match] ... [/no-match]` — run when the
  search did or did not produce rows

Wrap the repeating part in `[search-list] ... [/search-list]` (the "labeled
list"); markup outside it — headings, the `[more-list]`, "no matches" text — is
emitted once. See [Templating](templating.md) for the complete sub-tag set,
which is shared by every looping tag.

<a id="parameter-reference"></a>

## Parameter reference

The full set of search parameters, with their two-letter codes as defined in
`%Scan` in `lib/Vend/Scan.pm`. The code is the canonical short spelling; the
`mv_*` name is what you use as a form field. Only the commonly used defaults are
noted — behavior can vary by engine.

| Code | Variable | Purpose |
|------|----------|---------|
| `se` | `mv_searchspec` | The string(s) to search for. |
| `sf` | `mv_search_field` | Field(s) to search in. |
| `fi` | `mv_search_file` | Table(s)/file(s) to search (default: ProductFiles). |
| `st` | `mv_searchtype` | Engine: `db`/`sql`, `text`, `ref`, `glimpse`. |
| `rf` | `mv_return_fields` | Columns to return; first is the key. `*` = all. |
| `tf` | `mv_sort_field` | Sort column(s), by name or 0-based index. |
| `to` | `mv_sort_option` | Sort style per field (`f`/`fr`/`n`/`nr`/`r`/`none`). |
| `ml` | `mv_matchlimit` | Matches per page (default 50; `none`/`all` = unlimited). |
| `mm` | `mv_max_matches` | Hard cap on total matches (default unlimited). |
| `fm` | `mv_first_match` | Return starting at the Nth match. |
| `ms` | `mv_min_string` | Minimum search-string length (default 1). |
| `co` | `mv_coordinate` | Pair `sf` fields with `se` strings positionally. |
| `fc` | `mv_force_coordinate` | Keep coordination on when counts differ. |
| `op` | `mv_column_op` | Per-field comparison operator (coordinated). |
| `nu` | `mv_numeric` | Numeric comparison for a field. |
| `os` | `mv_orsearch` | Match any word/spec rather than all. |
| `su` | `mv_substring_match` | Substring rather than whole-word match. |
| `cs` | `mv_case` | Case-sensitive. |
| `em` | `mv_exact_match` | Exact/phrase match. |
| `bs` | `mv_begin_string` | Match at start of field only. |
| `ne` / `ng` | `mv_negate` | Return non-matching rows. |
| `ra` | `mv_return_all` | Return every row, ignoring the spec. |
| `un` | `mv_unique` | Drop duplicate rows (by first return field). |
| `rs` | `mv_return_spec` | Result is the search string(s) themselves. |
| `mp` | `mv_profile` | Apply a named search profile. |
| `va` | `mv_value` | Set a value variable as part of the search. |
| `lb` | `mv_search_label` | Name this search (for `ref` re-search / caching). |
| `bd` | `mv_base_directory` | Base directory for text-file searches. |
| `sp` | `mv_search_page` | Results page for form/scan searches. |
| `np` | `mv_nextpage` | Next page after the search. |
| `sq` | `mv_sql_query` | Text-search-only pseudo-SQL over the file. |
| `ix` | `mv_index_delim` | Field delimiter in index/text data (default TAB). |
| `dr` | `mv_record_delim` | Record delimiter in index/text data (default `\n`). |
| `rd` | `mv_return_delim` | Delimiter for joining returned fields. |
| `hs` | `mv_head_skip` | Leading lines to skip (text; default 1). |
| `nm` | `mv_no_more` | Do not save extra matches for paging. |
| `pm` | `mv_more_permanent` | Store the more-set permanently, not per-session. |

Dictionary-lookup (`dl`, `di`, `do`, `df`), range-look (`rl`, `rm`, `rx`,
`rg`), Glimpse spelling-error, and `Text::Query` (`op=tq`/`aq`) parameters exist
for specialized cases; the complete list is the `%Scan` hash in
`lib/Vend/Scan.pm`.

<a id="external-engines"></a>

## Notes on external engines

- **Glimpse** — configure the [Glimpse](../config/Glimpse.md) directive with the
  path to the `glimpse` binary and an index, then search with `st=glimpse`. If
  Glimpse is not configured, `st=glimpse` silently falls back to a database
  search. Glimpse suits very large text corpora where per-row scanning is too
  slow.
- **Swish-e** — an add-on module (`Vend::Swish`) integrates a Swish-e index,
  invoked with `st=swish` after loading the module and configuring the `Swish`
  directive. It returns configurable fields (code, score, title, url, ...) from
  the external index rather than the catalog tables.

Both are optional; the built-in `db` and `text` engines cover typical catalogs.

## Security

Search parameters arrive from the browser, so the engine constrains what a
request may reach:

- **`fi`/`bd` are validated.** A search cannot read arbitrary files: text-file
  targets pass through file/directory security (`allowed_file`), and any file
  matching the [NoSearch](../config/NoSearch.md) directive is refused. Reaching
  outside `ProductDir` requires the `MV_SEARCH_FILE` Variable or a matching
  scratch flag.
- **`sq` (pseudo-SQL over text files) is not a real SQL passthrough** — it is
  parsed and mapped onto the same `mv_*` engine, so it cannot execute arbitrary
  database statements. For real SQL use [query](../tags/query.md), which is
  governed by the table's write/ACL controls (see [Databases](databases.md)).
- Whether remote requests may search a given table at all is further governed by
  the catalog's search configuration; keep sensitive tables out of
  `ProductFiles` and off the default search path.

See [Security](security.md) for the broader model.

## See also

- [search-region](../tags/search-region.md) · [loop](../tags/loop.md) ·
  [item-list](../tags/item-list.md) · [region](../tags/region.md) ·
  [query](../tags/query.md) — the tags that run and display searches
- [search](../tags/search.md) — the `search` form action in tag form
- [page](../tags/page.md) · [area](../tags/area.md) — generate scan URLs
- [Templating](templating.md) — looping regions and `[PREFIX-*]` sub-tags
- [Databases](databases.md) — the tables being searched; SQL via `[query]`
- Config: [SearchProfile](../config/SearchProfile.md) ·
  [ProductFiles](../config/ProductFiles.md) · [NoSearch](../config/NoSearch.md) ·
  [Glimpse](../config/Glimpse.md)
- Variables: [MV_DEFAULT_SEARCH_DB](../variables/MV_DEFAULT_SEARCH_DB.md) ·
  [MV_DEFAULT_MATCHLIMIT](../variables/MV_DEFAULT_MATCHLIMIT.md) ·
  [MV_DEFAULT_SEARCH_TABLE](../variables/MV_DEFAULT_SEARCH_TABLE.md)

## Source

Engine dispatch and the `mv_*`/two-letter map: `lib/Vend/Scan.pm`. Base class,
matching, sorting, and paging: `lib/Vend/Search.pm`. Per-engine implementations:
`lib/Vend/DbSearch.pm`, `lib/Vend/TextSearch.pm`, `lib/Vend/RefSearch.pm`,
`lib/Vend/Glimpse.pm`. Form/scan actions: `Vend::Page::do_search` /
`do_scan`. Region rendering and `[more-list]`: `lib/Vend/Interpolate.pm`.
