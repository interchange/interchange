# Profiles

Loads files of order- and search-profile definitions and makes them
available to every catalog on the server. Reach for it to share a common set
of form-validation profiles across all catalogs from `interchange.cfg`.

**Scope:** global (`interchange.cfg`)

> As a catalog directive, `Profiles` is an alias for
> [OrderProfile](OrderProfile.md), not this global directive. See the note
> below.

## Syntax

    Profiles  fileglob ...

A shell glob (or list of globs) naming profile files. Each file is read and
split on lines containing `__END__`; within each entry a `__NAME__ name` line
names the profile. Definitions accumulate. Default: empty.

## Description

An order profile is a named block of form-processing directives -- the rules
that validate and act on a submitted form. `Profiles` reads such blocks from
files and stores them globally, in the `$Global::Profiles` array indexed by
`$Global::ProfilesName`. When a form submission names a profile that the
catalog's own [OrderProfile](OrderProfile.md) does not define, the dispatcher
(`lib/Vend/Dispatch.pm`) falls back to these global profiles. This is how one
set of validation rules can be maintained once and reused by every catalog.

## Examples

Load a shared profile file in `interchange.cfg`:

```
Profiles etc/profiles.common
```

## Notes

`Profiles` is also a catalog-scope directive name, where it is an **alias**
for [OrderProfile](OrderProfile.md). In `catalog.cfg`, therefore, a
`Profiles` line defines that catalog's own order profiles -- as the strap
demo does:

```
Profiles include/profiles/*.*
```

The two are separate directives that happen to share a name: the global one
documented here populates the server-wide profile pool, while the catalog
alias populates one catalog's [OrderProfile](OrderProfile.md) list.

## See also

[OrderProfile](OrderProfile.md), [SearchProfile](SearchProfile.md),
[Profile](Profile.md), the [forms](../guides/forms.md) guide.

## Source

Parsed by `parse_profile` in `lib/Vend/Config.pm`; the global form stores
into `$Global::Profiles` / `$Global::ProfilesName` and is consumed in
`lib/Vend/Dispatch.pm`. The catalog-scope `Profiles` is registered as a
`DirectiveAlias` for `OrderProfile`.
