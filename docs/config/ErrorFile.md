# ErrorFile

Names the log file that receives error messages. Reach for it to control where
Interchange writes errors, either server-wide or for a single catalog.

**Scope:** both (`interchange.cfg` global, `catalog.cfg` catalog)

## Syntax

    ErrorFile  filename

### Global

In `interchange.cfg`, `ErrorFile` names the file for global (server-level)
error logging, resolved relative to the Interchange root. Default: unset. When
[SysLog](SysLog.md) is not configured, global messages go to this file
(`logGlobal` in `lib/Vend/Util.pm`).

### Catalog

In `catalog.cfg`, `ErrorFile` names the catalog's own error log, given as a path
relative to the catalog root (absolute paths are rejected unless allowed; see
[NoAbsolute](NoAbsolute.md)). Default: `error.log`. Catalog error logging
(`logError`) writes here unless a per-message destination is chosen by
[ErrorDestination](ErrorDestination.md).

## Description

Interchange must have permission to create and append to the named file. The
directory containing it must exist. Catalog errors and many request-level
warnings are appended here with a timestamped log line; the file grows until you
rotate it.

## Examples

Catalog error log in `catalog.cfg` (the strap demo writes into a log
directory):

```
ErrorFile  error.log
```

Global error log in `interchange.cfg`:

```
ErrorFile  /var/log/interchange/error.log
```

## Notes

The directive is `ErrorFile`, not `ErrorLog`. When routing specific errors to
separate files, combine it with [ErrorDestination](ErrorDestination.md). To send
errors to the system logger instead of a file, configure [SysLog](SysLog.md).

## See also

[ErrorDestination](ErrorDestination.md), [SysLog](SysLog.md),
[DebugFile](DebugFile.md), [NoAbsolute](NoAbsolute.md), the
[logging-debugging](../guides/logging-debugging.md) guide.

## Source

Parsed by `parse_root_dir` (global) and `parse_relative_dir` (catalog) in
`lib/Vend/Config.pm`; consumed in `lib/Vend/Util.pm` (`logError`,
`logGlobal`) and `lib/Vend/Server.pm`.
