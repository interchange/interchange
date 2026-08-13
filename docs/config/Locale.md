# Locale

Defines a named locale -- a set of key/value settings covering currency and
number formatting plus message translations -- that Interchange can switch
to at runtime. Reach for it to localize a storefront's prices, number
formats, and text into one or more languages/regions.

**Scope:** both (`interchange.cfg` global, `catalog.cfg` catalog)

## Syntax

    Locale  NAME  KEY VALUE [KEY VALUE ...]
    Locale  NAME  { PERL-HASH }

The first token is the locale `NAME` (for example `en_US`, `fr_FR`). The
rest is either shell-quoted `KEY VALUE` pairs or a `{ ... }` Perl hash
(evaluated in a `Safe` compartment). Repeat the directive with the same
`NAME` to add more keys. Default: empty.

## Description

A locale is a hash of settings stored under its name in a locale
repository. Settings fall into two broad groups:

- **Formatting** keys such as `frac_digits`, `mon_decimal_point`,
  `mon_thousands_sep`, and `currency_symbol`, which control how
  [currency](../tags/currency.md) and numbers are rendered. When the locale
  name is a real system locale, Interchange seeds these from the operating
  system's `localeconv()` before applying your overrides.
- **Message** keys, where the key is an original string and the value is its
  translation. These drive Interchange's message localization
  (`errmsg`/the `[L]...[/L]` construct).

The active locale is selected at runtime (for example by the `mv_locale`
variable or the [DefaultLocale](DefaultLocale.md) directive), at which point
Interchange applies its formatting settings, calling `POSIX::setlocale`
where appropriate.

### Global

A `Locale` in `interchange.cfg` defines a locale in the global repository,
available as a base to every catalog. It is read at server startup.

### Catalog

A `Locale` in `catalog.cfg` defines a locale for that catalog. Catalog
locale settings can also be loaded from a table with
[LocaleDatabase](LocaleDatabase.md), which merges on top of inline
definitions. If no [DefaultLocale](DefaultLocale.md) is set, the last
`Locale` defined becomes the default and current locale.

## Examples

Add a few message translations to `en_US` (from the strap demo
`catalog.cfg`, using the here-document hash form):

```
Locale en_US  <<EOL
{
    "Username already exists (indirect).",
    "Sorry, that email is already associated with an account.",
}
EOL
```

Set currency formatting for a locale with key/value pairs:

```
Locale de_DE  mon_decimal_point "," mon_thousands_sep "." frac_digits 2
```

## Notes

The Interchange page lookup that honors [HTMLsuffix](HTMLsuffix.md) is
locale-sensitive, so a locale can also select localized page files.

Several other directives ([Route](Route.md), [Shipping](Shipping.md),
[UserDB](UserDB.md), [Options](Options.md), [Levy](Levy.md)) share the same
`parse_locale` parser to build their own keyed repositories -- the syntax
is identical even though the data is unrelated to internationalization.

## See also

[LocaleDatabase](LocaleDatabase.md), [DefaultLocale](DefaultLocale.md),
[currency](../tags/currency.md), the
[internationalization](../guides/internationalization.md) guide.

## Source

Parsed by `parse_locale` in `lib/Vend/Config.pm` (into the `Locale`
repository; the last catalog locale may become `DefaultLocale` in
post-processing); applied at runtime by `Vend::Util::setlocale`
(`lib/Vend/Util.pm`).
