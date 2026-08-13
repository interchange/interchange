# parse_locale

Interpolate `[L]...[/L]` and `[LC]...[/LC]` localization markup in the tag's
body, translating phrases against the active locale. Reach for it when you have
a block of text containing locale markup that you want translated explicitly,
rather than relying on the normal page-level locale pass.

## Syntax

    [parse_locale]BODY WITH [L]...[/L] MARKUP[/parse_locale]

Container tag (has an end tag). It returns the body with all locale markup
resolved.

## Attributes

None. The tag takes no attributes and no positional parameters.

## Description

Interchange's internationalization system stores per-locale phrase tables in
the `Locale` directive. Two pieces of Interchange Tag Language (ITL) markup use
them:

- `[L]phrase[/L]` — look up `phrase` in the current locale's table and
  substitute the translation; if there is no entry, the original phrase is left
  in place. `[L key]default[/L]` uses `key` for the lookup and `default` as the
  fallback text.
- `[LC]...[/LC]` — a locale "bit" block, resolved with the same locale data
  (via `find_locale_bit`).

`parse_locale` runs exactly that substitution pass over its body. This is the
same routine Interchange applies to whole pages, exposed as a tag so you can
force it over a specific region — for instance, text assembled by other tags,
or content pulled from a database.

If no `Locale` is active, `[L]` markup collapses to its literal (untranslated)
content and `[LC]` blocks are left as-is.

### Pragma interaction

If the `no_locale_parse` pragma is set, `parse_locale` returns without doing
anything — the body passes through unchanged. Set it when a page must not have
locale markup interpreted.

## Examples

Translate a greeting using the active locale:

    [parse_locale]
    [L]Hello, welcome to our store[/L]
    [/parse_locale]

With a locale that maps that phrase to French, this yields:

    Bonjour, bienvenue dans notre boutique

Use an explicit key with a fallback for untranslated locales:

    [parse_locale][L greeting]Hello[/L][/parse_locale]

If the active locale defines `greeting`, its value is emitted; otherwise the
literal `Hello` is shown.

## Notes

- The `[L]` and `[LC]` markup is normally handled during ordinary page
  interpolation; you only need `parse_locale` to apply it to text that was not
  in the original page source (or to re-apply it to a specific block).
- Honesty note: the substitution keys off `$Vend::Cfg->{Locale}`, the locale
  currently in effect for the request. This tag does not switch locales; use
  the locale-setting machinery (`mv_locale`, the [setlocale](setlocale.md) tag)
  to choose which table is consulted.

## See also

- [setlocale](setlocale.md) — switch the active locale
- [loc](loc.md) — inline locale lookup
- [internationalization guide](../guides/internationalization.md)

## Source

Defined in `code/SystemTag/parse_locale.coretag` (registered tag name
`parse_locale`). Implemented by `Vend::Util::parse_locale`.
