# ConfigParseComments

> **Obsolete:** as of Interchange 5.5.0 this directive is no longer supported.
> Any value is ignored and a warning is logged; behavior is always as if
> `ConfigParseComments No` were set.

Formerly controlled whether hash-prefixed configuration meta-directives
(`#include`, `#ifdef`, `#ifndef`) were interpreted or treated as plain
comments.

**Scope:** both (`interchange.cfg` global, `catalog.cfg` catalog)

## Syntax

    ConfigParseComments  yes|no

Historically a boolean. Default: empty. In current Interchange the value has no
effect.

## Description

In Interchange 4.6 and earlier, configuration meta-directives were written with
a leading `#` (borrowed from the C preprocessor), which was easily mistaken for
a comment. Versions 4.7 and later switched to the hashless forms (`include`,
`ifdef`, `ifndef`), and `ConfigParseComments` existed to select which
convention applied.

From 5.5.0 onward the directive is retired. Interchange logs a message that it
is no longer supported and ignores whatever value you give it; hash-prefixed
meta-directives are always treated as pure comments, and the hashless forms are
always active.

## Examples

If present in a config file, the directive is accepted but does nothing:

```
ConfigParseComments No
```

Use the hashless meta-directives directly; a `#`-prefixed form is now just a
comment:

```
#include comment
# The line above is a pure comment.

include comment
```

## See also

The [configuration](../guides/configuration.md) and
[upgrading](../guides/upgrading.md) guides.

## Source

Parsed by `parse_warn` in `lib/Vend/Config.pm`, which logs that the directive
is unsupported and discards the value.
