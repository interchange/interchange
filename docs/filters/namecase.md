# namecase

Normalizes ALL-CAPS words to capitalized form ("DOE" → "Doe"), leaving
already-lowercase words untouched — handy for tidying names entered in capitals.

## Syntax

    [filter namecase]TEXT[/filter]
    [value name=field filter="namecase"]

## Description

The filter matches each run of a capital letter followed by word characters
(`[A-Z]\w+`) and rewrites it so only the first letter is upper case and the
rest lower case (`\L\u`). Perl's `use locale` is in effect, so case folding
follows the active locale.

Consequences of the pattern:

- An all-caps word like `DOE` becomes `Doe`.
- A word that already starts lower case (for example `de` in a surname) does
  not match and is left as-is.
- Because the whole matched run is lower-cased before the first letter is
  re-capitalized, interior capitals are **not** preserved: `MCDONALD` becomes
  `Mcdonald`, not `McDonald`, and `O'BRIEN` becomes `O'Brien` only up to the
  apostrophe (`O` and `BRIEN` are matched separately). This filter is a
  best-effort tidy, not a full name-formatting engine.

Empty input yields empty output.

## Examples

    [filter namecase]DOE, John[/filter]

produces:

    Doe, John

A single all-caps surname:

    [filter namecase]MCDONALD[/filter]

produces (note the interior capital is not restored):

    Mcdonald

## See also

- [name](name.md)
- [ucfirst](ucfirst.md)
- [lc](lc.md)
- [uc](uc.md)

## Source

Defined in `code/Filter/namecase.filter`.
