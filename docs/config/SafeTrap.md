# SafeTrap

Lists the Perl opcodes to *trap* (forbid) inside the `Safe` compartment
that Interchange uses to run embedded Perl and conditional expressions.
Reach for it to tighten what embedded Perl in your pages is allowed to do.

**Scope:** global (`interchange.cfg`)

## Syntax

    SafeTrap  OPCODE [OPCODE ...]

A whitespace/comma-separated list of opcode names or opcode-group tags
(`parse_array`), appended to the trap list. Individual opcodes (`rand`,
`ftfile`) and `Opcode` group tags (`:base_io`, `:filesys_read`) are both
accepted. Default: `:base_io`.

## Description

Interchange evaluates embedded Perl (the [calc](../tags/calc.md),
[calcn](../tags/calcn.md), and `[perl]` constructs, and conditional
expressions) inside a `Safe` compartment that restricts which operations
the code may perform. `SafeTrap` names operations to remove from the
permitted set, on top of `Safe`'s own restrictive defaults, making the
compartment stricter.

The trap list is applied when the Safe object is built, in
`lib/Vend/Interpolate.pm`, by calling the compartment's `trap` method with
these opcodes. `SafeTrap` is applied *before* [SafeUntrap](SafeUntrap.md);
because untrapping runs afterward and takes precedence, an opcode you trap
here can be re-enabled by a later `SafeUntrap` entry.

For the full set of opcode names and group tags, see the `Opcode(3perl)`
manual page.

## Examples

Forbid the `rand` opcode in embedded Perl:

```
SafeTrap rand
```

Trap a group of operations in addition to the default:

```
SafeTrap :subprocess
```

## Notes

The value accumulates: each `SafeTrap` line adds to the list rather than
replacing it. See the [security](../guides/security.md) guide and the
[safe](../glossary.md) glossary entry for background on programming under
`Safe` restrictions.

## See also

[SafeUntrap](SafeUntrap.md), [AllowGlobal](AllowGlobal.md),
[calc](../tags/calc.md), the [perl-embedding](../guides/perl-embedding.md)
and [security](../guides/security.md) guides.

## Source

Parsed by `parse_array` in `lib/Vend/Config.pm`; applied to the `Safe`
compartment in `lib/Vend/Interpolate.pm` (`$ready_safe->trap`).
