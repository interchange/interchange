# LockoutCommand

Specifies a shell command Interchange runs to lock out a client that has
tripped robot/abuse detection. Reach for it to push a misbehaving IP
address into a firewall or web-server denylist at the OS level.

**Scope:** global (`interchange.cfg`)

## Syntax

    LockoutCommand  COMMAND

The command line stored verbatim (no parser). The first `%s` is replaced
with the offending IP address; if there is no `%s`, the address is appended
to the command. Default: empty (no command run).

## Description

When a session exceeds the robot access limit
([RobotLimit](RobotLimit.md)) or the order line limit
([OrderLineLimit](OrderLineLimit.md)), Interchange logs a warning and, if
`LockoutCommand` is set, runs the command with the client IP substituted
for `%s`. The command executes under the Interchange user ID via the shell,
so it must have (through `sudo` or file permissions) whatever privileges it
needs. A non-zero exit status is logged.

After the lockout step, Interchange rewrites the session's `VendURL` and
`SecureURL` to `http://127.0.0.1`, effectively bouncing the client back to
itself, and marks the session locked out.

The directive is read at server startup and applies to all catalogs.

## Examples

Deny the address at the firewall (put in `interchange.cfg`):

```
LockoutCommand ipfwadm -I -i deny -S %s
```

`ipfwadm` is obsolete; a modern equivalent would call `iptables`,
`nft`, or `pf` instead. A command with no `%s` also works -- the IP is
appended:

```
LockoutCommand /usr/local/bin/deny-ip
```

## Notes

A wrapper script can edit access-control files such as `.htaccess`
(web-server level) or `/etc/hosts.deny` (TCP wrappers) for an additional
layer of lockout. Because the command runs as the Interchange user,
grant the necessary privileges deliberately -- do not run Interchange as
root to satisfy it.

## See also

[RobotLimit](RobotLimit.md), [OrderLineLimit](OrderLineLimit.md),
[Limit](Limit.md), the [security](../guides/security.md) guide.

## Source

Stored raw (no parser) from the `global_directives()` table in
`lib/Vend/Config.pm`; invoked in the lockout handler in
`lib/Vend/Error.pm`.
