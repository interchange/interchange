# list_glob

Expand a shell-style glob pattern into a list of matching file names,
optionally stripping a common directory prefix from each result. Reach for it
to populate file pickers in admin UI pages, for example listing the component
templates in a directory.

`[list_glob]` is part of the admin UI tag set in `code/UI_Tag/`, loaded when
the administrative interface is enabled; it is not a storefront tag.

## Syntax

    [list_glob pattern]
    [list_glob pattern prefix]

Standalone tag (no end tag). In scalar context it returns the matches joined
with newlines; called from Perl in list context it returns the list.

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `spec` | none | The glob pattern to expand (for example `*` or `*.html`). Multiple space-separated patterns are allowed. |
| `prefix` | none | A directory prefix prepended to the pattern before globbing and stripped from each returned name, so results are relative to that directory. |

Positional order: `spec`, `prefix` (`PosNumber 2`).

## Description

`[list_glob]` delegates to `UI::Primitive::list_glob`, which runs Perl's
`glob` on the pattern. When `prefix` is supplied, it is trimmed of surrounding
whitespace and prepended to each whitespace-separated pattern before globbing;
the same prefix is then stripped from the front of each matched path, so the
returned names are relative to the prefix directory.

Paths are resolved relative to the process's current working directory (the
catalog directory during page interpolation) unless the pattern or prefix is
absolute.

## Examples

List every file in a directory below the catalog root:

    [list_glob * templates/components/]

With a `templates/components/` directory containing `box.html` and
`leftright.html`, the (newline-joined) result is:

    box.html
    leftright.html

List only the HTML files in the current directory, keeping full names:

    [list_glob *.html]

## Notes

`[list_glob]` matches files by name only; it does not recurse into
subdirectories. To walk a page tree recursively, use
[list_pages](list_pages.md).

## See also

- [list_pages](list_pages.md) — recursive listing of catalog pages
- Concepts: [admin UI](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/list_glob.coretag` (`UserTag list_glob`); the routine
delegates to `UI::Primitive::list_glob` in `dist/lib/UI/Primitive.pm`.
