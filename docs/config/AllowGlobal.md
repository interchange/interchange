# AllowGlobal

Names the catalogs that are allowed to run Perl with the full permissions
of the Interchange server, outside the restricted `Safe` compartment.
Reach for it only for catalogs you completely trust, such as the
administrative interface.

**Scope:** global (`interchange.cfg`)

## Syntax

    AllowGlobal  catalog ...

A whitespace- or comma-separated list of catalog names. Each named
catalog is flagged as trusted. The directive accumulates, so multiple
lines add to the set. Default: empty (no catalog is trusted with global
Perl).

## Description

Interchange normally runs embedded Perl (the `[perl]` tag, `[calc]`,
action code, and similar) inside a restricted `Safe` compartment that
blocks dangerous operations. When a catalog is listed in `AllowGlobal`,
its Perl instead runs unrestricted, with access to the full symbol table
and the operations `Safe` would otherwise trap.

The flag is stored as `$Global::AllowGlobal->{catalogname}` and checked
wherever Interchange decides whether to compile or evaluate code globally
or inside `Safe` -- for example in `lib/Vend/Interpolate.pm` (the `[perl]`
and `[mvasp]` tags), `lib/Vend/Config.pm` (action maps), and
`lib/Vend/Subs.pm` (global subroutine calls). It also gates whether a
catalog may use certain server-level features in `lib/Vend/Server.pm`.

## Examples

Trust the demo and admin catalogs in `interchange.cfg`:

```
AllowGlobal standard admin
```

## Notes

Granting global permission removes the sandbox: code in that catalog can
read and write any file the Interchange user can, run programs, and alter
the running server. Only enable it for catalogs whose page and
configuration source you control entirely.

`AdminSub` works alongside this directive: it restricts named global
subroutines so that only catalogs listed in `AllowGlobal` may call them.
`PerlNoStrict` and `PerlAlwaysGlobal` are related per-catalog flags that
further tune how a catalog's Perl is compiled.

## See also

[AdminSub](AdminSub.md), [PerlNoStrict](PerlNoStrict.md), [PerlAlwaysGlobal](PerlAlwaysGlobal.md), [SafeTrap](SafeTrap.md), [SafeUntrap](SafeUntrap.md),
[GlobalSub](GlobalSub.md), the [security](../guides/security.md) and
[perl-embedding](../guides/perl-embedding.md) guides.

## Source

Parsed by `parse_boolean` in `lib/Vend/Config.pm`; consumed via
`$Global::AllowGlobal` in `lib/Vend/Interpolate.pm`, `lib/Vend/Subs.pm`,
`lib/Vend/Config.pm`, and `lib/Vend/Server.pm`.
