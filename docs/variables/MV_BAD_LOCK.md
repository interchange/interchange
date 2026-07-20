# MV_BAD_LOCK

Works around a broken file-locking mechanism so that stopping the server still
works. Reach for it only on platforms where `interchange -stop` fails because
reading the PID file destroys its lock.

**Scope:** global (`interchange.cfg`)

## Syntax

    Variable  MV_BAD_LOCK  1

A boolean flag. Default: `0` (off).

## Description

On some systems the lock held on the server's PID file is dropped when the file
is read, which prevents a clean shutdown. When `MV_BAD_LOCK` is set to a true
value, Interchange changes how it obtains the parent process ID so that the PID
file lock survives being read, and `interchange -stop` works correctly.

Internally this takes the same code path as pre-forking mode: the server reads
the PID directly when either `PreFork` is enabled or `MV_BAD_LOCK` is set.

## Examples

Enable the workaround:

    Variable  MV_BAD_LOCK  1

## Notes

Leave this off unless you have actually observed `interchange -stop` failing;
it is a compatibility workaround, not a tuning option.

## See also

[MV_GETPPID_BROKEN](MV_GETPPID_BROKEN.md), the
[installation](../guides/installation.md) guide.

## Source

Consumed in `lib/Vend/Server.pm` via
`$Global::Variable->{MV_BAD_LOCK}`.
