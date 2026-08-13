# PerlAlwaysGlobal

Names the catalogs whose embedded Perl should always be compiled and run
globally -- outside the restricted `Safe` compartment -- even for tags that would
normally use the sandbox. Reach for it only for fully trusted catalogs that need
unrestricted Perl throughout.

**Scope:** global (`interchange.cfg`)

## Syntax

    PerlAlwaysGlobal  catalog ...

A whitespace- or comma-separated list of catalog names, each flagged on. The
directive accumulates across lines. Default: empty (no catalog forced global).

## Description

Interchange normally evaluates page-level Perl (`[calc]` and similar) inside a
restricted `Safe` compartment. When a catalog is flagged in `PerlAlwaysGlobal`,
`lib/Vend/Interpolate.pm` sets its per-request `$always_global` flag, so those
constructs are routed to the global [perl](../tags/perl.md) evaluator instead of
the sandboxed one:

```perl
$always_global = $Global::PerlAlwaysGlobal->{$Vend::Cat};
$loop_calc = $always_global ? sub { tag_perl('', {}, @_) } : \&tag_calc;
```

This differs from [AllowGlobal](AllowGlobal.md): `AllowGlobal` permits a catalog
to run global Perl when it explicitly asks (for example a `[perl global=1]`
block), whereas `PerlAlwaysGlobal` makes global the default for the catalog's
ordinary calc/loop Perl as well. A catalog listed here must also be trusted with
global Perl, so it is used together with [AllowGlobal](AllowGlobal.md).

## Examples

Force the admin catalog's Perl to run globally (in `interchange.cfg`):

```
AllowGlobal admin
PerlAlwaysGlobal admin
```

## Notes

This removes the sandbox for that catalog's page Perl, so its pages can read and
write any file the Interchange user can and alter the running server. Enable it
only for catalogs whose page source you fully control.

## See also

[AllowGlobal](AllowGlobal.md), [PerlNoStrict](PerlNoStrict.md),
[perl](../tags/perl.md), [SafeTrap](SafeTrap.md), [SafeUntrap](SafeUntrap.md),
the [perl-embedding](../guides/perl-embedding.md) and
[security](../guides/security.md) guides.

## Source

Parsed by `parse_boolean` in `lib/Vend/Config.pm`; consumed via
`$Global::PerlAlwaysGlobal` in `lib/Vend/Interpolate.pm`.
