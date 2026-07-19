# process

Return the URL that a completed order form or search form should submit to.
Reach for it to fill the `action="..."` of a `<form>` that runs an Interchange
action, with session handling and secure/insecure choice taken care of.

## Syntax

    [process]
    [process target secure]
    [process href="ord/checkout" secure=1 download_name="invoice.pdf"]

Standalone tag (no end tag). Returns a URL string.

Aliases: [process-target](process-target.md) and
[process-order](process-order.md) invoke this same tag.

## Attributes

| Attribute      | Default | Description |
|----------------|---------|-------------|
| `target`       | (none)  | HTML frame/`target` value; when set, the return value is extended so it closes the `action="..."` attribute and adds `target="..."`. |
| `secure`       | current request | Force a secure (`https:`) or insecure (`http:`) action URL. Defaults to whether the current request is secure. |
| `href`         | `ProcessPage` | Page the form submits to. Defaults to the catalog `ProcessPage` (normally `process`). |
| `download_name`| (none)  | Append this as a trailing path segment, for content-disposition style download URLs. |
| `add_dot_html` | scratch `mv_add_dot_html` | Append `.html` to the page unless it already ends in a slash or `.htm(l)`. |
| `no_session`   | off     | Omit the session id and page-count parameters from the URL. |

Positional order: `target`, `secure`.

## Description

Interchange processes form submissions (order updates, checkout, searches)
through a single dispatch page named by the `ProcessPage` directive. `process`
builds the URL to that page:

- It chooses the base URL by security: for a secure request (or `secure=1`) it
  uses `SecurePostURL`/`SecureURL`; otherwise `PostURL`/`VendURL`. This keeps a
  checkout form on `https:` and an ordinary form on `http:` without you
  hard-coding either.
- When `TolerateGet` is on, it appends the session id, page-count, and (for
  virtual catalogs) catalog parameters as query-string arguments, so sessions
  survive even without cookies. `no_session=1` suppresses these.
- With a `target`, the return value is written so that dropping it straight
  into `action="[process ...]"` both closes the `action` attribute and adds a
  matching `target` attribute.

The result is meant to go in a form action. It is the form-submission
counterpart to [area](area.md)/[page](page.md), which link to display pages.

## Examples

A basic order/checkout form action:

    <form action="[process]" method="post">
      ...
      <input type="submit" value="Check out">
    </form>

`[process]` is commonly written as `[area process]` as well; both resolve to
the process URL. A search form is identical in shape:

    <form action="[process]" method="post">
      <input name="mv_searchspec" value="">
      <input type="hidden" name="mv_search_type" value="text">
      <input type="submit" value="Search">
    </form>

Force a secure action even from an insecure page (checkout):

    <form action="[process secure=1]" method="post">

Submit into a named frame with the `target` form:

    <form action="[process target=_top]" method="post">

## Notes

- `secure` follows the current request's security when unset, so a form on an
  `https:` page stays secure automatically. Set it explicitly to override.
- [process-target](process-target.md) and [process-order](process-order.md)
  are historical alias names for the same tag; new code should use `process`.

## See also

- [area](area.md), [page](page.md) — URLs and links to display pages
- [profile](profile.md) — order/search profiles that validate a submission
- [forms guide](../guides/forms.md),
  [cart and checkout guide](../guides/cart-and-checkout.md)

## Source

Defined in `code/SystemTag/process.coretag` (which also declares the aliases
`process-target` and `process-order`). Implemented by the inline `Routine` in
that file.
