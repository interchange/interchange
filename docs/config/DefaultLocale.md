# DefaultLocale

Names which of the catalog's configured locales is the default at startup.
Reach for it when you define several locales with [Locale](Locale.md) and
want to state explicitly which one is active before any request selects
another.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    DefaultLocale  locale_name

A raw string (no parser): the name of a locale already defined with
[Locale](Locale.md). Default: empty.

## Description

Interchange keeps a repository of named locales (currency formats,
messages, and other localized settings). `DefaultLocale` designates which
of them is in force when a session begins, before any page or form
switches locale. It has the same effect as marking one locale `default 1`
in its [Locale](Locale.md) definition.

## Examples

Make the Croatian locale the default:

```
DefaultLocale hr_HR
```

The identical result using [Locale](Locale.md) directly:

```
Locale  hr_HR  default 1
```

## Notes

If two locales are both marked default via [Locale](Locale.md) and no
`DefaultLocale` is given, which one wins is undefined -- whichever
"default" is encountered first is used. Set `DefaultLocale` to remove the
ambiguity.

## See also

[Locale](Locale.md), [ExecutionLocale](ExecutionLocale.md), the
[internationalization](../guides/internationalization.md) guide.

## Source

Stored unparsed in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{DefaultLocale}` when the locale repository is finalized in
`lib/Vend/Config.pm`.
