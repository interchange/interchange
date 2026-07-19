# yesno

Turns a true/false value into the word `Yes` or `No` (localized if a locale
provides translations).

## Syntax

    [filter yesno]VALUE[/filter]
    [value name=field filter="yesno"]

`yesno` takes no arguments.

## Description

The filter returns `Yes` when its input is a true value in Perl terms and `No`
otherwise. This means the empty string, the single character `0`, and undefined
input yield `No`; **any** other value — including a string of whitespace or the
string `00` — yields `Yes`. To treat whitespace-only input as empty, strip it
first: `filter="strip yesno"` (see [strip](strip.md)).

If the active locale (`$Vend::Cfg->{Locale}`) defines a translation for the
literal `Yes` or `No`, that translation is returned instead, so the output can
be localized.

## Examples

Non-empty input:

    [filter yesno]anything[/filter]

produces:

    Yes

Empty input:

    [filter yesno][/filter]

produces:

    No

The string `0` is false, so it also yields `No`:

    [filter yesno]0[/filter]

produces:

    No

## See also

- [strip](strip.md) — trim whitespace before testing
- [yesno](../widgets/yesno.md), [noyes](../widgets/noyes.md) — the Yes/No form
  widgets
- [internationalization](../guides/internationalization.md) — locale translations

## Source

Defined in `code/Filter/yesno.filter`; reads `$Vend::Cfg->{Locale}`. Applied by
`Vend::Interpolate::filter_value` (`lib/Vend/Interpolate.pm`).
