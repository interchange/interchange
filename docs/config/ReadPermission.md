# ReadPermission

Sets who may read the files Interchange creates -- the read side of the
umask it applies to generated session, cache, and data files. Reach for it
(together with [WritePermission](WritePermission.md)) when another account,
such as the web server user, must read Interchange's files.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    ReadPermission  user | group | world

One of the three words `user`, `group`, or `world` (`parse_permission`);
any other value raises a configuration error. Default: `user`.

## Description

Interchange combines `ReadPermission` and
[WritePermission](WritePermission.md) into a file creation mask and umask
that it applies when writing files it generates. `ReadPermission` controls
the read bits:

| Value   | Files readable by           |
|---------|-----------------------------|
| `user`  | the Interchange user only   |
| `group` | user and group              |
| `world` | everyone                    |

With the default of `user`, only the account Interchange runs under can
read the files it creates. Setting `group` adds the group read bit so a
web server or admin account in the same group can read cached and session
files; `world` makes them readable by any account on the host.

The value is turned into the file mode and umask in
`lib/Vend/Dispatch.pm` (`set_file_permissions`), which stores
`$Vend::Cfg->{FileCreationMask}` and `$Vend::Cfg->{Umask}`.

## Examples

Let the group (for example, the web server's group) read Interchange's
files:

```
ReadPermission  group
WritePermission group
```

## Notes

Grant no more access than a task requires; `world` exposes session files,
which can contain sensitive customer data, to every account on the server.

## See also

[WritePermission](WritePermission.md), [SetGroup](SetGroup.md), the
[security](../guides/security.md) guide.

## Source

Parsed by `parse_permission` in `lib/Vend/Config.pm`; applied in
`lib/Vend/Dispatch.pm` (`set_file_permissions`).
