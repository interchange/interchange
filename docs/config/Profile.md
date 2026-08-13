# Profile

Defines a named set of directive overrides that can be switched on at
runtime with the [profile](../tags/profile.md) tag. Reach for it to swap
groups of catalog settings -- most often pricing directives -- based on who
is shopping.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Profile  name  key value [key value ...]
    Profile  name  { perl-hashref }
    Profile  name <<EOR
    { perl-hashref }
    EOR

The value uses the same syntax as [Locale](Locale.md): a profile `name`
followed either by shell-quoted `key value` pairs or by a Perl hash
reference in braces. Each `key` is a directive name whose value the profile
should set. Definitions accumulate into the profile repository, so several
`Profile` lines can build up (or extend) one named profile. Default: empty.

## Description

Each named profile is stored in `$Vend::Cfg->{Profile_repository}`. It does
nothing until it is activated: the [profile](../tags/profile.md) tag, run
with the profile name, copies the profile's keys into the live
`$Vend::Cfg` for the current request (in `lib/Vend/Interpolate.pm`), so the
listed directives temporarily take the profile's values. This lets a
catalog present one price basis to ordinary visitors and another to, say,
logged-in dealers, without duplicating pages.

This directive is distinct from the file-based order and search profiles set
by [OrderProfile](OrderProfile.md) and [SearchProfile](SearchProfile.md); it
uses the inline locale-style syntax rather than pointing at profile files.

## Examples

The strap demo defines pricing profiles for dealers and distributors, plus a
default, in `catalog.cfg`:

```
Profile dealer <<EOR
{
    CommonAdjust => <<EOF,

        pricing:w5,w10:,
        ;:wholesale,
        ;:wholesale:mv_sku,
        ;$,
        ==:options
EOF
    NonTaxableField => 'nontaxable',
}
EOR

Profile default CommonAdjust   "pricing:q5,q10 ;:sale_price, ;:price, ;$, :related, ==:options"
Profile default NonTaxableField
Profile default PriceField 0
```

The `default` profile above shows the `key value` form; the `dealer`
profile shows the hash-reference form.

## Notes

The keys in a profile are directive names, and only directives already
present in `$Vend::Cfg` are affected when the profile is applied.

## See also

[profile](../tags/profile.md), [OrderProfile](OrderProfile.md),
[SearchProfile](SearchProfile.md), [Profiles](Profiles.md),
[CommonAdjust](CommonAdjust.md), the [pricing](../guides/pricing.md) guide.

## Source

Parsed by `parse_locale` in `lib/Vend/Config.pm` (stored in
`Profile_repository`); consumed via `$Vend::Cfg->{Profile_repository}` and
`$Vend::Cfg->{Profile}` in `lib/Vend/Interpolate.pm`.
