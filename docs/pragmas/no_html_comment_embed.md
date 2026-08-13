# no_html_comment_embed

Turns off Interchange's feature of unwrapping ITL tags that were hidden inside
HTML comments. Set it when you have literal `<!--[ ... ]-->` sequences that
should stay as comments rather than being treated as Interchange Tag Language
(ITL) code.

**Default:** off — specially-formed HTML comments *are* unwrapped and their ITL
is interpolated.

## Syntax

Catalog-wide, in `catalog.cfg`:

    Pragma no_html_comment_embed

Page-wide, anywhere in an Interchange page:

    [pragma no_html_comment_embed]
    [pragma no_html_comment_embed 0]

Block-wide, around an ITL block:

    [tag pragma no_html_comment_embed]1[/tag]

This is a boolean pragma.

## Description

Many HTML editors mangle or strip bare ITL tags. To work around that, Interchange
lets you wrap ITL in HTML comments with no space between the comment marker and
the bracket. By default `vars_and_comments()` rewrites `<!--[` to `[` and `]-->`
to `]`, so a wrapped tag is unwrapped, interpolated, and displayed as if the
comment had never been there:

    The time is now <!--[time]-->.

renders the current time. When `no_html_comment_embed` is set, this rewriting is
skipped, so the same line stays a literal HTML comment and the `[time]` tag is
never executed.

## Examples

Disable comment-embedded ITL for a page that shows example markup verbatim:

    [pragma no_html_comment_embed]
    Example: <!--[time]--> stays literally in the source.

## Notes

The comment-embedding feature is long-standing, but the pragma to turn it off was
added in September 2004.

## See also

- [Pragma](../config/Pragma.md)

## Source

The `Pragma` directive is parsed by `boolean_value` in
`lib/Vend/Config.pm`. This pragma is consumed in `vars_and_comments()` in
`lib/Vend/Interpolate.pm`.
