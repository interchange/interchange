# PIDfile

Names the file that holds the process ID of the master Interchange server.
Reach for it to place the PID file where your init or service scripts expect
it, so they can signal the daemon to stop or restart.

**Scope:** global (`interchange.cfg`)

## Syntax

    PIDfile  path

A single file path, made absolute against the Interchange root if given
relative. Default: `etc/<exename>.pid` (for example `etc/interchange.pid`).

## Description

On startup the master server writes its process ID to this file, and the
`bin/interchange` control commands (stop, restart, reconfigure) read it to
find the daemon to signal -- the standard Unix approach for locating a
running service. The path is consumed as `$Global::PIDfile` in
`lib/Vend/Control.pm`, `lib/Vend/Server.pm`, and `lib/Vend/ModPerl.pm`.

The directory holding the file must be writable by the Interchange daemon
user.

## Examples

Store the PID file under the system run directory (in `interchange.cfg`):

```
PIDfile /var/run/interchange/interchange.pid
```

## See also

[PIDcheck](PIDcheck.md), [IPCsocket](IPCsocket.md), [RunDir](RunDir.md),
the [installation](../guides/installation.md) guide.

## Source

Parsed by `parse_root_dir` in `lib/Vend/Config.pm`; consumed via
`$Global::PIDfile` in `lib/Vend/Control.pm`, `lib/Vend/Server.pm`, and
`lib/Vend/ModPerl.pm`.
