# msg

Return a localized message for a key, with optional `%s`-style argument
substitution. Reach for it to emit translatable text driven by the active
[locale](../guides/internationalization.md).

## Syntax

    [msg]Default English text[/msg]
    [msg key]Default text[/msg]
    [msg arg.0="Jan"]Hello, %s[/msg]
    [msg locale=de_DE]Default text[/msg]

Container tag. The body is interpolated by default (the `Interpolate` flag
is set).

## Attributes

| Attribute | Default | Description |
|-----------|---------|-------------|
| `key`     | (body)  | Locale key to look up; when set and found, its value replaces the body as the message. |
| `arg`     | (none)  | Argument(s) substituted for `%s`/`%N$s` placeholders. Accepts `arg.0=`, `arg.1=`, … (assembled in order), a single value, or an arrayref/hashref. |
| `locale`  | current | Temporarily switch to this locale for the lookup. |
| `inline`  | off     | Treat the body as an inline `[L]...[/L]`-style locale bit and resolve it. |
| `raw`     | off     | Return the message without running `errmsg`/argument substitution. |

Positional order: `key`.
Alias: `lc` for `inline`.

## Description

`[msg]` produces a translated string. The message text comes from the body
unless a `key` is given and that key is found in the catalog `Locale` table
(or the global locale), in which case the keyed translation is used instead.
The resulting text is then passed through Interchange's `errmsg` routine,
which substitutes any `%s` (or positional `%1$s`, `%2$s` …) placeholders
with the `arg` values you supply and applies the active locale's
translation of the string.

Supply arguments with numbered `arg.N` attributes — they are collected in
numeric order — or as a single `arg` value. With `locale=`, the tag switches
to the named locale just for this lookup (saving and restoring the session
`mv_locale`), so you can force one message into a specific language without
affecting the rest of the page.

`raw=1` skips `errmsg` entirely and returns the message unchanged, useful
when the text itself contains literal `%` characters.

## Examples

A simple translatable string (returns the body, translated if the active
locale defines it):

    [msg]Your order has been received.[/msg]

Substitute an argument into a placeholder:

    [msg arg.0="[value fname]"]Welcome back, %s![/msg]

produces, with `fname` set to `Sarah`:

    Welcome back, Sarah!

Force a specific locale for one message:

    [msg locale=fr_FR]Thank you[/msg]

## See also

- [loc](loc.md) — localize a body that contains other tags
- [setlocale](setlocale.md) — switch the active locale for the page
- [internationalization](../guides/internationalization.md)

## Source

Defined in `code/SystemTag/msg.coretag` (inline `Routine`). Uses
`Vend::Util::find_locale_bit` and `errmsg` (`lib/Vend/Util.pm`).
