# value-extended

Return a form variable from the `$Values` space with extra handling that
plain [value](value.md) does not offer: joining multiple values, selecting by
index, testing presence, and reading or writing uploaded-file contents. Reach
for it with multi-select fields, checkbox groups, and file uploads.

## Syntax

    [value-extended name]
    [value-extended name=name joiner=", " filter=encode_entities]
    [value-extended name=upload outfile=path ascii=1]

Standalone tag (no end tag). Like [value](value.md), the returned text is not
reparsed as ITL: `[` is encoded to `&#91;` unless `enable_itl` is set, and `<`
is encoded to `&lt;` unless `enable_html` is set.

## Attributes

| Attribute      | Default | Description |
|----------------|---------|-------------|
| `name`         |         | Name of the form variable to read (positional 1). |
| `joiner`       | `` (space) | String placed between multiple values. `\n` and other escapes are honored. |
| `index`        | `*`     | Which element(s) of a multi-value variable to return; a Perl range/subscript expression (e.g. `0`, `1..2`). `*` means all. |
| `elements`     | `0`     | Return `0 .. last-index` instead of the values (the element numbers). |
| `filter`       |         | Apply a [filter](../filters/) to each selected element. |
| `test`         |         | Return `yes`/`no` for a presence test: `isput`, `isfile`, `defined`, `length`/`size`. |
| `put_contents` | `0`     | Return the raw body of a `PUT` request. |
| `file_contents`| `0`     | Return the contents of the uploaded file named by `name`. |
| `put_ref`      | `0`     | Return a scalar reference to the `PUT` body. |
| `outfile`      |         | Write the uploaded file named by `name` to this path; returns `yes`/`no`. |
| `ascii`        | `0`     | With `outfile`, normalize CR/LF line endings to Unix. |
| `maxsize`      |         | With `outfile`, reject uploads larger than this many bytes. |
| `yes` / `no`   | `1` / `` | Values returned by `test` and `outfile` for true/false. |
| `enable_itl`   | `0`     | Leave `[` characters intact. |
| `enable_html`  | `0`     | Leave `<` characters intact. |
| `values_space` |         | Read from a named `$Values` namespace (see [values-space](values-space.md)). |

Positional order: `name`.

## Description

Interchange stores a form field submitted more than once (multiple checkboxes,
a multi-select, or a repeated input of the same `name`) as a single string
with the individual values separated by null bytes (`\0`). Plain
[value](value.md) returns that raw string; `[value-extended]` splits it and
rejoins the pieces with `joiner`, so it is the correct tag for displaying
multi-value fields.

`index` selects a subset of the values using a Perl list-slice expression
evaluated in the Safe compartment — `index=0` for the first, `index="0..1"`
for the first two. `elements=1` returns the available element numbers instead
of the data, useful for building a loop.

The upload-oriented options work on file inputs: `file_contents` returns the
uploaded bytes, `outfile` streams them to a server path (subject to the
catalog's file-access rules via `Vend::File::allowed_file`), and the `test`
forms report whether a file or `PUT` body is present. An `outfile` write to a
disallowed path is logged and returns the empty string.

## Examples

Show a multi-select search spec with a readable separator, as the strap demo
results page does:

    [value-extended name=mv_searchspec joiner=" / "]

Encode multiple error strings for safe display, one per line:

    [value-extended name=mv_search_error joiner="<BR>" filter=encode_entities]

Return just the first submitted value:

    [value-extended name=colors index=0]

Save an uploaded file and branch on success:

    [value-extended name=userfile outfile="uploads/[value mv_username].dat" yes=1 no=0]

## Notes

- With a single-valued variable, `[value-extended name]` behaves like
  [value](value.md) but defaults its `joiner` to a single space rather than
  returning the value verbatim.
- A bad `index` expression is logged as `value-extended NAME: bad index` and
  yields no elements.

## See also

- [value](value.md) — the simpler single-value form
- [cgi](cgi.md) — raw CGI input, including `\0`-joined multiples
- The [forms guide](../guides/forms.md)

## Source

Defined in `code/SystemTag/value_extended.coretag`. Implemented by
`Vend::Interpolate::tag_value_extended` (`MapRoutine`).
