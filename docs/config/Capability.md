# Capability

Tests for the presence of a global subroutine, tag, Perl module, file, or
executable at startup and quietly records the result, without warning or
aborting if the item is missing. Reach for it to load an optional module when
available and let your code adapt to whatever is present.

**Scope:** global (`interchange.cfg`)

## Syntax

    Capability  type  item ...

`type` is one of:

- `globalsub` -- a defined [GlobalSub](GlobalSub.md) exists
- `sub` -- a defined `Sub` exists
- `taggroup` -- a defined [TagGroup](TagGroup.md) exists
- `usertag` -- a defined [UserTag](UserTag.md) exists
- `module` (or `perlmodule`) -- a Perl module can be loaded
- `include` (or `perlinclude`) -- prepend a path to Perl's `@INC`
- `file` -- a readable file exists
- `executable` -- an executable file exists

An optional `/path` (for `module`, `include`, or `file`) and an optional
quoted `"message"` may follow. Default: empty (no capabilities tested).

## Description

`Capability` uses the same detection logic as [Require](Require.md) and
[Suggest](Suggest.md), but takes neither of their actions: where `Require`
aborts the daemon and `Suggest` logs a warning when the item is absent,
`Capability` stays silent. It exists so a catalog or module can probe for an
optional dependency at configuration time and let page code branch on the
result later.

It is evaluated once, while the configuration file is read at startup. As with
`include`/`perlinclude`, using `Capability` to add a directory to `@INC` works
but makes little sense -- reach for `Require` when the point is to make the
path available.

## Examples

Test for a range of items in `interchange.cfg`:

```
Capability globalsub my_global_sub
Capability sub       my_sub
Capability taggroup  :group1,:group2 :group3
Capability usertag   my_global_usertag
Capability module    Archive::Zip
Capability module    Set::Crontab /usr/local/perl/modules/
Capability file      /etc/syslog.conf
Capability executable bin/gfont
```

Probe for an old-style `.pl` Perl library:

```
Capability module /path/to/module.pl
```

## Notes

The `include`/`perlinclude` and `module` checks against a real `require`
happen only when the code is trusted with global Perl (the catalog is listed in
[AllowGlobal](AllowGlobal.md)); otherwise the module test falls back to
looking for a readable module file on `@INC`.

## See also

[Require](Require.md), [Suggest](Suggest.md), [GlobalSub](GlobalSub.md),
[UserTag](UserTag.md), [TagGroup](TagGroup.md), the
[configuration](../guides/configuration.md) guide.

## Source

Parsed by `parse_capability` in `lib/Vend/Config.pm`, which delegates to
`parse_require` with the capability flag set (so no warning or abort is
issued).
