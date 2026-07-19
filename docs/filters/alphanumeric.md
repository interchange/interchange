# alphanumeric

Removes every character that is not an ASCII letter or digit
(`A-Z`, `a-z`, or `0-9`).

## Syntax

    [filter alphanumeric]TEXT[/filter]
    [value name=field filter="alphanumeric"]

`alphanumeric` takes no arguments. It can be used anywhere a filter is
accepted: the [filter](../tags/filter.md) tag, the `filter=` attribute
of tags such as [value](../tags/value.md), and the `filter` setting of a
form widget.

## Description

The filter strips out any run of characters that are not in the ASCII
ranges `A-Z`, `a-z`, or `0-9`, using the substitution
`s/[^A-Za-z0-9]+//g`. Whitespace, punctuation, and multibyte characters
are all removed. Empty or undefined input yields the empty string.

Note that the underscore is removed; use [word](word.md) if you need to
keep underscores as well.

## Examples

    [filter alphanumeric]** Test 2: Hello, World! **[/filter]

produces:

    2TestHelloWorld

## See also

- [alpha](alpha.md)
- [word](word.md)
- [digits](digits.md)

## Source

Defined in `code/Filter/alphanumeric.filter`.
