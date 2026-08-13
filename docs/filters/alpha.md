# alpha

Removes every character that is not an ASCII letter (`A-Z` or `a-z`).

## Syntax

    [filter alpha]TEXT[/filter]
    [value name=field filter="alpha"]

`alpha` takes no arguments. It can be used anywhere a filter is
accepted: the [filter](../tags/filter.md) tag, the `filter=` attribute
of tags such as [value](../tags/value.md), and the `filter` setting of a
form widget.

## Description

The filter strips out any run of characters that are not in the ASCII
ranges `A-Z` or `a-z`, using the substitution `s/[^A-Za-z]+//g`. Digits,
whitespace, punctuation, and multibyte characters are all removed. Empty
or undefined input yields the empty string.

Because the match is on the literal ASCII ranges only, accented or
non-ASCII letters (for example `é`) are not preserved.

## Examples

    [filter alpha]** Test 1: Hello, World! **[/filter]

produces:

    TestHelloWorld

Applied to a form value:

    [value name=coupon filter="alpha"]

If the submitted `coupon` value is `SAVE-20%`, the tag renders:

    SAVE

## See also

- [alphanumeric](alphanumeric.md)
- [word](word.md)
- [digits](digits.md)

## Source

Defined in `code/Filter/alpha.filter`.
