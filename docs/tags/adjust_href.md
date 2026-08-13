# adjust_href

Rewrite the `<a href="...">` links in its body so that page-relative links
become full Interchange URLs (session id, secure prefix, and all). Reach for
it when HTML authored in an external editor contains plain links like
`somepage.html?parm=val` that need to run through [area](area.md) to work in
the catalog.

## Syntax

    [adjust-href]
    <a href="somepage.html?parameter=value">link anchor</a>
    [/adjust-href]

Container tag (processes its body). The body is HTML, parsed with
`HTML::Parser`; the tag returns the same HTML with qualifying `href` values
rewritten.

## Attributes

This tag takes no attributes. Its optional behavior is controlled by pragmas
(see below).

## Description

The tag walks the body looking for `<a>` start tags. For each one it inspects
the `href`:

- Absolute links (those starting with a scheme such as `http:` or `mailto:`,
  or with a non-word character) are left untouched.
- A page-relative link is passed through [area](area.md), which prepends the
  catalog URL and adds the session id and any needed link parameters, so the
  final markup is a valid Interchange link.

Attributes on the `<a>` tag that [area](area.md) understands (`form`,
`secure`, `anchor`, `no_session`, `path_only`, and similar) are handed to it;
all other attributes are preserved verbatim.

Most catalogs never call the tag directly. Setting

    Pragma adjust_href

in `catalog.cfg` (or `[pragma adjust_href]` at the top of a page) applies the
same transformation to every page automatically, letting an HTML editor manage
links without knowing about Interchange URL syntax.

With `Pragma allow_for_users` additionally set, the tag will also strip a
previously added catalog-URL prefix and move existing query-string parameters
(other than session-specific ones like `mv_session_id`) into an [area](area.md)
form list, so already-adjusted links downloaded and re-submitted are handled
cleanly.

## Examples

Convert an editor-authored link inline:

    [adjust-href]
    <a href="cat/hats.html">Browse hats</a>
    [/adjust-href]

produces a link whose `href` is the full catalog URL for the `cat/hats` page,
for example:

    <a href="/cgi-bin/strap/cat/hats.html?id=xYz12AbC">Browse hats</a>

Apply the transformation catalog-wide instead of per-block, in `catalog.cfg`:

    Pragma adjust_href

## Notes

- Relative paths using `../` are not adjusted (a known limitation noted in the
  tag source).
- The registered tag name is `adjust_href`; Interchange treats hyphen and
  underscore as equivalent, so `[adjust-href]` and `[adjust_href]` both work.

## See also

- [area](area.md) — builds the Interchange URLs this tag applies
- [page](page.md) — the anchor-generating equivalent
- The [templating guide](../guides/templating.md)

## Source

Defined in `code/UserTag/adjust_href.tag` (inline `Routine`).
