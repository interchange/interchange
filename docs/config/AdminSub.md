# AdminSub

Restricts named global subroutines so that only trusted catalogs -- those
listed in the global `AllowGlobal` directive -- may call them. Reach for it
when you have powerful `GlobalSub` routines that should not be callable
from an ordinary catalog.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    AdminSub  subroutine_name ...

A whitespace- or comma-separated list of global subroutine names. Each
listed name is marked as restricted. The directive accumulates, so
multiple lines add to the set. Default: empty.

## Description

Interchange stores the listed names as keys of the hash
`$Vend::Cfg->{AdminSub}`. When a page tries to call a `GlobalSub`,
`lib/Vend/Subs.pm` checks that hash: if the subroutine is listed as an
admin sub and the current catalog is *not* listed in the global
`AllowGlobal` directive, the call is refused.

If `AdminSub` is unset, no such restriction applies and any global
subroutine may be called by any catalog (subject to the usual
`AllowGlobal`/`Safe` rules for global code).

## Examples

Restrict two sensitive global subs so only trusted catalogs may call them
(in `catalog.cfg`):

```
AdminSub dangerous1 dangerous2
```

The subs are usable from a catalog only if that catalog also appears in
`AllowGlobal` in `interchange.cfg`:

```
AllowGlobal admin
```

## Notes

This directive names the subroutines to protect; `AllowGlobal` names the
catalogs allowed past the protection. Use the two together: `AdminSub` in
each catalog that defines the restriction, `AllowGlobal` in
`interchange.cfg` for the catalogs you trust.

## See also

[AllowGlobal](AllowGlobal.md), [GlobalSub](GlobalSub.md), [Sub](Sub.md), the [security](../guides/security.md)
guide.

## Source

Parsed by `parse_boolean` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{AdminSub}` in `lib/Vend/Subs.pm` (and `lib/Vend/Parse.pm`,
`lib/Vend/Parser.pm` for the `calc` restriction).
