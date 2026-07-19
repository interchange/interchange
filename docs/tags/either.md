# either

Return the first non-empty alternative from a list of `[or]`-separated
choices in its body. Reach for it when you want a fallback chain: use a
value if it is set, otherwise the next one, otherwise a literal default.

## Syntax

    [either] FIRST [or] SECOND [or] DEFAULT [/either]

Container tag. Each alternative is interpolated as Interchange Tag Language
(ITL) in turn; the first one that produces non-blank text (after trimming
leading and trailing whitespace) is returned. If every alternative is
empty, the last (empty) result is returned.

## Attributes

`[either]` takes no attributes and no positional parameters.

## Description

The body is split on the literal token `[or]`. Interchange interpolates
each piece in order and trims surrounding whitespace from the result. The
first piece whose trimmed result is non-empty is returned immediately;
later pieces are then not evaluated. This makes `[either]` a compact
alternative to nested `[if]`/`[else]` blocks when all you need is "first
value that has something in it."

Because each alternative is fully interpolated, you can mix tags,
variables, and literal text freely between the `[or]` separators.

## Examples

Use a scratch value if set, otherwise fall back to a literal menu name:

    [either][scratch line_menu][or]catalog/line[/either]

Choose a character set from an HTTP variable, defaulting to a literal:

    <meta charset="[either]__MV_HTTP_CHARSET__[or]iso-8859-1[/either]">

Chain several fallbacks — the first non-empty email wins:

    [either]__EMAIL_SERVICE__[or]__EMAIL_INFO__[or]__ORDERS_TO__[/either]

## Notes

Whitespace-only alternatives count as empty, so indentation and line breaks
around a value do not accidentally satisfy the test. To treat a value as
present even when it is `0` or blank, use an explicit
[if](if.md)/[else](else.md) test instead.

## See also

[if](if.md), [or](or.md), [default](default.md), the
[templating](../guides/templating.md) guide.

## Source

Defined in `code/SystemTag/either.coretag` (inline `Routine`), which splits
the body on `[or]` and interpolates each part with `interpolate_html`.
