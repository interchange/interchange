# ErrorDestination

Routes selected error messages to their own log files, keyed by an error's tag
or by its message text. Reach for it to split noisy or category-specific errors
out of the main error log without adding a `file` attribute to every logging
call.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    ErrorDestination  tag_or_message  filename

`key value` pairs collected into a hash (shell-quote the key when it contains
spaces). The key is either an arbitrary error tag or the exact error message
text; the value is the log file to receive matching errors. Default: empty (all
errors go to [ErrorFile](ErrorFile.md)).

## Description

When Interchange logs a catalog error (`logError` in `lib/Vend/Util.pm`), it
looks up a destination before falling back to [ErrorFile](ErrorFile.md). The
lookup key is the error's `tag` option if one was supplied, otherwise the
message text itself. If that key matches an `ErrorDestination` entry, the error
is written to the named file instead of the default log.

This lets you tag error-producing code (for example in a `[perl]` block, by
passing a `tag` to `logError`) or match on a fixed message string, and direct
those errors to a dedicated file -- configured once in `catalog.cfg` rather than
at every logging site.

## Examples

Route two known messages to their own files (from the strap `catalog.cfg`):

```
ErrorDestination  "Run jobs group=%s pid=%s"       error/jobs_run.log
ErrorDestination  "Finished jobs group=%s pid=%s"  error/jobs_run.log
```

Route everything tagged `search` to a search-error log:

```
ErrorDestination  search  error/search_errors.log
```

with catalog Perl that tags its errors:

```perl
::logError('Bad search column ' . $_, { tag => 'search' });
```

## Notes

Matching on message text requires the key to equal the message exactly (before
any locale translation of the message), so tag-based routing is usually more
robust. Tag-based routing (`tag=`) does not apply to
`[log type=error]...[/log]`.

## See also

[ErrorFile](ErrorFile.md), [SysLog](SysLog.md), the
[logging-debugging](../guides/logging-debugging.md) guide.

## Source

Parsed by `parse_hash` in `lib/Vend/Config.pm`; consumed in
`lib/Vend/Util.pm` (`logError`, `$Vend::Cfg->{ErrorDestination}`).
