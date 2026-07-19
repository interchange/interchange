# Glimpse

Points Interchange at the `glimpse` search binary and its options, enabling
Glimpse-based full-text search for the catalog. Reach for it only if you have a
legacy Glimpse index; for new work prefer a database or Swish-e search.

> **Deprecated:** Glimpse is unmaintained and non-free. Use a text/SQL search
> (see the [search](../guides/search.md) guide) instead.

**Scope:** catalog (`catalog.cfg`)

## Syntax

    Glimpse  PROGRAM_PATH [options...]

The value is an executable path (optionally with command-line options). The
executable parser resolves it to the first existing program named; the whole
string, including options, is stored for use at search time. Default: empty
(Glimpse search disabled).

## Description

Setting `Glimpse` does two things. At configuration time it causes Interchange
to load the `Vend::Glimpse` search module. At search time, a request whose
search type is Glimpse runs the configured command to query a prebuilt Glimpse
index and returns the matching records.

If `Glimpse` is not set, the Glimpse search type is unavailable: Interchange
clears the `mv_searchtype` when it would select Glimpse, falling back to its
normal search. The command actually run defaults to `glimpse` if the stored
value is somehow empty.

To use `glimpseserver` rather than the standalone binary, include its
`-C`, `-J`, and `-K` options in the value.

## Examples

Enable Glimpse search against a running `glimpseserver` (`catalog.cfg`):

```
Glimpse  /usr/local/bin/glimpse -C -J srch_engine -K2345
```

## Notes

Glimpse indexes must be built and maintained outside Interchange. Because the
project is unmaintained, treat this directive as legacy support only.

## See also

[NoSearch](NoSearch.md), [AllowRemoteSearch](AllowRemoteSearch.md), the
[search](../guides/search.md) guide.

## Source

Parsed by `parse_executable` in `lib/Vend/Config.pm` (which also requires
`Vend::Glimpse` when the directive is set); consumed by `lib/Vend/Glimpse.pm`
and gated in `lib/Vend/Scan.pm`.
