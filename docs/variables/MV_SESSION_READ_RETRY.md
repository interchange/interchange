# MV_SESSION_READ_RETRY

Sets how many times the server retries reading a visitor's session file before
giving up. Reach for it on busy or slow-storage systems where a session file is
occasionally mid-write when another process tries to read it.

**Scope:** global (`interchange.cfg`)

## Syntax

    Variable  MV_SESSION_READ_RETRY  count

`count` is an integer number of attempts. Default: `5`.

## Description

When Interchange fails to read a session file, it waits briefly and tries
again, up to `MV_SESSION_READ_RETRY` times, before treating the session as
unreadable. Raising the value trades a slightly longer worst-case delay for
resilience against transient read failures; lowering it makes the server give
up sooner.

The value is read from the global variable space, so set it in
`interchange.cfg` (or in the global section of a `variable` file), not in a
single catalog.

## Examples

Reduce the number of retries to three:

    Variable  MV_SESSION_READ_RETRY  3

## Notes

The value is read as `$Global::Variable->{MV_SESSION_READ_RETRY}`; a missing or
non-numeric value falls back to the built-in default of `5`.

## See also

The [sessions](../guides/sessions.md) guide.

## Source

Consumed in `lib/Vend/Session.pm` via
`$Global::Variable->{MV_SESSION_READ_RETRY}`.
