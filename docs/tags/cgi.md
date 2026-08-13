# cgi

Returns (or sets) the value of a CGI input variable submitted with the current
request. Reach for it to read form fields, query-string parameters, and other
transient per-request input — as opposed to [value](value.md), which reads the
persistent form values kept in the session.

## Syntax

    [cgi name]
    [cgi name=varname set=value default=text filter=op]

Standalone tag (no end tag). Output is not reparsed as Interchange Tag Language
(ITL); on the contrary, the tag actively defangs any tags found in the value
(see Description).

## Attributes

| Attribute     | Default | Description |
|---------------|---------|-------------|
| `name`        | (none)  | Name of the CGI variable to read or set. |
| `set`         | (unset) | If defined, store this value into the variable first. |
| `default`     | (none)  | Value to return if the variable is missing or false. |
| `filter`      | (none)  | Filter(s) to apply to the value before returning it. |
| `keep`        | `0`     | With `filter`, apply the filter for display only; do not overwrite the stored CGI value. |
| `enable_html` | `0`     | Allow HTML `<` characters through unescaped. |
| `hide`        | `0`     | Perform any `set`/`filter` side effect but return nothing. |

Positional order: `name`. The tag accepts arbitrary additional attributes
(`addAttr`).

## Description

CGI variables are the raw inputs of the current HTTP request: query-string
parameters (`page?foo=bar`), submitted form fields, and path components. They
are reset on every request, so `[cgi foo]` sees only what the browser sent this
time. The equivalent in embedded Perl is `$CGI->{foo}` (or `$CGI::values{foo}`).

The tag reads `$CGI::values{name}`. Behavior in order:

- If `set` is defined, its value is written to `$CGI::values{name}` before
  reading, so the tag can both set and echo a value.
- If the resulting value is non-empty, Interchange **sanitizes** it: any
  embedded `<tag ... mv=...>` construct and any `[` are escaped so that
  user-supplied input cannot inject ITL or active markup. This is a security
  measure — never trust that `[cgi]` output is the exact bytes the user typed.
- If the value is empty and `default` is set, the default is returned instead.
- If `filter` is given, the named filter(s) run on the value. Unless `keep` is
  set, the filtered result is written back to `$CGI::values{name}`.
- Finally, unless `enable_html` is set, remaining `<` characters are converted
  to `&lt;` so the value is safe to drop into an HTML page.

Because of the sanitizing and HTML-escaping, `[cgi]` is the safe way to echo
request input back to the page. To store input under a persistent name, filter
it once with [input-filter](input-filter.md) or copy it into the values space.

## Examples

Save a page as `cgitest.html`, then visit `cgitest?foo=bar&toad=stool`:

    Value of 'foo': [cgi foo]
    Value of 'toad': [cgi name=toad]

produces:

    Value of 'foo': bar
    Value of 'toad': stool

Supply a fallback when the parameter is absent:

    Sort order: [cgi name=sort default=ascending]

Read a numeric field and clamp it through a filter for display only, leaving
the raw CGI value intact for later processing:

    Quantity: [cgi name=quantity filter=digits keep=1]

## Notes

- The tag never reaches into the database or session; for persistent form
  values use [value](value.md), and for session fields use
  [data](data.md) with the `session` pseudo-table.

> **strap note:** strap-derived catalogs define `[ecgi foo]`, a
> catalog-level extended alias expanding to
> `[cgi name=foo filter=encode_entities keep=1]` — the safe way to echo
> request input. See
> [Catalog anatomy](../guides/catalog-anatomy.md).

## See also

- [value](value.md) — persistent form values
- [input-filter](input-filter.md) — attach a filter to a CGI variable
- [filter](filter.md) — apply filters to arbitrary text
- Guide: [Forms](../guides/forms.md)

## Source

Defined in `code/SystemTag/cgi.coretag` (inline `Routine`).
