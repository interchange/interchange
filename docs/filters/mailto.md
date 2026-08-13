# mailto

Wraps an email address in an HTML `<a href="mailto:...">` link, optionally with
custom anchor text.

## Syntax

    [filter mailto]ADDRESS[/filter]
    [filter mailto.WORD1.WORD2]ADDRESS[/filter]

## Description

The filter builds `<a href="mailto:ADDRESS">ANCHOR</a>`, where `ADDRESS` is the
input value. By default the anchor text is the address itself. If you supply
dotted arguments, they are joined with single spaces to form the anchor text
instead — so `mailto.Contact.us` yields the anchor `Contact us`. The address is
not escaped or validated.

## Examples

Minimal — the address is both link target and visible text:

    [filter mailto]sales@example.com[/filter]

produces:

    <a href="mailto:sales@example.com">sales@example.com</a>

With custom anchor text from dotted arguments:

    [filter mailto.Contact.us]sales@example.com[/filter]

produces:

    <a href="mailto:sales@example.com">Contact us</a>

## See also

- [liven_urls](liven_urls.md)

## Source

Defined in `code/Filter/mailto.filter`.
