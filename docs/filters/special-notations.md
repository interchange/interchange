# Special filter notations

Five filter "names" are not defined as filter files at all; they are
numeric and format forms recognized directly by Interchange's
`filter_value()` routine and applied before any named filter is looked up.
They let you reformat, truncate, or word-limit a value inline without a
dedicated filter.

These forms work anywhere a filter name is accepted — the
[filter](../tags/filter.md) tag, the `filter=` attribute of tags such as
[value](../tags/value.md), and the `filter` setting of a form widget — and
they can be combined with named filters in a space-separated filter list.

## Syntax

    [filter %SPEC]TEXT[/filter]      <!-- sprintf format -->
    [filter N]TEXT[/filter]          <!-- truncate to N characters -->
    [filter N.]TEXT[/filter]         <!-- truncate, append "..." -->
    [filter N$]TEXT[/filter]         <!-- keep last N characters, prefix "..." -->
    [filter wordsN]TEXT[/filter]     <!-- truncate to N words -->
    [filter wordsN.]TEXT[/filter]    <!-- truncate to N words, append "..." -->

## Description

The five forms are recognized in this order inside `filter_value()`:

### sprintf format — a token containing `%`

Any filter token that contains a `%` (with no dot before it) is treated as
a Perl `sprintf` format string, and the value is passed through
`sprintf(FORMAT, value)`. This covers the full range of `sprintf`
conversions: `%.2f` for two decimal places, `%03d` for zero-padded
integers, `%x` for hexadecimal, and so on.

### `N` — truncate to N characters

A plain non-negative integer truncates the value to its first `N`
characters. If the value is already `N` characters or shorter, it is
returned unchanged.

### `N.` — truncate and append an ellipsis

An integer followed by a dot keeps the first `N` characters and appends a
literal `...`. If the value is `N` characters or shorter it is returned
unchanged (no ellipsis is added).

### `N$` — keep the last N characters, prefix an ellipsis

An integer followed by a `$` keeps the last `N` characters and replaces
the removed leading portion with a literal `...`. As with the other
truncation forms, a value already `N` characters or shorter is returned
unchanged.

### `wordsN` and `wordsN.` — truncate to N words

`words` followed by an integer keeps the first `N` whitespace-separated
words. The optional trailing dot (`wordsN.`) appends a literal `...` when
truncation actually happens. A value with `N` words or fewer is returned
unchanged.

## Examples

sprintf, two decimal places:

    [filter %.2f]3.14159[/filter]

produces:

    3.14

sprintf, zero-padded integer:

    [filter %03d]7[/filter]

produces:

    007

Truncate to 4 characters:

    [filter 4]Interchange[/filter]

produces:

    Inte

Truncate to 4 characters with an ellipsis:

    [filter 4.]Interchange[/filter]

produces:

    Inte...

Keep the last 4 characters, prefixed with an ellipsis:

    [filter 4$]Interchange[/filter]

produces:

    ...ange

A value that is already short enough is unchanged:

    [filter 20]abc[/filter]

produces:

    abc

Truncate to 3 words:

    [filter words3]the quick brown fox jumps[/filter]

produces:

    the quick brown

Truncate to 3 words with an ellipsis:

    [filter words3.]the quick brown fox jumps[/filter]

produces:

    the quick brown...

## See also

- [filter](../tags/filter.md) tag
- [commify](commify.md)
- [round](round.md)
- [oneline](oneline.md)
- [templating guide](../guides/templating.md)

## Source

Implemented directly in `filter_value()` in `lib/Vend/Interpolate.pm`
(around line 682), applied before the `%Filter` / CodeDef lookup. There
are no `code/Filter/*.filter` files for these forms.
