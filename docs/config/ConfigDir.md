# ConfigDir

Sets the default directory searched for files referenced with the `<file`
notation in configuration files. Reach for it to control where directive
values loaded from external files are read from.

**Scope:** both (`interchange.cfg` global, `catalog.cfg` catalog)

## Syntax

    ConfigDir  directory_name

A single directory name. At catalog scope it is relative to the catalog root
(absolute not allowed); at global scope it is stored as given. Defaults:
`config` (catalog scope), `etc/lib` (global scope).

## Description

Interchange lets a directive take its value from a file by writing `<filename`
after the directive name. When the referenced file has a relative path,
`ConfigDir` is the directory searched for it (the current directory is tried as
a fallback). Because directives take effect immediately as the config file is
read, `ConfigDir` can be redefined multiple times to draw different values from
different directories.

The global and catalog values feed the same file-reading code; the global value
applies while reading `interchange.cfg`, the catalog value while reading a
catalog's configuration.

Do not confuse `ConfigDir` with the similarly named [ConfDir](ConfDir.md) (the
catalog's `etc/` control directory) or [DirConfig](DirConfig.md) (which loads a
directory of files into a directive hash).

## Examples

Point the include directory at `variables/`, then read a directive's value from
a file in it (in `catalog.cfg`):

```
ConfigDir variables
MailOrderTo <mailorderto
```

This reads the value of [MailOrderTo](MailOrderTo.md) from
`variables/mailorderto` (relative to the catalog root).

## See also

[ConfDir](ConfDir.md), [DirConfig](DirConfig.md),
[ParseVariables](ParseVariables.md), the
[configuration](../guides/configuration.md) guide.

## Source

At catalog scope, parsed by `parse_relative_dir` in `lib/Vend/Config.pm`; at
global scope, stored as a raw string. Consumed by the `<file` value-reading
logic in `lib/Vend/Config.pm`.
