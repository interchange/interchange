# setlocale

Switch the active locale and/or currency. Reach for it to render a page (or a
whole session) in a different language, number format, or currency than the
catalog default.

## Syntax

    [setlocale de_DE]
    [setlocale locale=fr_FR currency=fr_FR persist=1]

Standalone tag (no end tag). Produces no output; its effect is the locale
change.

## Attributes

| Attribute  | Default | Description |
|------------|---------|-------------|
| `locale`   | current session default | Locale to switch to. If omitted, reverts to the session default (`mv_locale` / `mv_currency` scratch values). |
| `currency` | none    | Currency locale to switch to; changes pricing and currency keys only. |
| `persist`  | `0`     | When true, the change persists for the rest of the session; otherwise it lasts only for the current page. |
| `get`      | `0`     | When true, return the name of the currently active locale instead of changing anything. |

Positional order: `locale`, `currency`.

The tag declares `addAttr`, so `persist` and `get` are read from the attribute
list.

## Description

`[setlocale]` maps to `Vend::Util::setlocale`. Given a `locale`, it loads that
locale's entry from the catalog's locale repository (see
[Locale](../config/Locale.md) and [LocaleDatabase](../config/LocaleDatabase.md))
and copies its directive values into the running configuration, so subsequent
text, number, date, and price formatting use that locale. Given a `currency`,
it applies just the currency-related keys, so you can keep the display language
while changing the priced currency.

If the named locale or currency is not defined in the repository, the change is
refused and an error is logged; the tag returns empty either way.

By default the switch applies only to the current page. With `persist=1` the
chosen locale (and currency) are written into the session scratch variables
`mv_locale`/`mv_currency` so they carry forward to later pages. Calling
`[setlocale]` with no arguments restores the session default locale.

`get=1` is a read-only mode: it returns the name of the currently active locale
and makes no change.

## Examples

Render the current page in German:

    [setlocale de_DE]

Switch to French locale and currency for the rest of the session:

    [setlocale locale=fr_FR currency=fr_FR persist=1]

Price the same cart two ways on one page, then return to the default:

    Dollar pricing:
    [setlocale en_US]
    [item-list][item-code]: [item-price]<br>[/item-list]

    Euro pricing:
    [setlocale locale=de_DE currency=de_DE]
    [item-list][item-code]: [item-price]<br>[/item-list]

    [comment]Return to the default locale[/comment]
    [setlocale]

## See also

- [Locale](../config/Locale.md), [LocaleDatabase](../config/LocaleDatabase.md)
- [DefaultLocale](../config/DefaultLocale.md)
- [currency](currency.md)
- Concepts: [internationalization](../guides/internationalization.md)

## Source

Defined in `code/SystemTag/setlocale.coretag`. Implemented by
`Vend::Util::setlocale`.
