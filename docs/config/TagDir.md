# TagDir

Names the directories Interchange scans at startup for code-declaration files
-- tags, filters, widgets, order checks, action maps, and other `CodeDef`
definitions. Reach for it to add a directory of custom or third-party code
alongside the built-in `code` tree.

**Scope:** global (`interchange.cfg`)

## Syntax

    TagDir  directory ...

A shell-quoted list of directory names. Each directory is made absolute against
the Interchange root and appended to the search list, so multiple lines
accumulate. Default: `code`.

## Description

At startup Interchange walks every `TagDir` directory (with `File::Find`) and
reads the code-declaration files it finds, registering the tags, filters,
widgets, order checks, and other code they define. The first entry also serves
as the base directory when the configuration installs generated code. Grouping
of the discovered symbols is controlled by [TagGroup](TagGroup.md), and which of
them are actually compiled in is controlled by [TagInclude](TagInclude.md).

`TagDir` is read once, at server start; changing it requires a restart.

## Examples

Add a catalog-independent code directory to the default `code` tree
(in `interchange.cfg`):

```
TagDir  code  etc/other_code
```

## See also

[TagGroup](TagGroup.md), [TagInclude](TagInclude.md),
[CodeDef](CodeDef.md), [UserTag](UserTag.md), the
[configuration](../guides/configuration.md) guide.

## Source

Parsed by `parse_root_dir_array` in `lib/Vend/Config.pm`; consumed there via
`$Global::TagDir` during the code-scanning pass (`File::Find::find` over the
directories).
