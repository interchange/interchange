# calcn

Evaluate the body as Perl and return the result, **without** interpolating the
body first. Identical to [calc](calc.md) in every other way. Reach for it when
your Perl contains literal `[` characters or ITL-like text that must not be
expanded before the code runs.

## Syntax

    [calcn] EXPRESSION [/calcn]

Container tag (has an end tag). The body is passed to Perl as-is (no Interchange
Tag Language expansion) and evaluated; the value of the last expression is
returned.

## Attributes

None. `[calcn]` takes no attributes.

## Description

`[calcn]` shares its implementation with [calc](calc.md)
(`Vend::Interpolate::tag_calc`); the only difference is that `[calcn]` is *not*
declared `Interpolate`, so the body is handed to Perl exactly as written. All
other behavior — evaluation inside Interchange's `Safe` compartment, the
available globals (`$Tag`, `$Session`, `$Values`, `$CGI`, `$Scratch`,
`$Items`), variable persistence across blocks on a page, and error handling
through [try](try.md)/[catch](catch.md) — is the same.

See [calc](calc.md) for the full description.

## Examples

Because the body is not pre-interpolated, ITL-looking text passes through
untouched. With `[cgi test]` set to `TEST`:

    [cgi name=test set=TEST hide=1]
    [calcn] "[cgi test]" [/calcn]

returns the literal string `"[cgi test]"` — the inner tag is not expanded,
whereas `[calc]` would have produced `"TEST"`.

A plain calculation works exactly as in `[calc]`:

    [calcn] 3 * 14 [/calcn]

produces:

    42

## Notes

Reach for `[calcn]` whenever the Perl body legitimately contains `[` or `]`
(regexes, array indexing written awkwardly, literal ITL text) that `[calc]`
would misread as tag markup. You can also re-enable interpolation explicitly
with the `reparse` attribute where a page relies on it, but the default and
intended use is non-interpolated.

## See also

- [calc](calc.md)
- [perl](perl.md), [mvasp](mvasp.md)
- Concepts: [perl embedding](../guides/perl-embedding.md)

## Source

Defined in `code/SystemTag/calcn.coretag`. Implemented by
`Vend::Interpolate::tag_calc` (the same routine as [calc](calc.md), without the
`Interpolate` flag).
