# mm_locale

Switch the current request into the administrative UI's locale, loading that
locale's settings and text direction. Reach for it at the top of admin pages
(it runs from the admin `.autoload`) so the back office renders in the
administrator's chosen language.

`[mm_locale]` is part of the admin UI tag set in `code/UI_Tag/`, loaded when
the administrative interface is enabled; it is not a storefront tag.

## Syntax

    [mm_locale]

Standalone tag (no end tag). It performs its work as a side effect and always
returns `1`, so it produces no visible output.

## Attributes

This tag takes no attributes.

## Description

`[mm_locale]` determines the admin locale from the `ui_locale` form value,
falling back to the `UI_LOCALE` catalog variable. It then, for the duration of
the request:

- enables `mv_shadowpass` so shadow databases return unmangled records;
- clears the catalog `Locale_repository` and, if the chosen locale exists in
  the global locale repository, installs that locale's settings into the
  catalog and calls `setlocale`;
- sets the temporary `mv_locale` value to the chosen locale;
- when the locale defines `MV_LANG_DIRECTION`, sets the temporary
  `ui_language_direction` value to a `dir="..."` attribute string for
  right-to-left rendering.

The locale, `mv_locale`, and direction changes are set as *temporary*
(request-scoped) values, so they apply to the current admin page render only.
A "locale" is a named set of language and formatting settings; see
[internationalization](../guides/internationalization.md).

## Examples

Activate the admin locale at the top of a page (as the admin `.autoload`
does):

    [mm_locale]

With `ui_locale` set to a right-to-left locale such as `he_IL`, later markup
can pick up the direction:

    <html[value ui_language_direction]>

which renders as:

    <html dir="rtl">

## Notes

`[mm_locale]` acts only when the resolved locale exists in the global locale
repository configured for the server; an unknown locale leaves the default
settings in place. It reads `ui_locale` from the values space, so a locale
selector on an admin page takes effect on the next request.

## See also

- Concepts: [internationalization](../guides/internationalization.md),
  [admin UI](../guides/admin-ui.md)

## Source

Defined in `code/UI_Tag/mm_locale.coretag` as an inline `UserTag` Routine
(`UserTag mm_locale`).
