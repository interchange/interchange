# CounterDir

Sets the base directory under which the [counter](../tags/counter.md) tag
and other counter files are stored when their filename is not absolute.
Reach for it to keep counter files together in one directory rather than
scattered relative to the catalog root.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    CounterDir  DIRECTORY

A single relative directory (`parse_relative_dir`), resolved against the
catalog root. An absolute path is rejected. Default: empty.

## Description

When a counter is referenced by a relative filename, Interchange prepends
this directory to form the full path:

```perl
my $basedir = $Vend::Cfg->{CounterDir} || $Vend::Cfg->{VendRoot};
```

If `CounterDir` is empty (the default), counter files are placed relative
to the catalog root (`VendRoot`) instead. An absolute filename passed to
a counter bypasses `CounterDir` entirely.

The directory is consumed in `lib/Vend/Interpolate.pm` by the counter
machinery behind the [counter](../tags/counter.md) tag.

## Examples

Store counter files under a `counters` subdirectory of the catalog:

```
CounterDir counters
```

A relative counter then lands there:

```
[counter file="orders.number"]
```

writes to `counters/orders.number` within the catalog root.

## Notes

The path must be relative; an absolute directory raises a configuration
error. To place counters outside the catalog tree, give an absolute
filename to the individual [counter](../tags/counter.md) tag instead.

## See also

[counter](../tags/counter.md), [OrderCounter](OrderCounter.md), the
[templating](../guides/templating.md) guide.

## Source

Parsed by `parse_relative_dir` in `lib/Vend/Config.pm`; consumed via
`$Vend::Cfg->{CounterDir}` in `lib/Vend/Interpolate.pm`.
