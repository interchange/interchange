# loc

Localizes the input by looking it up in the active locale's message catalog,
returning the translated string (or the original if no translation exists).

## Syntax

    [filter loc]TEXT[/filter]
    [value name=field filter="loc"]

## Description

The filter calls Interchange's `errmsg()` on the input, which is the same
localization routine behind the [L][/L] message tags. It looks the text up in
the message catalog for the **currently active** locale and returns the
translation; if there is no matching entry, the original text is returned
unchanged. See the
[internationalization guide](../guides/internationalization.md) for how locales
and their catalogs are configured.

Because `errmsg()` may treat the text as a `sprintf`-style format string, a
literal `%` in the input can be interpreted specially; escape it as `%%` if you
need a literal percent.

Empty input yields empty output.

## Notes

The filter uses whatever locale is already active for the request. It does
**not** accept a locale argument: historic documentation shows the form
`[filter loc.fr_FR]January[/filter]`, but the routine (`return errmsg($val)`)
never reads the dotted argument, so `.fr_FR` is discarded and the lookup still
uses the current locale. To localize in a specific locale, switch the locale
first (for example with the [setlocale](../tags/setlocale.md) tag) and then
apply `loc`.

## Examples

With the active locale providing a translation for `January`:

    [filter loc]January[/filter]

produces the localized form for the current locale (for example `Janvier`
under a French locale); with no matching catalog entry it produces:

    January

## See also

- [internationalization guide](../guides/internationalization.md)
- [setlocale](../tags/setlocale.md)

## Source

Defined in `code/Filter/loc.filter`; the routine calls `errmsg`
(`Vend::Util::errmsg`).
