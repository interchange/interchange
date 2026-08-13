# WritePermission

Controls the write bits on files Interchange creates -- whether they are
writable only by the server's own user, by its group, or by everyone. Reach
for it when another account (a web server, a deploy user) in the same group
needs to write files Interchange generates.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    WritePermission  user|group|world

One of the three keywords `user`, `group`, or `world` (case-insensitive).
Any other value is a configuration error. Default: `user`.

## Description

By default, files Interchange writes (session files, counters, logs, and
other generated data) are writable only by the user account Interchange runs
as. `WritePermission` widens that:

- `user` -- only the Interchange user may write (the default, most secure).
- `group` -- members of the Interchange user's group may also write.
- `world` -- anyone may write (rarely appropriate).

The setting feeds into the file mode (umask) Interchange applies when
creating files. Pair it with [ReadPermission](ReadPermission.md) to control
the read bits the same way.

## Examples

Let others in the Interchange group read and write generated files (in
`catalog.cfg`):

```
ReadPermission   group
WritePermission  group
```

## Notes

Broadening write permission is a security trade-off: only widen it as far as
a genuine second account requires, and prefer `group` (with a tightly
controlled group) over `world`. The value validated here is `user`,
`group`, or `world` -- numeric modes are not accepted.

## See also

[ReadPermission](ReadPermission.md), [SetGroup](SetGroup.md), the
[security](../guides/security.md) guide.

## Source

Parsed by `parse_permission` in `lib/Vend/Config.pm`, which accepts only
`user`, `group`, or `world`.
