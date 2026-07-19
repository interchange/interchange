# Member

Overrides the value of named catalog variables for logged-in users. Reach for
it to show members different text or settings than anonymous visitors without
changing any page code.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Member  NAME value

A variable name followed by its member value, parsed like
[Variable](Variable.md) (`parse_variable`). Repeat the directive to define
several member overrides. Default: empty.

## Description

`Member` populates a parallel set of variable values used only when a user is
logged in. It stores each `NAME`/`value` pair in `$Vend::Cfg->{Member}`. The
override is applied by the [var](../tags/var.md) tag: when a page requests a
variable, the tag returns the `Member` value if the session is logged in and a
member override exists for that name; otherwise it returns the ordinary
[Variable](Variable.md) value:

```perl
elsif ($Vend::Session->{logged_in} and defined $Vend::Cfg->{Member}{$key}) {
    $value = $Vend::Cfg->{Member}{$key};
}
```

The override therefore takes effect only through the [var](../tags/var.md) tag
(`[var NAME]`), not through the raw `__NAME__` interpolation form. A "logged-in"
user is one for whom `$Vend::Session->{logged_in}` is true, as set by the user
database login process.

## Examples

Show a different greeting to members. In `catalog.cfg`:

```
Variable GREETING Hello, Guest!
Member   GREETING Hello, Member!
```

On a page:

```
[var GREETING]
```

This renders `Hello, Guest!` for anonymous visitors and `Hello, Member!` once
the visitor is logged in.

## See also

[Variable](Variable.md), [var](../tags/var.md), [UserDB](UserDB.md), the
[user-database](../guides/user-database.md) and
[templating](../guides/templating.md) guides.

## Source

Parsed by `parse_variable` in `lib/Vend/Config.pm` (stored in
`$Vend::Cfg->{Member}`); consumed by the [var](../tags/var.md) tag in
`code/UserTag/var.tag`.
