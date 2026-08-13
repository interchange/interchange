# MV_DOLLAR_ZERO

Controls the base label the running Interchange process shows in the system
process list (`ps`, `top`). Reach for it to make a catalog's daemon
identifiable among several Interchange instances.

**Scope:** global (`interchange.cfg`)

## Syntax

    Variable  MV_DOLLAR_ZERO  value

The value sets the base process name:

- unset or `1` — use the base name `interchange`;
- any other string — use that string as the base name.

Default: `interchange`.

## Description

Interchange rewrites Perl's `$0` variable, which supplies the process name
shown by tools like `ps` and `top`. `set_process_name()` takes the base name
from `MV_DOLLAR_ZERO` and, when a status indicator is supplied, appends it as
`base: status`; otherwise the process name is just the base.

Setting the value to `1` is treated the same as leaving it unset — both yield
the base name `interchange` — for backward compatibility. Setting it to a
string makes that string the base name.

## Examples

Label this catalog's processes distinctly:

    Variable  MV_DOLLAR_ZERO  ic-storefront

The process list then shows entries such as `ic-storefront: ...` for the
running children.

## Notes

Prior to current releases, the historic documentation described a `1` value as
producing `interchange --> (CATROOT)` and mentioned a FreeBSD Perl startup bug.
The current code (`set_process_name` in `lib/Vend/Server.pm`) does not do this:
`1` is equivalent to unset, and the process name is formed as `base` or
`base: status`.

## Source

Consumed in `lib/Vend/Server.pm` (`set_process_name`) via
`$Global::Variable->{MV_DOLLAR_ZERO}`.
