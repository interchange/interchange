# ProcessPage

Names the virtual page that receives form submissions and searches -- the
form-processor target. Reach for it only if you must rename the default
`process` action path.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    ProcessPage  name

A single page name. Default: `process`.

## Description

The process page is not a file on disk; it is a built-in
[ActionMap](ActionMap.md) that runs form and search submissions. Its name is
whatever `ProcessPage` holds. The [process](../tags/process.md) tag uses this
name as the default path when building a form action, and the dispatcher
(`lib/Vend/Dispatch.pm`) recognizes an incoming path under
`/<ProcessPage>/...` as a form-processing request, stripping optional
`locale`, `language`, and `currency` segments from it.

The default of `process` satisfies almost all catalogs and rarely needs to
change.

## Examples

Rename the processor path to `proc` (in `catalog.cfg`):

```
ProcessPage proc
```

## See also

[process](../tags/process.md), [ActionMap](ActionMap.md),
[PostURL](PostURL.md), the [forms](../guides/forms.md) guide.

## Source

Stored with no parser (raw string) in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{ProcessPage}` in `lib/Vend/Dispatch.pm`, `lib/Vend/Util.pm`,
and `code/SystemTag/process.coretag`.
