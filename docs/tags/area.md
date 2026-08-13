# area

Build the URL to an Interchange page or action — the value that goes inside an
`href="..."` attribute, without the surrounding `<a>` tag. Reach for it
whenever you write a link by hand and need a session-aware, correctly-prefixed
URL. `[href]` is an alias of `[area]`.

## Syntax

    [area href arg]
    [area href="page" arg="arg1=val1/arg2=val2" secure=1 form="k=v"]

Standalone tag (no end tag). The return value is a URL string; it is not
reparsed as Interchange Tag Language (ITL). To get the whole `<a href=...>`
open tag instead, use [page](page.md).

## Attributes

| Attribute        | Default | Description |
|------------------|---------|-------------|
| `href`           | current page | Page name or action to link to (for example `index`, `ord/basket`, or an `order`/`scan` action). |
| `arg`            | none    | Path-style argument list appended to the URL, in the form `arg1=value1/arg2=value2`. |
| `secure`         | `0`     | Build the URL from [SecureURL](../config/SecureURL.md) (HTTPS) instead of [VendURL](../config/VendURL.md). |
| `form`           | none    | Query-string parameters to append, one `name=value` per line. |
| `search`         | none    | Treat the link as a search: the value is a search string that becomes a `scan` URL. |
| `alias`          | none    | Register a static path alias for `href` in the session (see below). |
| `once`           | `0`     | With `alias`, make the alias one-time (consumed after a single use). |
| `no_session_id`  | `0`     | Omit the session id from the URL. |
| `no_count`       | `0`     | Omit the page counter (`mv_pc`) from the URL. |
| `no_session`     | `0`     | Omit both the session id and the page counter. |
| `add_dot_html`   | varies  | Append `.html` to the page name in the generated URL. |
| `match_security` | `0`     | Inherit the current request's HTTP/HTTPS scheme. |

Positional order: `href`, `arg`.

Implicit: a bare `secure` (with no value) sets `secure=1`.

Because the tag declares `addAttr`, other attributes are passed through to the
URL builder as options.

## Description

`[area]` calls `Vend::Interpolate::tag_area`, which normalizes the page and
then dispatches to `vendUrl` (or `secure_vendUrl` when `secure` is set) to
assemble the final URL. The result carries the session id and page counter by
default so that Interchange can track the visitor across the link; the
`no_session*` and `no_count` options suppress those when you want a clean or
cacheable URL.

Several forms of `href` are recognized:

- A plain page name (`index`, `ord/basket`) links to that catalog page.
- `scan` plus an `arg` builds a search URL; equivalently, pass the search
  string as `search=...`.
- An absolute or scheme-prefixed URL (`http://...`, `mailto:...`,
  `javascript:...`) is returned largely untouched — session id and counter are
  not added — so `[area]` is safe to wrap around external links.

The `form` attribute adds query-string parameters; each line becomes one
`name=value` pair. The `arg` attribute instead adds Interchange's path-style
arguments, which the target page reads with `[cgi]` or `[data session arg]`.

Setting `alias` records a path alias in the session so a friendlier URL can
stand in for `href`; with `once` the alias is used a single time.

## Examples

Link to the catalog welcome page:

    Please visit our <a href="[area index]">Welcome</a> page.

Pass path-style arguments to a page:

    <a href="[area href=test arg='arg1=value1/arg2=value2']">test</a>

An order link that adds a product to the cart:

    Order a <a href="[area order TK112]">Toaster</a> today.

A checkout link forced over HTTPS:

    <a href="[area href='ord/checkout' secure=1]">Checkout</a>

Append query parameters with `form`:

    <a href="[area href=index form='template=leftonly']">Simple layout</a>

## Notes

`[area]` produces only the URL. Use [page](page.md) for the full `<a href=...>`
open tag, or when you want Interchange to also emit tracking attributes.

Argument quoting (single, double, and backtick/pipe forms) follows the general
ITL quoting rules; the pipe form `form=|k=v|` is common when values contain
spaces or nested tags.

## See also

- [page](page.md)
- [href](href.md) (alias of this tag)
- [process](process.md)
- [VendURL](../config/VendURL.md), [SecureURL](../config/SecureURL.md)
- Concepts: [templating](../guides/templating.md)

## Source

Defined in `code/SystemTag/area.coretag` (which also registers the `href`
alias). Implemented by `Vend::Interpolate::tag_area`, which calls
`Vend::Util::vendUrl` / `secure_vendUrl`.
