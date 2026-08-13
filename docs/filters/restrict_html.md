# restrict_html

Neutralizes all HTML tags except an explicitly allowed set.

## Syntax

    [filter restrict_html.tag1.tag2...]TEXT[/filter]
    [value name=field filter="restrict_html.tag1.tag2..."]

The dotted arguments list the tag names that are permitted.

## Description

The filter scans the value for HTML tags. For each tag whose name is not in
the allowed list, it converts the opening `<` to the entity `&lt;`, so the
markup is displayed as literal text instead of being interpreted by the
browser. Tags in the allowed list are passed through unchanged. Both the
opening and closing forms of an allowed tag are recognized (for example
listing `b` permits both `<b>` and `</b>`), and matching is
case-insensitive.

The tag name is matched by its leading word only; attributes on an allowed
tag are left in place. Only the `<` that begins a recognized tag construct
is affected -- stray `<` characters that are not followed by a tag name are
not altered.

Use it to let users submit a small amount of formatting (bold, lists,
paragraphs) while defusing scripts, links, and other unwanted markup. To
strip all HTML instead, use [strip_html](strip_html.md).

## Examples

Allow paragraphs, line breaks, lists, and bold, but nothing else:

    [filter restrict_html.p.br.ul.li.b]<p>Keep this <b>bold</b> but
<a href="http://example.com">defuse this link</a>.</p>[/filter]

produces:

    <p>Keep this <b>bold</b> but
&lt;a href="http://example.com">defuse this link&lt;/a>.</p>

The `<a>` open and close tags become `&lt;a ...>` and `&lt;/a>`, which the
browser shows as text, while the allowed `<p>` and `<b>` tags are kept.

## See also

[strip_html](strip_html.md), [encode_entities](encode_entities.md),
[encode_special_entities](encode_special_entities.md)

## Source

Defined in `code/Filter/restrict_html.filter`.
