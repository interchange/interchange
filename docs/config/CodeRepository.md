# CodeRepository

Names a directory of system code (tags and [CodeDef](CodeDef.md) definitions)
that Interchange draws from on demand, compiling only the pieces a running
catalog actually uses. Reach for it, together with
[AccumulateCode](AccumulateCode.md), to trim the server's memory footprint
during development.

**Scope:** global (`interchange.cfg`)

## Syntax

    CodeRepository  directory_name

A single directory, made absolute against the Interchange root. Default: empty
(no repository; all code is loaded at startup).

## Description

Interchange ships a large body of system code -- built-in [UserTag](UserTag.md)
and [CodeDef](CodeDef.md) definitions -- most of which a given catalog never
uses. Loading all of it at startup enlarges every server process.

With [AccumulateCode](AccumulateCode.md) disabled, operation is traditional:
everything is loaded at startup and `CodeRepository` has no effect. The
directive becomes active when you remove the standard `code/` directory and
enable `AccumulateCode`. Interchange then looks in `CodeRepository` for missing
pieces (tags, action maps, filters, widgets, and so on) and compiles them as
they are needed at runtime. Compiled blocks are copied under
`$Global::TagDir/Accumulated/`, so that after the next restart they are read
normally and need not be recompiled on the fly.

## Examples

Enable on-demand loading from a code pool, in `interchange.cfg`:

```
AccumulateCode Yes
CodeRepository /usr/interchange/code.pool/
```

Prepare the pool from the standard code directory at the shell:

```sh
mkdir /usr/interchange/code.pool/
mv /usr/interchange/code/* /usr/interchange/code.pool/
```

## Notes

This is a development convenience, not a production feature. The first call to a
not-yet-compiled tag from within embedded Perl can fail (a consequence of the
`Safe` compartment); the failure clears once the master process compiles the
tag, within [HouseKeeping](HouseKeeping.md) seconds. Adding files to the
repository loads new code without a server restart.

The feature applies only to global code; catalog-based code is unaffected. It
is not intended for [PreFork](PreFork.md) mode, and some code directives
(notably order checks) are not fully supported. Defining more than one tag or
code block in a single repository file can lead to unpredictable behavior.

## See also

[AccumulateCode](AccumulateCode.md), [CodeDef](CodeDef.md),
[UserTag](UserTag.md), [AllowGlobal](AllowGlobal.md),
[HouseKeeping](HouseKeeping.md), the [performance](../guides/performance.md)
guide.

## Source

Parsed by `parse_root_dir` in `lib/Vend/Config.pm` (stored in
`$Global::CodeRepository`); scanned by `get_repos_code` in `lib/Vend/Config.pm`
when `AccumulateCode` is set.
