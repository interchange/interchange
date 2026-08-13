# history-scan

Return a URL from the visitor's own page-history stack, optionally filtered
by pattern, so you can build a "back" or "return to previous page" link that
survives the session. Reach for it on interstitial pages (login, error,
confirmation) that need to send the visitor back where they came from.

## Syntax

    [history-scan]
    [history-scan find="REGEX" exclude="REGEX" default="PAGE"]

Standalone tag (no end tag). Returns a full anchor href (an `[area]`-built
URL) by default, or a bare page path with the `pageonly` option.

## Attributes

| Attribute     | Default              | Description |
|---------------|----------------------|-------------|
| `find`        | *(none)*             | Only match history entries whose page path matches this regular expression. |
| `exclude`     | *(none)*             | Skip history entries whose page path matches this regular expression. |
| `default`     | catalog special page | Page path to fall back to when no history entry matches. |
| `include`     | *(none)*             | Only match entries whose page path matches this regular expression (an additional include filter). |
| `count`       | `0`                  | Skip this many of the most recent entries before matching (its absolute value is used). `count=1` returns the page before the most recent match. |
| `pageonly`    | *(none)*             | Return the bare page path instead of a full URL. |
| `no_session`  | *(none)*             | Passed to `[area]`: build the URL without the session id. |
| `var_exclude` | *(see below)*        | Extra CGI variable names (whitespace/comma/null separated) to drop from the rebuilt query string. |
| `form`        | *(none)*             | Extra `name=value` lines appended to the rebuilt query string. |
| `size_limit`  | `1024`               | Maximum length of the generated URL; over this the tag returns nothing. |
| `debug`       | *(none)*             | When the size limit is exceeded, record a `[history-scan]` error message. |

Positional order: `find`, `exclude`, `default`.

## Description

Interchange records each non-volatile page the visitor requests, together
with its CGI parameters, in the session `History` stack. `[history-scan]`
walks that stack from most recent backward and returns the first entry that
passes the `exclude`, `include`, and `find` filters.

The matched entry is rebuilt into a link: the page path is cleaned up and
passed through [area](area.md), and the entry's saved CGI parameters are
re-encoded into the query string. A built-in exclude list drops sensitive
or navigation-control parameters (`mv_credit_card_number`, `mv_pc`,
`mv_session_id`, `expand`, `collapse`, `expandall`, `collapseall`); add more
with `var_exclude`.

If no entry matches, the tag returns a link (or, with `pageonly`, the bare
path) to `default`, which itself defaults to the catalog's `catalog` special
page. If the rebuilt URL would exceed `size_limit` bytes, the tag returns
nothing (undef) rather than emit a huge link.

Entries whose page recorded as `expired` are skipped.

## Examples

A simple "back" link to the previous page:

    <a href="[history-scan]">Return to the previous page</a>

Return to the last catalog or product page, skipping the checkout flow:

    <a href="[history-scan exclude="^ord/"]">Continue shopping</a>

Get just the page name (no full URL) to reuse elsewhere:

    [history-scan find="^products/" pageonly=1]

Fall back to a named page when there is no usable history:

    <a href="[history-scan default="index"]">Go back</a>

## Notes

- Only non-volatile page views are recorded in history, so search result
  pages and other volatile requests will not appear. See
  [if_not_volatile](if_not_volatile.md) for the related volatility concept.
- `find`, `exclude`, and `include` are interpolated straight into Perl
  regular expressions; keep them to trusted, page-authored values.

## See also

- [area](area.md) — builds the URL that `[history-scan]` returns
- [if_not_volatile](if_not_volatile.md) — the request-volatility flag that
  governs what gets recorded in history
- [../guides/sessions.md](../guides/sessions.md) — session storage,
  including the history stack

## Source

Defined in `code/UserTag/history_scan.tag` (registers the tag
`history-scan`). Implemented by an inline Routine that reads
`$Vend::Session->{History}` and calls the [area](area.md) tag.
