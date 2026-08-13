# PerlNoStrict

Names the catalogs whose embedded Perl is compiled without `use strict`.
Reach for it only for trusted catalogs that run legacy `[perl]` or `[calc]`
code relying on unqualified global variables.

**Scope:** global (`interchange.cfg`)

## Syntax

    PerlNoStrict  catalog ...

A whitespace- or comma-separated list of catalog names. Each named catalog
is flagged, and the flag accumulates across multiple lines. Default: empty
(every catalog's Perl runs under `strict`).

## Description

When a catalog runs embedded Perl outside the restricted `Safe`
compartment -- which happens only for catalogs granted global permission
through [AllowGlobal](AllowGlobal.md) or [PerlAlwaysGlobal](PerlAlwaysGlobal.md)
-- Interchange normally evaluates the code with `use strict` in force. If
the catalog is listed in `PerlNoStrict`, that global code is instead
evaluated with `no strict`, so symbolic references and undeclared package
variables do not raise compile errors.

The flag is stored as `$Global::PerlNoStrict->{catalogname}` and checked in
`lib/Vend/Interpolate.pm` when the `[perl]`/`[calc]` body is compiled. It
has no effect on code that still runs inside `Safe`; strictness there is
governed by the compartment, not by this directive.

## Examples

Relax strictness for the admin catalog in `interchange.cfg`:

```
PerlNoStrict admin
```

## Notes

This directive only matters for catalogs already running Perl globally; on
a sandboxed catalog it does nothing. Prefer fixing code to satisfy
`strict` over disabling it -- turn strictness off only when you cannot
modify the offending pages.

## See also

[AllowGlobal](AllowGlobal.md), [PerlAlwaysGlobal](PerlAlwaysGlobal.md),
[GlobalSub](GlobalSub.md), the
[perl-embedding](../guides/perl-embedding.md) and
[security](../guides/security.md) guides.

## Source

Parsed by `parse_boolean` in `lib/Vend/Config.pm`; consumed via
`$Global::PerlNoStrict` in `lib/Vend/Interpolate.pm`.
