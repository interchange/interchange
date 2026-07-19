# forum

Render a threaded discussion display from a `forum` database table: a post and
its nested replies, formatted with customizable templates and scored so
low-rated posts can be collapsed. The companion [forum-userlink](forum-userlink.md)
tag builds the display name for a post's author.

## Syntax

    [forum TOP]
    [forum]...template and sub-templates...[/forum]

Container tag (has an end tag). Its body holds the display templates. Output is
not reparsed (`NoReparse`).

## Attributes

| Attribute           | Default                    | Description |
|---------------------|----------------------------|-------------|
| `top`               | `0`                        | Article id (`code`) of the post to display as the thread root (first positional). |
| `template`          | built-in                   | Template for a shown post; may instead be given as a `[forum-header]...` block in the body (see below). |
| `header_template`   | built-in                   | Template rendered once before the thread. |
| `link_template`     | built-in                   | Template for a post shown only as a link (below `show_level`). |
| `scrub_template`    | built-in                   | Template for a post at or below `scrub_score`. |
| `reply_page`        | `forum/reply`              | Page used to build each post's reply URL. |
| `submit_page`       | `forum/submit`             | Page used for the submit URL. |
| `display_page`      | current page (`MV_PAGE`)   | Page used to build top/parent/display URLs. |
| `date_format`       | `%B %e, %Y @%H:%M`         | `convert-date` format for each post's date. |
| `full`              | `1`                        | Retrieve the full subtree. |
| `sort`              | `code`                     | Sort column for the tree. |
| `scrub_score`       | `0`                        | Posts scoring at or below this are shown via `scrub_template`. |
| `show_score`        | `1`                        | Posts scoring at or above this get the full `template`. |
| `show_level`        | `0` or `2`                 | Nesting depth still shown in full; deeper posts collapse to a link. |
| `threshold_message` | localized "Message below your threshold" | Text used by the default scrub template. |

Positional order: `top`.

## Description

`forum` reads the `forum` table (which must exist) and walks the reply tree
with the [tree](tree.md) tag, starting at the row whose `code` is `top`. Each
row is enriched with reply/parent/top/display URLs (built with [area](area.md)),
a formatted `date` (via [convert-date](convert-date.md)), and a `userinfo`
display name (via [forum-userlink](forum-userlink.md)), then rendered with the
appropriate template.

Templates use `{FIELD}` placeholders (uppercased row columns) and `{FIELD?}...
{/FIELD?}` conditionals -- for example `{SUBJECT}`, `{USERINFO}`, `{DATE}`,
`{COMMENT}`, `{REPLY_URL}`, and `{DISPLAY_URL}`. You can override the built-in
templates either through the `*_template` attributes or by embedding named
sub-blocks in the tag body:

    [forum-header]...[/forum-header]
    [forum-link]...[/forum-link]
    [forum-scrub]...[/forum-scrub]
    [forum-footer]...[/forum-footer]

Any body text left after those blocks are removed becomes the per-post
`template`.

Scoring selects a template per post: at or below `scrub_score` uses the scrub
template; at or above `show_score`, or within `show_level` nesting depth, uses
the full template; otherwise the post shows only as a link.

## Examples

Display an entire thread rooted at article `1001` with the built-in templates:

    [forum 1001]

Display a thread with a custom per-post template and a header:

    [forum top=1001]
    [forum-header]<h2>Discussion</h2>[/forum-header]
    <div class="post">
      <b>{SUBJECT}</b> by {USERINFO} on {DATE}<br>
      {COMMENT}
      [ <a href="{REPLY_URL}">Reply</a> ]
    </div>
    [/forum]

## Notes

This tag targets a specific `forum` schema (columns such as `code`, `artid`,
`parent`, `username`, `subject`, `comment`, `created`, `score`, plus the
tree-iteration fields `mv_level`, `mv_children`, `mv_last`). It is the display
half of a forum application; posting and reply pages (`forum/reply`,
`forum/submit`) are separate. The strap demo does not ship a forum table, so a
running example needs that schema in place.

## See also

[forum-userlink](forum-userlink.md), [tree](tree.md), [area](area.md),
[convert-date](convert-date.md),
[../guides/templating.md](../guides/templating.md)

## Source

Defined in `code/UserTag/forum.tag` (which also registers
[forum-userlink](forum-userlink.md)). Implemented by the inline Routine in that
file, which iterates with `Vend::Interpolate`'s `tree` tag.
