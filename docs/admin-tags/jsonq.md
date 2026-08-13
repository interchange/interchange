# jsonq

Generate a cached, tokenized URL that returns the result of a SQL query as
JSON (or as templated text) when fetched. Reach for it to feed Ajax
autocomplete and data-grid widgets in the administrative interface without
exposing the raw query or running the full Interchange dispatch on every
keystroke.

`[jsonq]` is part of the admin UI tag set in `code/UI_Tag/`, loaded when the
administrative interface is enabled; it is not a storefront tag. It is
active only when the `QueryCache` directive is configured.

## Syntax

    [jsonq query="select ..." expire="30min" public="0|1"
           params="cgivar" hash="0|1|field" ...]

Standalone tag (no end tag). The return value is a URL string; it is not
reparsed as Interchange Tag Language (ITL). Only `query` is required.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `query` | none (required) | The SQL statement to run when the URL is fetched. Stored as the `qtext` field of the cache record. May contain `?` placeholders bound from `params`. |
| `public` | off | When set, the resulting URL is usable by anyone; when unset, the URL is bound to the creating session. Never enable for private data. |
| `params` | none | Names of CGI variables (or path-info segments) bound, in order, to the `?` placeholders. Supports `LIKE` helpers and a minimum-length threshold (see Description). |
| `expire` | `QueryCache default_expire`, or `default_public_expire` when `public` | How long the cached URL stays valid: a number of seconds, an absolute `YYYYMMDDHHMMSS` timestamp, or a duration such as `30min` or `3 days`. |
| `hash` | off | Controls JSON shape: empty returns an array of arrays; a digit (e.g. `1`) returns an array of hashes; a field name returns a hash of hashes keyed on that field. |
| `meta` | none | Metadata options applied to the output (for example `jui_datagrid` shaping). Ignored under the external delivery mechanism. |
| `meta_view` | none | Meta view whose filters transform the query output. Ignored under the external delivery mechanism. Alias: `meta-view`. |
| `ip` | off | When set, binds the URL to the creating client IP address as well. |
| `secure` | off | When set, marks the record secure so the generated URL uses HTTPS. |
| `template` | none | An `attr_list`-format template to iterate over the rows and emit text/HTML instead of JSON (see Examples). |
| `content_type` | `application/json` | MIME type sent with the response. Alias: `content-type`. |
| `external_program` | `QueryCache external_program` | Overrides the external delivery program used to build the URL. |

Positional order: `params`, `public`, `query`. In practice you call `[jsonq]`
with named attributes.

Because the tag declares `addAttr`, any additional attribute is forwarded in
the option hash.

## Description

`[jsonq]` writes a row into the query-cache table (by default `qc`) and
returns a URL that, when fetched, runs the stored query and streams the
result. The URL bypasses the normal Interchange session and catalog
configuration path in `Vend::Dispatch`, so it answers much faster than a
regular page; an external handler can make it faster still.

The tag is enabled by configuring `QueryCache` in `catalog.cfg`:

    QueryCache  enabled 1
    QueryCache  table   qc
    QueryCache  intro   qc
    QueryCache  default_expire 30min
    QueryCache  default_public_expire 48hours
    QueryCache  default_return {}

The `intro` value is the URL prefix (here `/qc/`) that Interchange
short-circuits to JSON delivery. Generating a record requires the `JSON`,
`Digest::MD5`, `SQL::Statement`, and `SQL::Parser` Perl modules.

A cache key (`qid`) is computed from the query text plus the binding options
(session, IP, params, secure, hash, meta, meta view). If a live record with
the same key already exists, its URL is returned instead of writing a new
row, so repeated identical calls are cheap.

### Parameter binding

`params` names the CGI variables bound to the query's `?` placeholders, using
DBI placeholder binding, so values are not interpolated into the SQL and
cannot cause injection. Two prefix helpers rewrite the bound value for `LIKE`
queries:

- `q%` wraps the value in `%...%` for a substring match.
- `^q` appends `%` for a match anchored at the start.

Append `:N` to set the minimum length before the query runs; below the
threshold the configured `default_return` (by default `{}`) is returned
instead. The default threshold is 3 characters, which keeps early keystrokes
in an autocomplete field from launching broad scans.

## Examples

A public autocomplete query over the strap `products` table, matching the
`q` CGI variable as a leading substring:

    [jsonq
        public=1
        params="^q"
        query="select sku, description from products where description like ?"
    ]

Fetching the returned URL with `?q=nai` yields JSON such as:

    [["os28057a","16 Penny Nails"],["os28057b","10 Penny Nails"]]

Add `hash=1` to get an array of objects keyed by column name:

    [jsonq hash=1
        params="^q"
        query="select sku, description from products where description like ?"
    ]

    [{"sku":"os28057a","description":"16 Penny Nails"}]

Emit HTML instead of JSON by supplying a template. The `{PRE_TEMPLATE}` and
`{POST_TEMPLATE}` regions are output once, around the iterated rows:

    [tmpn tpl]
    {PRE_TEMPLATE}<ul>{/PRE_TEMPLATE}
    <li>{SKU} - {DESCRIPTION}</li>
    {POST_TEMPLATE}</ul>{/POST_TEMPLATE}
    [/tmpn]
    [jsonq hash=1 content-type="text/html"
        template="[scratch tpl]"
        query="select sku, description from products where description like '%Nails%'"
    ]

Fetching that URL produces:

    <ul>
    <li>os28057a - 16 Penny Nails</li>
    <li>os28057b - 10 Penny Nails</li>
    <li>os28057c - 8 Penny Nails</li>
    </ul>

## Notes

Do not set `public=1` for queries over private data; a public URL requires no
session and is fetchable by anyone who has it.

`mv_matchlimit` and `mv_first_match` CGI variables page the result set;
`mv_first_match` has no effect without `mv_matchlimit`. Standard catalogs
remap these to `ml` and `fm`, which matters when using external delivery.

`meta` and `meta_view` are ignored when the external CGI delivery program
handles the request.

## See also

- [jsq](jsq.md), [jsqn](jsqn.md)
- Concepts: [databases](../guides/databases.md),
  [admin UI](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/jsonq.coretag` as an inline `UserTag` Routine
(`UserTag jsonq`). Delivery of the generated URL is handled in
`Vend::Dispatch` via the `QueryCache` configuration.
