# GlobalSub

Defines a named Perl subroutine, registered globally, that pages and other code
can call. Reach for it when a routine must run *outside* the `Safe` compartment
-- doing things (filesystem, network, arbitrary modules) that a catalog
[Sub](Sub.md) is forbidden to do.

**Scope:** global (`interchange.cfg`)

## Syntax

    GlobalSub  name  sub { ... }
    GlobalSub  name  Package::subname

Parsed as a subroutine definition. Two forms are accepted: an inline
`name sub { ... }` (the name may be given separately or taken from a named
`sub NAME {...}`), or a mapping of a name to an existing `Package::subname`.
Inline definitions are commonly written with here-document syntax. Default:
empty.

## Description

A `GlobalSub` becomes available by name to embedded Perl -- the
[perl](../tags/perl.md) tag, MVASP, and similar -- when the page lists it in the
tag's `subs` attribute, and to other Interchange facilities that call global
subroutines by name (jobs, cron targets, actions).

The defining subsystem is the global configuration parser. Unlike a catalog
[Sub](Sub.md), a `GlobalSub` runs with full Perl privileges: it is **not**
restricted by the `Safe` compartment and can do essentially anything the
Interchange process can. That power is the reason to prefer a catalog `Sub` or
scratch code whenever the task does not actually require it.

## Examples

Define a global subroutine in `interchange.cfg`:

```
GlobalSub <<EOF
sub count_orders {
    my $counter = new File::CounterFile "tmp/count_orders", '1';
    my $number  = $counter->inc();
    return "There have been $number orders placed.\n";
}
EOF
```

Call it from a page, naming it in the `subs` attribute:

```
[perl subs='count_orders']
    return count_orders();
[/perl]
```

A minimal single-line form, as shipped (commented context) in the distribution
`interchange.cfg`:

```
GlobalSub sub test_global_sub { return 'Test of global subroutine OK.' }
```

## Notes

As with any Perl here-document, the end marker (`EOF` or any name you choose)
must stand alone on its line with no surrounding whitespace, and the opening
marker takes no trailing semicolon.

Global subroutines bypass `Safe` security entirely, so keep them minimal and
trusted. A catalog may only reach global subs at all if it is permitted; see
[AllowGlobal](AllowGlobal.md).

## See also

[Sub](Sub.md), [AllowGlobal](AllowGlobal.md), [CodeDef](CodeDef.md),
[ActionMap](ActionMap.md), [HouseKeepingCron](HouseKeepingCron.md), the
[perl](../tags/perl.md) tag, the [perl-embedding](../guides/perl-embedding.md)
guide.

## Source

Parsed by `parse_subroutine` in `lib/Vend/Config.pm` (storing to
`$Global::GlobalSub`); invoked from `lib/Vend/Interpolate.pm` and other callers
that run global subroutines by name.
