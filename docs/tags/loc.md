# loc

Localize (translate) the body text through Interchange's locale message
tables. It is the container equivalent of the `[L]...[/L]` localization
markup, but unlike `[L]` it works correctly when the body itself contains
other Interchange Tag Language (ITL) tags. Reach for it to translate a
phrase that also includes interpolated values.

## Syntax

    [loc] message [/loc]
    [loc LOCALE] message [/loc]

Container tag (has an end tag). The body is interpolated
(`Interpolate 1`) before translation, so nested tags run first and the
resulting text is used as the lookup key.

## Attributes

| Attribute | Default          | Description |
|-----------|------------------|-------------|
| `locale`  | current locale   | Name of the locale whose message table to use. When omitted, the currently active locale is used. |

Positional order: `locale`.

## Description

`[loc]` looks up the interpolated body in a locale message table and returns
the translation, falling back to the original text when no translation
exists:

- If the `no_locale_parse` [pragma](../pragmas/) is in effect, `[loc]` does
  not translate; it reconstructs and returns the equivalent
  `[L]...[/L]` markup instead (so translation can be deferred to a later
  pass).
- If no `Locale` is configured for the catalog, the body is returned
  unchanged.
- With an explicit `locale` argument, the message is looked up in that
  locale's repository (`Locale_repository`); if that locale is not defined,
  the original body is returned.
- Otherwise the message is looked up in the active locale.

If the (interpolated) message key is present in the chosen locale table its
translation is returned; otherwise the original message is returned. This
"missing key returns the source text" behavior means an untranslated phrase
still renders in its original language.

Because the body is interpolated first, `[loc]` can wrap markup and tags
that `[L]` cannot handle cleanly.

## Examples

Translate a static phrase in the active locale:

    [loc]Add to cart[/loc]

Translate for a specific locale regardless of the current one:

    [loc fr_FR]Checkout[/loc]

Translate a phrase that contains an interpolated value (the case `[L]`
cannot handle):

    [loc]Welcome back, [value fname][/loc]

## Notes

- Be careful editing localized text: the (interpolated) message is itself
  the lookup key, so changing even one character changes the key and
  detaches it from existing translations. For long or volatile text, prefer
  the keyed `[L key]default[/L]` form so a stable `key` indexes the message.
- `[l]` is an alias of `[loc]`; see [l](l.md).

## See also

- [l](l.md) — alias of `[loc]`
- [msg](msg.md) — key-based localized message lookup
- [setlocale](setlocale.md) — switch the active locale
- [../guides/internationalization.md](../guides/internationalization.md)

## Source

Defined in `code/UserTag/loc.tag` (registers the tag `loc`, with `l` as an
alias). Implemented by an inline Routine that reads
`$Vend::Cfg->{Locale}` and `$Vend::Cfg->{Locale_repository}`.
