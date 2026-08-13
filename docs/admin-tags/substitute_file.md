# substitute_file

Rewrite the region of an on-disk file that lies between a begin marker and an
end marker, replacing it with the tag's body. The admin UI's content editor uses
it to update just the editable part of a template file in place. This tag is
part of the admin UI toolset (registered from `code/UI_Tag/` and loaded only
when the administrative interface is enabled), not a storefront tag.

## Syntax

    [substitute_file file=path begin=re end=re]
    new content
    [/substitute_file]

    [substitute_file file=path content=1]
    new content
    [/substitute_file]

Container tag. The body is the replacement text. Returns a true value on a
successful substitution, `0` if the markers were not found, or undefined on
error (with the reason stored in the scratch variable `ui_failure`).

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `file`    | none    | Path of the file to modify. Must exist and be writable. |
| `begin`   | none    | Regular expression marking the start of the region to replace. |
| `end`     | none    | Regular expression marking the end of the region. |
| `content` | off     | Preset `begin`/`end` to the standard content markers `<!--+ begin content --+>` and `<!--+ end content --+>` (and turn on `newline`). |
| `scratch` | none    | Preset `begin`/`end` to `[tmp NAME]`/`[set NAME]`/`[seti NAME]` and their closers for the named scratch block (non-greedy, `newline` on). |
| `newline` | off\*   | Let the region span newlines (match with `[\s\S]` instead of `.`). |
| `greedy`  | on\*    | When off, match the smallest region between markers. |
| `replace` | off     | Replace the markers too; by default the markers are kept and only the text between them changes. |
| `case`    | off     | Case-sensitive marker matching (default is case-insensitive). |
| `global`  | off     | Replace every marked region in the file, not just the first. |

Positional order: `file`. Remaining named attributes are collected as options
(`addAttr`); the body supplies the replacement text.

\* `content` and `scratch` change the `newline`/`greedy` defaults as noted.

## Description

The tag first verifies the file exists and is writable, setting `ui_failure`
and returning undefined if not. It copies the file to a temporary backup, reads
it, and substitutes the region delimited by `begin`/`end` with the body text.
Whether the markers survive depends on `replace`: by default the begin and end
markers are preserved and only the text between them is swapped, so the region
stays editable; with `replace` on, the whole match including the markers is
replaced.

The `content` and `scratch` shortcuts fill in `begin`/`end` for the two common
cases — an HTML content block delimited by `<!--+ begin content --+>` /
`<!--+ end content --+>`, or an Interchange `[tmp]`/`[set]`/`[seti]` block for a
named scratch variable. On a successful write the backup is removed; if no
region matched, the file is left untouched and the tag returns `0`. Any write
error leaves the backup in place and reports its path in `ui_failure`.

## Examples

Replace the standard content block of a page file with new markup:

    [substitute_file file="pages/about.html" content=1]
    <h1>About us</h1>
    <p>We have moved.</p>
    [/substitute_file]

Replace the first region between explicit comment markers, keeping the markers:

    [substitute_file file="templates/foo" begin="<!-- START -->" end="<!-- END -->" newline=1]
    fresh body
    [/substitute_file]

Replace the body of a named scratch block across the whole file:

    [substitute_file file="pages/page.html" scratch=greeting global=1]
    Welcome back!
    [/substitute_file]

## Notes

The `begin` and `end` values are regular expressions, so characters like `.`,
`(`, or `[` in a literal marker must be escaped. On any write failure the
original file is preserved as the temporary backup named in `ui_failure`.

## See also

- [write_relative_file](write_relative_file.md)
- [unlink_file](unlink_file.md)
- Concepts: [admin UI](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/substitute_file.coretag`, registered as the UserTag
`substitute_file` (inline Routine).
