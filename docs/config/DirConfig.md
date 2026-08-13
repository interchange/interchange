# DirConfig

Populates a hash-valued directive (usually [Variable](Variable.md)) from a
directory of files, using each file's name as the key and its contents as
the value. Reach for it to keep large or numerous variable values in their
own files instead of inline in `catalog.cfg`.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    DirConfig  directive_name  directory_glob

Parsed by `parse_dirconfig`. The first token is the target directive --
any hash-based directive, most commonly `Variable`. The rest is a glob
that may match several directories (plain files in the glob are ignored).
Default: empty.

## Description

Interchange reads each named directory and, for every file whose name is
made up only of word characters (a valid [Variable](Variable.md) name),
sets the target directive's key of that name to the file's contents:

```perl
my @files = grep /^\w+$/, readdir(DIRCONFIG);
for(@files) {
    $ref->{$_} = readfile("$dir/$_", ...);
}
```

Files whose names contain non-word characters (backup files and the like)
are skipped, so editor leftovers do not become variables. When
[ParseVariables](ParseVariables.md) is on, the file contents are run
through variable substitution as they are read.

For each key, the source file path is recorded in
`$Vend::Cfg->{DirConfig}{directive}{KEY}`. With the
[dynamic_variables](../pragmas/dynamic_variables.md) pragma set,
Interchange re-reads a variable's file on demand rather than only at
configuration time, so edits to the file take effect without a restart.

## Examples

Load region templates as variables from a directory:

```
DirConfig Variable templates/foundation/regions
```

If the file `NOLEFT_TOP` exists there at configuration time, then
`__NOLEFT_TOP__` on a page yields that file's contents -- the same result
as `[include templates/foundation/regions/NOLEFT_TOP]`.

## Notes

Do not confuse `DirConfig` with the similarly named directory directives
[ConfDir](ConfDir.md) and [ConfigDir](ConfigDir.md); `DirConfig` loads
files *into* a directive's hash, it does not set a working directory.

## See also

[Variable](Variable.md), [VariableDatabase](VariableDatabase.md),
[ParseVariables](ParseVariables.md),
[dynamic_variables](../pragmas/dynamic_variables.md), the
[configuration](../guides/configuration.md) guide.

## Source

Parsed by `parse_dirconfig` in `lib/Vend/Config.pm`; the resulting hash is
consumed via `$Vend::Cfg->{<directive>}` (for example
`$Vend::Cfg->{Variable}`) wherever that directive's values are used.
