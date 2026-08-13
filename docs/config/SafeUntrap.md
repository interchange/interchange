# SafeUntrap

Lists the Perl opcodes to *untrap* (re-enable) inside the `Safe` compartment
that Interchange uses to run embedded Perl and conditional expressions.
Reach for it when trusted embedded Perl needs an operation that the default
`Safe` restrictions forbid.

**Scope:** global (`interchange.cfg`)

## Syntax

    SafeUntrap  OPCODE [OPCODE ...]

A whitespace/comma-separated list of opcode names or opcode-group tags
(`parse_array`), appended to the untrap list. Individual opcodes (`ftfile`,
`ftsize`, `sort`) and `Opcode` group tags (`:filesys_read`) are both
accepted. Set it blank to allow nothing beyond `Safe`'s restrictive
defaults. Default: `ftfile sort`.

## Description

Interchange evaluates embedded Perl (the [calc](../tags/calc.md),
[calcn](../tags/calcn.md), and `[perl]` constructs, and conditional
expressions) inside a `Safe` compartment. By default `Safe` denies many
operations; `SafeUntrap` names operations to add back so trusted embedded
Perl can use them.

The untrap list is applied when the Safe object is built, in
`lib/Vend/Interpolate.pm`, by calling the compartment's `untrap` method.
`SafeUntrap` runs *after* [SafeTrap](SafeTrap.md) and takes precedence, so
an opcode listed here overrides a matching `SafeTrap` entry.

For the full set of opcode names and group tags, see the `Opcode(3perl)`
manual page.

## Examples

Allow the `-s` file-size operator (opcode `ftsize`) so code like the
following works:

```
SafeUntrap ftsize
```

```
[set upload_repository]upload/[/set]
[calcn]-s $Scratch->{upload_repository};[/calcn]
```

Allow a whole group of read-only filesystem operations, so tests such as
`-r` succeed:

```
SafeUntrap :filesys_read
```

Restrict to the most restrictive defaults by untrapping nothing:

```
SafeUntrap
```

## Notes

The value accumulates across lines. Every opcode you untrap widens what
embedded Perl can do, so untrap only what your pages genuinely need. See
the [security](../guides/security.md) guide and the [safe](../glossary.md)
glossary entry for background.

## See also

[SafeTrap](SafeTrap.md), [AllowGlobal](AllowGlobal.md),
[calc](../tags/calc.md), the [perl-embedding](../guides/perl-embedding.md)
and [security](../guides/security.md) guides.

## Source

Parsed by `parse_array` in `lib/Vend/Config.pm`; applied to the `Safe`
compartment in `lib/Vend/Interpolate.pm` (`$ready_safe->untrap`).
