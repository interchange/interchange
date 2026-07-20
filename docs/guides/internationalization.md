# Internationalization and localization

One Interchange catalog can serve the same store in many languages,
currencies, and number formats at once — each visitor sees their own,
chosen per session or per page. This chapter shows how to define **locales**,
select the active one, translate interface text, format prices and numbers
for a region, overlay locale-specific database content, and handle non-ASCII
text with UTF-8. The individual pieces have reference pages —
[Locale](../config/Locale.md), [setlocale](../tags/setlocale.md),
[loc](../tags/loc.md), [currency](../tags/currency.md),
[MV_UTF8](../variables/MV_UTF8.md) — and this guide ties them together.

Localization in Interchange has four largely independent axes, and it helps
to keep them separate in your head:

1. **Message translation** — swapping interface strings ("Add to cart" →
   "In den Warenkorb") for the active language.
2. **Currency and number formatting** — decimal points, thousands
   separators, currency symbols, and conversion factors.
3. **Locale-driven directive changes** — pointing the catalog at a
   different page directory, image set, or product field per locale.
4. **Localized data** — serving a different `description` (or any column)
   from a per-locale overlay table.

All four are driven from the same construct — a named **locale** — and all
four honor the same active-locale selection. UTF-8 handling
([below](#utf-8-and-character-sets)) is orthogonal: it governs *bytes*, not
language, and you usually want it on regardless.

## What a locale is

A locale is a named hash of key/value settings stored in the catalog's
locale repository. The [Locale](../config/Locale.md) directive builds it:

    Locale  de_DE  mon_decimal_point "," mon_thousands_sep "." frac_digits 2

Repeat the directive with the same name to add more keys; the values
accumulate into one hash. The keys fall into three groups that map onto the
axes above:

- **Formatting keys** — POSIX-style names like `mon_decimal_point`,
  `mon_thousands_sep`, `currency_symbol`, `frac_digits`, plus Interchange's
  own `price_picture` and `PriceDivide`. These drive
  [currency](../tags/currency.md) and number rendering.
- **Directive keys** — names that match catalog directives (`PageDir`,
  `ImageDir`, `PriceField`, `DescriptionField`, `HTMLsuffix`, `SalesTax`,
  and more). When the locale becomes active, these values are copied into
  the running configuration.
- **Message keys** — an arbitrary source string as key, its translation as
  value. These drive `[L]`, [loc](../tags/loc.md), and
  [msg](../tags/msg.md).

When the locale name matches a real system locale, Interchange seeds the
formatting keys from the operating system's `POSIX::localeconv()` before
applying your overrides — so `Locale de_DE` starts with the platform's
German conventions and you only override what differs. This happens in
`parse_locale` (`lib/Vend/Config.pm`) at config time.

For a long list of message translations, use the here-document hash form
(valid Perl, evaluated in a [Safe](perl-embedding.md) compartment) — this
is exactly how strap's `catalog.cfg` adds a couple of messages to `en_US`:

    Locale en_US  <<EOL
    {
        "Username already exists (indirect).",
        "Sorry, that email is already associated with an account.",
    }
    EOL

### Global versus catalog locales

A `Locale` in `interchange.cfg` populates the **global** repository
(`$Global::Locale`), read once at server start and available as a base to
every catalog. A `Locale` in `catalog.cfg` populates the **catalog**
repository (`$Vend::Cfg->{Locale_repository}`). Message lookups check the
catalog locale first, then the global one, so a catalog can override
server-wide translations. See [Configuration](configuration.md) for the two
config levels generally.

### Loading locales from a database

Keeping hundreds of translations in `catalog.cfg` is unwieldy.
[LocaleDatabase](../config/LocaleDatabase.md) reads them from a table whose
columns are locales and whose rows are keys:

    Database        locale  locale.txt  TAB
    LocaleDatabase  locale

    code     en_US    de_DE           nl_NL
    About Us About Us "Über uns"      "Over ons"

Each column becomes one locale's set of key/value pairs, merged on top of
any inline `Locale` directives (database values win). strap ships exactly
this: a `locale` table (`products/locale.txt` in the distribution) with
hundreds of interface strings across `en_US`, `de_DE`, `fr_FR`, `nl_NL`,
`hr_HR`, and `sl_SI`. The table is read **once, at catalog configuration
time** — it is not consulted per request, so editing it requires a
[reconfig](configuration.md).

## Selecting the active locale

The active locale is whichever entry `Vend::Util::setlocale`
(`lib/Vend/Util.pm`) has copied into `$Vend::Cfg->{Locale}`. Three things
select it, from least to most dynamic:

**The catalog default.** [DefaultLocale](../config/DefaultLocale.md) names
the locale a session starts in. If you omit it, the *last* `Locale` defined
in `catalog.cfg` becomes the default (or any locale carrying a `default 1`
key). strap sets it from a Variable:

    DefaultLocale  __DEFAULT_LOCALE__

**The session.** Each session carries an `mv_locale` (and optional
`mv_currency`) [scratch](templating.md) value. On session creation it
defaults to `DefaultLocale`
(`$::Scratch->{mv_locale} ||= $Vend::Cfg->{DefaultLocale}`), and at the
start of every request a dispatch routine re-applies it with
`setlocale($mv_locale, $mv_currency, {persist => 1})`. Whatever `mv_locale`
holds is therefore the session's language for that request. An older
catalog convention set this default with a
[ScratchDefault](../config/ScratchDefault.md) instead —
`ScratchDefault mv_locale de_DE` — which still works;
[DefaultLocale](../config/DefaultLocale.md) is the cleaner modern form.

**Per page or per session, at runtime.** The
[setlocale](../tags/setlocale.md) tag switches locale from within a page:

    [setlocale de_DE]                              this page only
    [setlocale locale=fr_FR currency=fr_FR persist=1]   rest of session

With `persist=1` the choice is written back into `mv_locale`/`mv_currency`
so it carries to later pages; without it, the switch lasts only for the
current page's remaining interpolation. Calling `[setlocale]` with no
arguments reverts to the session default. Note the split between `locale`
(everything — language, formatting, directive keys) and `currency` (pricing
and currency keys only), which lets you display German text while pricing in
dollars. See the [setlocale reference](../tags/setlocale.md) for every
attribute.

A visitor-facing language switcher is usually just a set of persistent
`[setlocale]` links or a form posting `mv_locale`. There is also a legacy
URL form still recognized by the dispatcher:

    [page process/locale/fr_FR/page/index]

This sets `mv_locale` to `fr_FR` (persistently) and then displays `index`.
It works, but it is marked legacy in `lib/Vend/Dispatch.pm`; prefer
`[setlocale ... persist=1]`.

## Message translation

### `[L]` — compile-time string translation

The fastest translation construct is the bracket-**capital-L** markup:

    [L]Add to cart[/L]

When the page file is read in, `Vend::Util::parse_locale` scans it and
replaces each `[L]...[/L]` with the active locale's translation of the
enclosed text, falling back to the text itself when no translation exists.
So with the German locale active and a `de_DE` translation of "Add to cart"
defined, the reader sees the German; with an undefined key or no locale
active, they see "Add to cart" unchanged. The uppercase `L` is required
(chosen for fast scanning).

Because the message text is itself the lookup key, changing a single
character detaches the string from its translations. For long or volatile
text, give a stable key:

    [L cart_add]Add to cart[/L]

Now `cart_add` indexes the translation and the default text can be reworded
freely.

`[L]` is resolved **at page read-in time, before any tag runs.** Two
consequences follow:

- You cannot translate a string that contains other tags — the tags have
  not run yet. `[L]You have [nitems] items[/L]` will try to translate the
  literal string `You have [nitems] items`. Use [loc](../tags/loc.md) for
  that (below).
- A `[setlocale]` **on the same page** does not re-translate that page's
  `[L]` blocks; they were already substituted using the locale that was
  active when the file was read.

`[LC]` is a companion that inlines several languages in the page source and
picks the block for the current locale:

    [LC]
      Default text.
      [de_DE]Voreingestellter Text.[/de_DE]
      [nl_NL]Standaardtekst.[/nl_NL]
    [/LC]

The block matching the session's `mv_locale` (or `DefaultLocale`) is kept;
if none matches, the leading default text is used. Like `[L]`, this is
resolved at read-in time.

### `[loc]` / `[l]` — runtime translation

[loc](../tags/loc.md) (and its alias [l](../tags/l.md)) does the same
lookup as `[L]`, but as a real tag that runs *after* the rest of the page
has interpolated. That is the whole reason it exists: its body can contain
other tags.

    [loc]Add to cart[/loc]
    [loc]Welcome back, [value fname][/loc]

The body is interpolated first, then the resulting text is looked up in the
active locale's message table (or a named locale: `[loc fr_FR]Checkout[/loc]`).
Missing keys return the source text, exactly like `[L]`. The same
"the-text-is-the-key" caution applies. Under the
[no_locale_parse](../pragmas/no_locale_parse.md) pragma, `[loc]` defers
translation by re-emitting the equivalent `[L]` markup instead of
translating.

### `[msg]` — key-first messages with arguments

[msg](../tags/msg.md) is the message tag built for `sprintf`-style
placeholders and an explicit key. It is the current replacement for the old
`[locale key]...[/locale]` construct (which no longer exists):

    [msg key=cart_add]Add to cart[/msg]
    [msg arg="3"]You have %s items in your cart[/msg]

`[msg]` looks the key (or, absent a key, the message text) up in the
catalog locale, then the global locale, and applies any `arg` values
through `sprintf`. It can also switch locale for its body via `locale=`.

### Translation from Perl: `errmsg` / `l`

Inside [embedded Perl](perl-embedding.md) and throughout the Interchange
core, the `errmsg` function (exported also as `l`) is the programmatic
equivalent:

    $Tag->msg(...);                      # from tags
    my $s = errmsg("Order number %s not found", $order);   # from Perl

`errmsg` checks the catalog locale, then the global locale, then applies
`sprintf`. Interchange's own error and status messages all pass through it,
which is why translating a catalog's built-in messages is a matter of adding
the English source strings as keys to your target locale.

### Generating translation files

The distribution ships a `scripts/localize` utility. Point it at a set of
pages and it extracts the `[L]` strings into a locale file you can hand to a
translator, merging new strings into an existing translation on re-runs. Run
`scripts/localize` with no arguments for its usage.

## Currency and number formatting

Prices are formatted by `Vend::Util::currency`, reached through the
[currency](../tags/currency.md) tag and used automatically by
[price](../tags/price.md), `[item-price]`, and friends. Formatting is driven
entirely by the active locale's keys.

    [currency]8.99[/currency]

Under `en_US` (`mon_decimal_point .`, `mon_thousands_sep ,`,
`currency_symbol $`, `frac_digits 2`) that yields:

    $8.99

Under a German locale with `mon_decimal_point ,` and
`mon_thousands_sep .`, the same input renders as `8,99`. The keys
Interchange honors are the POSIX set:

| Key | Controls |
|-----|----------|
| `mon_decimal_point` (or `decimal_point`) | decimal separator |
| `mon_thousands_sep` (or `thousands_sep`) | grouping separator |
| `currency_symbol` | symbol for `display=symbol` (the default) |
| `int_currency_symbol` | symbol for `display=text` |
| `frac_digits` | digits after the decimal |
| `p_cs_precedes` / `p_sep_by_space` | symbol placement and spacing |

Whether the thousands separator is applied at all is gated by the
[PriceCommas](../config/Locale.md) locale key (on by default). Two keys
beyond POSIX give explicit control:

- **`price_picture`** — a template that fixes the layout exactly, e.g.
  `"$ ###,###,###.##"`, which renders `4452.3` as `$ 4,452.30`. When a
  picture is set, `frac_digits` is ignored (precision comes from the
  `#`s after the point) and the picture's own separators must match
  `mon_decimal_point`/`mon_thousands_sep`. Overflow digits become
  asterisks.
- **`picture`** — same idea, but for the value shown when the
  `[currency]` tag is *not* used.

### Currency conversion with PriceDivide

[PriceDivide](../config/PriceDivide.md) is a per-locale divisor applied to
raw prices before formatting — the mechanism both for penny-pricing (store
prices as integer cents, `PriceDivide 100`) and for locale conversion:

    Locale  en_US  PriceDivide  1
    Locale  gbp    PriceDivide  1.27   # store in USD, show in GBP

The [currency](../tags/currency.md) tag's `convert` argument and a
`locale=` option let you convert a single amount on demand without
switching the whole session. Because conversion is a static divisor, it is
suitable for stable exchange relationships, not live foreign-exchange rates.

### Pricing in one currency, displaying in another

Because `[setlocale currency=...]` changes only the pricing/currency keys,
you can show one page priced two ways:

    Dollar pricing:
    [setlocale en_US]
    [item-list][item-code]: [item-price]<br>[/item-list]

    Euro pricing:
    [setlocale locale=de_DE currency=de_DE]
    [item-list][item-code]: [item-price]<br>[/item-list]

    [comment]back to the session default[/comment]
    [setlocale]

Under the hood the locale keys that affect pricing —
[PriceField](../config/PriceField.md),
`PriceDivide`, `PriceCommas`, `SalesTax`,
`TaxShipping` — are all locale-switchable, so a locale change can select a
different price column, tax rule, and format together.

### A note on the process locale

The daemon runs under a fixed base system locale set by
[ExecutionLocale](../config/ExecutionLocale.md) (default `C`), re-applied at
the start of each request. Interchange deliberately does its own numeric
formatting with `sprintf` under a `C` `LC_NUMERIC` (see `safe_sprintf` in
`lib/Vend/Util.pm`) so that a system locale set for collation or messages
cannot corrupt the machine-readable decimal points in prices and totals.
Only `LC_COLLATE`, `LC_CTYPE`, and `LC_TIME` are pushed into the OS when a
locale carries those keys.

## Locale-driven directive changes

Setting a locale key whose name matches a catalog directive makes that
directive change when the locale activates. This is the classic way to swap
whole page sets or asset directories per language:

    # startup defaults
    PageDir    pages
    ImageDir   /images/en/

    Locale  fr_FR  PageDir   pages_fr
    Locale  fr_FR  ImageDir  /images/fr/

Now selecting `fr_FR` serves French pages and French button images without
touching any page markup. The scalar directives that can be set this way are
listed in `@Locale_directives_scalar` (`lib/Vend/Config.pm`) and include
`PageDir`, `SpecialPageDir`, `ImageDir`, `ImageDirSecure`, `HTMLsuffix`,
`PriceField`, `DescriptionField`, `CategoryField`, `SalesTax`,
`TaxShipping`, and `CommonAdjust`.

### Locale-suffixed page files

The [HTMLsuffix](../config/HTMLsuffix.md) key hooks the page lookup itself.
Set it per locale and the page reader tries a locale-specific file first:

    Locale  fr_FR  HTMLsuffix  .fr_FR

With `fr_FR` active, a request for `index` looks for `pages/index.fr_FR`
before falling back to `pages/index.html`. This is a lightweight way to have
a few fully hand-translated pages alongside a mostly-shared set.

## Localized database content

The directive-key approach handles *which column* to read — set
[DescriptionField](../config/DescriptionField.md) or
[PriceField](../config/PriceField.md) per locale to read `desc_fr` instead
of `description`, or `prix` instead of `price`. This still works and is the
lightest option when one alternate column per locale suffices.

The modern strap demo uses a more capable mechanism:
[Vend::Table::Shadow](databases.md) plus per-locale overlay tables selected
by `mv_locale`. A **shadow** table wraps a real table and, for mapped
columns, transparently reads the value from a locale-specific table
instead. strap wires it up in `dbconf/locales/default.cfg`:

    Database products MAP_OPTIONS share __CURLOCALE__ products___CURLOCALE__
    Database products MAP description __CURLOCALE__ products___CURLOCALE__::description
    Database products MAP description fallback 1

Expanded for `de_DE` (`__CURLOCALE__` is `de_DE`), this tells the `products`
table: for the `description` column, when the active locale is `de_DE`, read
`description` from the `products_de_DE` table keyed by the same SKU; if that
value is empty, `fallback 1` returns the original English. The overlay table
`products_de_DE.txt` is a parallel file with the same keys and the
translated columns. `MAP_OPTIONS share` extends the same overlay to
searches and listings.

The important detail: the shadow layer resolves the locale from
`$::Scratch->{mv_locale}` (falling back to `DefaultLocale`) at access time —
so it tracks the **persistent session locale**, not a transient per-page
`[setlocale]`. A `[data products description os28005]` therefore returns the
German description whenever the session's `mv_locale` is `de_DE`, with no
markup change:

    [data products description os28005]

strap applies the same pattern to its `options` table. Because the overlay
is an ordinary Interchange table, its contents *can* be edited without a
reconfig (unlike [LocaleDatabase](../config/LocaleDatabase.md), which is
read once at startup).

> **Historic note.** The 2004-era I18N documentation described localized
> data purely through per-locale `PriceField`/`DescriptionField` keys; the
> shadow-table `MAP` mechanism postdates it and is what current strap ships.
> Both work; choose the shadow tables when you need several localized
> columns with fallback.

## Sorting

Interchange's `[sort table:field]` collation uses the operating system's
`LC_COLLATE` when the active locale defines it, so accented and non-Latin
characters sort in their language's order rather than raw byte order. This
requires that the host OS actually has the locale's collation definitions
installed and that the locale name matches a system locale. Interchange
pushes `LC_COLLATE` (and `LC_CTYPE`, `LC_TIME`) into POSIX in `setlocale`
only when the locale hash carries those keys. If the definitions are missing
on the platform, sorting silently falls back to the `C` byte order.

## UTF-8 and character sets

Language and *encoding* are separate concerns. A German locale tells
Interchange how to translate and format; UTF-8 tells it how to read and
write the *bytes* of non-ASCII text. Any catalog storing or serving
characters outside ASCII wants UTF-8 on. This is a modern addition with no
counterpart in the historic I18N docs.

Turn it on with a single Variable, globally or per catalog — strap sets both:

    Variable  MV_UTF8          1
    Variable  MV_HTTP_CHARSET  UTF-8

[MV_UTF8](../variables/MV_UTF8.md) makes Interchange apply a `:utf8` layer
when reading pages and when importing/exporting database files, so
multi-byte characters are handled as characters, not bytes. It is checked in
both the catalog and global variable space
(`$::Variable->{MV_UTF8} || $Global::Variable->{MV_UTF8}`), so a single
global setting covers the whole server. UTF-8 support depends on Perl's
`Encode` module; the `MINIVEND_DISABLE_UTF8` environment variable installs
pass-through stubs when it is unavailable (`lib/Vend/CharSet.pm`).

[MV_HTTP_CHARSET](../variables/MV_HTTP_CHARSET.md) sets the charset declared
on HTTP responses (and is the default used when decoding incoming
form data). `Vend::CharSet` provides the decode helpers —
`decode_urlencode` and `to_internal` normalize incoming URL-encoded and form
data to Interchange's internal representation when `$Global::UTF8` is on. For
outbound email, [MV_EMAIL_CHARSET](../variables/MV_EMAIL_CHARSET.md) plays
the same role as `MV_HTTP_CHARSET` does for pages.

A practical checklist for a UTF-8 catalog:

- `Variable MV_UTF8 1` and `Variable MV_HTTP_CHARSET UTF-8` in config.
- Page files, `*.txt` database sources, and template components saved as
  UTF-8 without a BOM.
- Database backends (MySQL/PostgreSQL) configured for a UTF-8 connection and
  storage — Interchange's layer handles its file I/O, but the DBI connection
  and column collation are the backend's responsibility.

## Putting it together: a two-language storefront

A minimal recipe for adding German to an English catalog:

1. **Define the locale and its messages** — add a `de_DE` column to your
   [LocaleDatabase](../config/LocaleDatabase.md) table (or `Locale de_DE`
   directives) with translations of your interface strings.
2. **Make it selectable** — leave `en_US` as
   [DefaultLocale](../config/DefaultLocale.md); offer a switcher of
   `[setlocale locale=de_DE persist=1]` / `[setlocale locale=en_US persist=1]` links.
3. **Format prices** — give `de_DE` its `mon_decimal_point`,
   `mon_thousands_sep`, `currency_symbol`, and (if converting) `PriceDivide`.
4. **Translate content** — for interface text, wrap it in
   [loc](../tags/loc.md) or `[L]`; for product descriptions, add a
   `products_de_DE` overlay table via the shadow `MAP` directives.
5. **Turn on UTF-8** — `Variable MV_UTF8 1`, `Variable MV_HTTP_CHARSET
   UTF-8`, and save everything as UTF-8.

Every string the visitor sees then flows from the one `mv_locale` value,
which your switcher controls.

## See also

- [Locale](../config/Locale.md),
  [LocaleDatabase](../config/LocaleDatabase.md),
  [DefaultLocale](../config/DefaultLocale.md),
  [ExecutionLocale](../config/ExecutionLocale.md) — the directives
- [setlocale](../tags/setlocale.md), [loc](../tags/loc.md),
  [l](../tags/l.md), [msg](../tags/msg.md), [currency](../tags/currency.md)
  — the tags
- [MV_UTF8](../variables/MV_UTF8.md),
  [MV_HTTP_CHARSET](../variables/MV_HTTP_CHARSET.md),
  [MV_EMAIL_CHARSET](../variables/MV_EMAIL_CHARSET.md) — encoding
- [no_locale_parse](../pragmas/no_locale_parse.md) — defer `[L]`/`[loc]`
  translation
- [Configuration](configuration.md), [Templating](templating.md),
  [Databases](databases.md), [Pricing](pricing.md),
  [Embedded Perl](perl-embedding.md) — related guides
</content>
</invoke>
