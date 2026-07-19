# page

Produce an opening `<a href="...">` anchor tag whose URL points at an
Interchange page, search, or order action, with session information preserved
automatically. Reach for it whenever you want a link to another page in the
catalog and do not want to build the URL and session id by hand.

## Syntax

    [page href arg]
    [page href="pagename" arg="arg1=value1/arg2=value2" extra="class"]

Standalone tag (no end tag). It emits only the opening `<a ...>`; you supply
the link text and close it yourself with `</a>`.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `href`    | (empty) | Target page, relative to the catalog `pages/` directory. Also accepts special targets like `scan` and `order`, or an absolute/`scheme:` URL. |
| `arg`     | (none)  | Extra path arguments appended to the URL, available on the target page as `[value mv_arg]`. |
| `secure`  | current request | If true, build an `https:` URL using `SecureURL`. |
| `form`    | (none)  | Newline- or space-separated `name=value` pairs to embed as a form-style submission in the link. |
| `search`  | (none)  | Shorthand: sets `href` to `scan` and `arg` to this value (a search spec). |
| `extra`   | (none)  | Text inserted into the anchor tag; a bare word becomes `class=word`. |

Positional order: `href`, `arg`.
Alias: `base` for `arg`.

`page` is a thin wrapper over [area](area.md): it takes the same options as
`area` and simply wraps the resulting URL in `<a href="...">`. See
[area](area.md) for the full option list (`alias`, `once`, `no_session`, and
so on).

## Description

The `page` tag builds a hypertext link that keeps Interchange session state
intact across the click. The target is resolved relative to your catalog's
`pages/` directory, so `[page index]` links to `pages/index.html`. Interchange
Tag Language (ITL) sessions rely on the URL carrying a session id (unless
cookies fully cover it), and `page` adds that for you.

Because the tag emits only the opening anchor, a link reads naturally:

    [page index]Home</a>

There is a `[/page]` macro that expands to `</a>`, but writing `</a>`
directly is preferred and saves the parser work.

### Special targets

- `href=scan` (or the `search` attribute) builds a search URL; the `arg`
  value is the search spec.
- `href=order` with an item code builds an order-this-item link, equivalent
  to the [order](order.md) tag.
- A value beginning with a scheme (`http:`, `mailto:`, `javascript:`) is
  treated as an absolute link and passed through.

### Embedded forms

The `form` attribute embeds a set of form variables in the link so a single
click performs a form submission (one-click ordering, canned searches). The
value is a block of `name=value` lines.

## Examples

A basic link to the catalog `index` page:

    Please visit our [page index]Welcome</a> page.

Pass path arguments to a page; the target reads them with `[value mv_arg]`:

    Visit the [page href=test arg="arg1=value1/arg2=value2"]test</a> page.

One-click order of a specific item (strap demo sku `os28004`):

    Order an [page order os28004]Ergo Rest</a> today.

Embed a form to add a configured item to the cart in one click:

    [page form="
        mv_todo=refresh
        mv_order_item=os28004
        mv_order_quantity=1
    "]Add Ergo Rest to cart</a>

Build a search link with the `search` shorthand:

    [page search="
        se=shirt
        sf=description
    "]Search for shirts</a>

## Notes

- `page` and [area](area.md) differ only in output: `area` returns the bare
  URL (for use inside `href="..."`, form actions, or redirects), `page` wraps
  it in an anchor open tag.
- Advanced quoting rules apply to `form`/`arg` blocks; keep each `name=value`
  on its own line to avoid ambiguity.

## See also

- [area](area.md) — same URL builder without the `<a>` wrapper
- [order](order.md) — order-a-specific-item link
- [process](process.md) — form action URL for order/search submission
- [value](value.md) — read `mv_arg` and other submitted values
- [forms guide](../guides/forms.md), [search guide](../guides/search.md)

## Source

Defined in `code/SystemTag/page.coretag`. Implemented by
`Vend::Interpolate::tag_page`, which calls `Vend::Interpolate::tag_area` and
wraps the URL in an `<a href>` open tag.
