# MV_GETPPID_BROKEN

Enables a workaround for a broken `getppid()` on Linux systems running a
thread-enabled Perl. Reach for it only if the server misbehaves detecting its
parent process on such a Perl build.

**Scope:** global (`interchange.cfg`)

## Syntax

    Variable  MV_GETPPID_BROKEN  1

A boolean flag. Default: `0` (off).

## Description

On Linux with a thread-enabled Perl, the `getppid()` function can return the
wrong value. When `MV_GETPPID_BROKEN` is set to a true value, Interchange calls
`syscall(64)` to obtain the parent process ID instead of using Perl's
`getppid()`.

Since Interchange 5.0 this variable ships enabled in the Debian/GNU
`features.cfg` so the server runs on Debian releases that carry a threaded
Perl.

## Examples

Enable the workaround:

    Variable  MV_GETPPID_BROKEN  1

## Notes

Running Interchange in production on a thread-enabled Perl is discouraged; this
variable exists to keep it functional where that Perl is unavoidable.

## See also

[MV_BAD_LOCK](MV_BAD_LOCK.md), the
[installation](../guides/installation.md) guide.

## Source

Consumed in `lib/Vend/Server.pm` via
`$Global::Variable->{MV_GETPPID_BROKEN}`.
